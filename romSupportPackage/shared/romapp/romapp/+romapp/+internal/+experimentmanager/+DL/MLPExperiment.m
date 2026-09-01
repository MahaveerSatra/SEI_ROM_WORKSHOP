classdef MLPExperiment < romapp.internal.experimentmanager.ROMExperiment
    %

    %   Copyright 2024-2026 The MathWorks, Inc.
    
    properties(Constant)
        TYPE = "mlp"
        ICON = romapp.internal.resources.getIcon("neuralNetFittingApp")
        NAME = romapp.internal.resources.getString('lblMethod_MLP')
        DESCRIPTION = romapp.internal.resources.getString('msgMLP_Description')
        REQUIREDPRODUCTS = romapp.internal.experimentmanager.RequiredProducts("nnet","Neural_Network_Toolbox");
        HAS_SCALAR_OUTPUT = true;
        HAS_SIGNAL_OUTPUT = true;
        NO_SIGNAL_INPUT = true;
    end

    methods(Access=protected)
        function str = getCode(~)
            fname = 'romapp.internal.experimentmanager.DL.trainMLP';
            fullpath = which(fname);
            str = string(fileread(fullpath));
            str = regexprep(str,'trainMLP','{functionName}');
        end

        function tbl = getHyperparameterSettings(this)

            data = this.HelperFunctions('trainingData.mat');
            experimentDS = data.results;

            reset(experimentDS)
            result = read(experimentDS);
            haveSignalData = size(result.OutputSignals(1).Values,1) > 1;
            if haveSignalData
 
                %Determine default sample rate from training data
                fs = getEffectiveFs(this,experimentDS);

                %Approximate model order from the training data and use
                %that to approximate the hidden layer size
                [ny,nu,nx] = romapp.internal.experimentmanager.QuickStart.approximateModelOrder(result,fs);
                nh = romapp.internal.experimentmanager.QuickStart.approximateHiddenLayerSize([ny,nu,nx],2);
                nh = [max(16,nh/2) nh*2];
            else
                nh = [16 32];
            end

            tbl = { ...
                {"HiddenLayerSize",['[',num2str(nh),']'],'integer','none'}, ...                
                {"NumberLayers",'[1 2]','integer','none'}};
        end

        function str = getLongDescription(this)

            data = this.HelperFunctions('trainingData.mat');
            reset(data.results)
            result = read(data.results);
            mdl = getModelName(result);
            str = romapp.internal.resources.getString('msgMLP_Description_Long',mdl);
        end

        function classname = getExportMenuClass(~)
            classname = "romapp.internal.experimentmanager.DL.MLPBlock";
        end
    end

    methods
        function obj = MLPExperiment(varargin)
            obj = obj@romapp.internal.experimentmanager.ROMExperiment(varargin{:});
        end
    end

    methods(Static=true)
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
                idxInclude = data(ct).IncludeForTraining;
                experimentDS = subset(experimentDS,idxKeep & idxInclude);
                if ct == 1
                    rTrain = experimentDS;
                else
                    rTrain = combine(rTrain,experimentDS,ReadOrder="sequential");
                end
            end
            
            %No explicit test data is specified, the MLP
            %algorithm selects test data from the training data
            rTest = romapp.internal.data.ExperimentData.empty;
        end
    end
end

% LocalWords:  lstm lblMethod RNN mlp
