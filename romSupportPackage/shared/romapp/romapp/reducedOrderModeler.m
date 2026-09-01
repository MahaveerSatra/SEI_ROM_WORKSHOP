function out = reducedOrderModeler(varargin)
% reducedOrderModeler  Reduced Order Modeler App
%
%   reducedOrderModeler(modelname)
%   reducedOrderModeler(data1,data2,....,dataN)
%   reducedOrderModeler(sys1,sys2,...,sysN)
%   reducedOrderModeler()
%  
%   If reducedOrderModeler() is called with no input arguments
%   the function will prompt for data or a Simulink model name.
%
%   Inputs
%      modelname - Name of an open Simulink model or a Simulink model on
%                  the path. Use this input syntax to create a new Reduced
%                  Order Modeler GUI session for the model.  
%      data1,...,dataN - Numeric matrices or timetables. Use this input syntax to
%                  create a new Reduced Order Modeler GUI session for
%                  data1, ..., dataN. Each argument must have the same
%                  number of rows, and represents different input/output
%                  channels. By default dataN is considered an output,
%                  earlier arguments are considered inputs. An import
%                  dialog will be launched where the input/output
%                  configuration can be edited.
%      sys1,...,sysN - Linear system models (ss, tf, zpk, sparss, mechss).
%                      Use this input syntax to create a model order
%                      reducer session. This syntax requires Control System
%                      Toolbox.
%

%   Copyright 2023-2025 The MathWorks, Inc.

try
    if nargin > 0 && ~isempty(varargin{1})
        names = cell(nargin,1);
        for ct=1:nargin
            names{ct} = inputname(ct);
        end
        tool = romapp.reducedOrderModeler(varargin,names);
    else
        tool = romapp.reducedOrderModeler([]);
    end
catch E
    throwAsCaller(E)
end

if nargout > 0
    out = tool;
end
end

% LocalWords:  modelname sparss mechss
