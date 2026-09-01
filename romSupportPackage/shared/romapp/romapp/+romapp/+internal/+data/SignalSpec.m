classdef SignalSpec < handle
    %

    % SignalSpec
    %

    % Copyright 2023-2025 The MathWorks, Inc.

    properties(Constant, Abstract)
        TYPE string
        DESCRIPTION string
    end

    properties(Access = private)
        ID string
    end

    properties
        Signals Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
        Name string = string.empty
        Enable logical = true
        Mode string {mustBeMember(Mode,["add","replace"])} = "replace"
    end

    events(NotifyAccess = protected)
        DataChanged
    end

    methods(Access = protected)
        function obj = SignalSpec(options)
            arguments
                options.Signals Simulink.SimulationData.Signal = Simulink.SimulationData.Signal.empty
                options.Name string = string.empty;
                options.Enable logical = true;
                options.Mode string = "replace";
            end

            obj.ID = matlab.lang.internal.uuid;
            obj.Signals = options.Signals;
            obj.Name = options.Name;
            obj.Enable = options.Enable;
            obj.Mode = options.Mode;
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
            for ct=1:numel(this.Signals)
                bp = this.Signals(ct).BlockPath;
                bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                this.Signals(ct).BlockPath = bp;
            end
        end

        function dspace = createDesignSpace(this,dspace,injectionPts,values)
            %createDesignSpace
            %
            % Create a multi-sim design space that contains variables to
            % set the values for the signal injection points.

            %Generate the timeseries for each signal
            [tsAll,t] = generateTimeseries(this,values,1);

            %Assign the timeseries to injection points and variables,
            %combine the variables into the design study.
            msValueSet = cell(numel(this.Signals),1);
            for ct=1:numel(this.Signals)
                ts = tsAll{ct};
                [~,msValueSet{ct}] = createDesignParameter(this,this.Signals(ct),injectionPts,ts);
            end

            slP = multisim.design.internal.Variable('INJECT_OUT_TIMES','global-workspace');
            pValue = multisim.design.internal.ValueSetParameter(slP,t(1));
            dspace = multisim.design.internal.Sequential([dspace,[msValueSet{:}],pValue]);
        end

        function [msvSig,msvTime] = getMultisimDesignVariables(this,injectionPts)
            %getMultiSimDesignVariables
            %
            % Create multi-sim variables to use to set the signal
            % injection values.
            %

            msvSig = cell(numel(this.Signals),1);
            for ct=1:numel(this.Signals)
                msvSig{ct} = createDesignParameter(this,this.Signals(ct),injectionPts);
            end

            msvTime = multisim.design.internal.Variable('INJECT_OUT_TIMES','global-workspace');
        end
    end

    methods(Access = protected)

        function [msParam,msValueSet] = createDesignParameter(this,sigSpec,injectionPts,signalData)
            %createDesignParameter
            %
            % [msParam,msValueSet] = createDesignParameter(this,sigSpec,injectionPts,signalData)
            %
            % Creates multi-sim design variables to set the signal values
            % for an injection point (injection point data is set via model
            % variables). Optionally returns the multi-sim value set with
            % the signal data.
            %
            % Inputs
            %   sigSpec - a Simulink.SimulationData.Signal
            %   injectionPoints - a vector of slcontrollib.internal.siginject.InjectionPointData
            %   signalData - timeseries with signal data, only needed/used
            %                if the msValueSet return argument is requested
            %
            % Outputs
            %   msParam - a multisim.design.internal.Variable
            %   msValueSet - a multisim.design.internal.ValueSetParameter
            %

            createValueSet = nargout > 1;

            blkPath = convertToCell(sigSpec.BlockPath);
            blkPath = blkPath{1}; %How handle model reference
            found = false;
            ctP = 1;
            while ~found && ctP <= numel(injectionPts)
                pt = injectionPts(ctP);
                ptData = getSignalData(pt);
                found = strcmp(blkPath,ptData.Block);
                found = found && sigSpec.PortIndex == ptData.PortNumber;
                ctP = ctP+1;
            end
            if found
                switch this.Mode
                    case "add"
                        pt.PerturbationType = slcontrollib.internal.siginject.PerturbationType.ADD;
                    case "replace"
                        pt.PerturbationType = slcontrollib.internal.siginject.PerturbationType.REPLACE;
                end
                simin = Simulink.SimulationInput();
                simin = installPertSignal(pt,simin,[]);
                msParam = multisim.design.internal.Variable(simin.Variables.Name,simin.Variables.Workspace);
                if createValueSet
                    msValueSet = multisim.design.internal.ValueSetParameter(msParam,signalData);
                end
            end
        end
    end

    methods(Access = public, Abstract = true)
        nsim = getNumSim(this)
        [ts,t] = generateTimeseries(this)
        sig = getSignalValues(this,sig)
        ranges = getPlotRanges(this,values)
        israndom = isRandom(this)
        NumPulse = getNumPulse(this)
        values = sampleSpecValues(this,nump)
        obj = copy(this)
        setSignalLimits(this,ranges)
        ranges = getSignalLimits(this)
    end
end

% LocalWords:  injectionPts slcontrollib siginject multisim
