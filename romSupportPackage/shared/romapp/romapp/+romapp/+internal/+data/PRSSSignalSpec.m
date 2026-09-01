classdef PRSSSignalSpec < romapp.internal.data.SignalSpec
    %

    % PRSSSignalSpec - Spec for a pseudo random Sobol sequence signal
    %

    % Copyright 2024-2025 The MathWorks, Inc.

    properties(Constant)
        TYPE string = "PRSS";
        DESCRIPTION string = romapp.internal.resources.getString('lblPRSS_Description');
    end
    
    properties(SetAccess = protected, GetAccess = public)
        PulseWidth double = 2
        NumPulse double = 10
        Ranges double
        Values double
    end

    methods
        function obj = PRSSSignalSpec(signals)

            obj = obj@romapp.internal.data.SignalSpec(...
                'Signals', signals, ...
                'Name', "PRSS");

            %Initialize pulse width, num pulses and signal ranges
            setValues(obj,2,10,repmat([-10 10],numel(signals),1))
        end
        function obj = copy(this)

            %Construct new object
            obj = romapp.internal.data.PRSSSignalSpec(this.Signals);

            %Set Properties from parent
            obj.Enable = this.Enable;
            obj.Mode = this.Mode;

            %Set own properties
            obj.PulseWidth = this.PulseWidth;
            obj.Ranges = this.Ranges;
        end
    end

    methods
        function setValues(this,pwidth,nump,ranges)

            this.PulseWidth = pwidth;
            this.NumPulse = nump;
            this.Ranges = ranges;

            notify(this,'DataChanged')
        end

        function updateSpecValues(this,values)
            this.Values = values;
            notify(this,'DataChanged')
        end

        function values = sampleSpecValues(this,nump)
            nSig = numel(this.Signals);
            ss = sobolset(nSig);
            ss = scramble(ss);
            ss = net(ss,nump);
            values = nan(nump,nSig);
            ranges = this.Ranges;
            for ct = 1:nSig
                values(:,ct) = ranges(ct,1) + diff(ranges(ct,:))*ss(:,ct);
            end
        end
    end

    methods
        function nsim = getNumSim(this)
            nsim = 1;
        end

        function NumPulse = getNumPulse(this)
            NumPulse = this.NumPulse;
        end

        function [ts,t] = generateTimeseries(this,values,numSim)
            %generateTimeseries
            %

            nSig = numel(this.Signals);
            ts = cell(numSim,nSig);
            t = cell(numSim,1);
            tValues = this.PulseWidth*(0:this.NumPulse)';
            sigSize = this.NumPulse; 
            for ctSim = 1:numSim
                t{ctSim,1} = tValues;
                iRange = (1:sigSize) + (ctSim-1)*sigSize;
                for ctSig = 1:nSig
                    ts{ctSim,ctSig} = timeseries([values(iRange,ctSig); values(iRange(end),ctSig)],tValues);
                end
            end
        end

        function signals = getSignalValues(this,values)    
            values = values(1:this.NumPulse,:);
            nSig = numel(this.Signals);
            signals = cell(nSig,1);
            t = this.PulseWidth*(0:this.NumPulse)';
            for ct=1:nSig
                %Convert pulse amplitudes and start times to pulses
                amps = [values(:,ct), values(:,ct)]';
                tvec = [t(1:end-1), t(2:end)]';
                vals = timetable(seconds(tvec(:)),amps(:),'VariableNames',{'Data'});
                signals{ct} = vals;
            end
        end

        function ranges = getPlotRanges(this,values)
            ranges = this.Ranges;
        end

        function israndom = isRandom(this)
            israndom = true;
        end
        
        function setSignalLimits(this,ranges)

            if isfield(ranges,'PulseWidth')
                pw = ranges.PulseWidth;
            else
                pw = this.PulseWidth;
            end
            nump = floor(ranges.Length/pw);
            setValues(this,pw,nump,ranges.Amplitudes)
        end
        function ranges = getSignalLimits(this)
            ranges = struct(...
                'Amplitudes', this.Ranges, ...
                'Length', this.PulseWidth*this.NumPulse, ...
                'PulseWidth',this.PulseWidth);
        end
    end
end

% LocalWords:  PRSS lbl Sobol
