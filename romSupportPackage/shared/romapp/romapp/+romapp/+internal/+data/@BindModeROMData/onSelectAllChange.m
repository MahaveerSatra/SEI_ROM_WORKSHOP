function success = onSelectAllChange(this,~, bindableRows,isChecked)
% This method invokes ROM client code that needs to executed when the user
% changes the 'Select All' checkbox at the top of the
% Binding Table.

% Copyright 2023 The MathWorks, Inc.

if ~this.allowSelectAll
    success = false;
    return;
end

data = this.ROMAppData;
for ct=1:numel(bindableRows)
    switch bindableRows(ct).bindableTypeChar
        case 'SLSIGNAL'
            success = lSignalSelectionChange(data, bindableRows(ct).bindableMetaData, isChecked);
        case {'SLPARAMETER', 'VARIABLE'}
            success = lParameterSelectionChange(data, bindableRows(ct).bindableTypeChar, bindableRows(ct).bindableMetaData, isChecked);
        otherwise
            romapp.internal.resources.error('errUnexpected','Unknown type')
    end

    if ~success
        %Quick return as soon as one fails
        break
    end
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

% LocalWords:  SLSIGNAL SLPARAMETER bindable
