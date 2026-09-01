function output = trainScatteredInterp(params,monitor)
%% Experiment to estimate a Scattered Interpolation model
% Estimate a scatteredInterpolant. Hyper-parameters for training are:
%%
% * |Method| - The interpolation method
% * |ExtrapolationMethod| - The extrapolation method
%
%% 
% The estimation follows the following automated steps:
%% 
% # Extract the training data
% # Estimate the scattered interpolant model
% # Evaluate model on validation data (if available)
% 

%   Copyright 2024-2025 The MathWorks, Inc.

% TestSplit - The percentage of results to use
% for testing, a double in range [0 100]. The test results sets are selected
% randomly from the available results.
testSplit = 20; 

% Get hyper-parameter values
[method,extrapolationMethod] = getHyperparameters(params);

%% Step-1: Extract data

% Load data
monitor.Status = "Loading data";
data = load('trainingData.mat','results');
experimentDS = data.results;
while hasdata(experimentDS)
    experiment = read(experimentDS);
    if isempty(experiment.Errors)
        [~,outputNames,parameterNames] = getDisplayNames(experiment);
        nparam = numel(parameterNames);
        break
    end
end

%Transform the experiment datastore to return the data in table format.
%dataDS = transform(experimentDS, @(x) romapp.internal.experimentmanager.extractData(x));
nresult = romapp.internal.experimentmanager.getNumResults(experimentDS);
haveTest = nresult > 10;
if haveTest
    rngState = rng(43210); %So that different hyper-parameter runs use the same split
    shuffle = randperm(nresult);
    rng(rngState) %restore
    ntrain = max([1,floor(nresult*(1-testSplit/100))]);
    trainDS = transform(subset(experimentDS,shuffle(1:ntrain)),@(x) lExtractData(x,outputNames,parameterNames));
    testDS = transform(subset(experimentDS,shuffle(ntrain+1:nresult)),@(x) lExtractData(x,outputNames,parameterNames));
else
    %Only small amount of data, use it all for training
    trainDS  = transform(experimentDS, @(x) lExtractData(x,outputNames,parameterNames));
end

% Configure process monitor
romapp.internal.experimentmanager.configureMonitor(monitor,haveTest,false)

%% Step-2: Estimate Scattered Interpolant

%Retrieve parameter and output data
data = readall(trainDS);
xTrain = data(:,1:nparam);
vTrain = data(:,nparam+1:end);

monitor.Status = "Interpolating";
if nparam<2
    F = @(xq) interp1(xTrain,vTrain,xq,method,extrapolationMethod);
else
    F = scatteredInterpolant(xTrain,vTrain,method,extrapolationMethod);
end
yTrain = F(xTrain); 
trainingMSE = getMSE(yTrain,vTrain);
updateInfo(monitor,TrainingMSE=trainingMSE);

% Collect data to return 
output = struct(...
    'ScatteredInterpolantModel',F, ...
    'TrainingMSE', trainingMSE);

%% Step-3: evaluate model on test data
if haveTest
    monitor.Status = "Evaluating model fit on test data";
    data = readall(testDS);
    xTest = data(:,1:nparam);
    vTest = data(:,nparam+1:end);

    yTest = F(xTest);
    testMSE = getMSE(yTest,vTest);
    output.TestMSE = testMSE;
    updateInfo(monitor,TestMSE=testMSE)
    
    yTest = F(xTest);
    testMSE = getMSE(yTest,vTest);
    output.TestMSE = testMSE;
    updateInfo(monitor,TestMSE=testMSE)
end

% Create a validation plot
if haveTest
    figure(Name="Test Data: Actual vs Predicted")   
    yPred = yTest; 
    vAct = vTest;  
else
    figure(Name="Training Data: Actual vs Predicted")
    yPred = yTrain;
    vAct = vTrain;
end
romapp.internal.experimentmanager.performancePlot(vAct,yPred,outputNames)
end

%% 
function [method,extrapolationMethod] = getHyperparameters(params)
    % Helper function to set hyper-parameters
    if isfield(params,'Method')
        method = params.Method;
    else
        method = 'linear';
    end
    if isfield(params,'ExtrapolationMethod')
        extrapolationMethod = params.ExtrapolationMethod;
    else
        extrapolationMethod = 'linear';
    end
end

function data = lExtractData(exp,outputNames,parameterNames)

pvalues = [exp.InputParameters.Value];
ovalues = nan(1,numel(outputNames));
if isempty(exp.Errors)
    for ct=1:numel(outputNames)
        ovalues(ct) = [exp.OutputSignals(ct).Values.Data];
    end
end

data = [pvalues,ovalues];
end

function mseValue = getMSE(y,v)
    mseValue = sum((y-v).^2,'all')/numel(y);
end

% LocalWords:  scatteredInterpolant interpolant