classdef AppData < handle
    % 

    %APPDATA
    %
    % Class for storing & managing all ROM app data

    % Copyright 2022-2026 The MathWorks, Inc.

    properties(GetAccess = public, SetAccess = protected, SetObservable = true)
        Model string = string.empty;
        SimulationSets romapp.internal.data.SimulationSet = romapp.internal.data.SimulationSet.empty
        ModelPorts romapp.internal.data.ModelPorts = romapp.internal.data.ModelPorts.empty
    end

    properties(GetAccess = public, SetAccess = public)
        SimulationOptions romapp.internal.data.SimulationOptions = romapp.internal.data.SimulationOptions.empty
    end

    properties(GetAccess = public, SetAccess = private)
        Version
    end

    properties(GetAccess = public, SetAccess = private, Dependent = true)
        HaveSimulinkModel
    end

    properties(Constant = true, Access = private)
        LOGNAME = 'romLogsOut';
        STATELOGNAME = 'romStateOut';
    end

    properties(Access = private, Transient)
        SimulationSetListeners event.listener = event.listener.empty
    end

    events(NotifyAccess = private)
        DataChanged
    end

    methods
        function obj = AppData(model)
            %APPDATA Construct an instance of this class
            %

            obj.Version = '1.0';

            if iscell(model) 
                %Launched with data
                obj.Model = string.empty;
            elseif ischar(model) || isstring(model)
                %Launched with a model name
                if endsWith(model,'.slx')
                    model = replace(model,'.slx','');
                end
                obj.Model = model;
            else
                romapp.internal.resources.error('errUnexpected','Invalid data type')
            end

            %Initialize properties
            obj.ModelPorts = romapp.internal.data.ModelPorts;
            obj.SimulationOptions = romapp.internal.data.SimulationOptions;
        end

        function addSimulationSet(this,simset)
            %ADDSIMULATIONSET
            %

            if ~any(strcmp(getUID(this.SimulationSets),getUID(simset)))
                this.SimulationSets = [this.SimulationSets; simset];
                weak = romapp.internal.resources.WeakReference(this);
                this.SimulationSetListeners = [this.SimulationSetListeners; ...
                    event.listener(simset,'DataChanged', @(hSrc,hData) notify(weak.Handle,'DataChanged'))];
                notify(this,'DataChanged')
            end
        end

        function copySimulationSet(this,name)
            %Name could be the display name or the UID, check name 1st
            idx = strcmp([this.SimulationSets.Name],name);
            if ~any(idx)
                idx = strcmp(getUID(this.SimulationSets),name);
            end

            if any(idx)
                % Copy the requested simulation set
                ssCopy = copy(this.SimulationSets(idx));
    
                % Update the simset name
                ssCopy.Name = matlab.lang.makeUniqueStrings(...
                    romapp.internal.resources.getString('lblSimulation'),...
                    [this.SimulationSets.Name]);
                this.SimulationSets = [this.SimulationSets; ssCopy];
                weak = romapp.internal.resources.WeakReference(this);
                this.SimulationSetListeners = [this.SimulationSetListeners; ...
                    event.listener(ssCopy,'DataChanged', @(hSrc,hData) notify(weak.Handle,'DataChanged'))];
                notify(this,'DataChanged')
            end
        end

        function removeSimulationSet(this,name)
            %REMOVESIMULATIONSET
            %

            if isempty(name)
                %Remove all
                idx = 1:numel(this.SimulationSets);
            else
                %Name could be the display name or the UID, check name 1st
                idx = strcmp([this.SimulationSets.Name],name);
                if ~any(idx)
                    idx = strcmp(getUID(this.SimulationSets),name);
                end
            end
            %Remove and delete the simulation set in steps to avoid
            %multiple firing of the this.SimulationSets property.
            ss = this.SimulationSets;
            ssRemove = ss(idx);
            delete(ssRemove)
            ss(idx) = [];
            this.SimulationSets = ss;
            delete(this.SimulationSetListeners(idx))
            this.SimulationSetListeners(idx) = [];
            notify(this,'DataChanged')
        end

        function runSimulations(this, fcnProgressDisplay)
            %runSimulations
            %

            %Check that the model is not in fast restart
            if strcmp(get_param(this.Model,'FastRestart'),'on')
                romapp.internal.resources.error('errRun_FastRestart')
            end

            %Check whether the model uses a data dictionary, need some
            %extra management/checks if so.
            dd = get_param(this.Model,"DataDictionary");
            mdlHasDD = ~isempty(dd);
            if mdlHasDD
                dd = Simulink.data.dictionary.open(dd);
            end
            %Check if using reference config set as then have to handle
            %data dictionary differently
            cfg = getActiveConfigSet(this.Model);
            hasRefCfgSet = isa(cfg,"Simulink.ConfigSetRef");

            %Check that can use parallel if it was requested. Note should
            %only expect UseParallel to be one of {"on","off"} but the
            %setting has 3 potential values {"on","off","auto"}.
            isModeParallel = false;
            if matlab.internal.parallel.willAttemptParallel(this.SimulationOptions.UseParallel)
                %Check that the model and data dictionary are saved, if not
                %default back to serial (UseParallel='auto') unless user
                %has explicitly asked for parallel (UseParallel='on')
                tryParallel = true;
                if mdlHasDD && dd.HasUnsavedChanges
                    if strcmp(this.SimulationOptions.UseParallel,"on")
                        [~,name] = fileparts(dd.filepath);
                        romapp.internal.resources.error('errRun_ParallelDirtyModel',name)
                    end
                    tryParallel = false;
                end
                if strcmp(get_param(this.Model,'Dirty'),'on') 
                    if strcmp(this.SimulationOptions.UseParallel,"on")
                        romapp.internal.resources.error('errRun_ParallelDirtyModel',this.Model)
                    end
                    tryParallel = false;
                end
                if tryParallel
                    %Ok to run in parallel if possible. Check that can open
                    %pool. resolveUseParallel() will:
                    % - error if unable to create a pool (UseParallel='on')
                    % - return an empty pool if unable to create a pool (UseParallel='auto')
                    pool = matlab.internal.parallel.resolveUseParallel(this.SimulationOptions.UseParallel);
                    if ~isempty(pool)
                        %Able to create a pool as requested (auto or on)
                        isModeParallel = true;
                    end
                end
            end
            
            %Find the simulation sets that need to be evaluated
            idx = [this.SimulationSets.Enable]';
            idx = idx & arrayfun(@(x) ~isempty(x.SimulationSpec),this.SimulationSets);
            idx = idx & arrayfun(@(x) x.SimulationSpec.hasEnoughSamples, this.SimulationSets);   
            allSimsets = this.SimulationSets(idx);
            
            %Check that have at least one signal spec that will use signal
            %injection
            haveSignalInjection = ~isempty(allSimsets(1).SimulationSpec.SignalSpec);

            %Separate the simulation sets into groups with common
            %injection modes as cannot mix injection modes in one set of
            %simulations
            if haveSignalInjection
                simset_groups = cell(0,2);
                modes = arrayfun(@(x) x.SimulationSpec.SignalSpec.Mode,allSimsets);
                idx = find(strcmp(modes,'add'));
                if ~isempty(idx)
                    simset_groups(end+1,:) = {idx, slcontrollib.internal.siginject.PerturbationType.ADD};
                end
                idx = find(strcmp(modes,'replace'));
                if ~isempty(idx)
                    simset_groups(end+1,:) = {idx, slcontrollib.internal.siginject.PerturbationType.REPLACE};
                end
            else
               %Need to set injection mode as we still use injection infrastructure for logging
               %signals (outputs, ROM only inputs)
               simset_groups = {1:numel(allSimsets), slcontrollib.internal.siginject.PerturbationType.NONE};
            end
           
            %Loop over each simulation set group and perform simulations
            for ctGrp=1:size(simset_groups,1)

                injectMode = simset_groups{ctGrp,2};
                idxIntoAllSimsets = simset_groups{ctGrp,1};
                simsets = allSimsets(idxIntoAllSimsets);

                %Create block insertion manager to run simulations
                insertionMGR = slcontrollib.internal.siginject.BlockInsertionManager(this.Model);
                bdHandle = get_param(this.Model,'handle');
                studioBlocker = SLM3I.ScopedStudioBlocker(bdHandle);
                %If have a data dictionary with reference config set, need
                %to give the dictionary base workspace access
                if hasRefCfgSet && mdlHasDD && ~dd.EnableAccessToBaseWorkspace
                    dd.EnableAccessToBaseWorkspace = true;
                    cleanupFcn = onCleanup(@() lSimCleanup(insertionMGR,studioBlocker,dd));
                else
                    cleanupFcn = onCleanup(@() lSimCleanup(insertionMGR,studioBlocker,[]));
                end

                %Get signal categories
                [eonly, ronly, eandr, simOutputs] = categorizeSignals(this);

                %Add points that are experiment input only (perturbation points only)
                pSig = romapp.internal.data.AppData.addInjectionPoint(...
                    insertionMGR,...
                    eonly,...
                    injectMode, ...
                    false, ...
                    false);

                %Add points that are ROM input only (measurement points only)
                mSig = romapp.internal.data.AppData.addInjectionPoint(...
                    insertionMGR,...
                    ronly,...
                    slcontrollib.internal.siginject.PerturbationType.NONE, ...
                    false, ...
                    true);

                %Add points that are ROM and experiment inputs (perturbation
                %and measurement points)
                sig = romapp.internal.data.AppData.addInjectionPoint(...
                    insertionMGR,...
                    eandr,...
                    injectMode, ...
                    false, ...
                    true);
                mSig = [mSig; sig]; %#ok<AGROW>
                pSig = [pSig; sig]; %#ok<AGROW>

                %Add points that are ROM outputs (measurement points)
                mSig = [mSig; romapp.internal.data.AppData.addInjectionPoint(...
                    insertionMGR,...
                    simOutputs,...
                    slcontrollib.internal.siginject.PerturbationType.NONE, ...
                    false, ...
                    true)]; %#ok<AGROW>

                %Compile the model to get updated signal data. Use updated
                %signal data to confirm injection point settings
                compileAndUpdateSignalData(insertionMGR);
                E = romapp.internal.data.AppData.checkAndConfigureInjectionPoint([mSig; pSig]);
                if ~isempty(E)
                    throwAsCaller(E(1));
                end

                %Create the design space common to all simulations
                [baseSpace, ddCleanUpFcn] = createBaseDesignSpace(this,haveSignalInjection,isModeParallel,mdlHasDD&&~hasRefCfgSet);
            
                %Expand design space with inputs/settings for each simulation set
                nSimSet = numel(simsets);
                isimset = ones(nSimSet,1);
                allDS = [];
                for ctSS=1:nSimSet
                    [dspace, params] = createDesignSpace(simsets(ctSS),baseSpace,pSig);
                    if ctSS > 1
                        isimset(ctSS,1) = isimset(ctSS-1,2) + 1;
                        isimset(ctSS,2) = isimset(ctSS,1) + dspace.NumDesignPoints -1;
                    else
                        isimset(ctSS,2) = dspace.NumDesignPoints;
                    end
                    allDS = horzcat(allDS,dspace);
                end

                %Create a design study 
                ds = multisim.design.internal.DesignStudy(char(this.Model));
                if numel(allDS) > 1
                    ds.ParameterSpace = multisim.design.internal.SimulationGroup(allDS);
                else
                    ds.ParameterSpace = allDS;
                end
                %Specify post simulation function, always use this as we
                %add the parameter values to the simulation log.
                [pROM,pExpOnly] = splitParameters(this,params);
                ds.PostSimFcn = @(simout,simin) romapp.internal.data.AppData.postSimFcn(...
                    simout,...
                    simin,...
                    mSig, ...
                    this.LOGNAME, ...
                    this.STATELOGNAME, ...
                    this.SimulationOptions.ClearLogPostSim, ...
                    getPort(simsets(1),romapp.internal.data.PortType.ROMInput), ...
                    getPort(simsets(1),romapp.internal.data.PortType.LoggedOutput), ...
                    pROM, ...
                    pExpOnly, ...
                    this.SimulationOptions.UsePostSimFcn, ...
                    this.SimulationOptions.PostSimFcn);
                
                %Create a simulation manager to run the required design
                %study
                simulationMGR = Simulink.SimulationManager(ds);
                simulationMGR.Options.ShowProgress = false;
                simulationMGR.Options.UseParallel = isModeParallel;
                if isModeParallel
                    if isempty(dd)
                        ddName = [];
                    else
                        ddName = dd.filepath;
                    end
                    simulationMGR.Options.SetupFcn =  @() lSimMgrSetupFcn(insertionMGR,ddName);
                    simulationMGR.Options.CleanupFcn =  @() lSimMgrCleanup(true,ddName);
                    simulationMGR.Options.TransferBaseWorkspaceVariables = this.SimulationOptions.TransferBaseWorkspaceVariables;
                    simulationMGR.Options.RunInBackground = false;
                    if this.SimulationOptions.LogToFile
                        simulationMGR.Options.OutputLocation= this.SimulationOptions.FileLocation;
                    else
                        simulationMGR.Options.OutputLocation='memory';
                    end
                else
                    installInjectionPoints(insertionMGR)
                end

                %Add listener for simulation events
                l = addlistener(simulationMGR,'SimulationFinished', ...
                    @(es,ed) fcnProgressDisplay(es));
               
                %Run the simulations
                job = run(simulationMGR);
                if isModeParallel
                    simDatastore = multisimDatastore(job);
                else
                    simDatastore = simulink.multisim.MultisimDatastore.build(job);
                end
                
                %Delete the simulation listener
                delete(l)

                %Cleanup the insertion manager so can reconfigure for next
                %group of simulation sets
                delete(cleanupFcn)
                if ~isempty(ddCleanUpFcn)
                    delete(ddCleanUpFcn)
                end
           
                %Store the simulation results along with the correct
                %settings
                for ctSS=1:nSimSet
                    iStart = isimset(ctSS,1);
                    iEnd = isimset(ctSS,2);
                    storeDatastoreResult(...
                        simsets(ctSS),...
                        simDatastore,...
                        [iStart, iEnd], ...
                        mSig, ...
                        this.LOGNAME, ...
                        this.STATELOGNAME)
                end
            end
        end

        function sdata = getSaveData(this)
            %getSaveData
            %

            sdata = this;
        end

        function loadSavedData(this,sData)
            %loadSavedData
            %

            this.SimulationOptions = sData.SimulationOptions; %do before databrowser updates
            loadSavedData(this.ModelPorts,sData.ModelPorts); %triggers databrowser update
            this.SimulationSets = sData.SimulationSets;
            %Recreate data listeners as they are not serialized
            for ct=1:numel(this.SimulationSets)
                createDataListeners(this.SimulationSets(ct));
                weak = romapp.internal.resources.WeakReference(this);
                this.SimulationSetListeners = [this.SimulationSetListeners; ...
                    event.listener(this.SimulationSets(ct),'DataChanged', @(hSrc,hData) notify(weak.Handle,'DataChanged'))];

                %For backwards compatibility, if the IncludeForTraining and
                %IncludeForExportToWorkspace properties were not
                %serialized, re-initialize them.
                nResults = this.SimulationSets(ct).NumResults;
                if isempty(this.SimulationSets(ct).IncludeForTraining)
                    this.SimulationSets(ct).IncludeForTraining = true(nResults,1);
                end
                if isempty(this.SimulationSets(ct).IncludeForExportToWorkspace)
                    this.SimulationSets(ct).IncludeForExportToWorkspace = true(nResults,1);
                end
            end
            notify(this,'DataChanged')
        end

        function val = get.HaveSimulinkModel(this)

            val = ~isempty(this.Model);
        end
    end

    methods(Access = protected)
        function [eonly, ronly, eandr, out] = categorizeSignals(this)
            %categorizeSignals
            %
            %  Query the ModelPorts property to determine the following types
            %     - Signals that are experiment inputs only
            %     - Signals that are ROM inputs only
            %     - Signals that are experiment and ROM inputs
            %     - Signals that are outputs

            %Output signals
            out = this.ModelPorts.LoggedOutputs;

            %Input signals
            enames = romapp.internal.data.ModelPorts.getFullName(this.ModelPorts.ExperimentInputSignals);
            rnames = romapp.internal.data.ModelPorts.getFullName(this.ModelPorts.InputSignals);

            %Find signals that are both experiment and rom inputs
            [~,ia,ib] = intersect(enames,rnames);
            eandr  = this.ModelPorts.ExperimentInputSignals(ia);

            %Find signal that are only experiment or only rom inputs
            eonly = setdiff(1:numel(this.ModelPorts.ExperimentInputSignals),ia);
            eonly = this.ModelPorts.ExperimentInputSignals(eonly);
            ronly = setdiff(1:numel(this.ModelPorts.InputSignals),ib);
            ronly = this.ModelPorts.InputSignals(ronly);
        end
        function [eonly, eandr] = categorizeParameters(this)
            %categorizeParameters
            %
            %  Query the ModelPorts property to determine the following types
            %     - Parameters that are experiment inputs only
            %     - Parameters that are experiment and ROM inputs
            
            %Input parameters
            enames = romapp.internal.data.ModelPorts.getFullName(this.ModelPorts.ExperimentInputParameters);
            rnames = romapp.internal.data.ModelPorts.getFullName(this.ModelPorts.InputParameters);

            %Find parameters that are both experiment and rom inputs
            [~,ia] = intersect(enames,rnames);
            eandr  = this.ModelPorts.ExperimentInputParameters(ia);

            %Find parameters that are only experiment inputs
            eonly = setdiff(1:numel(this.ModelPorts.ExperimentInputParameters),ia);
            eonly = this.ModelPorts.ExperimentInputParameters(eonly);
        end
        function [ds,ddCleanUpFcn] = createBaseDesignSpace(this,haveSignalInjection,isParallel,enableBaseWSAccess)
            %createBaseDesignSpace
            %
            % Model and Block settings common to all simulations

            ddCleanUpFcn = []; %This only used for models with reference configsets and data dictionaries

            %Signal logging format
            mdlParameters = {...
                'SignalLogging', 'on'; ...
                'SignalLoggingName', this.LOGNAME; ...
                'ReturnWorkspaceOutputs', 'on'; ...
                'DatasetSignalFormat', 'timetable'};

            dlo = get_param(this.Model,'DataLoggingOverride');
            if ~strcmp(dlo.LoggingMode,'LogAllAsSpecifiedInModel')
                %Disable data logging override
                dlo.LoggingMode = 'LogAllAsSpecifiedInModel';
                mdlParameters = vertcat(mdlParameters, ...
                    {'DataLoggingOverride', dlo});
            end
            if haveSignalInjection
                mdlParameters = vertcat(mdlParameters, {...
                    'OutputOption', 'AdditionalOutputTimes'; ...
                    'OutputTimes', 'INJECT_OUT_TIMES'; ...
                    'StopTime', 'INJECT_OUT_TIMES(end)'});
                if enableBaseWSAccess
                    %Needed for models with Data Dictionaries as signal
                    %injection adds variables to base workspace
                    mdlParameters = vertcat(mdlParameters,{...
                        'EnableAccessToBaseWorkspace', 'on'});
                end
            end

            if this.SimulationOptions.LogStates
                mdlParameters = vertcat(mdlParameters, {...
                    'SaveState', 'on'; ...
                    'SaveFormat', 'dataset'; ...
                    'SaveStateName', this.STATELOGNAME});
            else
                mdlParameters = vertcat(mdlParameters, {...
                    'SaveState','off'});
            end
            if this.SimulationOptions.LogToFile && ~isParallel
                filename = this.Model+"_ROMSimulation.mat";
                filename = char(fullfile(this.SimulationOptions.FileLocation,filesep,filename));
                mdlParameters = vertcat(mdlParameters,{...
                    'LoggingToFile','on'; ...
                    'LoggingFileName', filename});
            else
                mdlParameters = vertcat(mdlParameters,{...
                    'LoggingToFile','off'});
            end

            if strcmp(this.SimulationOptions.SignalLogging,'romonly')
                %Find all scopes in the model and disable them. Find all
                %To-Workspace blocks and comment them out
                blkScope = find_system(this.Model,...
                    'LookUnderMasks','all',...
                    'MatchFilter', @Simulink.match.activeVariants,...
                    'BlockType','Scope');
                blkToWorkspace = find_system(this.Model,...
                    'LookUnderMasks','all',...
                    'MatchFilter', @Simulink.match.activeVariants, ...
                    'BlockType','ToWorkspace');
                blkParameters = cell(numel(blkScope)+numel(blkToWorkspace),3);
                for ct=1:numel(blkScope)
                    %simin = setBlockParameter(simin,blks{ct},'DataLogging','off');
                    blkParameters(ct,:) = {blkScope{ct},'DataLogging','off'};
                end
                for ct=1:numel(blkToWorkspace)
                    %simin = setBlockParameter(simin,blkToWorkspace{ct},'Commented','on');
                    blkParameters(ct+numel(blkScope),:) = {blkToWorkspace{ct},'Commented','on'};
                end

                %Disable output, datastore, final state, and time logging
                mdlParameters = vertcat(mdlParameters, {...
                    'SaveTime', 'off'; ...
                    'SaveOutput', 'off'; ...
                    'SaveFinalState', 'off'; ...
                    'DSMLogging', 'off'});

                %Check for simscape logging and disable that. If/when we
                %support logging simscape signals will have to revisit
                %this.
                cs = getActiveConfigSet(char(this.Model));
                if cs.hasProp('SimscapeLogType')
                    mdlParameters = vertcat(mdlParameters, {...
                        'SimscapeLogType','none'});
                end

                %Find all currently logged signals and disable ones not
                %created by signal injection
                logInfo = Simulink.SimulationData.ModelLoggingInfo.createFromModel(char(this.Model));
                for ct=1:numel(logInfo.Signals)
                    blockpath = logInfo.Signals(ct).BlockPath;
                    if ~contains(getBlock(blockpath,1),'sig_inject')
                        logInfo.Signals(ct).LoggingInfo.DataLogging = false;
                    end
                end
            else
                blkParameters = cell(0,3);
            end

            %Create the different Model and Block parameter set value
            %objects
            paramValues = cell(size(mdlParameters,1)+size(blkParameters,1),1);
            for ct=1:size(mdlParameters,1)
                slP = multisim.design.internal.ModelParameter(mdlParameters{ct,1});
                paramValues{ct} = multisim.design.internal.ValueSetParameter(slP,mdlParameters{ct,2});
            end
            for ct=1:size(blkParameters,1)
                slP = multisim.design.internal.BlockParameter(blkParameters{ct,1},blkParameters{ct,2});
                paramValues{ct+size(mdlParameters,1)} = multisim.design.internal.ValueSetParameter(slP,blkParameters{ct,3});
            end
            
            %Create a sequential design study using the parameter set value
            %objects
            ds = multisim.design.internal.Sequential([paramValues{:}]);
        end
        function [pROM,pExpOnly] = splitParameters(this,params)
            %splitParameters
            %
            % Split parameters into those that are ROM inputs and
            % those used for experiment only

            eonly = categorizeParameters(this);
            if isempty(eonly)
                pROM = params;
                pExpOnly = romapp.internal.data.ParameterData.empty;
            else
                idxEonly = false(size(params));
                for ctP = 1:numel(params)
                    for ctR=1:numel(eonly)
                        idxEonly(ctP) = isequal(params(ctP).BlockPath,eonly(ctR).BlockPath) && ...
                            isequal(params(ctP).Name,eonly(ctR).Name);
                        if idxEonly(ctP)
                            break
                        end
                    end
                end
                pExpOnly = params(idxEonly);
                pROM = params(~idxEonly);
            end
        end
    end

    methods(Access = public, Hidden = true)
        function changeModelName(this,newname)
            %changeModelName
            %
            %   Utility to change the root level model name the session
            %   data refers to. Useful when renaming a Simulink model.
            %
            %   changeModelName(obj,newname)
            %

            changeModelName(this.ModelPorts,newname,this.Model)
            for ct=1:numel(this.SimulationSets)
                changeModelName(this.SimulationSets(ct),newname,this.Model)
            end
            this.Model = newname;

        end
    end

    methods(Access = protected, Static = true)
        function pSig = addInjectionPoint(mgr, sig,itype, logm, logp)
            %addInjectionPoint
            %
            %  Add signals as insertion points to the signal injection manager

            nSig = numel(sig);
            pSig = slcontrollib.internal.siginject.InjectionPointData.empty;
            for ct=1:nSig
                sigPath = convertToCell(sig(ct).BlockPath);
                sigPath = sigPath{1}; %How handle model references
                pt = addPoint(mgr,sigPath,sig(ct).PortIndex);
                pt.OpeningTime = inf;
                pt.LogMeasuredSignal = logm;
                pt.LogPerturbedSignal = logp;
                pt.PerturbationType = itype;
                pSig = [pSig; pt]; %#ok<AGROW>
            end
        end
        function allE = checkAndConfigureInjectionPoint(pt)

            allE = [];
            for ct=1:numel(pt)
                try
                    romapp.internal.data.AppData.checkInjectionPoint(pt(ct));
                    sigData = getSignalData(pt(ct));
                    if isfinite(sigData.SampleTime)
                        pt(ct).PerturbSampleTime = sigData.SampleTime;
                    else
                        romapp.internal.resources.error('errRun_InfSampleTime',pt(ct).Block+":"+pt(ct).PortNumber)
                    end
                catch E
                    allE = vertcat(allE,E); %#ok<AGROW>
                end
            end
        end
        function checkInjectionPoint(pt)

            sigData = getSignalData(pt);
            if ~isequal(prod(sigData.Dimension),1)
                romapp.internal.resources.error('errRun_NonScalarSignal',pt.Block+":"+pt.PortNumber)
            end
            if sigData.IsComplex
                romapp.internal.resources.error('errRun_ComplexSignal',pt.Block+":"+pt.PortNumber)
            end
            if ~any(strcmp(sigData.DataType,["double", "single"]))
                romapp.internal.resources.error('errRun_NonDoubleSignal',pt.Block+":"+pt.PortNumber)
            end
            if sigData.SampleTime(1) < 0
                romapp.internal.resources.error('errRun_TriggeredSignal',pt.Block+":"+pt.PortNumber)
            end
        end
        function simOut = postSimFcn(simOut,...
                simIn, ...
                SignalInjectionPoints, ...
                SignalLogName, ...
                StateLogName, ...
                ClearLog, ...
                Inputs, ...
                Outputs, ...
                ROMParameters, ...
                ExperimentParameters, ...
                usePostSimFcn, ...
                userFcn)
            %PostSimFcn
            %
            
            %Map parameters in SimulationInput to Parameters vector
            for ctV=1:numel(simIn.Variables)
                ROMParameters = romapp.internal.data.AppData.setParameterFromVariable(ROMParameters,simIn.Variables(ctV));
                ExperimentParameters = romapp.internal.data.AppData.setParameterFromVariable(ExperimentParameters,simIn.Variables(ctV));
            end
            for ctV=1:numel(simIn.BlockParameters)
                ROMParameters = romapp.internal.data.AppData.setParameterFromBlockVariable(ROMParameters,simIn.BlockParameters(ctV));
                ExperimentParameters = romapp.internal.data.AppData.setParameterFromBlockVariable(ExperimentParameters,simIn.BlockParameters(ctV));
            end
            simOut.ROMParameters = ROMParameters;
            simOut.ExperimentParameters = ExperimentParameters;

            if isempty(userFcn) || ~usePostSimFcn
                %Nothing else to do, quick return
                return
            end

            %Collect simulation results and info in a result store, create
            %an experiment and have it use the store.
            store = romapp.internal.data.SimulationResultStore(...
                    simOut, ...
                    'SignalInjectionPoints', SignalInjectionPoints, ...
                    'SignalLogName', SignalLogName, ...
                    'StateLogName', StateLogName, ...
                    'InputSignals', Inputs, ...
                    'OutputSignals', Outputs, ...
                    'InputParameters', [ROMParameters,ExperimentParameters]);
            eData = romapp.internal.data.ExperimentData;
            eData = setResultStore(eData,store);

            %Call user provided post-sim function
            simOut.DerivedData = userFcn(eData);

            if ClearLog
                %Remove any unexpected data
                names = who(simOut);
                names = setdiff(names,{SignalLogName, StateLogName, 'DerivedData', 'ROMParameters'});
                for ct=1:numel(names)
                    simOut = removeProperty(simOut,names{ct});
                end
            end
        end
        function p = setParameterFromVariable(p,Variable)
            for ct=1:numel(p)
                if strcmp(Variable.Name,p(ct).Name)
                    p(ct).Value = Variable.Value;
                    break
                end
            end
        end
        function p = setParameterFromBlockVariable(p,BlockParameter)
            for ct = 1:numel(p)
                sameName = strcmp(BlockParameter.Name, p(ct).Name);
                bp = convertToCell(p(ct).BlockPath);
                bp = bp{1}; %How handle model reference
                if sameName && isequal(BlockParameter.BlockPath,bp)
                    p(ct).Value = eval(BlockParameter.Value);
                end
            end
        end
    end

    methods (Hidden)
        function L = qeGetSimsetListeners(this)
            L = this.SimulationSetListeners;
        end

        function qeSetSimsetListeners(this, L)
            this.SimulationSetListeners = L;
        end
    end

    methods(Access = public, Static)
        function r = FinalValuePostSimFcn(data)

            outSigs = data.OutputSignals;

            for ct=1:numel(outSigs)
                values = outSigs(ct).Values;
                values = values(end,:);
                outSigs(ct).Values = values;
            end
            r = outSigs;
        end
    end
