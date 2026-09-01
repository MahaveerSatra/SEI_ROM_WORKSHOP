classdef CustomSignalSpec < romapp.internal.data.SignalSpec
    %

    % CustomSignalSpec - Spec for a custom signal
    %

    % Copyright 2024-2025 The MathWorks, Inc.

    properties(Constant)
        TYPE string = "CustomS";
        DESCRIPTION string = romapp.internal.resources.getString('lblCustomSignal_Description');
    end
    
    properties(SetAccess = protected, GetAccess = public)
    end

    properties(SetAccess = protected, GetAccess = public)
        userInput cell
        userData cell
        T cell
        Ranges double
    end

    methods
        function obj = CustomSignalSpec(signals)

            obj = obj@romapp.internal.data.SignalSpec(...
                'Signals', signals, ...
                'Name', "CustomS");

            %Initialize pulse width, num pulses and signal ranges
            nSig = numel(signals);
            setValues(obj, repmat({"[(0:0.1:10)', sin(0:0.1:10)']"},1,nSig),...
                repmat({[(0:0.1:10)', sin(0:0.1:10)']},1,nSig));
        end

        function obj = copy(this)
            %Construct new object
            obj = romapp.internal.data.CustomSignalSpec(this.Signals);
            %Set Properties from parent
            obj.Enable = this.Enable;
            obj.Mode = this.Mode;
            %Set own properties
            obj.userInput   = this.userInput;
            obj.userData    = this.userData;
            obj.T           = this.T;
            obj.Ranges      = this.Ranges;
        end
    end

    methods
        function setValues(this,userInputCell,userDataCell)
            % put inputs into array format
            nSig = numel(this.Signals);      
            Ts = cell(nSig,1);
            minVal = zeros(nSig,1);
            maxVal = zeros(nSig,1);
            for ct = 1:nSig
                [values{ct}, Ts{ct}] = convertOneInput(userDataCell{ct});
                minVal(ct) = min(values{ct});
                maxVal(ct) = max(values{ct});
            end
            % apply time and signal values
            this.userInput = userInputCell;
            this.userData = userDataCell;       
            this.T = Ts;
            this.Ranges = [minVal maxVal];

            notify(this,'DataChanged')
        end
    end

    methods
        function nsim = getNumSim(this)
            nsim = 1;
        end

        function NumPulse = getNumPulse(this)
            NumPulse = [];
        end

        function values = sampleSpecValues(this,nump)
            % put inputs into array format
            userDataCell = this.userData;
            nSig = numel(this.Signals);      
            values = cell(nSig,1);
            Ts = cell(nSig,1);
            minVal = zeros(nSig,1);
            maxVal = zeros(nSig,1);
            for ct = 1:nSig
                [values{ct}, Ts{ct}] = convertOneInput(userDataCell{ct});
                minVal(ct) = min(values{ct});
                maxVal(ct) = max(values{ct});
            end
        end 

        function [ts,t] = generateTimeseries(this,values,numSim)
            %generateTimeseries
            %

            nSig = numel(this.Signals);
            tValues = [];
            for ct = 1:nSig
                tValues = [tValues; this.T{ct}]; %#ok<AGROW>
            end
            tValues = sort(unique(tValues));

            ts = cell(numSim,nSig);
            t = cell(numSim,1);
            for ctSim = 1:numSim
                t{ctSim,1} = tValues;
                for ctSig = 1:nSig
                    ts{ctSim,ctSig} = timeseries(values{ctSig},this.T{ctSig});
                end
            end
        end

        function signals = getSignalValues(this,values)       
            nSig = numel(this.Signals);
            signals = cell(nSig,1);
            for ct = 1:nSig
                %Convert time and amplitudes to signal
                NumPulse = numel(this.T{ct});
                if isempty(values)
                    amps = [nan(NumPulse,1) nan(NumPulse,1)]';
                else
                    amps = [values{ct} values{ct}]';
                end              
                tvec = [this.T{ct} this.T{ct}]';
                vals = timetable(seconds(tvec(:)),amps(:),'VariableNames',{'Data'});
                signals{ct} = vals;
            end                  
        end

        function ranges = getPlotRanges(this,values)
            if isempty(values)
                ranges = this.Ranges;
            else
                values = getValuesArray(this,values);
                ranges = [min(values)' max(values)'];
            end
        end

        function values = getValuesArray(this,values)
            nSig = numel(this.Signals);
            TT = timetable(seconds(this.T{1}), values{1});
            for ct = 2:nSig
                newTT = timetable(seconds(this.T{ct}), values{ct});
                TT = synchronize(TT, newTT);
            end
            values = table2array(TT);
        end

        function israndom = isRandom(this)
            israndom = false;
        end
        
        function setSignalLimits(this,~)
            setValues(this,this.userInput,this.userData)
        end

        function ranges = getSignalLimits(this)
            nSig = numel(this.Signals);
            Tmax = 0;
            for ct = 1:nSig
                if max(this.T{ct}) >Tmax
                    Tmax = max(this.T{ct});
                end
            end
            ranges = struct( ...
                'Amplitudes', this.Ranges, ...
                'Length', Tmax);
        end
    end
end

function [value, t] = convertOneInput(oneInput)
    if isnumeric(oneInput)
        t = oneInput(:,1);
        value = oneInput(:,2);
    elseif istimetable(oneInput)
        t = seconds(oneInput.Time);
        value = oneInput{:,1};
    end
end

% LocalWords:  Custom lbl
