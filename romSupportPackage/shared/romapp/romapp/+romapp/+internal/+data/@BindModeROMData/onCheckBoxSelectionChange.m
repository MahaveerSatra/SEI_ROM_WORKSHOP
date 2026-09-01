function success = onCheckBoxSelectionChange(this, ~, bindableType, ~, bindableMetaData, isChecked)
% This method invokes ROM client code that needs to executed when the user
% changes the selection of a checkbox in the Binding Table.
%

% Copyright 2022-2023 The MathWorks, Inc.
    
data = this.ROMAppData;
switch bindableType
    case 'SLSIGNAL'
        success = lSignalSelectionChange(data, bindableMetaData, isChecked);
    case {'SLPARAMETER','VARIABLE'}
        success = lParameterSelectionChange(data, bindableType, bindableMetaData, isChecked);
    otherwise
        romapp.internal.resources.error('errUnexpected','Unknown type')
end
end

function success = lSignalSelectionChange(data, bindableMetaData, isChecked)
%Manage signal selection changes

%Create a signal object from the bindable meta data
sig = Simulink.SimulationData.Signal;
pathArr = bindableMetaData.hierarchicalPathArr;
if isequal(pathArr{1},pathArr{2})
    sig.BlockPath = pathArr{1};
else
    sig.BlockPath = pathArr;
end
sig.PortType = 'outport';
sig.PortIndex = bindableMetaData.outputPortNumber;
sig.Name = bindableMetaData.name;

if isChecked
    %By default add new signals as inputs
    addSignal(data,sig,'Input')
else
    %Remove the signal
    removeSignal(data,sig)
end
success = true;
end

function success = lParameterSelectionChange(data, bindableType, bindableMetaData, isChecked)

%Create a parameter object from the bindable meta data
param = romapp.internal.data.ModelParameter;
pathArr = bindableMetaData.hierarchicalPathArr;
if isequal(bindableType,'VARIABLE')
    param.BlockPath = bdroot(bindableMetaData.blockPathStr);
else
    if numel(pathArr) > 1 && isequal(pathArr{1},pathArr{2})
        param.BlockPath = pathArr{1};
    else
        param.BlockPath = pathArr;
    end
end
param.Name = bindableMetaData.name;
if strcmp(bindableType,'VARIABLE')
    param.Workspace = bindableMetaData.workspaceType.sourceName;
end

if isChecked
    addParameter(data,param)
else
    removeParameter(data,param)
end
success = true;
end

% LocalWords:  SLSIGNAL bindable SLPARAMETER
