classdef GriddedParameterSpec < romapp.internal.data.ParameterSpec
    %

    % GriddedParameterSpec
    %

    % Copyright 2023-2025 The MathWorks, Inc.

    properties(Dependent)
        Values
    end

    methods
        function obj = GriddedParameterSpec(params)
            
            obj = obj@romapp.internal.data.ParameterSpec(params)
            
            nParam = numel(params);
            names = romapp.internal.data.ModelPorts.getFullName(params);
            values = cell(nParam,1);
            for ct=1:nParam
                values{ct} = {getCurrentValue(params(ct))};
                %Truncate any long names, needed as gridding uses table and
                %table variables names have to be less than namelengthmax
                if strlength(names(ct)) > namelengthmax
                    names(ct) = extractAfter(names(ct),strlength(names(ct))-namelengthmax);
                end
            end
            obj.Space = stats.internal.Gridding(names,values);
        end

        function obj = copy(this)

            obj = romapp.internal.data.GriddedParameterSpec(this.Parameters);
            obj.Space = this.Space;
        end
        function values = get.Values(this)

            %Space stores values as cell array (since individual values can
            %be non-scalar). Need to convert that to an array of values.
            vals = this.Space.ParameterValues;
            nParam = numel(this.Parameters);
            values = cell(nParam,1);
            for ct=1:nParam
                val = vals{ct};
                val = [val{:}];
                values{ct} = val;
            end
        end

        function setValues(this,values)
            %Convert the cell array containing arrays of values to cell
            %array of cell arrays format that the space needs. 
            cvalues = cell(size(values));
            for ct=1:numel(values)
                cvalues{ct} = num2cell(values{ct});
            end
            this.Space.ParameterValues = cvalues;
            notify(this,'DataChanged')
        end

        function ranges = getPlotRanges(this,values)
            if isempty(values)
                nParams = numel(this.Parameters);
                ranges = zeros(nParams,2);
                for iParam = 1:nParams
                    paramValues = this.Values{iParam};
                    ranges(iParam,:) = [min(paramValues) max(paramValues)];
                end
            else
                values = sample(this.Space);
                values = values.X.Variables;
                ranges = [min(values,[],1); max(values,[],1)]';
            end
        end

        function israndom = isRandom(this)
            israndom = false;
        end

        function values = getValues(this)
            samplingSpace = stats.internal.Gridding(romapp.internal.data.ModelPorts.getDisplayName(this.Parameters),this.Values);
            values = sample(samplingSpace);
            values = values.X.Variables;
        end

        function paramValues = sampleSpecValues(this,numSim)
            paramValues = sample(this.Space);
            paramValues = paramValues.X.Variables;
        end

        function  nsim = getNumSim(this)
            
            %Need better way to get the number of simulations from the space
            nsim = utMethod(this.Space,'getNumCombinations',this.Space);
        end

        function obj = convertToGridded(this)
            obj = this;
        end
        function obj = convertToRandom(this,ranges)
            arguments
                this romapp.internal.data.GriddedParameterSpec
                ranges double = [];
            end

            obj = romapp.internal.data.RandomParameterSpec(this.Parameters);
            %Converts to uniform distribution. Set the distribution limits
            %to the min/max values of the current parameters
            for ct=1:numel(this.Parameters)
                if isempty(ranges)
                    values = this.Values{ct};
                    range = [min(values), max(values)];
                else
                    range = ranges(ct,:);
                end
                if isequal(range(1),range(2))
                    if isequal(range(1),0)
                        range = [-1 1];
                    else
                        range = range(1)*[1-0.1*sign(range(1)), 1+0.1*sign(range(1))];
                    end
                end

                if obj.Distributions(ct).Upper < range(1)
                    obj.Distributions(ct).Upper = range(2);
                    obj.Distributions(ct).Lower = range(1);
                else
                    obj.Distributions(ct).Lower = range(1);
                    obj.Distributions(ct).Upper = range(2);                    
                end
            end
        end
    end
end

% LocalWords:  gridding dspace nx
