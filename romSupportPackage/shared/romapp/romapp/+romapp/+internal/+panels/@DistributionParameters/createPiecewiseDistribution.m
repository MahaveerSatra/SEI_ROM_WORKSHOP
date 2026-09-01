function pd = createPiecewiseDistribution(~, numPoints, pdOld)
% CREATEPIECEWISEDISTRIBUTION Create piecewise distribution
%    New distribution is similar to old one in shape, mean and
%    standard deviation
%

%   Copyright 2023 The MathWorks, Inc.

% Choose x-points to cover region of support of old
% distribution.  If old distribution had support extending to
% infinity, choose finite value that includes most of
% probability.
lo = 0.005;
hi = 1 - lo;
% Set low value
xLo = icdf(pdOld, 0);
if ~isfinite(xLo)
    xLo = icdf(pdOld, lo);
end
% Set high value
xHi = icdf(pdOld, 1);
if ~isfinite(xHi)
    xHi = icdf(pdOld, hi);
end

% Preserve shape of old distribution by matching its cumulative
% distribution at x points
x  = linspace(xLo, xHi, numPoints);
Fx = cdf(pdOld, x);
% Ensure that Fx starts at 0 and ends at 1
Fx = Fx - Fx(1);
Fx = Fx * 1/Fx(end);
% Ensure machine precision doesn't make Fx end points differ
% from 0 and 1
Fx(1) = 0;
Fx(end) = 1;

% Create new piecewise distribution
pd = makedist('PiecewiseLinear',  'x', x,  'Fx', Fx);
end
