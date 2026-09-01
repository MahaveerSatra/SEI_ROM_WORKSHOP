classdef DynamicModelBlock < romapp.internal.experimentmanager.ExportToSL
    % DYNAMICMODELBLOCK works for Train All case where this class just acts
    % like a router by overriding the exportCallback and assign the right
    % builder class to handover the work to builder class

    % Copyright 2026 The MathWorks, Inc.
    
    methods
        function obj = DynamicModelBlock(varargin)
            obj = obj@romapp.internal.experimentmanager.ExportToSL(varargin{:});
        end

        function exportCallback(~, param, trainingOutput)    % Override ExportToSL's exportCallback for re-routing
            switch param.ModelType
                case romapp.internal.experimentmanager.DL.MLPExperiment.NAME
                    builder = romapp.internal.experimentmanager.DL.MLPBlock;
                case romapp.internal.experimentmanager.DL.RNNExperiment.NAME
                    builder = romapp.internal.experimentmanager.DL.RNNBlock;
                case romapp.internal.experimentmanager.NLARX.NLARXExperiment.NAME
                    builder = romapp.internal.experimentmanager.NLARX.NLARXBlock;
                case romapp.internal.experimentmanager.NSS.NSSExperiment.NAME
                    builder = romapp.internal.experimentmanager.NSS.NSSBlock;
                case romapp.internal.experimentmanager.CascadeCorrelation.CascadeCorrelationExperiment.NAME
                    builder = romapp.internal.experimentmanager.NLARX.NLARXBlock;
                otherwise
                    romapp.internal.resources.error('errEMQuickStart_InvalidModel_ForSimulink',param.ModelType)
            end
            modelParams = trainingOutput.modelParams;
            builder.exportCallback(modelParams, trainingOutput);
        end
    end

    methods (Access = protected)
        function createROMSLBlock(~, ~, ~)
        end
    end
end