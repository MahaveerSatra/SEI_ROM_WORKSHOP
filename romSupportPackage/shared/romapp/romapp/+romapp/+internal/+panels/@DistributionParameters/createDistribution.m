function pd = createDistribution(this, pdOld, distributionType)
% CREATEDISTRIBUTION Create distribution
%    Create new probability distribution, retaining where
%    possible the mean and standard deviation of the old one
%

% Copyright 2015-2023 The MathWorks, Inc.

% Create distribution of new type with default parameters
switch distributionType
    case 'PiecewiseLinear'
        defaultNumPoints = 6;
        pd = createPiecewiseDistribution(this, defaultNumPoints, pdOld);
    otherwise
        pd = makedist(distributionType);
end

% Adjust parameters of the new distribution if it is possible
% to preserve the old distribution's mean and standard
% deviation
meanOld = mean(pdOld);
stdOld  = std(pdOld);
distributionName = getDistributionName(this, 'DataForm', pd.DistributionName);
switch distributionName
    case 'Uniform'
        if isfinite(meanOld)
            % The mean is finite and can be preserved
            this.QEMeanPreserved = true;
            if isfinite(stdOld)
                % The standard deviation is finite and can be
                % preserved
                %
                % Notation:  halfSpan = (Upper - Lower) /2
                this.QEStdPreserved = true;
                halfSpan = stdOld*sqrt(12)/2;
                lower = meanOld - halfSpan;
                upper = meanOld + halfSpan;
            else
                % The standard deviation is not finite. Make
                % the bounds +/- 10%, but if the mean is 0 make
                % the bounds +/- 1.
                this.QEStdPreserved = false;
                meanOld = romapp.internal.panels.DistributionParameters.roundZero(meanOld, stdOld);
                if meanOld == 0
                    lower = -1;
                    upper = 1;
                else
                    limits = sort(meanOld *[0.9 1.1], 'ascend');
                    lower = limits(1);
                    upper = limits(2);
                end
            end
            % Set lower and upper limits in distribution
            lower = romapp.internal.panels.DistributionParameters.roundZero(lower, stdOld);
            upper = romapp.internal.panels.DistributionParameters.roundZero(upper, stdOld);
            pd = romapp.internal.panels.DistributionParameters.setUniformLimits(pd, lower, upper);
        else
            this.QEMeanPreserved = false;
            this.QEStdPreserved  = false;
        end
    case 'Normal'
        if isfinite(meanOld)
            % The mean is finite and can be preserved
            this.QEMeanPreserved = true;
            pd.mu = meanOld;
            pd.mu = romapp.internal.panels.DistributionParameters.roundZero(pd.mu, stdOld);
            if isfinite(stdOld)
                % The standard deviation is finite an can be preserved
                this.QEStdPreserved = true;
                pd.sigma = stdOld;
            else
                % The standard deviation is not finite. Make it
                % 10% of the mean, but if the mean is 0 make
                % the standard deviation 1.
                this.QEStdPreserved = false;
                if pd.mu ~= 0
                    pd.sigma = 0.1*abs(pd.mu);
                end
            end
        end
    case 'Beta'
        % Do not try to match variance since it is bounded
        this.QEStdPreserved = false;
        % Only reuse mean if between 0 and 1 (non-inclusive)
        %  - cannot include 0 because Beta "a" must be positive
        %  - cannot include 1 because Beta "a" must be finite
        if (0 < meanOld)  &&  (meanOld < 1)
            this.QEMeanPreserved = true;
            pd.a = meanOld / (1 - meanOld);
            pd.b = 1;
            % Round location-related parameters to 0 if
            % appropriate
            pd.a = romapp.internal.panels.DistributionParameters.roundZero(pd.a, pd.std);
        else
            this.QEMeanPreserved = false;
        end
    case 'Binomial'
        % Old variance may be any non-negative, but binomial
        % variance is constrained: var = Np(1-p), mean = Np,
        % thus var = mean(1-p), thus  p = 1 - var/mean, but p
        % must be between 0 and 1.
        this.QEStdPreserved = false;
        % Only reuse mean if it is non-negative
        if (meanOld > 0)  &&  isfinite(meanOld)
            this.QEMeanPreserved = true;
            N = ceil(meanOld);
            pd.N = N;
            pd.p = meanOld/N;
        else
            this.QEMeanPreserved = false;
        end
    case 'BirnbaumSaunders'
        % Cannot in general match variance, shown by numerical
        % simulation
        this.QEStdPreserved = false;
        % Only reuse mean if it is non-negative
        if (meanOld > 0)  &&  isfinite(meanOld)
            this.QEMeanPreserved = true;
            pd.beta = meanOld * 2/3;
        else
            this.QEMeanPreserved = false;
        end
    case 'PiecewiseLinear'
        % The mean and standard deviation are not preserved
        % exactly.  They are preserved approximately, based on
        % the way piecewise distributions are made by matching
        % the CDF of the old distribution.
        this.QEMeanPreserved = false;
        this.QEStdPreserved  = false;
    otherwise
        this.QEMeanPreserved = false;
        this.QEStdPreserved  = false;
end
end

% LocalWords:  BirnbaumSaunders
