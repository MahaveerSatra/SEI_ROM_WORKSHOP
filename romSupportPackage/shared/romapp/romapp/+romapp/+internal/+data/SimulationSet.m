classdef SimulationSet < matlab.mixin.Copyable
    %

    %SIMULATIONSET
    %

    % Copyright 2022-2026 The MathWorks, Inc.

    properties
        Name string
        Enable logical
    end

    properties
        % Logical indices for which results to include when exporting to EM
        % or to the workspace
        IncludeForTraining logical = logical.empty
        IncludeForExportToWorkspace logical = logical.empty
    end

    properties(GetAccess = public, SetAccess = protected)
        Results %Datastore containing results
        ResultsMatchSimSpec logical
    end

    properties(Dependent = true)
        NumSim % Number of simulations proposed by the SimulationSpec
        NumResults % Number of simulation results. May differ from NumSim if the spec changes after simulation
        IsError
    end

    properties(Access = private)
        NumSim_ = []
        NumResults_ = []
        IsError_ = []
    end

    properties(SetObservable = true)
        SimulationSpec romapp.internal.data.SimulationSpec
    end

    properties(SetAccess = private, GetAccess = public)
        Version string
    end

    properties(Access = private)
        UID string
    end

    properties(Access = private)
        ModelPorts romapp.internal.data.ModelPorts
        PortRanges (:,2)double
    end

    events(NotifyAccess = private)
        DataChanged
    end

    methods
        function obj = SimulationSet(ports)
            %SIMULATIONSET
            %

            obj.UID = matlab.lang.internal.uuid;
            obj.Version = '3.1';
            obj.ModelPorts = ports;
            nPorts = getNumPorts(ports);
            obj.PortRanges = ones(nPorts,1)*[-1 1];

            obj.Name = string.empty;
            obj.Enable = true;
            obj.Results = {};
            obj.ResultsMatchSimSpec = true;

            addSimulationSpec(obj,createSpec(obj))
        end

        function range = getPortRange(this,port)

            nport = numel(port);
            range = nan(nport,2);
            if isa(port,'Simulink.SimulationData.Signal')
                allPorts = [this.ModelPorts.InputSignals; this.ModelPorts.OutputSignals];
                offset = 0;
            elseif isa(port,'romapp.internal.data.ModelParameter')
                allPorts = this.ModelPorts.InputParameters;
                offset = nport - numel(this.ModelPorts.InputParameters);
            else
                error('Unexpected port type')
            end
            for ctP=1:nport
                ct = 1;
                found = false;
                while ct <= numel(allPorts)  && ~found
                    found = isequal(port(ctP),allPorts(ct));
                    if found
                        range(ctP,:) = this.PortRanges(ct+offset,:);
                    end
                    ct = ct+1;
                end
            end
        end

        function name = getFullPortName(~,port)

            name = romapp.internal.data.ModelPorts.getFullName(port);
        end
        function name = getShortPortName(~,port)

            name = romapp.internal.data.ModelPorts.getShortName(port);
        end

        function port = getPort(this,type)

            switch type
                case romapp.internal.data.PortType.ROMInput
                    port = this.ModelPorts.InputSignals;
                case romapp.internal.data.PortType.SimulationInput
                    port = this.ModelPorts.ExperimentInputSignals;
                case romapp.internal.data.PortType.SimulationParameter
                    port = this.ModelPorts.ExperimentInputParameters;
                case romapp.internal.data.PortType.ROMOutput
                    port = this.ModelPorts.OutputSignals;
                case romapp.internal.data.PortType.ROMParameter
                    port = this.ModelPorts.InputParameters;
                case romapp.internal.data.PortType.LoggedOutput
                    port = this.ModelPorts.LoggedOutputs;
                otherwise
                    error('Unknown port type')
            end
        end

        function addSimulationSpec(this,spec)

            if isempty(this.SimulationSpec)
                this.SimulationSpec = spec;
                notify(this,'DataChanged')
                createDataListeners(this,spec)
            else
                if ~any(this.SimulationSpec == spec)
                    currNames = [this.SimulationSpec.Name];
                    spec.Name = matlab.lang.makeUniqueStrings(spec.Name,currNames);
                    this.SimulationSpec = vertcat(this.SimulationSpec,spec);
                    notify(this,'DataChanged')
                    createDataListeners(this,spec)
                end
            end
        end

        function removeSimulationSpec(this,spec)

            if isempty(this.SimulationSpec)
                return
            end
            idx = this.SimulationSpec == spec;
            if any(idx)
                this.SimulationSpec(idx) = [];
                notify(this,'DataChanged')
            end
        end

        function [data,ranges] = getPlotData(this)

            if isempty(this.SimulationSpec)
                data = [];
                ranges = [];
                return
            end

            [data,ranges] = getPlotData(this.SimulationSpec(1));
            for ct=2:numel(this.SimulationSpec)
                [d,r] = getPlotData(this.SimulationSpec(2));
                data = [data; d]; %#ok<AGROW>
                ranges(:,1) = min(ranges(:,1), r(:,1));
                ranges(:,2) = max(ranges(:,2), r(:,2));
            end
        end

        function n = get.NumSim(this)
            if isempty(this.NumSim_)
                % Recompute the number of proposed simulations. If there is
                % no simulation spec, use a default of 0.
                if isempty(this.SimulationSpec)
                    n = 0;
                else
                    n = getNumSim(this.SimulationSpec(1));
                    for ct=2:numel(this.SimulationSpec)
                        n = n + getNumSim(this.SimulationSpec(ct));
                    end
                end
                this.NumSim = n;
            else
                % NumSim is a stored value
                n = this.NumSim_;
            end
        end

        function set.NumSim(this, n)
            this.NumSim_ = n;
        end

        function n = get.NumResults(this)
            if isempty(this.NumResults_)
                % Get the number of results from the simset.Results
                n = romapp.internal.experimentmanager.getNumResults(this.Results);
                this.NumResults = n;
            else
                % The number of results is already known
                n = this.NumResults_;
            end
        end

        function set.NumResults(this, n)
            this.NumResults_ = n;

            % When a new number of simulations is set, reset the error
            % information. It must be recomputed so that there is a value
            % for each simulation.
            this.IsError = [];
        end

        function isError = get.IsError(this)
            if isempty(this.IsError_) && this.NumResults>0
                errorDS = transform(this.Results, @(x) ~isempty(x.Errors));
                isError = readall(errorDS);
                this.IsError = isError;
            else
                isError = this.IsError_;
            end
        end

        function set.IsError(this, isError)
            this.IsError_ = isError;
        end

        function [dspace, params] = createDesignSpace(this,baseSpace,pSig)
            %createDesignSpace
            %

            %Call createDesignSpace on the simulation spec
            [dspace,param] = createDesignSpace(this.SimulationSpec,baseSpace,pSig);
            params = param(:);
        end

        function storeDatastoreResult(this,datastore,idxRange,mSig,logName,stateLogName)
            %storeDatastoreResult
            %

            %Create subset of the datastore that is related to this
            %specific simulation set. 
            subDS = subset(datastore,idxRange(1):1:idxRange(2));

            %Create a transformation on the simulation datastore that
            %returns experiments
            sigIn = this.ModelPorts.InputSignals; %To avoid ref to 'this' in anonymous function
            sigOut = this.ModelPorts.OutputSignals;
            tfcn = @(x) romapp.internal.data.SimulationSet.extractExperimentFromSimulation(x,...
                mSig,...
                sigIn,...
                sigOut,...
                logName,...
                stateLogName);
            expDatastore = transform(subDS,tfcn);

            %Store the transformed datastore as the results for this
            %simulation set
            this.Results = expDatastore;
            this.ResultsMatchSimSpec = true;
            this.NumResults = range(idxRange)+1; % A new simulation was run. Reset the number of results based on the idxRange. The +1 accounts for the inclusive boundary.
            nResult = this.NumResults;
            this.IncludeForTraining = true(nResult,1);
            this.IncludeForExportToWorkspace = true(nResult,1);

            %Notify listeners that the results are stored
            notify(this,'DataChanged')
        end

        function storeImportResult(this,experimentDS)
            %storeImportResult
            %
            %  Store the experiment results imported, i.e., not generated
            %  from simulation.

            arguments
                this romapp.internal.data.SimulationSet
                experimentDS matlab.io.Datastore
            end

            this.Results = experimentDS;
            nResult = this.NumResults; % Will recompute NumSim if it is not already known
            this.IsError = false(nResult,1); % Imported data does not have errors. Those come from simulation only
            this.IncludeForTraining = true(nResult,1);
            this.IncludeForExportToWorkspace = true(nResult,1);
        end

        function spec = createSpec(this)
            ports = getPort(this,romapp.internal.data.PortType.SimulationInput);
            params = getPort(this,romapp.internal.data.PortType.SimulationParameter);
            boundaries = romapp.internal.data.BoundarySpec();
            spec = romapp.internal.data.SimulationSpec('Signals',ports,'Parameters',params,'Boundaries',boundaries);
        end

        function delete(this)

            for ct = 1:numel(this.SimulationSpec)
                delete(this.SimulationSpec(ct))
            end
        end

        function createDataListeners(this,spec)

            weak = romapp.internal.resources.WeakReference(this);
            if nargin < 2
                %Called when loading a app session to recreate all data
                %listeners
                for ct=1:numel(this.SimulationSpec)
                    spec = this.SimulationSpec(ct);
                    addlistener(spec,'DataChanged', @(hSrc,hData) cbSpecValueChanged(weak.Handle,hSrc));
                    createDataListeners(spec)
                end
            else
                addlistener(spec,'DataChanged', @(hSrc,hData) cbSpecValueChanged(weak.Handle,hSrc));
            end
        end
    end

    methods(Hidden)
        function id = getUID(this)
            if isempty(this)
                id = string.empty;
            else
                id = this(1).UID;
                for ct = 2:numel(this)
                    id = [id, this(ct).UID]; %#ok<AGROW>
                end
            end
        end
        function changeModelName(this,newname,oldname)
            %changeModelName
            %
            %   Utility to change the root level model name the session
            %   data refers to. Useful when renaming a Simulink model.
            %

            changeModelName(this.SimulationSpec,newname,oldname)
            tFcn = @(x) changeModelName(x,newname,oldname);
            this.Results = transform(this.Results,tFcn);
        end
        function qeSetResultsMatchSimSpec(this,value)
            this.ResultsMatchSimSpec = value;
            notify(this,'DataChanged')
        end
        function qeSetResults(this,value)
            if isa(value,'romapp.internal.data.ExperimentData')
                value = arrayDatastore(value,'OutputType','same');
            end
            this.Results = value;
            if isempty(value)
                nResult = 0;
            else
                this.NumResults = []; % A new result was set. Clear the number of results so that it is recomputed.
                nResult = this.NumResults; % Will recompute NumResults
            end
            this.IncludeForTraining = true(nResult,1);
            this.IncludeForExportToWorkspace = true(nResult,1);
        end
    end

    methods(Access = protected)
        function copyObj = copyElement(this)
            % Copy the object using the mixin class. Then update the UID so
            % that it is unique.
            copyObj = copyElement@matlab.mixin.Copyable(this);
            copyObj.UID = matlab.lang.internal.uuid;

            % Make sure the SimulationSpec is a copy, not a reference
            copyObj.SimulationSpec = copy(this.SimulationSpec);
        end

        function cbSpecValueChanged(this,~)

            if isempty(this.Results)
                %Reset the flag indicating the results are consistent with
                %the spec definition.
                this.ResultsMatchSimSpec = true;
            else
                %Changing the spec almost certainly means the existing
                %results are inconsistent, i.e., from previous spec
                %definition.
                this.ResultsMatchSimSpec = false;
            end
            this.NumSim = []; % Reset so that it will be recomputed according to the new spec

            notify(this,'DataChanged')
        end
    end

    methods(Access = protected, Static)
        function data = convertV1ToV2(data)
            data.ResultsMatchSimSpec = true;
            data.Version = '2.0';
        end
        function data = convertV2ToV3(data)
            if isa(data.Results,'romapp.internal.data.ExperimentData')
                data.Results = arrayDatastore(data.Results,'OutputType','same');
            end
            nResult = romapp.internal.experimentmanager.getNumResults(data.Results);
            %Initialize the IncludeForTraining and
            %IncludeForExportToWorkspace properties.
            data.IncludeForTraining = true(nResult,1);
            data.IncludeForExportToWorkspace = true(nResult,1);

            data.Version = '3.0';
        end
        function data = convertV3ToV3p1(data)
            if isa(data.Results,'matlab.io.datastore.TransformedDatastore')

                %Recreate the datastore transform to clear any potential
                %function handle cycles.
                fh = data.Results.Transforms{1};
                fhData = functions(fh);
                wksp = fhData.workspace{1};
                if isfield(wksp,'this')
                    %The stored transformation references this, recreate it
                    sigIn = wksp.this.ModelPorts.InputSignals;
                    sigOut = wksp.this.ModelPorts.OutputSignals;
                    mSig = wksp.mSig;
                    logName = wksp.logName;
                    stateLogName = wksp.stateLogName;
                    tfcn = @(x) romapp.internal.data.SimulationSet.extractExperiment(x,...
                        mSig,...
                        sigIn,...
                        sigOut,...
                        logName,...
                        stateLogName);
                    underlyingDS = data.Results.UnderlyingDatastores{1};
                    expDatastore = transform(underlyingDS,tfcn);
                    data.Results = expDatastore;
                end
            end
            data.Version = '3.1';
        end
    end

    methods(Static)
        function expData = extractExperiment(dataLog,...
                mSig, ...
                InputSignals, ...
                OutputSignals, ...
                logName, ...
                stateLogName)
            % For backwards compatibility, we must keep an
            % extractExperiment static method with this signature. Sessions
            % saved prior to R2026b may contain a simulation set which
            % has a function handle referencing this method. The method was
            % renamed to extractExperimentFromSimulation, so we will just
            % pass the inputs into that method.
            expData = romapp.internal.data.SimulationSet.extractExperimentFromSimulation(...
                dataLog, mSig, InputSignals, OutputSignals, logName, stateLogName);
        end

        function expData = extractExperimentFromSimulation(dataLog,...
                mSig,...
                InputSignals, ...
                OutputSignals, ...
                logName, ...
                stateLogName)

            expData = romapp.internal.data.ExperimentData;
            store = romapp.internal.data.SimulationResultStore(...
                    dataLog, ...
                    'SignalInjectionPoints', mSig, ...
                    'SignalLogName', logName, ...
                    'StateLogName', stateLogName, ...
                    'InputSignals', InputSignals, ...
                    'OutputSignals', OutputSignals, ...
                    'InputParameters', dataLog.ROMParameters);
            expData = setResultStore(expData,store);

        end

        function expData = extractExperimentFromDatastore(dataIn, SigIn, SigOut, importSpec, Ts)
            % Construct an ExperimentData object on the fly using the data read from
            % the datastore
            expData = romapp.internal.data.ExperimentData;

            % Get the time vector either using the sample time (if
            % implicit) or from the data
            if ~isempty(Ts)
                % Time is implicit. Generate the time vector
                t = (0:height(dataIn)-1)*Ts;
                t = seconds(t(:));
            else
                % Time is a variable in the datastore. Use the spec to
                % fetch it
                iTime = [importSpec.Type] == romapp.internal.data.ImportType.Time;
                fTime = evalin('base', regexprep(importSpec(iTime).Expression, '.*\(:\)', '@(x)x')); % Datastore expressions will be something like dsName(:).Time. Convert this to a function handle @(x)x.Time
                t = fTime(dataIn);
                if ~isduration(t)
                    t = seconds(t(:));
                end
            end

            % Get the data for the input signals and output signals
            SigIn = lGetDatastoreSignalValues(SigIn, importSpec, dataIn, t);
            SigOut = lGetDatastoreSignalValues(SigOut, importSpec, dataIn, t);
            expData.InputSignals = SigIn;
            expData.OutputSignals = SigOut;
        end

        function obj = loadobj(data)

            if strcmp(data.Version,'1.0')
                data = romapp.internal.data.SimulationSet.convertV1ToV2(data);
                data = romapp.internal.data.SimulationSet.convertV2ToV3(data);
                obj = romapp.internal.data.SimulationSet.convertV3ToV3p1(data);
            elseif strcmp(data.Version,'2.0')
                data = romapp.internal.data.SimulationSet.convertV2ToV3(data);
                obj = romapp.internal.data.SimulationSet.convertV3ToV3p1(data);
            elseif strcmp(data.Version,'3.0')
                obj = romapp.internal.data.SimulationSet.convertV3ToV3p1(data);
            else
                obj = data;
            end
        end
        
    end
end

function sig = lGetDatastoreSignalValues(sig, importSpec, data, t)
for ct=1:numel(sig)
    iSig = [importSpec.Name] == romapp.internal.data.ModelPorts.getDisplayName(sig(ct));
    if any(iSig)
        % Convert the spec expression to a function handle and
        % evaluate to get the values
        fVals = evalin('base', regexprep(importSpec(iSig).Expression, '.*\(:\)', '@(x)x'));
        vals = fVals(data);
        if isduration(vals)
            % Can happen if import time from timetable as an input or output
            vals = seconds(vals);
        end
        sig(ct).Values = timetable(t(:),vals(:),'VariableNames',{'Data'});
    end
end
end

% LocalWords:  simin
