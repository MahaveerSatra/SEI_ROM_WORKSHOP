classdef griddedInterpExperiment < romapp.internal.experimentmanager.ROMExperiment
    %

    % Copyright 2024-2026 The MathWorks, Inc.

    %ROMExperiment properties
    properties(Constant)
        TYPE = "idgriddedinterp"
        ICON = romapp.internal.resources.getIcon("systemIdentificationApp");
        NAME = romapp.internal.resources.getString('lblMethod_GriddedInterp');
        DESCRIPTION = romapp.internal.resources.getString('msgGriddedInterp_Description')'';
        REQUIREDPRODUCTS = romapp.internal.experimentmanager.RequiredProducts("ident","Identification_Toolbox");
        HAS_SCALAR_OUTPUT = true;
        HAS_SIGNAL_OUTPUT = false;
        NO_SIGNAL_INPUT = false;
    end

    %ROMExperiment methods
    methods(Access = protected)
        function str = getCode(~)
            fname = 'romapp.internal.experimentmanager.InterpStatic.trainGriddedInterp';
            fullpath = which(fname);
            str = string(fileread(fullpath));
            str = regexprep(str,'trainGriddedInterp','{functionName}');
        end
        function tbl = getHyperparameterSettings(this)
           
            tbl = { ...
                {"Method", '["linear","nearest","spline"]'}, ...
                {"ExtrapolationMethod", '["linear","nearest","spline"]'}};
        end
        function str = getLongDescription(this)

            data = this.HelperFunctions('trainingAndTestData.mat'); 
            reset(data.results_training)
            found = false;
            while hasdata(data.results_training) & ~found
                result = read(data.results_training);
                found = isempty(result.Errors);
            end
            if found
                mdl = getModelName(result);
            else
                romapp.internal.resources.error('errUnexpected','No error free data for gridded model')
            end
            str = romapp.internal.resources.getString('msgGriddedInterp_Description_Long',mdl);
        end

        function classname = getExportMenuClass(~)
            classname = "romapp.internal.experimentmanager.InterpStatic.GriddedInterpBlock";
        end
    end

    methods
        function obj = griddedInterpExperiment(results_training, varargin)
            obj = obj@romapp.internal.experimentmanager.ROMExperiment(results_training, varargin{:});
            obj.OptimizableMetricData = [];
        end
    end

    methods(Static = true)
        function tf = canUseWithData(data)
            %canUseWithData
            %
            arguments
                data romapp.internal.data.SimulationSet
            end

            tf = false;
            if ~isempty(data)
                for ct=1:numel(data) % go through all experiments
                    if isa(data(ct).SimulationSpec.ParameterSpec,'romapp.internal.data.GriddedParameterSpec') ...
                            && ~isempty(data(ct).Results) % check if this experiment has GriddedParameterSpec
                        ldims = cellfun(@numel, data(ct).SimulationSpec.ParameterSpec.Values);
                        tf = all(ldims>1); % last check if all dimensions have at least 2 points
                        if tf
                            break; 
                        end
                    end
                end
                resultsMatchSimSpec = all([data.ResultsMatchSimSpec]);
                if ~resultsMatchSimSpec
                    tf = false;
                end
            end
        end
        function [trainDS,testDS] = prepareResults(data,idxTrain,idxTest)
            %prepareResults
            %
            arguments
                data romapp.internal.data.SimulationSet
                idxTrain logical
                idxTest logical = []
            end

            %Transform datastore to separate training and test data
            rTrain = data(idxTrain);
            trainDS = rTrain(1).Results;
            for ct=2:numel(rTrain)
                trainDS = combine(trainDS,rTrain(ct).Results,ReadOrder="sequential");
            end
            rTest = data(idxTest);
            if isempty(rTest)
                testDS = [];
            else
                testDS = rTest(1).Results;
                for ct=2:numel(rTest)
                    testDS = combine(testDS,rTest(ct).Results,ReadOrder="sequential");
                end
            end
        end

        function str = getResultsToExportString(nTot, ~)
            str = romapp.internal.resources.getString('lblXofY', nTot, nTot);
        end

    end
end

% LocalWords:  lbl idgriddedinterp lblXofY
