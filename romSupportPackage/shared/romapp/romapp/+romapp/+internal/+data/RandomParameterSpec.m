classdef RandomParameterSpec < romapp.internal.data.ParameterSpec
    %

    % RandomParameterSpec
    %

    % Copyright 2023-2025 The MathWorks, Inc.

    properties(Dependent)
        Values
        Correlation
        Distributions
        Options
    end
    
    properties(Access = protected)
        Values_
        NumSamples_ 
    end

    methods
        function obj = RandomParameterSpec(params)
            
            obj = obj@romapp.internal.data.ParameterSpec(params)
            
            nParam = numel(params);
            names = romapp.internal.data.ModelPorts.getFullName(params);
            dist = cell(nParam,1);
            for ct=1:nParam
                cValue = getCurrentValue(params(ct));
                dist{ct} = romapp.internal.data.RandomParameterSpec.createDefaultDistribution(cValue);
                %Truncate any long names, needed as Sampling uses table and
                %table variables names have to be less than namelengthmax
                if strlength(names(ct)) > namelengthmax
                    names(ct) = extractAfter(names(ct),strlength(names(ct))-namelengthmax);
                end
            end
            obj.Space = stats.internal.Sampling(names,[dist{:}]);
            obj.NumSamples_ = 2*nParam+1;
        end
        function obj = copy(this)

            obj = romapp.internal.data.RandomParameterSpec(this.Parameters);
            obj.Space = this.Space;
            obj.NumSamples_ = this.NumSamples_;
        end
        function dist = get.Distributions(this)
            dist = [this.Space.ParameterDistributions];
        end
        function set.Distributions(this, dist)
            if ~isequal(dist,this.Space.ParameterDistributions)
                this.Space.ParameterDistributions = dist;
                this.Values_ = [];
            end
        end
        function corr = get.Correlation(this)
            corr = this.Space.RankCorrelation;
        end
        function set.Correlation(this,corr)
            if ~isequal(corr,this.Space.RankCorrelation)
                this.Space.RankCorrelation = corr;
                this.Values_ = [];
            end
        end
        function opts = get.Options(this)
            opts = this.Space.Options;
        end
        function set.Options(this,opts)
            this.Space.Options = opts;
        end
        function values = get.Values(this)
            values = this.Values_;
        end
        
        function ranges = getPlotRanges(this,values)
            % If there are samples, get ranges from samples
            % If there are no samples due to boundaries, get ranges from
            if isempty(values)
                nParams = numel(this.Parameters);
                ranges = zeros(nParams,2);
                for iParam = 1:nParams
                    ranges(iParam,:) = getDistributionLimits(this,iParam);
                end
            else
                ranges = [min(values,[],1); max(values,[],1)]';
            end
        end
                
        function israndom = isRandom(this)
            israndom = true;
        end

        function  nsim = getNumSim(this)
            nsim = this.NumSamples_;
        end

        function setNumSim(this,numsim)
            this.NumSamples_ = numsim;
            notify(this,'DataChanged')
        end

        function updateSpec(this,spec)
            
            this.Distributions = spec.Distributions;
            this.Correlation = spec.Correlation;
            this.Options = spec.Options;

            setNumSim(this,getNumSim(spec)) %Fires data changed
        end
        
        function newParamValues = sampleSpecValues(this,nump)
            values = sample(this.Space,nump);
            newParamValues = values.X.Variables;
        end

        % function [siminAll,param] = createSimulationInput(this,simin,values)
        % 
        %     nValues = size(values,1);
        % 
        %     siminAllBase = simin;
        %     siminAll = [];
        % 
        %     param = cell(nValues,1);
        %     nParam = numel(this.Parameters);
        %     for ct=nParam:-1:1
        %         pElement = romapp.internal.data.ParameterData; 
        %         if isempty(this.Parameters(ct).Workspace)
        %             %Block dialog parameter
        %             pElement.BlockPath = this.Parameters(ct).BlockPath;
        %         else
        %             %Workspace variable
        %             mdl = bdroot(convertToCell(this.Parameters(ct).BlockPath));
        %             pElement.BlockPath = mdl{1};
        %         end
        %         pElement.Name = this.Parameters(ct).Name;
        %         pVec(ct) = pElement;
        %     end
        % 
        %     for ctV=1:nValues
        %         simin = siminAllBase(ctV);
        %         for ctP = 1:nParam
        %             simin = updateSimulationInput(this.Parameters(ctP),simin,values(ctV,ctP));
        %             pVec(ctP).Value = values(ctV,ctP);
        %         end
        %         siminAll = [siminAll;simin]; %#ok<AGROW>
        %         param{ctV} = pVec;
        %     end
        % end

        function obj = convertToGridded(this)
            obj = romapp.internal.data.GriddedParameterSpec(this.Parameters);
            %Converts to value set. Set to the mean of the distribution.
            values = cell(1,numel(this.Parameters));
            for ct=1:numel(this.Parameters)
                values{ct} = mean(this.Distributions(ct));
            end
            setValues(obj,values)
        end
        function obj = convertToRandom(this,ranges)
            arguments
                this romapp.internal.data.GriddedParameterSpec
                ranges double = []; %#ok<INUSA>
            end

            obj = this;
        end

        function AxesLimits = getDistributionLimits(this,iParam)
            probObj = this.Distributions(iParam);
            if isa(probObj,'prob.UniformDistribution')%Uniform
                Lower = probObj.Lower;
                Upper = probObj.Upper;
                AxesLimits = [Lower, Upper];
            elseif isa(probObj,'prob.NormalDistribution')...%Normal
                    || isa(probObj,'prob.ExtremeValueDistribution')...%ExtremeValue
                    || isa(probObj,'prob.GeneralizedExtremeValueDistribution')...%GeneralizedExtremeValue
                    || isa(probObj,'prob.LogisticDistribution')...%Logistic
                    || isa(probObj,'prob.PiecewiseLinearDistribution')...%PiecewiseLinear  
                    || isa(probObj,'prob.tLocationScaleDistribution')...%tLocationScale 
                    || isa(probObj,'prob.BurrDistribution')%Burr
                mu = mean(probObj);
                sigma = std(probObj);
                AxesLimits = [mu-5*sigma, mu+5*sigma];     
            elseif isa(probObj,'prob.BetaDistribution')%Beta
                AxesLimits = [0, 1];
            elseif isa(probObj,'prob.Binomial')%Binomial
                N = probObj.N;
                AxesLimits = [0, N];
            elseif isa(probObj,'prob.BirnBaumSaunders')...%BirnBaumSaunders
                    || isa(probObj,'prob.GammaDistribution')...%Gamma  
                    || isa(probObj,'prob.GeneralizedParetoDistribution')...%GeneralizedPareto 
                    || isa(probObj,'prob.InverseGaussianDistribution')...%InverseGaussian
                    || isa(probObj,'prob.LoglogisticDistribution')...%Loglogistic
                    || isa(probObj,'prob.LognormalDistribution')...%Lognormal 
                    || isa(probObj,'prob.MultinomialDistribution')...%Multinomial 
                    || isa(probObj,'prob.NakagamiDistribution')...%Nakagami  
                    || isa(probObj,'prob.NegativeBinomialDistribution')...%NegativeBinomial 
                    || isa(probObj,'prob.PoissonDistribution')...%Poisson
                    || isa(probObj,'prob.RayleighDistribution')...%Rayleigh
                    || isa(probObj,'prob.RicianDistribution')...%Rician
                    || isa(probObj,'prob.WeibullDistribution')%Weibull 
                mu = mean(probObj);
                sigma = std(probObj);
                AxesLimits = [0, mu+5*sigma];
            elseif isa(probObj,'prob.ExponentialDistribution') %Exponential
                AxesLimits = [0, mean(probObj)+5*std(probObj)];    
            elseif isa(probObj,'prob.TriangularDistribution') %Triangular  
                a = probObj.A;
                b = probObj.B;
                c = probObj.C;
                AxesLimits = [min([a,b,c]), max([a,b,c])];
            end          
            if isnan(AxesLimits(1)) || isinf(AxesLimits(1))
                AxesLimits(1) = -1e3;
            end
            if isnan(AxesLimits(2)) || isinf(AxesLimits(2))
                AxesLimits(2) = 1e3;
            end
        end
        
    end

    methods(Static = true, Access = protected)
        function pdist = createDefaultDistribution(v)
            %CREATEDEFAULTDISTRIBUTION
            %
            %    Create a default probability distribution for a parameter
            %
            %    pdist = createDefaultDistribution(v)
            %
            %    Inputs:
            %      v - a double scalar
            %
            %   Outputs:
            %      pdist - a uniform distribution range (1+-0.1) of v, or [-1
            %              1] if v == 0
            %
            
            % param.Continuous object may be compound, loop over components
            if isequal(v,0)
                r = [-1 1];
            else
                % Use +/- 10% range around value
                r = [(1-sign(v)*0.1) (1+sign(v)*0.1)] * v;
            end
        
            pdist = makedist('uniform','lower',r(1),'upper',r(2));
        end
    end
end

% LocalWords:  CREATEDEFAULTDISTRIBUTION simin pVec
