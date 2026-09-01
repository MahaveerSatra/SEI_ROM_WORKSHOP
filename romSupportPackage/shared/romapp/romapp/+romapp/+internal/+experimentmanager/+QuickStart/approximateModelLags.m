function [outLag,inLag] = approximateModelLags(result,fs,options)
%approximateModelLags
%
%  Approximate model lags from a simulation result by fitting a ARX 
%  with the best AIC.
%
%  [inLag,outLag] = approximateModelLags(result,fs,Name=Value)
%
%  Inputs
%    result - a romapp.internal.data.ExperimentData object with the
%             simulation result
%    fs     - sample rate to use when extracting signal data from the
%             experiment
%
%  Optional Name-Value pairs
%    MaxLag - Specify the maximum lag to search up to. Default value is 5
%    LinearModelSize - Use the size of a linear state-space model to set
%                      upper limit on lags to search, size is specified as
%                      [ny nu nx].
%
%  Outputs
%    outLag - output lag, i.e., y(k-1), ... y(k-outLag)
%    inLag - input lag, i.e., u(k-1), ... u(k-outLag)
%

%   Copyright 2025-2026 The MathWorks, Inc.

arguments
    result romapp.internal.data.ExperimentData
    fs double {mustBePositive, mustBeReal, mustBeFinite, mustBeScalarOrEmpty, mustBeNonempty}
    options.MaxLag double {mustBePositive, mustBeReal, mustBeFinite, mustBeScalarOrEmpty, mustBeNonempty} = 5;
    options.LinearModelSize(1,3) double = []
end

[inames,onames,pnames] = getDisplayNames(result);
z = romapp.internal.experimentmanager.getSignalDataFromExperiment(result,'SampleRate',fs);
z = removevars(z,pnames); %are constant for each simulation result
nIn = numel(inames);
nOut = numel(onames);

%Default lags, assume y[k+1] = y[k] + u[k]
outLag = 1;
inLag = 0;

%Extract data for approximation
[z,valid] = romapp.internal.experimentmanager.QuickStart.prepareResult(z);
if ~valid
    %Use default sizes, data from one result is not rich enough for good
    %model order estimation
    return
end

%Choose model lags from combinations of lags that result in
%minimum AIC
noLinearModel = isempty(options.LinearModelSize);
if noLinearModel
    iLag = 1+(0:options.MaxLag);
    oLag = 0:options.MaxLag;
    [iLag,oLag] = ndgrid(iLag,oLag);
else
    ny = options.LinearModelSize(1);
    nu = options.LinearModelSize(2);
    nx = options.LinearModelSize(3);
    maxLag = max(1,2*nx/nu);
    iLag = 1+(0:maxLag);
    oLag = 0:maxLag;
    [iLag,oLag] = ndgrid(iLag,oLag);
    iLag = iLag(:);
    oLag = oLag(:);
    idx = (ny*oLag+nu*iLag >= nx/2) & ...
        (ny*oLag+nu*iLag) <= 2*nx;
    if all(~idx)
        %All lag choices result in states not in acceptable range. Default
        %to 0/1 input and 1 output lag
        iLag = [0;1];
        oLag = [1;1];
    else
        iLag(~idx) = [];
        oLag(~idx) = [];
    end
end

mAIC = inf;
opts = arxOptions(EstimateCovariance=false);
for ct=1:numel(iLag)
    order = ones(nOut,1)*[oLag(ct)*ones(1,nOut) iLag(ct)*ones(1,nIn) zeros(1,nIn)];
    try %#ok<TRYNC>
        sys = arx(z,order,'OutputName',onames,opts);
        if sys.Report.Fit.AIC < mAIC
            inLag = iLag(ct);
            outLag = oLag(ct);
            mAIC = sys.Report.Fit.AIC;
        end
    end
end
end

% LocalWords:  fs ny nx
