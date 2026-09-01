classdef SimulationSpec < handle
    %

    % SimulationSpec
    %

    % Copyright 2023-2025 The MathWorks, Inc.

    properties(Access = private)
        ID string
    end

    properties(GetAccess = public, SetAccess = private)
        Version string = string.empty;
    end

    properties
        %The property this.Factors is a struct with SignalValues and
        %ParameterValues.
        %
        %ParameterValues is a matrix. Its number of rows is (number of
        %parameter value combinations) rows. Its number of columns is
        %(number of parameters).
        %
        %SignalValues is a matrix for random and chirp signals. Its number
        %of rows is (number of pulses*number of parameter value
        %combinations). Its number of columns is (number of signals).
        %
        %SignalValues is a cell array for Custom Signal, because we allow
        %different signal lengths from users. Each cell is the values for
        %one signal.

        SignalSpec romapp.internal.data.SignalSpec = romapp.internal.data.PRSignalSpec.empty
        ParameterSpec romapp.internal.data.ParameterSpec = romapp.internal.data.GriddedParameterSpec.empty
        BoundarySpec romapp.internal.data.BoundarySpec = romapp.internal.data.BoundarySpec.empty
        Name string = string.empty
        Enable logical = true
        FactorValues romapp.internal.data.FactorValues = romapp.internal.data.FactorValues()
    end

    properties(Access = private, Transient = true)
        SignalSpecListener
        ParameterSpecListener
        BoundarySpecListener
        FactorValuesListener
    end

    events(NotifyAccess = protected)
        DataChanged
    end

    methods
        function obj = SimulationSpec(options)
            arguments
                options.Signals Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
                options.Parameters romapp.internal.data.ModelParameter = romapp.internal.data.ModelParameter.empty
                options.Boundaries romapp.internal.data.BoundarySpec = romapp.internal.data.BoundarySpec.empty
                options.Name string = "SimSpec";
                options.Enable logical = true;
            end

            obj.ID = matlab.lang.internal.uuid;
            obj.Version = "2.0";
            obj.Enable = options.Enable;
            obj.Name = options.Name;

            if ~isempty(options.Signals)
                %Create a default signal spec
                obj.SignalSpec = romapp.internal.data.PRSignalSpec(options.Signals);
                createSignalDataListeners(obj)
            end
            if ~isempty(options.Parameters)
                %Create a default parameter spec
                obj.ParameterSpec = romapp.internal.data.GriddedParameterSpec(options.Parameters);
                createParameterDataListeners(obj)
            end
            if ~isempty(options.Boundaries)
                %Default is no boundaries
                obj.BoundarySpec = options.Boundaries;
                createBoundaryDataListeners(obj)
            end
            obj.FactorValues = romapp.internal.data.FactorValues();
            createFactorDataListeners(obj)
            sampleFactors(obj)
        end

        function obj = copy(this)

            if isempty(this.SignalSpec) && isempty(this.ParameterSpec)
                %No Parameters or Signals
                obj = romapp.internal.data.SimulationSpec(...
                    'Name', this.Name, ...
                    'Enable', this.Enable);
                return
            end

            if isempty(this.SignalSpec)
                %Parameters only
                obj = romapp.internal.data.SimulationSpec(...
                    'Parameters', this.ParameterSpec.Parameters, ...
                    'Name', this.Name, ...
                    'Enable', this.Enable);
                obj.ParameterSpec = copy(this.ParameterSpec);
                createParameterDataListeners(obj)
            elseif isempty(this.ParameterSpec)
                % Signals only
                obj = romapp.internal.data.SimulationSpec(...
                    'Signals', this.SignalSpec.Signals, ...
                    'Boundaries', this.BoundarySpec, ...
                    'Name', this.Name, ...
                    'Enable', this.Enable);
                obj.SignalSpec = copy(this.SignalSpec);
                createSignalDataListeners(obj)
            else
                %Signals, parameters
                obj = romapp.internal.data.SimulationSpec(...
                    'Signals', this.SignalSpec.Signals, ...
                    'Parameters', this.ParameterSpec.Parameters, ...
                    'Boundaries', this.BoundarySpec, ...
                    'Name', this.Name, ...
                    'Enable', this.Enable);
                obj.SignalSpec = copy(this.SignalSpec);
                obj.ParameterSpec = copy(this.ParameterSpec);
                createSignalDataListeners(obj)
                createParameterDataListeners(obj)
            end
            if ~isempty(this.BoundarySpec)
                obj.BoundarySpec = copy(this.BoundarySpec);
                createBoundaryDataListeners(obj)
            end
            obj.FactorValues = copy(this.FactorValues);
        end

        function [simin, param] = createSimulationInput(this,simin,pSig)

            if isempty(this.ParameterSpec) && isempty(this.SignalSpec)
                param = {romapp.internal.data.ParameterData.empty};
            elseif isempty(this.SignalSpec)
                %parameters only
                numSim = size(this.FactorValues.ParameterValues,1);
                simin = repmat(simin,[numSim,1]);
                [simin,param] = createSimulationInput(this.ParameterSpec,simin,this.FactorValues.ParameterValues);
            elseif isempty(this.ParameterSpec)
                %signals only
                simin = createSimulationInput(this.SignalSpec,simin,pSig,this.FactorValues.SignalValues);
                param = {romapp.internal.data.ParameterData.empty};
            else
                %both signals and parameters
                numSim = size(this.FactorValues.ParameterValues,1);
                siminAll = [];
                if iscell(this.FactorValues.SignalValues)
                    simin = createSimulationInput(this.SignalSpec,simin,pSig,this.FactorValues.SignalValues);
                    siminAll = repmat(simin,[numSim,1]);
                else
                    numPulse = getNumPulse(this.SignalSpec);
                    for i = 1:numSim
                        indStart = numPulse*(i-1)+1;
                        indEnd = numPulse*i;
                        simin = createSimulationInput(this.SignalSpec,simin,pSig,this.FactorValues.SignalValues(indStart:indEnd,:));
                        siminAll = [siminAll; simin];
                    end
                end
                [simin,param] = createSimulationInput(this.ParameterSpec,siminAll,this.FactorValues.ParameterValues);
            end
        end

        function [dspace, param] = createDesignSpace(this,baseSpace,pSig)
            %createDesignSpace
            %
            % Expand a base design space with signal inputs and parameter
            % values.

            %If there is no boundary model, or if there are only signals,
            %or if there are only parameters create the signal and
            %parameter design spaces independently and exhaustively combine
            %them. This is preferred as it is more memory efficient. If
            %there is a boundary model with both signals and parameters
            %then jointly create the design space (the parameter values can
            %influence the signal values and vice versa).

            haveSignals = ~isempty(this.SignalSpec);
            haveParameters = ~isempty(this.ParameterSpec);
            if hasBoundary(this) && haveSignals && haveParameters
                nSim = getNumSim(this);
                nSig = numel(this.SignalSpec.Signals);
                nParam = numel(this.ParameterSpec.Parameters);

                [msvSig,msvTime] = getMultisimDesignVariables(this.SignalSpec,pSig);
                [msvParam,param] = getMultisimDesignVariables(this.ParameterSpec);

                %Create multi-sim value-sets for signals
                valueSets = cell(nSig+1+nParam,1);
                [tsAll,tAll] = generateTimeseries(this.SignalSpec,this.FactorValues.SignalValues,nSim);
                valueSets{1} = multisim.design.internal.ValueSetParameter(msvTime,tAll);
                for ct=1:nSig
                    valueSets{1+ct} = multisim.design.internal.ValueSetParameter(msvSig{ct},tsAll(:,ct));
                end

                %Create multi-sim value-sets for parameters
                offset = nSig+1;
                for ct=1:nParam
                    values = num2cell(this.FactorValues.ParameterValues(:,ct));
                    if isempty(this.ParameterSpec.Parameters(ct).Workspace)
                        %Parameter is for a block, values need to be strings
                        values = cellfun(@(x) mat2str(x),values,'UniformOutput',false);
                    end
                    valueSets{offset+ct} = multisim.design.internal.ValueSetParameter(msvParam{ct},values);
                end

                %Convert the value sets into a sequential design space and
                %combine exhaustively with the base design space.
                sp1 = multisim.design.internal.Sequential([valueSets{:}]);
                dspace = multisim.design.internal.Exhaustive([baseSpace,sp1]);
            else

                %Add signals to the design space
                if isempty(this.SignalSpec)
                    %No simulation inputs, the design space is just the
                    %baseSpace
                    dspace = baseSpace;
                else
                    dspace = createDesignSpace(this.SignalSpec,baseSpace,pSig,this.FactorValues.SignalValues);
                end

                %Add parameters to the design space
                if isempty(this.ParameterSpec)
                    %No parameters
                    param = romapp.internal.data.ParameterData.empty;
                else
                    [dspace,param] = createDesignSpace(this.ParameterSpec,dspace,this.FactorValues.ParameterValues);
                end
            end
        end

        function convertToRandom(this,ranges)
            arguments
                this romapp.internal.data.SimulationSpec
                ranges double = [];
            end
            this.ParameterSpec = convertToRandom(this.ParameterSpec,ranges);
            createParameterDataListeners(this)
        end

        function convertToGridded(this)
            this.ParameterSpec = convertToGridded(this.ParameterSpec);
            createParameterDataListeners(this)
        end

        function convertSignalSpec(this,spec,intermSignalSpec)

            if ~isequal(this.SignalSpec.TYPE,spec)
                oldspec = intermSignalSpec;
                switch spec
                    case romapp.internal.data.PRSignalSpec.TYPE
                        newspec = romapp.internal.data.PRSignalSpec(this.SignalSpec.Signals);
                    case romapp.internal.data.PRBSSignalSpec.TYPE
                        newspec = romapp.internal.data.PRBSSignalSpec(this.SignalSpec.Signals);
                    case romapp.internal.data.FSCSignalSpec.TYPE
                        newspec = romapp.internal.data.FSCSignalSpec(this.SignalSpec.Signals);
                    case romapp.internal.data.PRSSSignalSpec.TYPE
                        newspec = romapp.internal.data.PRSSSignalSpec(this.SignalSpec.Signals);
                    case romapp.internal.data.CustomSignalSpec.TYPE
                        newspec = romapp.internal.data.CustomSignalSpec(this.SignalSpec.Signals);
                    otherwise
                        romapp.internal.resources.error('errUnexpected','Unsupported Signal Spec Type')
                end

                newspec.Enable = oldspec.Enable;
                newspec.Mode = oldspec.Mode;
                setSignalLimits(newspec,getSignalLimits(oldspec))

                this.SignalSpec = newspec;
                createSignalDataListeners(this)
            end
        end

        function createDataListeners(this)
            %

            %Called when loading a app session to recreate all data
            %listeners
            createSignalDataListeners(this)
            createParameterDataListeners(this)
            createBoundaryDataListeners(this)
            createFactorDataListeners(this)
        end

    end

    methods(Access = protected)
        function createSignalDataListeners(this)
            if ~isempty(this.SignalSpecListener)
                delete(this.SignalSpecListener)
                this.SignalSpecListener = [];
            end
            if ~isempty(this.SignalSpec)
                weak = romapp.internal.resources.WeakReference(this);
                this.SignalSpecListener = addlistener(this.SignalSpec,...
                    'DataChanged', @(hSrc,hData) cbSpecChanged(weak.Handle));
            end
        end

        function createParameterDataListeners(this)
            if ~isempty(this.ParameterSpecListener)
                delete(this.ParameterSpecListener)
                this.ParameterSpecListener = [];
            end
            if ~isempty(this.ParameterSpec)
                weak = romapp.internal.resources.WeakReference(this);
                this.ParameterSpecListener = addlistener(this.ParameterSpec,...
                    'DataChanged', @(hSrc,hData) cbSpecChanged(weak.Handle));
            end
        end

        function createBoundaryDataListeners(this)
            if ~isempty(this.BoundarySpecListener)
                delete(this.BoundarySpecListener)
                this.BoundarySpecListener = [];
            end
            if ~isempty(this.BoundarySpec)
                weak = romapp.internal.resources.WeakReference(this);
                this.BoundarySpecListener = addlistener(this.BoundarySpec, ...
                    'DataChanged', @(hSrc,hData) cbSpecChanged(weak.Handle));
            end
        end

        function createFactorDataListeners(this)
            if ~isempty(this.FactorValuesListener)
                delete(this.FactorValuesListener)
                this.FactorValuesListener = [];
            end
            if ~isempty(this.FactorValues)
                weak = romapp.internal.resources.WeakReference(this);
                this.FactorValuesListener = addlistener(this.FactorValues, ...
                    'DataChanged', @(hSrc,hData) cbSpecChanged(weak.Handle));
            end
        end

        function cbSpecChanged(this)
            notify(this,'DataChanged')
        end
    end

    methods(Hidden = true)
        function id = getUID(this)
            id = this.ID;
        end
        function qeFireDataChanged(this)
            notify(this,'DataChanged')
        end
        function changeModelName(this,newname,oldname)
            %changeModelName
            %
            %   Utility to change the root level model name the session
            %   data refers to. Useful when renaming a Simulink model.
            %

            if ~isempty(this.ParameterSpec)
                changeModelName(this.ParameterSpec,newname,oldname)
            end
            if ~isempty(this.SignalSpec)
                changeModelName(this.SignalSpec,newname,oldname)
            end
        end
    end

    methods(Access = public)

        function nsim = getNumSim(this)
            if ~hasEnoughSamples(this)
                nsim = 0;
            elseif hasBoundary(this)
                nsim = max(1,size(this.FactorValues.ParameterValues,1));
            elseif isempty(this.SignalSpec) && isempty(this.ParameterSpec)
                nsim = 0;
            elseif isempty(this.SignalSpec)
                nsim = getNumSim(this.ParameterSpec);
            elseif isempty(this.ParameterSpec)
                nsim = getNumSim(this.SignalSpec);
            else
                nsim = getNumSim(this.SignalSpec) * getNumSim(this.ParameterSpec);
            end
        end

        function sampleFactors(this)
            sampleFactors(this.FactorValues, this)
        end

        function enoughSamples = hasEnoughSamples(this)
            if isempty(this)
                enoughSamples = false;
                return
            end
            enoughSamples = hasEnoughSamples(this.FactorValues);
        end

        function [values,ranges] = getPlotData(this)
            ranges = [];

            if ~isempty(this.SignalSpec)
                [values,ranges] = getSignalPlotData(this);
            end
            if ~isempty(this.ParameterSpec)
                [v,r] = getParameterPlotData(this);
                if isempty(ranges)
                    values = v;
                    ranges = r;
                else
                    %Exhaustively combine parameter and signal values
                    ranges = [ranges; r];
                    sValues = values;
                    pValues = v;
                    nPV = size(pValues,1);
                    if iscell(this.FactorValues.SignalValues)
                        sValues = getValuesArray(this.SignalSpec,sValues);
                        sValues = repmat(sValues,[nPV,1]);
                    end
                    nSV = size(sValues,1);
                    values = nan(nSV,size(pValues,2));
                    for i = 1:nPV
                        inds = (i-1)*(nSV/nPV)+1;
                        inde = i*(nSV/nPV);
                        values(inds:inde,:) = repmat(pValues(i,:),[nSV/nPV,1]);
                    end
                    values = [sValues,values];
                end
            end
            if iscell(values)
                values = getValuesArray(this.SignalSpec,values);
            end
        end

        function signals = getSignalValues(this)
            %outputs a cell array of timetables. of different timetable
            %sizes for chirp and custom
            signals = getSignalValues(this.SignalSpec,this.FactorValues.SignalValues);
        end

        function [sValues,sRanges] = getSignalPlotData(this)
            %outputs matrices
            sValues = this.FactorValues.SignalValues;  
            sRanges = getPlotRanges(this.SignalSpec, sValues);
        end

        function [pValues,pRanges] = getParameterPlotData(this)
            % Outputs matrices
            pValues = this.FactorValues.ParameterValues;
            pRanges= getPlotRanges(this.ParameterSpec,pValues);
        end
        
        function FactorLimits = getFactorLimits(spec, factorName)
            if ~isempty(spec.SignalSpec)
                signalNames = {spec.SignalSpec.Signals.Name};
                [isSignal,ind] = ismember(factorName,signalNames);
                if isSignal
                    FactorLimits = spec.SignalSpec.Ranges(ind,:);
                    return
                end
            end
            if ~isempty(spec.ParameterSpec)
                nParams = numel(spec.ParameterSpec.Parameters);
            else
                nParams = 0;
            end
            for iParam = 1:nParams
                paramName = char(romapp.internal.data.ModelPorts.getDisplayName(spec.ParameterSpec.Parameters(iParam)));
                if isequal(paramName,factorName)
                    if ~isRandom(spec.ParameterSpec)
                        %gridded 
                        paramValues = spec.ParameterSpec.Values{iParam};
                        FactorLimits = [min(paramValues), max(paramValues)];
                    elseif isa(spec.ParameterSpec.Distributions(1),'prob.UniformDistribution')
                        FactorLimits = getDistributionLimits(spec.ParameterSpec,iParam);
                    else
                        FactorLimits = [-Inf,Inf];
                    end
                end
            end
        end

    end

    methods(Static=true)
        function obj = loadobj(data)

            if isempty(data.Version)
                obj = romapp.internal.data.SimulationSpec.convertV1ToV2(data);
            else
                obj = data;
            end
        end
        function obj = convertV1ToV2(data)

            data.Version = "2.0";
            data.BoundarySpec = romapp.internal.data.BoundarySpec;
            emptyFactorValues = romapp.internal.data.FactorValues;
            data.FactorValues = populateFactorValues(emptyFactorValues, data);

            obj = data;
        end
    end

    methods (Access = public)
        function tf = hasBoundary(this)
            if isempty(this.BoundarySpec)
                tf = false;
            else
                tf = hasBoundaries(this.BoundarySpec);
            end
        end
        function tf = hasSignalBoundary(this)
            tf = false;
            if hasBoundary(this)
                SignalNames = getSignalNames(this);
                ParameterNames = getParameterNames(this);
                [SignalBoundaries, ~, ~] = separateBoundaries(this.BoundarySpec, SignalNames, ParameterNames);
                tf = ~isempty(SignalBoundaries.Factors);
            end
        end
        
        function FactorNames = getFactorNames(this)
            %Outputs a cell array of all factor (signals and parameter)
            %names.
            %
            %Outputs an empty array if there are no signals nor parameters.
            SignalNames = getSignalNames(this);
            ParameterNames = getParameterNames(this);
            FactorNames = [SignalNames,ParameterNames];
        end

        function SignalNames = getSignalNames(this)
            if ~isempty(this.SignalSpec)
                SignalNames = {this.SignalSpec.Signals.Name};
            else
                SignalNames = [];
            end
        end

        function ParameterNames = getParameterNames(this)
            if ~isempty(this.ParameterSpec)
                ParameterNames = romapp.internal.data.ModelPorts.getDisplayName(this.ParameterSpec.Parameters);
                ParameterNames = cellstr(ParameterNames');
            else
                ParameterNames = [];
            end
        end
    end

end

% LocalWords:  simin cb