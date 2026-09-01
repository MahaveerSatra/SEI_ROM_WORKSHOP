function output = trainNLARX(params,monitor)
%% Experiment to train a NLARX model
% Train a NLARX model with a single sigmoid layer. Hyper-parameters for training are:
%%
% * |ModelOrder| - The model order, an integer > 0
% * |HiddenLayerSize| - The number of hidden units in the sigmoid layer, an integer > 0
% * |SampleRate| - Sample rate of the model, a real > 0
% * |WindowSize| - Number of samples in each frame or batch when segmenting data for model training, an integer > 0
%
%%
% The tuning follows the following automated steps:
%%
% # Extract and resample the training data
% # Fit a linear model
% # Initialize a NLARX model based on the linear model
% # Train the NLARX model for 1-step ahead prediction
% # Train the model for simulation prediction (inf-step ahead
% prediction)
% # Evaluate model on test data (if available)
%

%   Copyright 2023-2026 The MathWorks, Inc.

testSplit = 20; % For multiple data sets the percentage of data sets to use
% for testing, a double in range [0 100]. The test data sets are selected
% randomly from the available data sets.

% Get hyper-parameter values
[fs,mdlOrder,nUnits,WindowSize] = getHyperparameters(params);

%Load data
monitor.Status = "Loading and preprocessing data"; 
if isfield(params,'DataFileName')
    data = load(params.DataFileName,'results');
else
    data = load('trainingData.mat','results');
end
experimentDS = data.results;

%Randomly split results into training and test data sets
nresults = romapp.internal.experimentmanager.getNumResults(experimentDS);
rngState = rng(43210); %So that different hyper-parameter runs use the same split
experimentDS = shuffle(experimentDS);
rng(rngState) %restore 
ntrain = max([1,floor(nresults*(1-testSplit/100))]);
ntest = max([0,nresults-ntrain]);

%Transform the experiment datastore to return signal data in timetable
%format
tfcn = @(x) romapp.internal.experimentmanager.extractSignalData(x,'SampleRate',fs);
trainDS = transform(subset(experimentDS,1:ntrain),tfcn);
testDS = transform(subset(experimentDS,ntrain+1:nresults),tfcn);

%Find outputs
reset(experimentDS);
result = read(experimentDS);
outputNames = {result.OutputSignals.Name};
inputNames = {result.InputSignals.Name};

%% Step-1: Extract data
reset(trainDS);
zTrain = cell(ntrain,1);
idxKeep = true(size(zTrain));
for ct=1:ntrain
    zTrain{ct} = read(trainDS);
    idxKeep(ct) = height(zTrain{ct} > width(zTrain{ct}));
end
zTrain = zTrain(idxKeep);
if isempty(zTrain)
    error("Not enough signal data to estimate model")
end
haveTest = ntest > 0;
if haveTest
    zTest = cell(ntest,1);
    idxKeep = true(size(zTest));
    for ct=1:ntest
        zTest{ct} = read(testDS);
        idxKeep(ct) = height(zTest{ct}) > width(zTest{ct});
    end
    zTest = zTest(idxKeep);
    haveTest = ~isempty(zTest);
end

%Configure progress monitor
romapp.internal.experimentmanager.configureMonitor(monitor,haveTest,true)

%% Step-2: Fit linear model
sw  = ctrlMsgUtils.SuspendWarnings('Ident:estimation:transientDataCorrection');
monitor.Status = "Fitting linear model to initialize NLARX"; 
opt = ssestOptions('Focus','simulation');
modelType = "NLARX";
opt.Utility.OutputFcn = @(varargin) romapp.internal.experimentmanager.identStopHandler(monitor,opt.SearchOptions.MaxIterations,0,modelType,varargin{:});
mLinear = ssest(zTrain,mdlOrder,'OutputName',outputNames,...
        'feed',1,'Ts',1/fs,'dist','none',opt);
