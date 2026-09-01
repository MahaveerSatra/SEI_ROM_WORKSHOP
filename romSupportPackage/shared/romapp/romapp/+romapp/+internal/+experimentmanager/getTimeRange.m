function range = getTimeRange(results)
%getTimeRange
%
%  range = getTimeRange(results)
%
%  Inputs:
%    results - vector of romapp.internal.data.ExperimentData objects
%
%  Outputs:
%    range - array with intersection of min/max time values from all results

%   Copyright 2023-2024 The MathWorks, Inc.

nr = numel(results);
range = nan(nr,2);
for ct=1:nr
    sig = results(ct).OutputSignals(1);
    t = seconds(sig.Values.Time);
    range(ct,:) = [min(t) max(t)];
end
range = [max(range(:,1),[],'omitnan'), min(range(:,2),[],'omitnan')];

% LocalWords:  omitnan
