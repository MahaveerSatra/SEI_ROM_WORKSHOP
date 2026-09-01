function [ny,nu,nx] = approximateModelOrder(result,fs,options)
%approximateModelOrder
%
%  Approximate model order from a simulation result by fitting a linear
%  state space model with the best AIC.
%
%  [ny,nu,nx] = approximateModelOrder(result,fs,[MaxOrder=#])
%
%  Inputs
%    result - a romapp.internal.data.ExperimentData object with the
%             simulation result
%    fs     - sample rate to use when extracting signal data from the
%             experiment
%    MaxOrder - Optional Name-Value pair to specify the maximum order to
%               search up to. Default value is 10
%
%  Outputs
%    ny - number of outputs
%    nu - number of inputs
%    nx - number of states
%

%   Copyright 2025-2026 The MathWorks, Inc.

arguments
    result romapp.internal.data.ExperimentData
    fs double {mustBePositive, mustBeReal, mustBeFinite, mustBeScalarOrEmpty, mustBeNonempty}
    options.MaxOrder double {mustBePositive, mustBeReal, mustBeFinite, mustBeScalarOrEmpty, mustBeNonempty} = 10;
end

[inames,onames,pnames] = getDisplayNames(result);
z = romapp.internal.experimentmanager.getSignalDataFromExperiment(result,'SampleRate',fs);
z = removevars(z,pnames); %are constant for each simulation result

%Default sizes
ny = numel(onames);
nu = numel(inames);
nx = max(ny,nu);

%Extract data for approximation
[z,valid] = romapp.internal.experimentmanager.QuickStart.prepareResult(z);
if ~valid
    %Use default sizes, data from one result is not rich enough for good
    %model order estimation
    return
end

%Choose model order that has minimum AIC
opts = n4sidOptions(EstimateCovariance=false);
mAIC = inf;
AICDropped = true;
maxOrder = options.MaxOrder; 
ct = 1;
while AICDropped && ct <= maxOrder
    try %#ok<TRYNC>
        sys = n4sid(z,ct,'Ts',1/fs,'DisturbanceModel','none','OutputName',onames,opts);
        AICDropped = sys.Report.Fit.AIC < mAIC;
        if AICDropped
            nx = size(sys.A,1);
            nu = size(sys.B,2);
            ny = size(sys.C,1);
            mAIC = sys.Report.Fit.AIC;
        end
    end
    ct = ct +1;
end

end

% LocalWords:  ny nx fs
