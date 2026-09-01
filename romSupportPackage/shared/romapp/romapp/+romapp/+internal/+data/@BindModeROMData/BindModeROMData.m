classdef BindModeROMData < BindMode.BindModeSourceData
    % This class implements the abstract class BindModeSourceData
    % to provide the information required for the ROM app
    % 
    % For detailed information about each property and method look at
    % description of fields in the Abstract class.
    %
    % https://inside.mathworks.com/wiki/Bind_Mode_API_for_Internal_Clients

    % Copyright 2022-2023 The MathWorks, Inc.

    properties (SetAccess = protected, GetAccess = public)
        modelName;
        clientName = BindMode.ClientNameEnum.SSM; %Temp until add ROM/Control specific Enum
        isGraphical = false;
        modelLevelBinding = true;
        sourceElementPath;
        hierarchicalPathArray = {};
        sourceElementHandle = [];
        allowMultipleConnections = true;
        requiresDropDownMenu = false;
    end

    properties(SetAccess = protected, GetAccess = public)
        SelectionType %One of {'signal','parameter'}
    end

    properties(Access = protected)
        ROMAppData
    end

    methods
        function newObj = BindModeROMData(modelName, SelectionType, data)
            newObj.modelName = char(modelName);
            newObj.sourceElementPath = 'romkey';
            newObj.allowMultipleConnections = true;
            newObj.allowSelectAll = true;
            newObj.SelectionType = SelectionType;
            newObj.ROMAppData = data;

            switch SelectionType
                case 'Signal'
                    setTableHeader(newObj,romapp.internal.resources.getString('lblSelectIO_Signals'))
                case 'Parameter'
                    setTableHeader(newObj,romapp.internal.resources.getString('lblSelectIO_Parameters'))
            end
        end

        function setTableHeader(this,tableHeader)
            this.tableHeader = tableHeader;
        end
    end
end

% LocalWords:  romkey lbl
