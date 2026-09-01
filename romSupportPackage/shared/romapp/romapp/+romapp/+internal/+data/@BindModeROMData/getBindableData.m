function bindableData = getBindableData(this, selectionHandles, ~)
% This method invokes ROM client code to query the bindable data in the
% current selection
%

% Copyright 2022-2023 The MathWorks, Inc.

selectionModelName = '';
validSelectionHandle = -1;
for idx = 1 : numel(selectionHandles)
    if (selectionHandles(idx) ~= 0)
        validSelectionHandle = selectionHandles(idx);
        selectionModelName = get_param(bdroot(selectionHandles(idx)), 'Name');
        break;
    end
end
if validSelectionHandle < 0 || ~strcmp(selectionModelName,this.modelName)
    error('Invalid selection')
end

activeEditor = BindMode.utils.getLastActiveEditor();
assert(~isempty(activeEditor));

switch this.SelectionType
    case 'Signal'
        bindableData = lgetBindableSignalData(this.ROMAppData, selectionHandles);
    case 'Parameter'
        bindableData = lgetBindableParameterData(this.ROMAppData, selectionHandles);
    otherwise
        romapp.internal.resources.error('errUnexpected','Unknown selection type')
end
end

function bindableData = lgetBindableSignalData(AppData,selectionHandles)

% Get signal rows from selection.
signalRows = BindMode.utils.getSignalRowsInSelection(selectionHandles);

% Get currently connected signals
currentSignals = [AppData.WorkingModelSignals{:,1}];
connectedRows = cell(size(currentSignals));
for ct=1:numel(currentSignals)
    sig = currentSignals(ct);
    blockpath = sig.BlockPath.convertToCell;
    hPort = get_param(blockpath{1},'PortHandles'); %TODO: how handle model reference
    hPort = hPort.Outport(sig.PortIndex);
    connectedRows(ct) =  BindMode.utils.getSignalRowsInSelection(hPort);
    connectedRows{ct}.isConnected =  true;
end

% Combine selected rows with current connection.
selectionRows = signalRows;
combinedRows = BindMode.utils.combineSelectedAndConnectedRows(selectionRows, connectedRows);
bindableData.updateDiagramButtonRequired = false;
bindableData.bindableRows = combinedRows;
end

function bindableData = lgetBindableParameterData(AppData,selectionHandles)

% Get selection rows
[selectionRows, updateDiagramNeeded_selection] = BindMode.utils.getParameterRowsInSelection(selectionHandles);

% Get currently connected parameters
currentParams = [AppData.WorkingParameters{:,1}];
connectedParams = cell(size(currentParams));
for ct=1:numel(connectedParams)
    dataStruct.name = char(currentParams(ct).Name);
    blockpath = currentParams(ct).BlockPath;
    cPath = convertToCell(blockpath);
    dataStruct.blockPathStr = cPath{1}; %TODO: how handle model reference
    dataStruct.hierarchicalPathArr = cPath;
    dataStruct.enableInputField = false;
    dataStruct.inputValue = '';
    connectionStatus = true;
    if isempty(currentParams(ct).Workspace)
        %Block dialog property
        metaData = BindMode.utils.getBindableMetaDataFromStruct(BindMode.BindableTypeEnum.SLPARAMETER,dataStruct);
        bindableName = [get_param(cPath{1},'Name'),':',dataStruct.name];

        connectedParams{ct} = BindMode.BindableRow(connectionStatus, ...
            BindMode.BindableTypeEnum.SLPARAMETER, ...
            bindableName, ...
            metaData);
    else
        %Variable used in block dialog
        dataStruct.workspaceType.sourceName = currentParams(ct).Workspace;
        if strcmp(currentParams(ct).Workspace,"base")
            dataStruct.workspaceTypeStr = 'base';
        else
            dataStruct.workspaceTypeStr = 'model';
        end

        metaData = BindMode.utils.getBindableMetaDataFromStruct(BindMode.BindableTypeEnum.VARIABLE,dataStruct);
        bindableName = dataStruct.name;
        connectedParams{ct} = BindMode.BindableRow(connectionStatus, ...
            BindMode.BindableTypeEnum.VARIABLE, ...
            bindableName, ...
            metaData);
    end
end

% Merge selected and connected rows and remove duplicates.
combinedRows = BindMode.utils.combineSelectedAndConnectedRows(selectionRows, connectedParams);
bindableData.updateDiagramButtonRequired = updateDiagramNeeded_selection;
bindableData.bindableRows = combinedRows;
end

% LocalWords:  bindable utils
