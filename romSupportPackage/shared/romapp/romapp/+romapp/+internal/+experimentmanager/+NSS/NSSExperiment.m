classdef NSSExperiment < romapp.internal.experimentmanager.ROMExperiment
%classdef NSSExperiment 
    %

    % Copyright 2023-2026 The MathWorks, Inc.

    %ROMExperiment properties
    properties(Constant)
        TYPE = "idnss"
        ICON = romapp.internal.resources.getIcon("neuralNetFittingApp");
        NAME = romapp.internal.resources.getString('lblMethod_NSS');
        DESCRIPTION = romapp.internal.resources.getString('msgNSS_Description');
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
            fname = 'romapp.internal.experimentmanager.NSS.trainNSS';
            fullpath = which(fname);
            str = string(fileread(fullpath));
            str = regexprep(str,'trainNSS','{functionName}');
        end
        function tbl = getHyperparameterSettings(this)
            %

            data = this.HelperFunctions('trainingData.mat');
            experimentDS = data.results;

            %Determine default sample rate from training data
            fs = getEffectiveFs(this,experimentDS);

            %Approximate model order from the training data
            reset(experimentDS)
            result = read(experimentDS);
            [ny,nu,nx] = romapp.internal.experimentmanager.QuickStart.approximateModelOrder(result,fs);
            [oLag,iLag] = romapp.internal.experimentmanager.QuickStart.approximateModelLags(result,fs,...
                LinearModelSize=[ny, nu, nx]);
            oLag = [floor(oLag/2), max(1,oLag*2)];
            iLag = [floor(iLag/2), max(1,iLag*2)];

            %Approximate hidden layer size
            nh = romapp.internal.experimentmanager.QuickStart.approximateHiddenLayerSize([ny,nu,nx],2);
            nh = [max(16,nh/2) nh*2];

            %Set default parameter values to min-max range, that way can
            %also be used for Bayes Opt
            tbl = { ...
                {"NumberInputLags", ['[', num2str(iLag), ']'], 'integer', 'none'}, ...
                {"NumberOutputLags", ['[', num2str(oLag), ']'], 'integer', 'none'}, ...
                {"NumberLayers", '[1 3]', 'integer', 'none'}, ...
                {"HiddenLayerSize", ['[', num2str(nh), ']'], 'integer', 'none'}, ...
                {"SampleRate", ['[',num2str(fs*[1/10 1]),']'], 'real', 'none'}, ...
                {"WindowSize", '50','integer','none'}, ...
                {"Overlap", '0','integer','none'}};
        end
        function str = getLongDescription(this)

            data = this.HelperFunctions('trainingData.mat');
            reset(data.results)
            result = read(data.results);
            mdl = getModelName(result);
            str = romapp.internal.resources.getString('msgNSS_Description_Long',mdl);
        end

        function classname = getExportMenuClass(~)
            classname = "romapp.internal.experimentmanager.NSS.NSSBlock";
        end
    end
   
    methods
        function obj = NSSExperiment(data)
            obj = obj@romapp.internal.experimentmanager.ROMExperiment(data);
        end
    end
end

% LocalWords:  lbl idnss
