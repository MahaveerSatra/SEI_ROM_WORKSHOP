function [z,valid] = prepareResult(zfull)
%prepareResult
%
%  Helper function used by approximateModelLags and approximateModelOrder
%  to choose a portion of the result data get a ballpark guess for the
%  model order etc. Limit the data usage as we want a quick answer. 

%   Copyright 2026 The MathWorks, Inc.

%If the signal is long only use 10% of the logged signal for analysis
nPts = height(zfull);
valid = true;
if nPts > 1000
    found = false;
    n = max(1000,floor(0.1*nPts));
    while ~found 
        nUse = min(n,nPts);
        z = zfull(1:nUse,:);
        
        %Remove means from the signals
        [zVar, zMu] = var(z);
        found = all(zVar{:,:} > eps(zMu{:,:}));
        if found || nUse == nPts
            break
        end
        n = n*2;
    end
    if found 
        z = z- zMu;
    else
        %Use default sizes, data from one result is not rich enough for good
        %model order estimation
        valid = false;
        z = nan;
        return
    end
else
    [zVar,zMu] = var(zfull);
    if all(zVar{:,:} > eps(zMu{:,:}))
        %Remove means from the signals
        z = zfull- zMu;
    else
        %Use default sizes, data from one result is not rich enough for good
        %model order estimation
        valid = false;
        z = nan;
    end   
end
end