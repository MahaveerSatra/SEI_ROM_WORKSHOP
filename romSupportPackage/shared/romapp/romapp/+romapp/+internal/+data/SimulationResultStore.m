classdef SimulationResultStore
    %

    %SimulationResultStore
    %
    % Class used by romapp.internal.data.ExperimentData for
    % lazy loading of logged simulation data

    % Copyright 2023-2024 The MathWorks, Inc.

    properties(Access = protected)

        InputSignals Simulink.SimulationData.Signal
        OutputSignals Simulink.SimulationData.Signal
        InputParameters romapp.internal.data.ParameterData

        SignalLogName string
        StateLogName string

        SimulationLog Simulink.SimulationOutput

        % SignalDataMap dictionary
        SignalDataMap 
    end
    
    methods
        function obj = SimulationResultStore(simlog, options)
            %SimulationResultStore
            %

            arguments
                simlog = Simulink.SimulationOutput
                options.InputSignals = Simulink.SimulationData.Signal.empty
                options.OutputSignals = Simulink.SimulationData.Signal.empty
                options.InputParameters = romapp.internal.data.ParameterData.empty
                options.SignalLogName = string.empty
                options.StateLogName = string.empty
                options.SignalInjectionPoints = slcontrollib.internal.siginject.InjectionPointData.empty
            end

            obj.SimulationLog = simlog;
            obj.InputSignals = options.InputSignals;
            obj.OutputSignals = options.OutputSignals;
            obj.InputParameters = options.InputParameters;
            obj.SignalLogName = options.SignalLogName;
            obj.StateLogName = options.StateLogName;
            
            nSig = numel(options.SignalInjectionPoints);
            bkport = strings(nSig,1);
            sigData = cell(nSig,1);
            for ct = 1:nSig
                bkport(ct) = strcat(options.SignalInjectionPoints(ct).Block,":", num2str(options.SignalInjectionPoints(ct).PortNumber));
                errDiagnostic = getSimulationError(simlog);
                if isempty(errDiagnostic)
                    sigData{ct} = getPerturbedSignal(options.SignalInjectionPoints(ct),simlog,options.SignalLogName);
                end
            end
            obj.SignalDataMap = dictionary(bkport,sigData);
        end
    end

    methods(Access = public)
        function data = getData(this,type)

            switch type
                case 'inputs'
                    sig = this.InputSignals;
                    data = getSignalData(this,sig);
                case 'outputs'
                    sig = this.OutputSignals;
                    ddata = find(this.SimulationLog,'DerivedData');
                    if isempty(ddata)
                        data = getSignalData(this,sig);
                    else
                        data = sig;
                        for ct=1:numel(sig)
                            data(ct) = lGetDerivedData(this.SimulationLog.DerivedData,sig(ct));
                        end
                    end
                case 'states'
                    haveStateLog = any(strcmp(this.SimulationLog.who,this.StateLogName));
                    if haveStateLog
                        data = [];
                        stateLog = this.SimulationLog.(this.StateLogName);
                        for ct=1:stateLog.numElements
                            stateSig = stateLog.getElement(ct);
                            data = [data; stateSig]; %#ok<AGROW>
                        end
                    else
                        data = Simulink.SimulationData.State.empty;
                    end
                case 'parameters'
                    data = this.InputParameters;
                case 'errors'
                    errDiagnostic = getSimulationError(this.SimulationLog);
                    if isempty(errDiagnostic)
                        data = MSLDiagnostic.empty;
                    else
                        data = errDiagnostic.Diagnostic;
                    end
            end
        end
        function log = getFullLog(this)
            %getFullLog Return the stored SimulationLog
            %

            log = this.SimulationLog;
        end
    end

    methods(Access = public, Hidden = true)
        function this = changeModelName(this,newname,oldname)
            %changeModelName
            %
            %   Utility to change the root level model name the session
            %   data refers to. Useful when renaming a Simulink model.
            %
            keys = this.SignalDataMap.keys;
            for ct=1:numel(this.InputSignals)+numel(this.OutputSignals)
                keys(ct) = regexprep(keys(ct),"^"+oldname,newname);
            end
            this.SignalDataMap = containers.Map(keys,this.SignalDataMap.values);
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
        end
        function this = removeIOSignals(this, idxInputs, idxOutputs)
            % Remove input and/or output signals from the result store.
            % idxInputs is a logical vector where true indicates that the
            % input signal should be retained. idxOutputs is a logical
            % vector where true indicates that the output signal should be
            % retained.

            % Remove input signals
            inputSignalsToRemove = this.InputSignals(~idxInputs);
            for iSig = 1:numel(inputSignalsToRemove)
                % For each signal that should be removed, construct the key
                % into the SignalDataMap and remove that key
                keyToRemove = convertToCell(inputSignalsToRemove(iSig).BlockPath);
                keyToRemove = strcat(string(keyToRemove{1}),":",num2str(inputSignalsToRemove(iSig).PortIndex));
                this.SignalDataMap = this.SignalDataMap.remove(keyToRemove);
            end
            this.InputSignals = this.InputSignals(idxInputs);

            % Remove output signals
            outputSignalsToRemove = this.OutputSignals(~idxOutputs);
            for iSig = 1:numel(outputSignalsToRemove)
                % For each signal that should be removed, construct the key
                % into the SignalDataMap and remove that key
                keyToRemove = convertToCell(outputSignalsToRemove(iSig).BlockPath);
                keyToRemove = strcat(string(keyToRemove{1}),":",num2str(outputSignalsToRemove(iSig).PortIndex));
                this.SignalDataMap = this.SignalDataMap.remove(keyToRemove);
            end
            this.OutputSignals = this.OutputSignals(idxOutputs);
        end
    end

    methods(Access = protected)
        function data = getSignalData(this,sig)
            data = sig;
            for ct=1:numel(sig)
                key = convertToCell(sig(ct).BlockPath);
                key = strcat(string(key{1}),":",num2str(sig(ct).PortIndex));
                if sum(ismember(this.SignalDataMap.keys,key),'all')
                    sigData = this.SignalDataMap(key);
                    data(ct).Values = sigData{1};
                else
                    romapp.internal.resources.error('errUnexpected',['Could not find signal for: ', char(key)]);
                end
            end
        end
    end
end

function sigData = lGetDerivedData(derivedData,data)

if isstruct(derivedData)
    %User provided function. Fields in struct array correspond to data
    %signal names. Field values are either timetables or scalars, for
    %scalars convert to timetable with one point.
    value = derivedData.(data.Name);
    if istimetable(value)
        data.Values = value;
    else
        data.Values = timetable(seconds(0),value,'VariableNames', {'Data'});
    end
    sigData = data;
else
    %Special case for logging final values. Derived data is an array of
    %signal objects.
    ct = 1;
    found = false;
    while ~found && ct <= numel(derivedData)
        found = isequal(data.Name,derivedData(ct).Name) && ...
            isequal(data.BlockPath,derivedData(ct).BlockPath) && ...
            isequal(data.PortType,derivedData(ct).PortType) && ...
            isequal(data.PortIndex,derivedData(ct).PortIndex);
        if found
            sigData = derivedData(ct);
        else
            ct = ct+1;
        end
    end
end

end

function errDiagnostic = getSimulationError(simlog)
errDiagnostic = simlog.SimulationMetadata.ExecutionInfo.ErrorDiagnostic;
end