end

function lSimCleanup(insertionMGR, studioBlocker,dd)
%Clean up actions to restore insertion manager and restore Simulation
%Canvas interactions
cleanup(insertionMGR);
delete(studioBlocker)
if ~isempty(dd)
    %We only ever set from false to true, so revert back to false. This
    %will dirty the data dictionary so discard any change
    dd.EnableAccessToBaseWorkspace = false;
    dd.discardChanges
end
end

function lSimMgrSetupFcn(insertionMGR,ddName)
%Used to setup parallel workers

if ~isempty(insertionMGR)
    slcontrollib.internal.siginject.BlockInsertionManager.workerSetupFcn(insertionMGR)
end
if ~isempty(ddName)
    dd = Simulink.data.dictionary.open(ddName);
    ddState = dd.EnableAccessToBaseWorkspace;
    if ~ddState
        %Enable 
        dd.EnableAccessToBaseWorkspace = true;
    end
end

end

function lSimMgrCleanup(insertionMGRCleanup,ddName)
%Used to cleanup parallel workers

if insertionMGRCleanup
    slcontrollib.internal.siginject.BlockInsertionManager.workerCleanupFcn();
end
if ~isempty(ddName)
    %We only ever set from false to true, so revert back to false. This
    %will dirty the data dictionary so discard any change
    dd = Simulink.data.dictionary.open(ddName);
    dd.EnableAccessToBaseWorkspace = false;
    dd.discardChanges
end
end

% LocalWords:  ADDSIMULATIONSET REMOVESIMULATIONSET romonly simin postsim newname databrowser lbl
