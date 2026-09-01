classdef ScatteredInterpBlock < romapp.internal.experimentmanager.ExportToSL
    % SCATTEREDINTERPBLOCK doesn't have a workaround or a way to create a
    % ROM Block. For now, this is a placeholder class and will only show a
    % uialert error message when the Export To SL option is selected in the
    % EM app's Export drop-down
    
    % Copyright 2026 The MathWorks, Inc.
    
    methods
        function obj = ScatteredInterpBlock(varargin)
            obj = obj@romapp.internal.experimentmanager.ExportToSL(varargin{:});
        end

        function exportCallback(~, ~, ~)    % Override ExportToSL's exportCallback for re-routing
            m = romapp.internal.resources.getString('lblMethod_ScatteredInterp');
            romapp.internal.resources.error('errEMQuickStart_InvalidModel_ForSimulink', m);
        end
    end

    methods (Access = protected)
        function createROMSLBlock(~, ~, ~)
        end
    end
end