classdef ModelPorts < handle
    %

    %MODELPORTS
    %

    % Copyright 2022-2024 The MathWorks, Inc.

    properties(SetObservable)
        InputSignals Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
        OutputSignals Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
        InputParameters romapp.internal.data.ModelParameter = romapp.internal.data.ModelParameter.empty
        ExperimentInputSignals Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
        ExperimentInputParameters romapp.internal.data.ModelParameter = romapp.internal.data.ModelParameter.empty
    end

    properties
        LoggedOutputs Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
    end

    properties(GetAccess = public, SetAccess = private)
        Version
    end

    properties(Access = protected)
        hasScalarOutput_ 
    end

    events(NotifyAccess = protected)
        DataChanged
    end

    methods
        function obj = ModelPorts(varargin)
            %MODELPORTS
            %

            obj.Version = '1.0'; %Original version
            obj.Version = '2.0'; %Added LoggedOutputs
            obj.hasScalarOutput_ = false;
        end

        function setPorts(this,options)
            arguments
                this romapp.internal.data.ModelPorts
                options.SimulationInputs Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
                options.Inputs Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
                options.Outputs Simulink.SimulationData.Signal =  Simulink.SimulationData.Signal.empty
                options.LoggedOutputs Simulink.SimulationData.Signal =  Simulink.SimulationData.Signal.empty
                options.Parameters romapp.internal.data.ModelParameter = romapp.internal.data.ModelParameter.empty
                options.SimulationParameters romapp.internal.data.ModelParameter = romapp.internal.data.ModelParameter.empty
            end

            this.ExperimentInputSignals = options.SimulationInputs;
            this.ExperimentInputParameters = options.SimulationParameters;
            this.InputSignals = options.Inputs;
            this.OutputSignals = options.Outputs;
            this.InputParameters = options.Parameters;
            this.LoggedOutputs = options.LoggedOutputs;
            
            notify(this,'DataChanged')
        end

        function num = getNumPorts(this)
            num = numel(this.InputSignals) + ...
                numel(this.InputParameters) + ...
                numel(this.OutputSignals);
        end

        function loadSavedData(this,savedData)

            this.InputSignals = savedData.InputSignals;
            this.OutputSignals = savedData.OutputSignals;
            this.InputParameters = savedData.InputParameters;
            this.ExperimentInputSignals =  savedData.ExperimentInputSignals;
            this.ExperimentInputParameters =  savedData.ExperimentInputParameters;
            this.LoggedOutputs = savedData.LoggedOutputs;
            this.hasScalarOutput_ = savedData.hasScalarOutput_;
            
            notify(this,'DataChanged')
        end

        function tf = hasSignalInput(this)

            tf = ~isempty(this.InputSignals);
        end
        function tf = hasScalarOutput(this,value)

            if nargin > 1
                this.hasScalarOutput_ = value;
            end
            if nargout > 0
                tf = this.hasScalarOutput_;
            end
        end

        function spec = convertToImportSpec(this)
            %convertToImportSpec
            %
            % Convert the port definitions to
            % romapp.internal.data.ImportDataSpec to be used to import data
            % into the app.

            spec = romapp.internal.data.ImportDataSpec.empty;
            names = romapp.internal.data.ModelPorts.getDisplayName(this.InputSignals);
            for ct=1:numel(this.InputSignals)
                s = romapp.internal.data.ImportDataSpec(...
                    names(ct), ...
                    '' , ...
                    romapp.internal.data.ImportType.Input);
                spec = vertcat(spec,s); %#ok<AGROW>
            end

            names = romapp.internal.data.ModelPorts.getDisplayName(this.OutputSignals);
            for ct=1:numel(this.OutputSignals)
                s = romapp.internal.data.ImportDataSpec(...
                    names(ct), ...
                    '', ...
                    romapp.internal.data.ImportType.Output);
                spec = vertcat(spec,s); %#ok<AGROW>
            end

            names = romapp.internal.data.ModelPorts.getDisplayName(this.InputParameters);
            for ct=1:numel(this.InputParameters)
                s = romapp.internal.data.ImportDataSpec(...
                    names(ct), ...
                    '', ...
                    romapp.internal.data.ImportType.Parameter);
                spec = vertcat(spec,s); %#ok<AGROW>
            end
        end
    end

    methods(Access = public, Hidden = true)
        function changeModelName(this,newname,oldname)
            %changeModelName
            %
            %   Utility to change the root level model name the session
            %   data refers to. Useful when renaming a Simulink model.
            %

            for ct=1:numel(this.InputSignals)
                bp = this.InputSignals(ct).BlockPath;
                bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                this.InputSignals(ct).BlockPath = bp;
            end
            for ct=1:numel(this.OutputSignals)
                bp = this.OutputSignals(ct).BlockPath;
                bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                this.OutputSignals(ct).BlockPath = bp;
            end
            for ct=1:numel(this.LoggedOutputs)
                bp = this.LoggedOutputs(ct).BlockPath;
                bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                this.LoggedOutputs(ct).BlockPath = bp;
            end
            for ct=1:numel(this.InputParameters)
                bp = this.InputParameters(ct).BlockPath;
                bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                this.InputParameters(ct).BlockPath = bp;
            end
            for ct=1:numel(this.ExperimentInputSignals)
                bp = this.ExperimentInputSignals(ct).BlockPath;
                bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                this.ExperimentInputSignals(ct).BlockPath = bp;
            end
            for ct=1:numel(this.ExperimentInputParameters)
                bp = this.ExperimentInputParameters(ct).BlockPath;
                bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                this.ExperimentInputParameters(ct).BlockPath = bp;
            end
        end
    end

    methods(Static = true)
        function strs = getFullName(obj)

            switch class(obj)
                case 'Simulink.SimulationData.Signal'
                    nObj = numel(obj);
                    strs = string.empty(nObj,0);
                    for ct=1:nObj
                        bp = convertToCell(obj(ct).BlockPath);
                        name = obj(ct).Name;
                        if isempty(obj(ct).Name)
                            if isempty(bp)
                                %No name or block path
                                str = ":" + obj(ct).PortIndex;
                            else
                                %Block path, no name
                                str = string(bp{1}) + ":" + obj(ct).PortIndex;
                            end
                        else
                            if isempty(bp) 
                                %Name, no block path
                                str = name;
                            else
                                %Block path and name
                                str = string(bp{1}) + ":" + obj(ct).PortIndex + "(" + string(obj(ct).Name) +")";
                            end
                        end
                        strs(ct,1) = str;
                    end
                case {'romapp.internal.data.ModelParameter', 'romapp.internal.data.ParameterData'}
                    nObj = numel(obj);
                    strs = string.empty(nObj,0);
                    for ct=1:nObj
                        strs(ct,1) = lParameterName(obj(ct),true);
                    end
            end
        end
        function strs = getShortName(obj)

            switch class(obj)
                case 'Simulink.SimulationData.Signal'
                    nObj = numel(obj);
                    strs = string.empty(nObj,0);
                    for ct=1:nObj
                        if isempty(obj(ct).Name)
                            bp = convertToCell(obj(ct).BlockPath);
                            if isempty(bp)
                                str = ":" + obj(ct).PortIndex;
                            else
                                str = string(bp{1}) + ":" + obj(ct).PortIndex;
                            end
                        else
                            str = string(obj(ct).Name);
                        end
                        strs(ct,1) = str;
                    end
                case {'romapp.internal.data.ModelParameter', 'romapp.internal.data.ParameterData'}
                    nObj = numel(obj);
                    strs = string.empty(nObj,0);
                    for ct=1:nObj
                        strs(ct,1) = lParameterName(obj(ct),false);
                    end
            end
        end

        function names = getDisplayName(obj)
            %getDisplayName
            %
            %   names = getDisplayNames(obj)
            %
            %   Return names to use to display input signals, output
            %   signals, and parameters. If the short names are unique
            %   those names are used, if not full names are used.

            names = romapp.internal.data.ModelPorts.getShortName(obj);

            if numel(names) ~= numel(unique(names))
                names = romapp.internal.data.ModelPorts.getFullName(obj);
            end

        end

        function data = loadobj(data)
            if strcmp(data.Version,'1.0')
                data = romapp.internal.data.ModelPorts.convertV1_V2(data);
            end
        end
    end

    methods(Access = protected, Static = true)
        function new = convertV1_V2(old)

            %V2:
            % - added a LoggedOutputs property, for V1 objects this is the
            %   same as the OutputSignals property.
            % - added a hasScalarOutput_ property, for V1 objects this is
            %   false
            new = old;
            new.LoggedOutputs = old.OutputSignals;
            new.hasScalarOutput_ = false;
            new.Version = "2.0";
        end
    end
end

function strs = lParameterName(obj,fullname)

bp = obj.BlockPath;
isVar = isa(obj,'romapp.internal.data.ModelParameter') && ~isempty(obj.Workspace);
isVar = isVar || isa(obj,'romapp.internal.data.ParameterData') && isVariable(obj);
if isVar
    %Workspace variable
    strs = obj.Name;
    if fullname && ~isempty(obj.BlockPath)
        bp = convertToCell(obj.BlockPath);
        mdl = bdroot(bp{1});
        strs = string(mdl) + ":" + strs;
    end
else
    %Block dialog parameter
    if isempty(bp)
        strs = ":";
        if ~isempty(obj.Name)
            strs = strs + obj.Name;
        end
    else
        bp = convertToCell(obj.BlockPath);
        bp = string(bp{1});
        idx = strfind(bp,"/");
        if ~isempty(bp) && ~fullname
            bp = extractAfter(bp,max(idx));
        end
        strs = bp + ":" + obj.Name;
    end
end
end