mLinear.Name = 'Linear Model';
 
%% Step-3 & 4: Initialize NLARX with linear model and perform 1-step ahead prediction training
monitor.Status = "1-step ahead prediction fitting"; 
monitor.Progress = 0;
f = idSigmoidNetwork(nUnits);
opt = nlarxOptions('Display','off','SearchMethod','lm','Focus','prediction','WindowSize',WindowSize);
opt.SearchOptions.MaxIterations = 10;
iterOffset = size(monitor.MetricData.TrainingLoss,1)+1;
opt.Utility.OutputFcn = @(varargin) romapp.internal.experimentmanager.identStopHandler(monitor,opt.SearchOptions.MaxIterations,iterOffset,modelType,varargin{:});
mNonLinear_pred = nlarx(zTrain,mLinear,f,opt);

%% Step-5: Fine tune using Simulation focus fitting
monitor.Status = "Simulation fitting"; 
monitor.Progress = 0;
opt.Focus = 'simulation';
iterOffset = size(monitor.MetricData.TrainingLoss,1)+1;
opt.Utility.OutputFcn = @(varargin) romapp.internal.experimentmanager.identStopHandler(monitor,opt.SearchOptions.MaxIterations,iterOffset,modelType,varargin{:});
mNonLinear = nlarx(zTrain,mNonLinear_pred,opt);
mNonLinear.Name = 'NLARX Model';
yTrain = lCompare(zTrain,mNonLinear);
trainFit= computeMSE(yTrain,zTrain,outputNames);
updateInfo(monitor,TrainingMSE=trainFit);

%% Step-6: Evaluate model on test data
if haveTest
    monitor.Status = "Evaluating model on test data"; 
    yTest = lCompare(zTest,mNonLinear);
    testFit= computeMSE(yTest,zTest,outputNames);
    updateInfo(monitor,TestMSE=testFit)
else
    testFit = nan;
end

%Create a validation plot
if haveTest
    figure(Name = "Test Data: Actual vs Predicted")
    romapp.internal.experimentmanager.performancePlot(zTest,yTest,outputNames)
    figure(Name = "Test Data: Predicted Response")
    romapp.internal.experimentmanager.responsePlot(zTest,yTest,outputNames);
else
    figure(Name = "Training Data: Actual vs Predicted")
    romapp.internal.experimentmanager.performancePlot(zTrain,yTrain,outputNames)
    figure(Name = "Training Data: Predicted Response")
    romapp.internal.experimentmanager.responsePlot(zTrain,yTrain,outputNames);
end

%Collect data to return
output = struct(...
    'LinearModel', mLinear, ...
    'NonlinearModel',mNonLinear, ...
    'TrainingMSE', trainFit, ...
    'TestMSE', testFit);

pNames = string({result.InputParameters.Name});
pVals  = [result.InputParameters.Value];
output.Parameters = cell2table(num2cell(pVals), 'VariableNames', cellstr(pNames));

delete(sw)
end  

function [fs,mdlOrder,nUnits,WindowSize] = getHyperparameters(params)
%Helper function to set hyper-parameters
if isfield(params,'SampleRate')
    fs = params.SampleRate;
else
    fs = 1;
end
if isfield(params,'ModelOrder')
    mdlOrder = params.ModelOrder;
else
    mdlOrder = 2;
end
if isfield(params,'HiddenLayerSize')
    nUnits = params.HiddenLayerSize;
else
    nUnits = 10;
end
if isfield(params,'WindowSize')
    WindowSize = params.WindowSize;
else
    WindowSize = 50;
end
end

function mse = computeMSE(y,z,names)

if iscell(y)
    h = cellfun(@height,y);
    idx = h > 0;
    y = y(idx);
    z = z(idx);
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

function y = lCompare(z,mdl)

y = compare(z,mdl);
if ~iscell(y)
    y = {y};
end
end

% LocalWords:  NLARX
