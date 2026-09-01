classdef NLARXExperiment < romapp.internal.experimentmanager.ROMExperiment
    %

    % Copyright 2022-2026 The MathWorks, Inc.

    %ROMExperiment properties
    properties(Constant)
        TYPE = "idnlarx"
        ICON = romapp.internal.resources.getIcon("systemIdentificationApp");
        NAME = romapp.internal.resources.getString('lblMethod_NLARX');
        DESCRIPTION = romapp.internal.resources.getString('msgNLARX_Description');
        REQUIREDPRODUCTS = romapp.internal.experimentmanager.RequiredProducts("ident","Identification_Toolbox");
        HAS_SCALAR_OUTPUT = false;
        HAS_SIGNAL_OUTPUT = true;
        NO_SIGNAL_INPUT = false;
    end

    %ROMExperiment methods
    methods(Access = protected)
        function str = getCode(~)
            fname = 'romapp.internal.experimentmanager.NLARX.trainNLARX';
            fullpath = which(fname);
            str = string(fileread(fullpath));
            str = regexprep(str,'trainNLARX','{functionName}');
        end
        function tbl = getHyperparameterSettings(this)
            %

            data = this.HelperFunctions('trainingData.mat');
            experimentDS = data.results;

            %Determine default sample rate from training data
            fs = getEffectiveFs(this,experimentDS);

            %Approximate model order from the 1st training data
            reset(experimentDS)
            result = read(experimentDS);
            [ny,nu,nx] = romapp.internal.experimentmanager.QuickStart.approximateModelOrder(result,fs);
            order = [max(1,floor(0.5*nx)) nx*2];

            %Approximate hidden layer size
            nh = romapp.internal.experimentmanager.QuickStart.approximateHiddenLayerSize([ny,nu,nx],2);
            nh = [max(16,nh/2) nh*2];
            
            %Set default parameter values to min-max range, that way can
            %also be used for Bayes Opt
            tbl = { ...
                {"ModelOrder", ['[',num2str(order),']'], 'integer', 'none'}, ...
                {"HiddenLayerSize", ['[',num2str(nh),']'], 'integer', 'none'}, ...
                {"SampleRate", ['[',num2str(fs*[1/10 1]),']'], 'real', 'none'}, ...
                {"WindowSize", '[40 60]', 'integer', 'none'}};
        end
        function str = getLongDescription(this)

            data = this.HelperFunctions('trainingData.mat');
            reset(data.results)
            result = read(data.results);
            mdl = getModelName(result);
            str = romapp.internal.resources.getString('msgNLARX_Description_Long',mdl);
        end

        function classname = getExportMenuClass(~)
            classname = "romapp.internal.experimentmanager.NLARX.NLARXBlock";
        end
    end
   
    methods
        function obj = NLARXExperiment(experimentDS)
            obj = obj@romapp.internal.experimentmanager.ROMExperiment(experimentDS);
        end
    end
end

% LocalWords:  lbl
