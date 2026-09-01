classdef FSCSignalSpec < romapp.internal.data.SignalSpec
    % 

    % FSCSignalSpec - Spec for a chirp signal
    % 

    % Copyright 2024-2025 The MathWorks, Inc.

    properties(Constant)
        TYPE string = 'FSCS';
        DESCRIPTION string = romapp.internal.resources.getString('lblFSCS_Description')
    end

    properties(SetAccess = protected, GetAccess = public)
        InitialFrequency double 
        TargetFrequency double 
        InitialPhase double 
        TargetTime double = 20
        Ranges double 
        MultiplyFrequency double = 20;
        T double
    end

    methods
        function obj = FSCSignalSpec(signals)
            
            obj = obj@romapp.internal.data.SignalSpec(...
                'Signals', signals, ...
                'Name', "FSCS");
            % Initialize initial frequency, target frequency, target time,
            % and signal ranges
            nSig = numel(signals);
            setValues(obj, 0.1*ones(1,nSig), ones(1,nSig), zeros(1,nSig), 20, repmat([-1 1],numel(signals),1));
        end

        function obj = copy(this)
            % Construct new object
            obj = romapp.internal.data.FSCSignalSpec(this.Signals);

            % Set Properties from parent
            obj.Enable = this.Enable;
            obj.Mode = this.Mode;
            
            % Set own properties
            obj.InitialFrequency = this.InitialFrequency;
            obj.TargetFrequency = this.TargetFrequency;
            obj.InitialPhase = this.InitialPhase;
            obj.TargetTime = this.TargetTime;
            obj.Ranges = this.Ranges;
            obj.T = this.T;
        end
    end
    
    methods
        function setValues(this, ifreq, tfreq, iphase, ttime, ranges)
            this.InitialFrequency = ifreq;
            this.TargetFrequency = tfreq;
            this.InitialPhase = iphase;
            this.TargetTime = ttime; 
            this.Ranges = ranges;       
            tSamp = getSamplingTime(this);
            this.T = tSamp;
            notify(this,'DataChanged')
        end

        function NumPulse = getNumPulse(this)
            NumPulse = size(this.T,1);
        end
        
        function tSamp = getSamplingTime(this)
            % For each signal, the sampling interval is 1/MultiplyFrequency
            % of the maximum frequency. The finest sampling interval is
            % used for all signals. 
            ifreq = this.InitialFrequency;
            tfreq = this.TargetFrequency;
            freqMax = max([ifreq,tfreq]);
            Ts = 1/(this.MultiplyFrequency*freqMax); % sampling interval   
            tSamp = unique( [0:Ts:this.TargetTime this.TargetTime]' );
        end

        function nsim = getNumSim(this)
            nsim = 1;
        end

        function values = sampleSpecValues(this,nump)
            ifreq = this.InitialFrequency;
            tfreq = this.TargetFrequency;
            iphase = this.InitialPhase;
            ttime = this.TargetTime; 
            ranges = this.Ranges;
            nSig = numel(this.Signals);
            tSamp = getSamplingTime(this);
            % Sample each signal using the same time vector
            numPulse = size(tSamp,1);
            values = nan(numPulse,nSig);
            for ct = 1:nSig
                chirpValue = 0.5*chirp(tSamp,ifreq(ct),ttime,tfreq(ct),'linear',iphase(ct));
                values(:,ct) = ranges(ct,1) + diff(ranges(ct,:))*(chirpValue+0.5);
            end
            this.T = tSamp;
        end

        function [ts,t] = generateTimeseries(this,values,numSim)
            %generateTimeseries
            %

            nSig = numel(this.Signals);
            ts = cell(numSim,nSig);
            t = cell(numSim,1);
            tValues = this.T;
            sigSize = numel(tValues); 
            for ctSim = 1:numSim
                t{ctSim,1} = tValues;
                iRange = (1:sigSize) + (ctSim-1)*sigSize;
                for ctSig = 1:nSig
                    ts{ctSim,ctSig} = timeseries(values(iRange,ctSig),tValues);
                end
            end
        end

        function signals = getSignalValues(this,values)
            nSig = numel(this.Signals);
            NumPulse = size(this.T,1);
            if isempty(values)
                values = nan(NumPulse,nSig);
            end            
            signals = cell(nSig,1);
            for ct = 1:nSig
                signals{ct} = timetable(seconds(this.T),values(1:NumPulse,ct),'VariableNames',{'Data'});
            end
        end

        function ranges = getPlotRanges(this,values)
            if isempty(values)
                ranges = this.Ranges;
            else
                ranges = [min(values)' max(values)'];
            end
        end
        
        function israndom = isRandom(this)
            israndom = false;
        end

        function setSignalLimits(this,ranges) 
            setValues(this, this.InitialFrequency, this.TargetFrequency, this.InitialPhase,...
                ranges.Length, ranges.Amplitudes);
        end

        function ranges = getSignalLimits(this)
            ranges = struct(...
                'Amplitudes', this.Ranges, ...
                'Length', this.TargetTime);
        end

    end
end

% LocalWords:  FSCS lbl
