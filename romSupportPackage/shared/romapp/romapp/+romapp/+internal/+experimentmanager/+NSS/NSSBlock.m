classdef NSSBlock < romapp.internal.experimentmanager.ExportToSL
    % NSSBLOCK creates Neural State Space sub-system block for ROM–Simulink workflow.
    
    % Copyright 2026 The MathWorks, Inc.
    
    properties
        InNames   cell = {}
        OutNames  cell = {}
        RawInNames cell = {}
        RawOutNames cell = {}
        PostIdx   double = []   % indices of "(t)" outputs
    end

    methods
        function obj = NSSBlock(varargin)
            obj = obj@romapp.internal.experimentmanager.ExportToSL(varargin{:});
        end

        function obj = extractIONames(obj, trainingOutput)
            %Extract input and trainingOutput names from the NSS model object along
            %with the trainingOutput order for appropriate signal selection
            sys = trainingOutput.NSSModel;

            inAll  = cellstr(sys.InputName(:));
            outAll = cellstr(sys.OutputName(:));

            % Keep only "(t)" outputs; compute indices
            hasParenT = ~cellfun(@isempty, regexp(outAll, '\(t\)\s*$', 'once'));
            hasUndT   = ~cellfun(@isempty, regexp(outAll, '_t\s*$',   'once'));
            obj.PostIdx = find(hasParenT | hasUndT);

            % Strip transient suffixes for display/IDs
            stripT = @(s) strtrim(regexprep(regexprep(s, '\(t\)\s*$', ''), '_t\s*$', ''));
            obj.RawInNames  = cellfun(stripT, inAll,  'UniformOutput', false);
            obj.RawOutNames = cellfun(stripT, outAll(obj.PostIdx), 'UniformOutput', false);

            % Normalize newlines -> space, '/' -> '_'(path-safe)
            cleanNames = @(c) cellstr( ...
                strtrim( ...
                regexprep( ...
                replace( ...
                replace(string(c), [newline, char(13), char(10)], " "), ...
                "/", "_"), ...
                "\s+", " ")) ); %#ok<CHARTEN>

            % Cache for later use by createROMSLBlock
            obj.InNames  = cleanNames(obj.RawInNames);
            obj.OutNames = cleanNames(obj.RawOutNames);
        end
    end

    methods (Access = protected)
        function createROMSLBlock(this, subsystemPath, trainingOutput)
            %CREATEROMSLBLOCK Creates the ROM_Block sub-system which is
            %unique for every model type

            % 1) Get the NSS model
            sys = trainingOutput.NSSModel;

            % 2) Use names and order cached in class properties
            inVarNames  = this.InNames;          
            outVarNames = this.OutNames;        
            postIdx     = this.PostIdx;  % indices into NSSModel.OutputName for "(t)" outputs

            % 3) Normalization vectors
            [muInputs, sigmaInputs, muOutputs, sigmaOutputs] = ...
                getNormalizationVectors(trainingOutput, this.RawInNames, this.RawOutNames);

            % 4) Save the model struct and assign model var to workspace
            [modelFile, modelVarName] = romapp.internal.experimentmanager.utils.saveModel(trainingOutput, 'NSS');
            assignin('base', modelVarName, sys);

            % 5) Build subsystem
            load_system(bdroot(subsystemPath));
            load_system(subsystemPath);

            % 5a) Inports
            muxOutH = romapp.internal.experimentmanager.utils.configureSLInputBlocks(subsystemPath, inVarNames);

            % 5b) Normalize (double)
            normPath = [subsystemPath '/Normalize'];
            romapp.internal.experimentmanager.utils.createNormalizationSubsystem( ...
                subsystemPath, 'Normalize', muInputs, sigmaInputs, [250 90 370 130]);

            phNorm   = get_param(normPath, 'PortHandles');
            normInH  = phNorm.Inport(1);
            normOutH = phNorm.Outport(1);
            add_line(subsystemPath, muxOutH, normInH, 'autorouting','on');

            % 5c) Neural State Space model (double)
            nssPath = [subsystemPath '/NeuralStateSpace'];
            add_block('slident/Models/Neural State Space Model', nssPath, ...
                      'Position', [390 90 510 130], ...
                      'sys', modelVarName);  % reference to base workspace variable

            phNSS   = get_param(nssPath, 'PortHandles');
            nssInH  = phNSS.Inport(1);
            nssOutH = phNSS.Outport(1);
            add_line(subsystemPath, normOutH, nssInH, 'autorouting','on');

            % 5d) Post-NSS Selector: pick only "(t)" outputs by indices (postIdx)
            postSelPath = [subsystemPath '/PostSignalSelector'];
            add_block('simulink/Signal Routing/Selector', postSelPath, ...
                      'Position', [520 90 570 130], ...
                      'NumberOfDimensions', '1', ...
                      'IndexOptionArray',   {'Index vector (dialog)'}, ...
                      'IndexMode',          'One-based', ...
                      'Indices',            mat2str(postIdx), ...
                      'InputPortWidth',     mat2str(numel(sys.OutputName)));

            phPostSel   = get_param(postSelPath, 'PortHandles');
            postSelInH  = phPostSel.Inport(1);
            postSelOutH = phPostSel.Outport(1);
            add_line(subsystemPath, nssOutH, postSelInH, 'autorouting','on');

            % 5e) Denormalize (double)
            denormPath = [subsystemPath '/Denormalize'];
            romapp.internal.experimentmanager.utils.createDenormalizationSubsystem( ...
                subsystemPath, 'Denormalize', muOutputs, sigmaOutputs, [580 90 700 130]);

            phDen   = get_param(denormPath, 'PortHandles');
            denInH  = phDen.Inport(1);
            denOutH = phDen.Outport(1);
            add_line(subsystemPath, postSelOutH, denInH, 'autorouting','on');

            % 5f) Outputs
            romapp.internal.experimentmanager.utils.configureSLOutputBlocks(subsystemPath, outVarNames, denOutH);

            % 6) Persist meta-data in the subsystem due to hard dependency 
            % on the workspace var
            set_param(subsystemPath, 'UserData', struct( ...
                'ROMType', 'NSS', ... 
                'ModelFile', modelFile, ...
                'ModelVar', modelVarName));
            
            % Set user discoverable info about the var and the MAT file
            desc = romapp.internal.resources.getString('descROMBlock', modelVarName, modelFile);
            set_param(subsystemPath, 'Description', desc);

        end
    end
end

% Local Helpers
function [muIn, sigIn, muOut, sigOut] = getNormalizationVectors(trainingOutput, inVars, outVars)
    Tmu  = trainingOutput.Normalization.Mu;
    Ts   = trainingOutput.Normalization.Sigma;

    muIn  = table2array(Tmu(:,  inVars));   sigIn  = table2array(Ts(:, inVars));
    muOut = table2array(Tmu(:,  outVars));  sigOut = table2array(Ts(:, outVars));

    muIn  = muIn(:);  sigIn  = sigIn(:);
    muOut = muOut(:); sigOut = sigOut(:);
end