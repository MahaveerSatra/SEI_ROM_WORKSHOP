function z = extractData(experiment)
%extractData Return table containing input and output
%data from an experiment object.
%
% z = extractData(experiment)
%
% Inputs:
%    experiment - romapp.internal.data.ExperimentData object
%
% Outputs:
%    z -table of data extracted from the experiment input argument with a
%        variable for each input, output and parameter contained in data.
%

%   Copyright 2024-2025 The MathWorks, Inc.

arguments
    experiment romapp.internal.data.ExperimentData
end

[iNames,oNames,pNames] = getDisplayNames(experiment);
nIn = numel(iNames);
nOut = numel(oNames);
nP = numel(pNames);

%Extract signal data at required sample rate. Keep track of number of time
%points after resampling, needed to expand any constant signals or
%parameters to a timeseries
nT = nan; 
names = cell(nIn+nP+nOut,1);
Z = cell(nIn+nP+nOut,1);
for ct=1:nOut
    data = experiment.OutputSignals(ct).Values.Data;
    if isnan(nT)
        nT = size(data,1);
    end
    names{ct+nIn+nP} = char(oNames(ct));
    Z{ct+nIn+nP} = data; 
end
for ct=1:nIn
    data =experiment.InputSignals(ct).Values.Data;
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
z = table(Z{:},'VariableNames',names);
end
