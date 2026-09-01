classdef PortType
    %PORTTYPE Enumeration for port types
    %

    %   Copyright 2022-2024 The MathWorks, Inc.

    enumeration
        ROMInput, ROMOutput, ROMParameter, SimulationInput, SimulationParameter, ROMandSimulationInput, LoggedOutput
    end

    methods(Access = public)
        function str = string(this)

            switch this
                case romapp.internal.data.PortType.ROMInput
                    str = romapp.internal.resources.getString('lblROMInput');
                case romapp.internal.data.PortType.ROMOutput
                    str = romapp.internal.resources.getString('lblROMOutput');
                case romapp.internal.data.PortType.ROMParameter
                    str = romapp.internal.resources.getString('lblROMParameter');
                case romapp.internal.data.PortType.SimulationInput
                    str = romapp.internal.resources.getString('lblSimulationInput');
                case romapp.internal.data.PortType.SimulationParameter
                    str = romapp.internal.resources.getString('lblSimulationInput');
                case romapp.internal.data.PortType.ROMandSimulationInput
                    str = romapp.internal.resources.getString('lblROMAndSimulationInput');
                case romapp.internal.data.PortType.LoggedOutput
                    str = romapp.internal.resources.getString('lblLoggedOutput');
            end
        end
    end
end

% LocalWords:  lbl
