function z = extractSignalData(experiment,options)
%extractSignalData Return time table containing input and output
%data from an experiment object.
%
% z = extractSignalData(experiment)
%
% Inputs:
%    experiment - romapp.internal.data.ExperimentData object
%    varargin - fs and range arguments. fs specifies the sample rate to use for
%               resampling the data in the data argument, range specifies
%               the time range of data to extract from the data input
%               argument
%
% Outputs:
%    z - timetable of data extracted from the data input argument with a
%        variable for each input, output and parameter contained in data.
%

%   Copyright 2024-2025 The MathWorks, Inc.

arguments
    experiment romapp.internal.data.ExperimentData
    options.SampleRate(1,1) double {mustBeReal, mustBeFinite, mustBePositive}  = 1;
    options.Range(1,2) double {mustBeReal, mustBeNonnegative} = [0 inf];
end

[iNames,oNames,pNames] = getDisplayNames(experiment);
nIn = numel(iNames);
nOut = numel(oNames);
nP = numel(pNames);

fs = options.SampleRate;
range = options.Range;

%Extract signal data at required sample rate. Keep track of number of time
%points after resampling, needed to expand any constant signals or
%parameters to a timeseries
nT = nan; 
names = cell(nIn+nP+nOut,1);
Z = cell(nIn+nP+nOut,1);
for ct=1:nOut
    data = lgetSignalAsDouble(experiment.OutputSignals(ct),fs,range);
    if isnan(nT)
        nT = size(data,1);
    end
    names{ct+nIn+nP} = char(oNames(ct));
    Z{ct+nIn+nP} = data; 
end
for ct=1:nIn
    data = lgetSignalAsDouble(experiment.InputSignals(ct),fs,range,nT);
    names{ct} = char(iNames(ct));
    Z{ct} = data; 
end
for ct=1:nP
    %Convert input parameters to model input signals
    data = experiment.InputParameters(ct).Value*ones(nT,1);
    names{ct+nIn} = char(pNames(ct));
    Z{ct+nIn} = data; 
end

%Collect the data together in one timetable. 
z = timetable(Z{:},'SampleRate',fs,'VariableNames',names);
end

function data = lgetSignalAsDouble(sig,fs,range,nT)
data = sig.Values;
if ~isscalar(data.Time)
    %Resample to common time base and range
    idx = data.Time >= range(1) & data.Time <= range(2);
    data = data(idx,:);
    data = retime(data,'regular','linear','SampleRate',fs);
    data = data(1:end-1,:); %remove right edge of last time bin
    data = data.Variables;
else
    %Signal is a constant value
    if nargin < 4
        romapp.internal.resources.error('errEM_OutputSignalConstant',sig.Name)
    else
        data = data.Variables*ones(nT,1);
    end
end
end

% LocalWords:  fs
