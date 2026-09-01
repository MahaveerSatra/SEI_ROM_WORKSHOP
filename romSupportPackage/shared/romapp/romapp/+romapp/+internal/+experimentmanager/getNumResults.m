function n = getNumResults(resultds)
%getNumResults
%
%  n = getNumResults(resultds)
%
%  Inputs:
%    resultds - datastore containing the results
%
%  Outputs:
%    n - number of results in the datastore

%   Copyright 2025 The MathWorks, Inc.

if isempty(resultds)
    n = 0;
    return
end

% For backwards compatibility, some saved sessions may have simset.Results
% as ExperimentData rather than a datastore. In these cases, we should just
% return the number of ExperimentData objects in the array.
if isa(resultds, 'romapp.internal.data.ExperimentData')
    n = numel(resultds); % Return the number of ExperimentData objects
elseif isa(resultds, 'matlab.io.Datastore') || isa(resultds, 'matlab.io.datastore.Datastore')
    % Read the datastore as long as there are more results.
    reset(resultds)
    n = 0;
    while hasdata(resultds)
        n = n+1;
        read(resultds);
    end
    reset(resultds)
else
    error('Unrecognized format. Cannot determine the number of results.')
end
end

% LocalWords:  resultds
