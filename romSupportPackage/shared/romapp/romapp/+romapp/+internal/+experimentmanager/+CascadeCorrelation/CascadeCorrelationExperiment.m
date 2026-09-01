classdef CascadeCorrelationExperiment < romapp.internal.experimentmanager.ROMExperiment
    %

    % Copyright 2025-2026 The MathWorks, Inc.

    %ROMExperiment properties
    properties(Constant)
        TYPE = "cascor"
        ICON = romapp.internal.resources.getIcon("systemIdentificationApp");
        NAME = romapp.internal.resources.getString('lblMethod_CasCor');
        DESCRIPTION = romapp.internal.resources.getString('msgCasCor_Description');
        REQUIREDPRODUCTS = romapp.internal.experimentmanager.RequiredProducts("ident","Identification_Toolbox");
        HAS_SCALAR_OUTPUT = false;
        HAS_SIGNAL_OUTPUT = true;
        NO_SIGNAL_INPUT = false;
    end

    %ROMExperiment methods
    methods(Access = protected)
        function str = getCode(~)
            fname = 'romapp.internal.experimentmanager.CascadeCorrelation.trainCascadeCorrelation';
            fullpath = which(fname);
            str = string(fileread(fullpath));
            str = regexprep(str,'trainCascadeCorrelation','{functionName}');
        end
        function tbl = getHyperparameterSettings(this)
            %

            data = this.HelperFunctions('trainingData.mat');
            experimentDS = data.results;

            %Determine default sample rate from training data
            fs = getEffectiveFs(this,experimentDS);

            %Set default parameter values to min-max range, that way can
            %also be used for Bayes Opt
            tbl = { ...
                {"ModelOrder", '[2 6]', 'integer', 'none'}, ...
                {"SampleRate", ['[',num2str(fs*[1/10 1]),']'], 'real', 'none'}, ...
                {"WindowSize", '[40,60]', 'integer', 'none'}, ...
                {"MaxNumActLayer",'[10,20]','integer', 'none'}, ...
                {"CrossValidate", '["true","false"]', 'categorical', 'none'}, ...
                {"HoldoutFraction", '[0.2,0.3]', 'real', 'none'}};
        end
        function str = getLongDescription(this)

            data = this.HelperFunctions('trainingData.mat');
            reset(data.results)
            result = read(data.results);
            mdl = getModelName(result);
            str = romapp.internal.resources.getString('msgCasCor_Description_Long',mdl);
        end
        function classname = getExportMenuClass(~)
            %Reusing the NLARXBlock class as the output object is identical to
            %NLARX workflow and perfectly fits the case
            classname = "romapp.internal.experimentmanager.NLARX.NLARXBlock";
        end
    end
   
    methods
        function obj = CascadeCorrelationExperiment(experimentDS)

            obj = obj@romapp.internal.experimentmanager.ROMExperiment(experimentDS);
        end
    end
end

% LocalWords:  lbl cascor
