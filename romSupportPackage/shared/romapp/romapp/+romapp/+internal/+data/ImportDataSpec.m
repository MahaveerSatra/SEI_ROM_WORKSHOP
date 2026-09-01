classdef ImportDataSpec
    %ImportDataSpec
    %
    %  Specification of data to import. Specifies a single variable (or
    %  expression) to import, what it is being imported as
    %  (input/output/parameter/time), and a name

    % Copyright 2024 The MathWorks, Inc.

    properties(GetAccess = public, SetAccess = protected)
        Name string = string.empty;
        Expression string = string.empty;
        Type romapp.internal.data.ImportType = romapp.internal.data.ImportType.Input;
    end
    
    methods
        function obj = ImportDataSpec(name,expression,type)
            %ImportDataSpec
            %
            arguments
                name string {mustBeNonempty} = ""
                expression string{mustBeNonempty} = ""
                type romapp.internal.data.ImportType = romapp.internal.data.ImportType.Input;
            end
            
            obj.Name = name;
            obj.Expression = expression;
            obj.Type = type;
        end
    end
end
