function [z, fs, range] = getSignalDataFromExperiment(trainData, mode, varargin)
%getSignalDataFromExperiment Return time table containing input and output
%data from an experiment object.
%
% [z, fs, range] = getSignalDataFromExperiment(data,<mode>,varargin);
% [z, fs, range] = getSignalDataFromExperiment(data,'DownSample',downSample);
% z = getSignalDataFromExperiment(data,'SampleRate',fs,range)
%
% Inputs:
%    data -romapp.internal.data.ExperimentData object
%    <mode> - string with one of {'DownSample', 'SampleRate'}
%    varargin - downsample, fs and range arguments. downsample specifies
%               the downsampling to use on the data contained in the data
%               input argument. fs specifies the sample rate to use for
%               resampling the data in the data argument, range specifies
%               the time range of data to extract from the data input
%               argument
%
% Outputs:
%    z - time table of data extracted from the data input argument with a
%        variable for each input, output and parameter contained in data.
%        The time table sample rate and range depend on the <mode> and
%        varargin arguments
%    fs - sample rate used in the returned table, this argument is only
%         returned when <mode> = DownSample
%    range - the [min max] time values in z, this argument is only valid
%            when <mode> = DownSample
%
% Usage:
%   For cases with multiple experiments getSignalDataFromExperiment with
%   <mode> = DownSample should be called with one experiment to determine
%   fs and range. Subsequent calls to getSignalDataFromExperiment should be
%   called with <mode> = SampleRate using the fs and range values from the
%   1st call. This ensures all data has the same sample rate and range.

%   Copyright 2023-2025 The MathWorks, Inc.

[iNames,oNames,pNames] = getDisplayNames(trainData);
nIn = numel(iNames);
nOut = numel(oNames);
nP = numel(pNames);

if strcmp(mode,'DownSample')

    %Check and find common time vector/sample rate for all signals. Be careful
    %of constant signals as they only have one time point
    fs = nan(nIn+nOut,1);
    range = nan(nIn+nOut,2);
    for ct=1:nIn
        t = seconds(trainData.InputSignals(ct).Values.Time);
        if ~isscalar(t)
            fs(ct) = romapp.internal.experimentmanager.getEffectiveFs(t);
            range(ct,:) = [min(t) max(t)];
        end
    end
    for ct=1:nOut
        t = seconds(trainData.OutputSignals(ct).Values.Time);
        if ~isscalar(t)
            fs(ct) = romapp.internal.experimentmanager.getEffectiveFs(t);
            range(ct,:) = [min(t) max(t)];
        end
    end
    fs = median(fs,'omitnan');
    fs = fs/varargin{1};
    range = [max(range(:,1),[],'omitnan'), min(range(:,2),[],'omitnan')];
else
    fs = varargin{1};
    if nargin > 3
        range = varargin{2};
    else
        range = [0 inf];
    end
end

%Extract signal data at required sample rate. Keep track of number of time
%points after resampling, needed to expand any constant signals or
%parameters to a timeseries
nT = nan; 
names = cell(nIn+nP+nOut,1);
Z = cell(nIn+nP+nOut,1);
for ct=1:nOut
    data = lgetSignalAsDouble(trainData.OutputSignals(ct),fs,range);
    if isnan(nT)
        nT = size(data,1);
    end
    names{ct+nIn+nP} = char(oNames(ct));
    Z{ct+nIn+nP} = data; 
end
for ct=1:nIn
    data = lgetSignalAsDouble(trainData.InputSignals(ct),fs,range,nT);
    names{ct} = char(iNames(ct));
    Z{ct} = data; 
end
for ct=1:nP
    %Convert input parameters to model input signals
    data = trainData.InputParameters(ct).Value*ones(nT,1);
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
    data = table2array(data);
else
    %Signal is a constant value
    if nargin < 4
        %Don't have enough info to determine number of points, return the
        %available data
        data = table2array(data);
    else
        data = table2array(data)*ones(nT,1);
    end
end
end

% LocalWords:  omitnan fs
