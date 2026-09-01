classdef NLARXBlock < romapp.internal.experimentmanager.ExportToSL
    % NLARXBLOCK creates Nonlinear ARX sub-system block for ROM–Simulink workflow.
    
    % Copyright 2026 The MathWorks, Inc.
    
    properties
        InNames   cell = {}
        OutNames  cell = {}
    end

    methods
        function obj = NLARXBlock(varargin)
            obj = obj@romapp.internal.experimentmanager.ExportToSL(varargin{:});
        end

        function obj = extractIONames(obj, trainingOutput)
            inNames  = cellstr(trainingOutput.NonlinearModel.InputName(:));
            outNames = cellstr(trainingOutput.NonlinearModel.OutputName(:));

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

            % 1) Get the identified NLARX model
            sys = trainingOutput.NonlinearModel;

            % 2) Names
            inVarNames  = this.InNames;   
            outVarNames = this.OutNames; 

            % 3) Save the model struct and assign model var to workspace
            [modelFile, modelVarName] = romapp.internal.experimentmanager.utils.saveModel(trainingOutput, 'NLARX');
            assignin('base', modelVarName, sys);

            % 4) Build subsystem
            load_system(bdroot(subsystemPath));
            load_system(subsystemPath);

            % 4a) Inports
            muxOutH = romapp.internal.experimentmanager.utils.configureSLInputBlocks(subsystemPath, inVarNames);

            % 4b) Nonlinear ARX block
            narxPath = [subsystemPath '/NonlinearARX'];
            add_block('slident/Models/Nonlinear ARX Model', narxPath, ...
                      'Position', [310 90 430 130], ...
                      'sys', modelVarName);  % reference to base workspace variable

            phNarx   = get_param(narxPath, 'PortHandles');
            narxInH  = phNarx.Inport(1);
            narxOutH = phNarx.Outport(1);

            % Mux -> NLARX
            add_line(subsystemPath, muxOutH, narxInH, 'autorouting','on');

            % 4c) Outputs
            romapp.internal.experimentmanager.utils.configureSLOutputBlocks(subsystemPath, outVarNames, narxOutH);

            % 5) Persist meta-data in the subsystem due to hard dependency 
            % on the workspace var
            set_param(subsystemPath, 'UserData', struct( ...
                'ROMType', 'NLARX', ... 
                'ModelFile', modelFile, ...
                'ModelVar', modelVarName));

            % Set user discoverable info about the var and the MAT file
            desc = romapp.internal.resources.getString('descROMBlock', modelVarName, modelFile);
            set_param(subsystemPath, 'Description', desc);
        end
    end
end