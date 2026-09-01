classdef DynamicModelExperiment < romapp.internal.experimentmanager.ROMExperiment
    % DynamicModelExperiment
    %

    % Copyright 2023-2026 The MathWorks, Inc.

    % ROMExperiment properties
    properties(Constant)
        TYPE = "dynamicQuickStart"
        ICON = romapp.internal.resources.getIcon("neuralNetFittingApp");
        NAME = romapp.internal.resources.getString('lblMethod_DynamicQuickStart');
        DESCRIPTION = romapp.internal.resources.getString('msgDynamicQuickStart_Description');
        REQUIREDPRODUCTS = romapp.internal.experimentmanager.RequiredProducts(...
                ["ident","nnet"],...
                ["Identification_Toolbox", "Neural_Network_Toolbox"]);
        HAS_SCALAR_OUTPUT = false;
        HAS_SIGNAL_OUTPUT = true;
        NO_SIGNAL_INPUT = false;
    end

    %ROMExperiment methods
    methods(Access = protected)
        function str = getCode(~)
            fname = 'romapp.internal.experimentmanager.QuickStart.trainDynamicModel';
            fullpath = which(fname);
            str = string(fileread(fullpath));
            str = regexprep(str,'trainDynamicModel','{functionName}');
        end
        function tbl = getHyperparameterSettings(this)
            %

            mdlTypes = getSuggestedHyperparameterSettings(this);

            tbl = mdlTypes;
        end
        function tbl = getSuggestedHyperparameterSettings(this)
            %
            modelTypes = [...
                romapp.internal.experimentmanager.DL.MLPExperiment.NAME, ...
                romapp.internal.experimentmanager.DL.RNNExperiment.NAME, ...
                romapp.internal.experimentmanager.NLARX.NLARXExperiment.NAME, ...
                romapp.internal.experimentmanager.NSS.NSSExperiment.NAME, ...
                romapp.internal.experimentmanager.CascadeCorrelation.CascadeCorrelationExperiment.NAME];
            strModelTypes = "["+""""+modelTypes(1)+"""";
            for ct=2:numel(modelTypes)
                strModelTypes = strModelTypes+", "+""""+modelTypes(ct)+"""";
            end
            strModelTypes = strModelTypes + "]";
            %Set default parameter values to min-max range, that way can
            %also be used for Bayes Opt
            tbl = { ...
                {"ModelType", strModelTypes, 'string', 'none'}};
        end

        function str = getLongDescription(this)

            data = this.HelperFunctions('trainingData.mat');
            reset(data.results)
            result = read(data.results);
            mdl = getModelName(result);
            str = romapp.internal.resources.getString('msgDynamicQuickStart_Description_Long',mdl);
        end
        function createHelperFunctions(this,experimentDS)

            fs = getEffectiveFs(this,experimentDS);

            reset(experimentDS)
            result = read(experimentDS);

            [ny,nu,nx] = romapp.internal.experimentmanager.QuickStart.approximateModelOrder(result,fs);
            [oLag,iLag] = romapp.internal.experimentmanager.QuickStart.approximateModelLags(result,fs,...
                LinearModelSize=[ny,nu,nx]);
            %For quickstart only use one simulation result
            experimentDS = subset(experimentDS,1);
            data = struct(...
                'results', experimentDS, ...
                'SampleRate', fs, ...
                'LinearModelSizes', [ny,nu,nx], ...
                'ModelLags', [oLag, iLag]);
            map = containers.Map({'trainingData.mat'},{data}); 
            this.HelperFunctions = map;
        end

        function classname = getExportMenuClass(~)
            classname = "romapp.internal.experimentmanager.QuickStart.DynamicModelBlock";
        end
    end
   
    methods
        function obj = DynamicModelExperiment(experimentDS)

            obj = obj@romapp.internal.experimentmanager.ROMExperiment(experimentDS);
            if numel(experimentDS) > 1
                %Have enough results to use at least one as a test set
                obj.OptimizableMetricData = {'TestMSE', 'Minimize'};
            else
                obj.OptimizableMetricData = {'TrainingMSE', 'Minimize'};
            end
        end
    end
end

% LocalWords:  lbl idnss
