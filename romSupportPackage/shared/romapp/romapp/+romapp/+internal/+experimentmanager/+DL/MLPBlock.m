classdef MLPBlock < romapp.internal.experimentmanager.ExportToSL
    % MLPBLOCK creates an MLP sub-system block for ROM–Simulink workflow.

    % Copyright 2026 The MathWorks, Inc.
    
    properties
        InNames   cell = {}
        OutNames  cell = {}
    end

    methods
        function obj = MLPBlock(varargin)
            obj = obj@romapp.internal.experimentmanager.ExportToSL(varargin{:});
        end

        function obj = extractIONames(obj, trainingOutput)
            inNames = strsplit(trainingOutput.Network.InputNames{1}, ', ');
            outNames = strsplit(trainingOutput.Network.OutputNames{1}, ', ');

            % Normalize newlines -> space, '/' -> '_'(path-safe)
            cleanNames = @(c) cellstr( ...
                strtrim( ...
                regexprep( ...
                replace( ...
                replace(string(c), [newline, char(13), char(10)], " "), ...
                "/", "_"), ...
                "\s+", " ")) ); %#ok<CHARTEN>

            obj.InNames  = cleanNames(inNames);
            obj.OutNames = cleanNames(outNames);
        end
    end

    methods (Access = protected)
        function createROMSLBlock(this, subsystemPath, trainingOutput)
            %CREATEROMSLBLOCK Creates the ROM_Block sub-system which is
            %unique for every model type

            % I/O metadata
            inVarNames  = this.InNames;
            outVarNames = this.OutNames;

            % 1) Normalization vectors
            rawInName = strsplit(trainingOutput.Network.InputNames{1}, ', ');
            rawOutName = strsplit(trainingOutput.Network.OutputNames{1}, ', ');
            [muInputs, sigmaInputs, muOutputs, sigmaOutputs] = ...
                getNormalizationVectors(trainingOutput, rawInName, rawOutName);

            % 2) Save model struct
            modelFile = romapp.internal.experimentmanager.utils.saveModel(trainingOutput);

            % 3) Build subsystem
            load_system(subsystemPath);  % ensure the subsystem is loaded

            % 3a) Inports
            muxOutH = romapp.internal.experimentmanager.utils.configureSLInputBlocks(subsystemPath, inVarNames);

            % 3b) Normalize (double in/out)
            normPath = [subsystemPath '/Normalize'];
            romapp.internal.experimentmanager.utils.createNormalizationSubsystem( ...
                subsystemPath, 'Normalize', muInputs, sigmaInputs, [160 90 280 130]);

            phNorm   = get_param(normPath, 'PortHandles');
            normInH  = phNorm.Inport(1);
            normOutH = phNorm.Outport(1);
            add_line(subsystemPath, muxOutH, normInH, 'autorouting','on');

            % 3c) Convert to single for Predict
            dtcInPath = [subsystemPath '/DTC_to_single'];
            add_block('simulink/Signal Attributes/Data Type Conversion', dtcInPath, ...
                'Position',[290 92 320 128], ...
                'OutDataTypeStr','single');

            phDtcIn   = get_param(dtcInPath, 'PortHandles');
            dtcInInH  = phDtcIn.Inport(1);
            dtcInOutH = phDtcIn.Outport(1);
            add_line(subsystemPath, normOutH, dtcInInH, 'autorouting','on');

            % 3d) Predict (dlnetwork)
            dlBlockPath = [subsystemPath '/Predict'];
            add_block('deeplib/Predict', dlBlockPath, ...
                'Position', [320 90 420 130], ...
                'NetworkFilePath', modelFile);

            phPred   = get_param(dlBlockPath, 'PortHandles');
            predInH  = phPred.Inport(1);
            predOutH = phPred.Outport(1);
            add_line(subsystemPath, dtcInOutH, predInH, 'autorouting','on');

            % 3e) Convert back to double after Predict
            dtcOutPath = [subsystemPath '/DTC_to_double'];
            add_block('simulink/Signal Attributes/Data Type Conversion', dtcOutPath, ...
                'Position',[430 92 460 128], ...
                'OutDataTypeStr','double');

            phDtcOut   = get_param(dtcOutPath, 'PortHandles');
            dtcOutInH  = phDtcOut.Inport(1);
            dtcOutOutH = phDtcOut.Outport(1);
            add_line(subsystemPath, predOutH, dtcOutInH, 'autorouting','on');

            % 3f) Denormalize (double in/out)
            denormPath = [subsystemPath '/Denormalize'];
            romapp.internal.experimentmanager.utils.createDenormalizationSubsystem( ...
                subsystemPath, 'Denormalize', muOutputs, sigmaOutputs, [460 90 560 130]);

            phDen   = get_param(denormPath, 'PortHandles');
            denInH  = phDen.Inport(1);
            denOutH = phDen.Outport(1);
            add_line(subsystemPath, dtcOutOutH, denInH, 'autorouting','on');

            % 3g) Outports
            romapp.internal.experimentmanager.utils.configureSLOutputBlocks(subsystemPath, outVarNames, denOutH);
        end
    end
end

% Local helpers
function [muIn, sigIn, muOut, sigOut] = getNormalizationVectors(trainingOutput, inVars, outVars)
% Returns row vectors of mu/sigma for inputs and outputs in the provided order.
Tmu  = trainingOutput.Normalization.Mu;
Ts   = trainingOutput.Normalization.Sigma;

muIn  = table2array(Tmu(:,  inVars));   sigIn  = table2array(Ts(:, inVars));
muOut = table2array(Tmu(:,  outVars));  sigOut = table2array(Ts(:, outVars));
end