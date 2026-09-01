classdef ExportToSL < experiments.internal.AbstractExportMenuPlugin
    % EXPORTTOSL class - Essential for adding the custom export menu. The 
    % callback functionality of the new export item resides here.
    
    % Copyright 2026 The MathWorks, Inc.

    properties
        Icon = "export_simulink"
        Title = romapp.internal.resources.getString('lblExportToSimulinkTitle')
        Description = romapp.internal.resources.getString('lblExportToSimulinkDesc')
    end

    methods (Abstract, Access = protected)
        createROMSLBlock(obj)
    end

    methods
        function exportCallback(this, param, trainingOutput)
            % EXPORTCALLBACK - Builds a top-level ROM_Block model and 
            % delegates the inner "ROM_Block" construction to its model 
            % specific subclass.
            arguments
                this 
                param struct
                trainingOutput struct
            end

            % 1) Create new empty model 
            systemHandle = new_system('', 'model');  % MATLAB assigns "untitledX"
            sysName = get_param(systemHandle, 'Name');
            load_system(sysName);

            % 2) Add Sample rate to the trainingOutput struct (only relevant for RNN as of now)
            if isstruct(param) && isfield(param, 'SampleRate')
                trainingOutput.SampleRate = param.SampleRate;
            end

            % 3) Ask subclass for I/O names (and let it cache extras)
            this = this.extractIONames(trainingOutput);
            inNames  = this.InNames;
            outNames = this.OutNames;

            nIn  = numel(inNames);
            nOut = numel(outNames);

            % 4) Parameter inputs detection
            hasParams  = isfield(trainingOutput, 'Parameters') && istable(trainingOutput.Parameters) && height(trainingOutput.Parameters) == 1;
            paramMask  = false(1, nIn);
            paramColIx = nan(1, nIn);
            pNames     = {};
            
            % Parameter names might not have exact name match and need 
            % regex to map the exact parameter name with the legit inputs
            % to the ROM_Block
            if hasParams    
                pNames = trainingOutput.Parameters.Properties.VariableNames;
                % canonical form: lowercase & remove non [a-z0-9]
                canon = @(s) regexprep(lower(string(s)), '[^a-z0-9]', '');
                inC = cellfun(canon, inNames, 'UniformOutput', false);
                pC  = cellfun(canon, pNames, 'UniformOutput', false);

                % unified full/partial match (either side contains the other)
                for i = 1:nIn
                    m1  = cellfun(@(s) contains(s,      inC{i}), pC);  % param contains input
                    m2  = cellfun(@(s) contains(inC{i}, s),      pC);  % input contains param
                    hit = find(m1 | m2, 1, 'first');
                    paramMask(i)  = ~isempty(hit);
                    if paramMask(i)
                        paramColIx(i) = hit; 
                    end
                end
            end

            % 5) Create ROM_Block placeholder
            subsystemPath = [sysName '/ROM_Block'];
            add_block('built-in/Subsystem', subsystemPath, 'Position', [180 80 280 140]);

            % 6) Add N top-level inputs
            xInL = 50; xInR = 80; y0 = 50; dy = 40;
            inBlkPaths = cell(1, nIn);
            inOutPH    = zeros(1, nIn);

            for k = 1:nIn
                pos           = [xInL, y0 + (k-1)*dy, xInR, y0 + (k-1)*dy + 20];
                inBlkPaths{k} = [sysName '/' inNames{k}];

                if hasParams && paramMask(k) && ~isnan(paramColIx(k))
                    % Parameter input -> Constant block with scalar/array value
                    add_block('simulink/Sources/Constant', inBlkPaths{k}, 'Position', pos);
                    v = trainingOutput.Parameters{1, pNames{paramColIx(k)}};
                    set_param(inBlkPaths{k}, 'Value', mat2str(v));
                else
                    % External input -> Inport
                    add_block('simulink/Sources/In1', inBlkPaths{k}, 'Position', pos);
                end

                ph = get_param(inBlkPaths{k}, 'PortHandles');
                inOutPH(k) = ph.Outport(1);
            end

            % 7) Add outports(s) and collect outport input handles
            xOutL = 350; xOutR = 380; yOut0 = 50; dyOut = 40;

            outBlkPaths = cell(1, nOut);
            sinkInPH    = zeros(1, nOut);

            for k = 1:nOut
                pos = [xOutL, yOut0 + (k-1)*dyOut, xOutR, yOut0 + (k-1)*dyOut + 20];
                outBlkPaths{k} = [sysName '/' outNames{k}];
                add_block('simulink/Sinks/Out1', outBlkPaths{k}, 'Position', pos);

                ph = get_param(outBlkPaths{k}, 'PortHandles');
                sinkInPH(k) = ph.Inport(1);
            end

            % 8) Call to subclass to build the ROM sub-system
            this.createROMSLBlock(subsystemPath, trainingOutput);

            % 9) Wire sources -> ROM_Block -> sinks
            phROM    = get_param(subsystemPath, 'PortHandles');
            romInPH  = phROM.Inport;
            romOutPH = phROM.Outport;

            % Inputs: source.Out -> ROM_Block.In(k)
            for k = 1:nIn
                set_param(inBlkPaths{k}, 'Name', inNames{k});
                add_line(sysName, inOutPH(k), romInPH(k), 'autorouting', 'on');
            end

            % Outputs: ROM_Block.Out(k) -> outport.In(k)
            for k = 1:nOut
                set_param(outBlkPaths{k}, 'Name', outNames{k});
                add_line(sysName, romOutPH(k), sinkInPH(k), 'autorouting', 'on');
            end

            % 10) Arrange & open
            Simulink.BlockDiagram.arrangeSystem(sysName);
            Simulink.BlockDiagram.arrangeSystem(subsystemPath);
            open_system(sysName);
            set_param(sysName, 'ZoomFactor', 'FitSystem');
        end
    end
end