classdef ImportType
    %IMPORTTYPE Enumeration for import data types
    %

    %   Copyright 2024 The MathWorks, Inc.

    enumeration
        Input, Output, Parameter, Time
    end

    methods(Access = public)
        function str = string(this)

            switch this
                case romapp.internal.data.ImportType.Input
                    str = romapp.internal.resources.getString('lblImportData_Input');
                case romapp.internal.data.ImportType.Output
                    str = romapp.internal.resources.getString('lblImportData_Output');
                case romapp.internal.data.ImportType.Parameter
                    str = romapp.internal.resources.getString('lblImportData_Parameter');
                case romapp.internal.data.ImportType.Time
                    str = romapp.internal.resources.getString('lblImportData_Time');
            end
        end
    end
end

% LocalWords:  lbl
