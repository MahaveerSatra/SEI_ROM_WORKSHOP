function output = trainNSS(params,monitor)
%% Experiment to train a NSS model
% Train a NSS model. Hyper-parameters for training are:
%%
% * |NumberInputLags| - The number of lagged inputs to use, an integer >= 0
% * |NumberOutputLags| - The number of lagged outputs to use, an integer >= 0
% * |NumberLayers| - The number of layers in the MLP, an integer > 0
% * |HiddenLayerSize| - The number of hidden units in each layer, an integer > 0
% * |SampleRate| - Sample rate of the model, a real > 0
% * |WindowSize| - Number of samples in each frame or batch when segmenting data for model training, an integer > 0
% * |Overlap| - Number of samples in the overlap between successive frames
% when segmenting data for model training, a negative integer indicates that certain data samples are skipped when creating the data frames, an integer.
%
%%
% The tuning follows the following automated steps:
%%
% # Extract and resample the training data
% # Train the NSS model 
% # Evaluate model on test data (if available)
%

%   Copyright 2023-2026 The MathWorks, Inc.

% TestSplit - For multiple data sets the percentage of data sets to use
% for testing, a double in range [0 100]. The test data sets are selected
% randomly from the available data sets.
testSplit = 20; 

% Get hyper-parameter values
[fs,nLagIn,nLagOut,nLayers,nUnits,WindowSize,Overlap] = getHyperparameters(params);

%Get data
monitor.Status = "Loading and preprocessing data."; 
if isfield(params,'DataFileName')
    resultData = load(params.DataFileName,'results');
else
    resultData = load('trainingData.mat','results');
end
experimentDS = resultData.results;

%Randomly split results into training and test data sets
nresults = romapp.internal.experimentmanager.getNumResults(experimentDS);
rngState = rng(43210); %So that different hyper-parameter runs use the same split
experimentDS = shuffle(experimentDS);
rng(rngState) %restore 
ntrain = max([1,floor(nresults*(1-testSplit/100))]);
ntest = max([0,nresults-ntrain]);
haveTest = ntest > 0;

%Transform the experiment datastore to return signal data in timetable
%format
tSignalFcn = @(x) romapp.internal.experimentmanager.extractSignalData(x,'SampleRate',fs);
trainDS = transform(subset(experimentDS,1:ntrain),tSignalFcn);
testDS = transform(subset(experimentDS,ntrain+1:nresults),tSignalFcn);

%Compute the training mean and std for normalization
dataDS = transform(trainDS,@(x) lExtractData(x));
[v,m] = std(tall(dataDS));
[zSigma,zMu] = gather(v,m,'verbose',false);
zSigma(zSigma(:) == 0) = 1; %Protect against any constant inputs
ntrainDS = transform(trainDS, @(x) lExtractData(x,zSigma,zMu));
ntestDS = transform(testDS, @(x) lExtractData(x,zSigma,zMu));

%Find input/output names and create regressor spec for them
reset(experimentDS);
experiment = read(experimentDS);
[inputNames,outputNames,parameterNames] = getDisplayNames(experiment);
names = struct(...
    'outputNames', outputNames, ...
    'inputNames', inputNames, ...
    'parameterNames', parameterNames);
[rSpec,ionames] = createRegressorSpec(names,nLagIn,nLagOut);

%Transform the signal datastore to return regressors.
trainRegressorsDS = transform(ntrainDS, @(x) applyRegressors(x,rSpec,WindowSize));
testRegressorsDS = transform(ntestDS, @(x) applyRegressors(x,rSpec,inf));

%Step-1: Collect data
reset(trainRegressorsDS);
zTrain = cell(0,1);
for ct=1:ntrain
    zTrain = vertcat(zTrain,read(trainRegressorsDS)); %#ok<AGROW>
end
if isempty(zTrain)
    error("Not enough signal data to estimate model with "+max(nLagIn,nLagOut)+" lags.")
end
if haveTest
    if ntest > 1
        zTest = cell(0,1);
        for ct=1:ntest
            zTest = vertcat(zTest,read(testRegressorsDS)); %#ok<AGROW>
        end
    else
        zTest = read(testRegressorsDS); 
    end
end

%Configure progress monitor
romapp.internal.experimentmanager.configureMonitor(monitor,haveTest,true)

