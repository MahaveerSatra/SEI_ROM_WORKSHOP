function fs = getEffectiveFs(t)
%getEffectiveFs
%
%  [fs, range] = getEffectiveFs(t)
%
%  Inputs:
%    t - time vector in doubles
%
%  Outputs:
%    fs - effective sampling rate in t, implementation similar to
%         signal.internal.utilities.getEffectiveFs

%   Copyright 2023 The MathWorks, Inc.

%Check for 'almost' regular time steps
if iscolumn(t)
    t = reshape(t, 1, numel(t));
end
err = max(abs(t-linspace(t(1),t(end),numel(t)))./max(abs(t), [], 2), [], 2);
isIrregular = err(1) > 3*eps(underlyingType(t));

if isIrregular
    fs = 1/median(diff(t(:)));
else
    fs = 1/mean(diff(t(:)));
end
fs = abs(fs); % time vector could be descending in values
end


% LocalWords:  fs
