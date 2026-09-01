function nh = approximateHiddenLayerSize(sz,nl)
%approximateHiddenLayerSize
%
%  Approximate hidden layer size using number of free parameters in a
%  linear state space model and a number of layers
%
%  nh = approximateHiddenLayerSize(sz,nl)
%
%  Inputs
%    sz - linear model sizes [ny, nu, nx]
%    nl - number of layers
%
%  Outputs
%    nh - number of units to use in each hidden layer

%   Copyright 2025 The MathWorks, Inc.

arguments
    sz(1,3) double 
    nl double {mustBeScalarOrEmpty, mustBeNonempty, mustBePositive, mustBeReal mustBeFinite}
end

%Equivalent number of parameters for a linear model
% n = nx*nx + nu*nx + ny*nx
nP = sz(3)*(sz(3) + sz(2) + sz(1));
nP = nP/nl; %Approximate number of parameters in each layer

%Default to next power of two for number of units in hidden layers but also
%have at least 16 units
nh = 2^ceil(log(nP)/log(2));
nh =  max(nh,16);
end

% LocalWords:  nh sz nl ny nx