%% Step-2: Fit model
sw  = ctrlMsgUtils.SuspendWarnings('Ident:estimation:transientDataCorrection');
monitor.Status = "Training NSS model using data."; 

%create nss model and training options
nu = numel(ionames.Inputs);
nx = numel(ionames.Outputs);
nss = idNeuralStateSpace(nx,NumInputs=nu,Ts=1/fs);
nss.InputName = ionames.Inputs;
nss.StateName = ionames.Outputs;
nss.OutputName = nss.StateName; %Output and states are the same
nss.StateNetwork = createMLPNetwork(nss,'state',...
    LayerSizes=nUnits*ones(1,nLayers),...
    WeightsInitializer="glorot",BiasInitializer="zeros",Activations="tanh");

options = nssTrainingOptions('adam');
options.MaxEpochs = 1000;
options.LearnRate = 1e-3;
options.LossFcn = "MeanAbsoluteError";
options.PlotLossFcn = false;
options.WindowSize = WindowSize;
options.Overlap = Overlap;
options.Utility.CommandLineOutput = false;
modelType = "NSS";
options.Utility.OutputFcn = @(varargin) romapp.internal.experimentmanager.identStopHandler(monitor,options.MaxEpochs,0,modelType,varargin{:});

%Train the model
mNSS = nlssest(zTrain,nss,options);

%Compute performance on original training data
monitor.Status = "Evaluating model fit on training data."; 
yTrain = lCompare(zTrain,mNSS);
%Denormalize data
reset(experimentDS)
[~,oNames] = getDisplayNames(read(experimentDS));
[yTrain,zTrain] = lDenormalize(yTrain,zTrain,zSigma,zMu,oNames+"(t)");
trainFit= computeMSE(yTrain,zTrain,oNames+"(t)");

%% Step-3: Evaluate model on test data
if haveTest
    monitor.Status = "Evaluating model fit on test data.";
    yTest = lCompare(zTest,mNSS);
    [yTest,zTest] = lDenormalize(yTest,zTest,zSigma,zMu,oNames+"(t)");
    testFit = computeMSE(yTest,zTest,oNames+"(t)");
    updateInfo(monitor,TrainingMSE=trainFit)
    updateInfo(monitor,TestMSE=testFit)
else
    testFit = nan;
    updateInfo(monitor,TrainingMSE=trainFit)
end

%Create a validation plot
if haveTest 
    figure(Name = "Test Data: Actual vs Predicted")
    romapp.internal.experimentmanager.performancePlot(zTest,yTest,oNames+"(t)")
    figure(Name = "Test Data: Predicted Response")
    romapp.internal.experimentmanager.responsePlot(zTest,yTest,oNames+"(t)");
else
    figure(Name = "Training Data: Actual vs Predicted")
    romapp.internal.experimentmanager.performancePlot(zTrain,yTrain,oNames+"(t)")
    figure(Name = "Training Data: Predicted Response")
    romapp.internal.experimentmanager.responsePlot(zTrain,yTrain,oNames+"(t)");
end

%Collect data to return
output = struct(...
    'NSSModel',mNSS, ...
    'TrainingMSE', trainFit, ...
    'TestMSE', testFit, ...
    'Normalization', struct());

