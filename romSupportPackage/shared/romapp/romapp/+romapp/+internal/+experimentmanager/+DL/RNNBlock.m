classdef RNNBlock < romapp.internal.experimentmanager.ExportToSL
    % RNNBLOCK creates an RNN/LSTM sub-system block for ROM–Simulink workflow.
    
    % Copyright 2026 The MathWorks, Inc.
    
    properties
        InNames   cell = {}
        OutNames  cell = {}
    end

    methods
        function obj = RNNBlock(varargin)
            obj = obj@romapp.internal.experimentmanager.ExportToSL(varargin{:});
        end

        function obj = extractIONames(obj, trainingOutput)
            inNames  = trainingOutput.Normalization.Inputs.Mu.Properties.VariableNames;
            outNames = trainingOutput.Normalization.Outputs.Mu.Properties.VariableNames;

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

            % Inputs / names
            inVarNames  = this.InNames;
            outVarNames = this.OutNames;

            % 1) Get Normalization data (grouped struct-of-tables)
            muInputs     = rowVec(table2array(trainingOutput.Normalization.Inputs.Mu));
            sigmaInputs  = rowVec(table2array(trainingOutput.Normalization.Inputs.Sigma));
            muOutputs    = rowVec(table2array(trainingOutput.Normalization.Outputs.Mu));
            sigmaOutputs = rowVec(table2array(trainingOutput.Normalization.Outputs.Sigma));
            muInputsSel    = muInputs;
            sigmaInputsSel = sigmaInputs;

            % 2) Make network codegen-able & save the model struct
            % Preserve your behavior: ensure projected layers are unpacked prior to save.
            net = trainingOutput.Network;
            if hasProjectedLayers(net)
                if exist('unpackProjectedLayers','file') == 2
                    trainingOutput.Network = unpackProjectedLayers(net);
                else
                    romapp.internal.resources.error('errCompressedRNNLayers');
                end
            else
                trainingOutput.Network = net;
            end
            modelFile = romapp.internal.experimentmanager.utils.saveModel(trainingOutput);

            % 3) Build subsystem
            load_system(subsystemPath);  % ensure the subsystem is loaded

            % 3a) Inputs
            muxOutH = romapp.internal.experimentmanager.utils.configureSLInputBlocks(subsystemPath, inVarNames);

            % 3b) Normalize (double in/out)
            normPath = [subsystemPath '/Normalize'];
            romapp.internal.experimentmanager.utils.createNormalizationSubsystem( ...
                subsystemPath, 'Normalize', muInputsSel, sigmaInputsSel, [260 90 380 130]);

            phNorm   = get_param(normPath, 'PortHandles');
            normInH  = phNorm.Inport(1);
            normOutH = phNorm.Outport(1);
            add_line(subsystemPath, muxOutH, normInH, 'autorouting','on');

            % 3c) Data Type Conversion to single (for Stateful Predict)
            dtcInPath = [subsystemPath '/DTC_to_single'];
            add_block('simulink/Signal Attributes/Data Type Conversion', dtcInPath, ...
                      'Position', [385 92 415 128], ...
                      'OutDataTypeStr', 'single');

            phDtcIn   = get_param(dtcInPath, 'PortHandles');
            dtcInInH  = phDtcIn.Inport(1);
            dtcInOutH = phDtcIn.Outport(1);
            add_line(subsystemPath, normOutH, dtcInInH, 'autorouting','on');

            % 3d) Stateful Predict
            lstmPath = [subsystemPath '/StatefulPredict'];
            add_block('deeplib/Stateful Predict', lstmPath, ...
                      'Position', [410 90 530 130], ...
                      'NetworkFilePath', modelFile);

            % SampleTime setting
            if isfield(trainingOutput, 'SampleRate') && ~isempty(trainingOutput.SampleRate)
                set_param(lstmPath, 'SampleTime', num2str(trainingOutput.SampleRate));
            end

            phLstm   = get_param(lstmPath, 'PortHandles');
            lstmInH  = phLstm.Inport(1);
            lstmOutH = phLstm.Outport(1);
            add_line(subsystemPath, dtcInOutH, lstmInH, 'autorouting','on');

            % 3e) Data Type Conversion back to double
            dtcOutPath = [subsystemPath '/DTC_to_double'];
            add_block('simulink/Signal Attributes/Data Type Conversion', dtcOutPath, ...
                      'Position', [535 92 565 128], ...
                      'OutDataTypeStr', 'double');

            phDtcOut   = get_param(dtcOutPath, 'PortHandles');
            dtcOutInH  = phDtcOut.Inport(1);
            dtcOutOutH = phDtcOut.Outport(1);
            add_line(subsystemPath, lstmOutH, dtcOutInH, 'autorouting','on');

            % 3f) Denormalize (double in/out)
            denormPath = [subsystemPath '/Denormalize'];
            romapp.internal.experimentmanager.utils.createDenormalizationSubsystem( ...
                subsystemPath, 'Denormalize', muOutputs, sigmaOutputs, [560 90 680 130]);

            phDenorm = get_param(denormPath, 'PortHandles');
            denInH   = phDenorm.Inport(1);
            denOutH  = phDenorm.Outport(1);
            add_line(subsystemPath, dtcOutOutH, denInH, 'autorouting','on');

            % 3g) Outputs
            romapp.internal.experimentmanager.utils.configureSLOutputBlocks(subsystemPath, outVarNames, denOutH);
        end
    end
end

% Local helper
function r = rowVec(x)
    % Ensure a row vector (1×N) regardless of input shape.
    r = x(:).';
end

function tf = hasProjectedLayers(net)
try
    layerClasses = arrayfun(@class, net.Layers, 'UniformOutput', false);
    tf = any(contains(layerClasses, 'ProjectedLayer', 'IgnoreCase', true));
catch
    % If net.Layers is inaccessible the ProjectedLayer class is missing,
    % which itself indicates the network contains compressed layers from an
    % unavailable library.
    tf = true;
end
end
