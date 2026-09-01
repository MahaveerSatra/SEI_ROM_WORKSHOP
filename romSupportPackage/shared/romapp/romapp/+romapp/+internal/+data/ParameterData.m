classdef ParameterData
    %ParameterData
    %

    % Copyright 2022-2024 The MathWorks, Inc.

    properties
        BlockPath Simulink.SimulationData.BlockPath = Simulink.SimulationData.BlockPath.empty
        Name string = string.empty;
        Value double = zeros(0,0)
    end
    
    methods
        function obj = ParameterData(varargin)
            %ParameterData
            %

        end
    end

    methods(Hidden = true)
        function tf = isVariable(this)

            if isempty(this.BlockPath)
                tf = true;
            else
                bp = convertToCell(this.BlockPath);
                tf = ~any(strfind(bp{1},'/'));
            end
        end
    end
end
