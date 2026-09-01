function r = CustomTransform(data)
%CustomTransform
%
%  Template function to apply a function to measured outputs and inputs to
%  create a new signal or scalar that will be treated as the ROM output.
%
%  Inputs
%    data - an object with properties for the logged input and output
%    signals as well as parameter values used during the simulation that
%    logged the data. If the state logging option is enable the object
%    also contains logged state data
%
%  Outputs
%    r - a struct with fields that contain the transformed data. These
%    fields and field values are treated as the ROM outputs. The field
%    values must all either be scalar values or timetables with the same
%    number of time points as the logged signals
%
% By way of example the template implements the product of the 1st input
% and 1st output. This could be for a circuit where the input is current
% and the output voltage. 
%

% Copyright 2024 The MathWorks, Inc.

%
outSigs = data.OutputSignals;
inSigs = data.InputSignals;

%Create a struct with field that multiplies the 1st input and 1st output
%signal.
r.InstantaneousPower = outSigs(1).Values.*inSigs(1).Values;

%Alternatively you can return the RMS value of the instantaneous power.
%The RMS is a scalar value. The returned structure cannot mix fields with
%scalars and fields with timeseries, the fields have to all either be
%scalars or timetables
%
% iPower = outSigs(1).Values.*inSigs(1).Values;
% r.RMS = rms(iPower{:,1});

end

% LocalWords:  Sigs rms
