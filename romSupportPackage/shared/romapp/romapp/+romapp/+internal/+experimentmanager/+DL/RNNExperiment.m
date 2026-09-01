classdef RNNExperiment < romapp.internal.experimentmanager.ROMExperiment
    %

    %   Copyright 2023-2025 The MathWorks, Inc.
    
    properties(Constant)
        TYPE = "lstm"
        ICON = romapp.internal.resources.getIcon("neuralNetFittingApp")
        NAME = romapp.internal.resources.getString('lblMethod_LSTM')
        DESCRIPTION = romapp.internal.resources.getString('msgLSTM_Description')
        REQUIREDPRODUCTS = romapp.internal.experimentmanager.RequiredProducts("nnet","Neural_Network_Toolbox");
        HAS_SCALAR_OUTPUT = false;
        HAS_SIGNAL_OUTPUT = true;
        NO_SIGNAL_INPUT = false;
    end

    methods(Access=protected)
        function str = getCode(~)
            fname = 'romapp.internal.experimentmanager.DL.trainRNN';
            fullpath = which(fname);
            str = string(fileread(fullpath));
            str = regexprep(str,'trainRNN','{functionName}');
        end

        function tbl = getHyperparameterSettings(this)

            data = this.HelperFunctions('trainingData.mat');
            experimentDS = data.results;

            %Determine default sample rate from training data
            fs = getEffectiveFs(this,experimentDS);

            %Approximate model order from the training data and use that to
            %approximate hidden layer size
            reset(experimentDS)
            result = read(experimentDS);
            [ny,nu,nx] = romapp.internal.experimentmanager.QuickStart.approximateModelOrder(result,fs);
            nh = romapp.internal.experimentmanager.QuickStart.approximateHiddenLayerSize([ny,nu,nx],2);
            nh = [max(16,nh/2) nh*2];

            tbl = { ...
                {"SampleRate", ['[',num2str(fs*[1/10 1]),']'], 'real', 'none'}, ...
                {"HiddenLayerSize",['[', num2str(nh),']'],'integer','none'}, ...                
                {"InitialLearnRate",'[1e-3, 1e-5]','double','none'}, ...
                {"NumberLayers",'[1,2]','integer','none'}};
        end

        function str = getLongDescription(this)

            data = this.HelperFunctions('trainingData.mat');
            reset(data.results)
            result = read(data.results);
            mdl = getModelName(result);
            str = romapp.internal.resources.getString('msgLSTM_Description_Long',mdl);
        end

        function classname = getExportMenuClass(~)
            classname = "romapp.internal.experimentmanager.DL.RNNBlock";
        end
    end

    methods
        function obj = RNNExperiment(varargin)
            obj = obj@romapp.internal.experimentmanager.ROMExperiment(varargin{:});
        end
    end
end

% LocalWords:  lstm lblMethod RNN
