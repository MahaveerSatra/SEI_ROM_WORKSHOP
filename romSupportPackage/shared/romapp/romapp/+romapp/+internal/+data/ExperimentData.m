classdef ExperimentData
    %ExperimentData
    %

    % Copyright 2022-2024 The MathWorks, Inc.

    properties(Dependent = true)
        InputSignals 
        OutputSignals 
        InputParameters 
        States
        Errors
    end

    properties(Access = private)
        ID_ string
        ResultStore_ romapp.internal.data.SimulationResultStore
    end

    properties(Access = protected)
        InputSignals_ Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
        OutputSignals_ Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
        InputParameters_ romapp.internal.data.ParameterData = romapp.internal.data.ParameterData.empty
        States_ Simulink.SimulationData.State = Simulink.SimulationData.State.empty
        Errors_ MSLDiagnostic = MSLDiagnostic.empty
    end
    
    methods
        function obj = ExperimentData(varargin)
            %ExperimentData
            %

            obj.ID_ = matlab.lang.internal.uuid;
        end

        function sigs = get.InputSignals(this)

            if isempty(this.ResultStore_)
                sigs = this.InputSignals_;
            else
                sigs = getData(this.ResultStore_,'inputs');
            end
            
        end
        function this = set.InputSignals(this,sig)
            this.InputSignals_ = sig;
        end

        function sigs = get.OutputSignals(this)
            if isempty(this.ResultStore_)
                sigs = this.OutputSignals_;
            else
                sigs = getData(this.ResultStore_,'outputs');
            end
        end
        function this = set.OutputSignals(this,sig)
            this.OutputSignals_ = sig;
        end

        function param = get.InputParameters(this)
            if isempty(this.ResultStore_)
                param = this.InputParameters_;
            else
                param = getData(this.ResultStore_,'parameters');
            end
        end
        function this = set.InputParameters(this,param)
            this.InputParameters_ = param;
        end

        function states = get.States(this)
            if isempty(this.ResultStore_)
                states = this.States_;
            else
                states = getData(this.ResultStore_,'states');
            end
        end
        function this = set.States(this,states)
            this.States_ = states;
        end

        function errors = get.Errors(this)
            if isempty(this.ResultStore_)
                errors = this.Errors_;
            else
                errors = getData(this.ResultStore_,'errors');
            end
        end
        function this = set.Errors(this,errors)
            this.Errors_ = errors;
        end

        function log = getFullSimulationLog(this)
            %getFullSimulationLog Return the full simulation log
            %

            if isempty(this.ResultStore_)
                log = [];
            else
                log = getFullLog(this.ResultStore_);
            end
        end
    end

    methods(Hidden = true)
        function id = getUID(this)
            id = this.ID_;
        end
        function this = setResultStore(this,results)

            this.ResultStore_ = results;
        end
        function this = changeModelName(this,newname,oldname)
            %changeModelName
            %
            %   Utility to change the root level model name the session
            %   data refers to. Useful when renaming a Simulink model.
            %

            if isempty(this.ResultStore_)
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
                for ct=1:numel(this.InputParameters)
                    bp = this.InputParameters(ct).BlockPath;
                    bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                    this.InputParameters(ct).BlockPath = bp;
                end
                for ct=1:numel(this.States)
                    bp = this.States(ct).BlockPath;
                    bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                    this.States(ct).BlockPath = bp;
                end
            else
                this.ResultStore_ = changeModelName(this.ResultStore_,newname,oldname);
            end
        end
        function this = removeIOSignals(this, idxInputs, idxOutputs)
            % Remove input and/or output signals from the experiment data.
            % idxInputs is a logical vector where true indicates that the
            % input signal should be retained. idxOutputs is a logical
            % vector where true indicates that the output signal should be
            % retained.
            if isempty(this.ResultStore_)
                this.InputSignals_ = this.InputSignals_(idxInputs);
                this.OutputSignals_ = this.OutputSignals_(idxOutputs);
            else
                this.ResultStore_ = removeIOSignals(this.ResultStore_, idxInputs, idxOutputs);
            end
        end
        function mdl = getModelName(this)
            %getModelName
            %
            %   Utility to return the simulink model name the experiment is
            %   for.
            %

            sig = this.OutputSignals(1);
            bp = convertToCell(sig.BlockPath);
            if isempty(bp)
                %Can happen if the data was collected using a post-sim
                %transform fcn. Check inputs and parameters, should have at
                %least one of these.
                sig = this.InputSignals;
                if ~isempty(sig)
                    bp = convertToCell(sig(1).BlockPath);
                    if ~isempty(bp)
                        mdl = strtok(bp{1},'/');
                        return
                    end
                end
                param = this.InputParameters;
                if isempty(param)
                    mdl = romapp.internal.resources.getString('lblUnknown');
                else
                    bp = convertToCell(param(1).BlockPath);
                    if isempty(bp)
                        mdl = romapp.internal.resources.getString('lblUnknown');
                    else
                        mdl = strtok(bp{1},'/');
                    end
                end
            else
                mdl = strtok(bp{1},'/');
            end
        end
        function [iNames,oNames,pNames] = getDisplayNames(this)
            %getDisplayNames
            %
            %   [iNames,oName,pNames] = getDisplayNames(obj)
            %
            %   Return names to use to display input signals, output
            %   signals, and parameters. If the short names are unique
            %   those names are used, if not full names are used.

            if isempty(this.InputSignals)
                iNames = string.empty;
            else
                iNames = romapp.internal.data.ModelPorts.getShortName(this.InputSignals);
            end
            if isempty(this.OutputSignals)
                oNames = string.empty;
            else
                oNames = romapp.internal.data.ModelPorts.getShortName(this.OutputSignals);
            end
            if isempty(this.InputParameters)
                pNames = string.empty;
            else
                pNames = romapp.internal.data.ModelPorts.getShortName(this.InputParameters);
            end

            allNames = [iNames;oNames;pNames];
            if numel(allNames) ~= numel(unique(allNames))
                if isempty(this.InputSignals)
                    iNames = string.empty;
                else
                    iNames = romapp.internal.data.ModelPorts.getFullName(this.InputSignals);
                end
                if isempty(this.OutputSignals)
                    oNames = string.empty;
                else
                    oNames = romapp.internal.data.ModelPorts.getFullName(this.OutputSignals);
                end
                if isempty(this.InputParameters)
                    pNames = string.empty;
                else
                    pNames = romapp.internal.data.ModelPorts.getFullName(this.InputParameters);
                end
            end
        end
    end
end

% LocalWords:  lbl
