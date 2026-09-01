classdef scatteredInterpExperiment < romapp.internal.experimentmanager.ROMExperiment
    %

    % Copyright 2024-2026 The MathWorks, Inc.

    %ROMExperiment properties
    properties(Constant)
        TYPE = "idscatteredinterp"
        ICON = romapp.internal.resources.getIcon("systemIdentificationApp");
        NAME = romapp.internal.resources.getString('lblMethod_ScatteredInterp');
        DESCRIPTION = romapp.internal.resources.getString('msgScatteredInterp_Description')'';
        REQUIREDPRODUCTS = romapp.internal.experimentmanager.RequiredProducts("ident","Identification_Toolbox");
        HAS_SCALAR_OUTPUT = true;
        HAS_SIGNAL_OUTPUT = false;
        NO_SIGNAL_INPUT = false;
    end

    %ROMExperiment methods
    methods(Access = protected)
        function str = getCode(~)
            fname = 'romapp.internal.experimentmanager.InterpStatic.trainScatteredInterp';
            fullpath = which(fname);
            str = string(fileread(fullpath));
            str = regexprep(str,'trainScatteredInterp','{functionName}');
        end

        function tbl = getHyperparameterSettings(this)
            data = this.HelperFunctions('trainingData.mat');
            reset(data.results)
            result = read(data.results);
            nParams = numel(result.InputParameters);
            if nParams<2
                tbl = { ...
                {"Method", '["linear","nearest","pchip","makima","spline"]'}, ...
                {"ExtrapolationMethod", '["extrap"]'}};
            else
                tbl = { ...
                {"Method", '["linear","nearest","natural"]'}, ...
                {"ExtrapolationMethod", '["linear","nearest"]'}};
            end   
        end

        function str = getLongDescription(this)
            
            data = this.HelperFunctions('trainingData.mat');
            reset(data.results)
            result = read(data.results);
            mdl = getModelName(result);
            str = romapp.internal.resources.getString('msgScatteredInterp_Description_Long',mdl);
        end

        function classname = getExportMenuClass(~)
            %ScatteredInterpolant model is not Supported for Export to SL
            %workflow yet
            classname = "romapp.internal.experimentmanager.InterpStatic.ScatteredInterpBlock";
        end
    end

    methods
        function obj = scatteredInterpExperiment(results_training, varargin)
            obj = obj@romapp.internal.experimentmanager.ROMExperiment(results_training, varargin{:});
            obj.OptimizableMetricData = [];
        end
    end
    
    methods(Static=true)
        function tf = canUseWithData(data)
            %canUseWithData
            %
            arguments
                data romapp.internal.data.SimulationSet
            end
            nSim = 0;
            for ct = 1:numel(data)
                if ~isempty(data(ct).Results)
                    nSim = nSim + data(ct).NumResults;
                end
            end
            resultsMatchSimSpec = all([data.ResultsMatchSimSpec]);
            if ~resultsMatchSimSpec
                tf = false;
                return
            end
            % Scattered Interpolant only supported for 1-2 parameters and
            % have to have 3 or more samples
            if isempty(data)
                tf = false;
                return
            end
            if isempty(data(1).SimulationSpec.ParameterSpec)
                tf = false;
            else
                numParam = numel(data(1).SimulationSpec.ParameterSpec.Parameters);
                tf = ~((numParam>3 || numParam<1) || nSim<3);
            end
        end
        function [rTrain,rTest] = prepareResults(data,idxTrain,idxTest)
            %prepareResults
            %
            arguments
                data romapp.internal.data.SimulationSet
                idxTrain logical
                idxTest logical = []
            end

            data = data(idxTrain);
            rTrain = [];
            for ct=1:numel(data)
                experimentDS = data(ct).Results;
                idxKeep = ~data(ct).IsError;
                experimentDS = subset(experimentDS,idxKeep);
                if ct == 1
                    rTrain = experimentDS;
                else
                    rTrain = combine(rTrain,experimentDS,ReadOrder="sequential");
                end
            end
            
            % find number of parameters
            reset(rTrain);
            result = read(rTrain);
            nParam = numel(result.InputParameters);
            
            % Identify any dup simulations 
            paramDS = transform(rTrain, @(x) lExtractParamValues(x));
            pData = readall(paramDS);
            
            [uParam,idx] = unique(pData,'rows'); %Unique parameter combinations
            rTrain = subset(rTrain,idx);
            nResult = romapp.internal.experimentmanager.getNumResults(rTrain);

            %Check there is sufficient data for 1- 2-d scattered
            %interpolation
            cond1 = nParam<2 && nResult<2; % one parameter. check for interp1 conditions. 
            cond2 = nParam>=2 && ...
                ( nResult<3 || rank(uParam-uParam(1,:))<2 ); % more than one parameters. check for enough non-colinear params      
            if cond1 || cond2
                error('shared_romapp:dialogs:errExportResults_FewResults', ...
                    romapp.internal.resources.getString('errExportResults_FewResults'))
            end

            %No explicit test data is specified, the scattered
            %interpolation algorithm selects test data from the training data
            rTest = romapp.internal.data.ExperimentData.empty;
        end

        function str = getResultsToExportString(nTot, ~)
            str = romapp.internal.resources.getString('lblXofY', nTot, nTot);
        end
    end

end

% function [mdl, nParams] = getModelInfo(expObj)
% 
% data = expObj.HelperFunctions('trainingData.mat');
% for ct = 1:numel(data.results)
%     if isempty(data.results(ct).Errors)
%         mdl = getModelName(data.results(ct));
%         nParams = numel(data.results(ct).InputParameters);
%         break
%     end
% end
% end

function pValues = lExtractParamValues(exp)

pValues = [exp.InputParameters.Value];
end

% LocalWords:  lbl idscatteredinterp makima extrap Interpolant dup lblXofY