allVarNames = [inputNames(:).' , parameterNames(:).' , outputNames(:).'];
output.Normalization = struct( ...
    'Sigma', array2table(zSigma(:).', 'VariableNames', allVarNames), ...
    'Mu',    array2table(zMu(:).' , 'VariableNames', allVarNames) ...
    );

pNames = string({experiment.InputParameters.Name});
pVals  = [experiment.InputParameters.Value];
output.Parameters = cell2table(num2cell(pVals), 'VariableNames', cellstr(pNames));

delete(sw)
end

function [fs,nLagIn,nLagOut,nLayers,nUnits,WindowSize,Overlap] = getHyperparameters(params)
% Get hyper-parameter values
if isfield(params,'SampleRate')
    fs = params.SampleRate;
else
    fs = 1;
end
if isfield(params,'NumberInputLags')
    nLagIn = params.NumberInputLags;
else
    nLagIn = 0;
end
if isfield(params,'NumberOutputLags')
    nLagOut = params.NumberOutputLags;
else
    nLagOut = 0;
end
if isfield(params,'NumberLayers')
    nLayers = params.NumberLayers;
else
    nLayers = 1;
end
if isfield(params,'HiddenLayerSize')
    nUnits = params.HiddenLayerSize;
else
    nUnits = 16;
end
if isfield(params,'WindowSize')
    WindowSize = params.WindowSize;
else
    WindowSize = 50;
end
if isfield(params,'Overlap')
    Overlap = params.Overlap;
else
    Overlap = 0;
end
end

function [y,z] = lDenormalize(yn,zn,sigma,mu,oNames)

%Only denormalize the outputs
nOut = numel(oNames);
nVar = numel(sigma);
sigma = sigma((nVar-nOut+1):end);
mu = mu((nVar-nOut+1):end);

if iscell(zn)
    y = cell(size(yn));
    z = cell(size(zn));
    for ct=1:numel(zn)
        [~,idx] = intersect(zn{ct}.Properties.VariableNames,oNames);
        zData = zn{ct}{:,idx};
        [~,idx] = intersect(yn{ct}.Properties.VariableNames,oNames);
        yData = yn{ct}{:,idx};
        z{ct} = array2timetable(zData.*sigma+mu,...
            RowTimes=zn{ct}.Properties.RowTimes,...
            VariableNames=oNames);
        y{ct} = array2timetable(yData.*sigma+mu, ...
            RowTimes=yn{ct}.Properties.RowTimes, ...
            VariableNames=oNames);
    end
else
    z = array2timetable(zn.(oNames).*sigma+mu, ...
        RowTimes=zn.Properties.RowTimes, ...
        VariableNames=oNames);
    y = array2timetable(yn.(oNames).*sigma+mu, ...
        RowTimes=yn.Properties.RowTimes, ...
        VariableNames=oNames);
end
end

function mse = computeMSE(y,z,names)

if iscell(y)
    yt = vertcat(y{:});
    zt = vertcat(z{:});
else
    yt = y;
    zt = z;
end
[~,iy] = intersect(yt.Properties.VariableNames,names);
[~,iz] = intersect(zt.Properties.VariableNames,names);
mse = goodnessOfFit(yt{:,iy},zt{:,iz},'MSE');
end

function [r,ionames] = createRegressorSpec(names,nLagIn,nLagOut)
%Create regressors for input and output signals but not parameters
%(parameters are constant signals).

nOut = numel(names.outputNames);
nIn = numel(names.inputNames);
nP = numel(names.parameterNames);

rnames = names.outputNames(:);
lags = repmat({0:nLagOut},1,nOut);
rnames = vertcat(names.parameterNames(:), rnames);
for ct=1:nP
    lags = horzcat({0}, lags); %#ok<AGROW>
end
if nIn > 0 
    rnames = vertcat(names.inputNames(:), rnames);
    lags = horzcat(repmat({0:nLagIn},1,nIn), lags);
end
r = linearRegressor(rnames,lags);

if nargout > 1
    %Get the names of the regressed variables and split into input and outputs
    rnames = getreg(r);
    inames = [names.inputNames;names.parameterNames];
    idx = false(size(rnames));
    for ct=1:nIn+nP
        idx = idx | strcmp(rnames,inames(ct)+"(t)");
    end
    ionames.Inputs = rnames(idx);

    %Sort the outputs so that the true outputs (not the lagged inputs) are
    %the 1st outputs
    onames = rnames(~idx);
    idx = false(size(onames));
    for ct=1:numel(names.outputNames)
        idx = idx | strncmp(onames,names.outputNames(ct),strlength(names.outputNames(ct)));
    end
    ionames.Outputs = [onames(idx); onames(~idx)];
end
end

function z = applyRegressors(z,regressorSpec,windowSize)
%Compute regressors for a data set

%Expand the data to include regressors but remove rows with missing values
z = getreg(regressorSpec,z);
maxLag = max(cellfun(@max,regressorSpec.Lags));
z = z(maxLag+1:end,:);

if isfinite(windowSize)
    %Check there is enough data to satisfy the lags order and window size
    if height(z) <= windowSize
        z = [];
    else
        z = {z};
    end
else
    z = {z};
end
end

function data = lExtractData(ttData,sigma,mu)

if nargin > 1
    ttData{:,:} = (ttData{:,:}-mu)./sigma;
    data = ttData;
else
    data = table2array(ttData);
end
end

function y = lCompare(z,mdl)

y = compare(z,mdl);
if ~iscell(y)
    y = {y};
end
end
% LocalWords:  MLP nss adam ndata glorot fs ionames rnames