function output = trainGriddedInterp(params,monitor)   
%% Experiment to estimate a Gridded Interpolation model
% Estimate a griddedInterpolant. Hyper-parameters for training are:
%%
% * |Method| - The interpolation method
% * |ExtrapolationMethod| - The extrapolation method
%
%% 
% The estimation follows the following automated steps:
%% 
% # Extract the training data
% # Estimate the gridded interpolant model
% # Evaluate model on validation data (if available)
% 

%   Copyright 2024-2026 The MathWorks, Inc.

% Get hyper-parameter values
[method,extrapolationMethod] = getHyperparameters(params);

%% Step-1: Extract data

% Load data
monitor.Status = "Loading data";
data = load('trainingAndTestData.mat','results_training');
trainDS = data.results_training;
data = load('trainingAndTestData.mat','results_test');
testDS = data.results_test;

%Find number and name of inputs/outputs/parameters
reset(trainDS);
experiment = read(trainDS);
while ~isempty(experiment.Errors) && hasdata(trainDS)
    experiment = read(trainDS);
end
[~,outputNames,parameterNames] = getDisplayNames(experiment);
nparam = numel(parameterNames);
noutput = numel(outputNames);
names = struct(...
    'OutputNames', outputNames, ...
    'ParameterNames', parameterNames);

% Configure process monitor
haveTest = ~isempty(testDS) && hasdata(testDS);
romapp.internal.experimentmanager.configureMonitor(monitor,haveTest,false)

%Transform data store to return parameter and output data and collect the
%data
trainDS = transform(trainDS,  @(x) lExtractData(x,noutput));
data = readall(trainDS);
xTrain = data(:,1:nparam);
vTrain = data(:,nparam+1:end);

%Create a grid
[xGrid,vGrid] = createGrid(xTrain,vTrain,nparam,noutput);

%% Step-2: Estimate Gridded Interpolant
monitor.Status = "Interpolating";
F = griddedInterpolant(xGrid,vGrid,method,extrapolationMethod);
yTrain = squeeze(F(xTrain)); 
trainingMSE = getMSE(yTrain,vTrain);
updateInfo(monitor,TrainingMSE=trainingMSE);

% Collect data to return 
output = struct(...
    'GriddedInterpolantModel',F, ...
    'TrainingMSE', trainingMSE, ...
    'OutputNames', outputNames);

pNames = string({experiment.InputParameters.Name});
pVals  = [experiment.InputParameters.Value];
output.Parameters = cell2table(num2cell(pVals), 'VariableNames', cellstr(pNames));

%% Step-3: evaluate model on test data
if haveTest
    monitor.Status = "Evaluating model fit on test data";
    testDS = transform(testDS,  @(x) lExtractData(x));
    data = readall(testDS);
    xTest = data(:,1:nparam);
    vTest = data(:,nparam+1:end);
    yTest = squeeze(F(xTest));
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
romapp.internal.experimentmanager.performancePlot(vAct,yPred,names.OutputNames)
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

function data = lExtractData(exp,noutput)

if isempty(exp.Errors) || nargin < 2
    data = romapp.internal.experimentmanager.extractData(exp);
    data = data{:,:};
else
    data = [exp.InputParameters.Value, nan(1,noutput)];
end
end

function [xGrid,vGrid] = createGrid(xTrain,vTrain,nparams,noutputs)
    
    xGrid = cell(nparams,1);
    for iparam = 1:nparams
        xGrid{iparam} = unique(xTrain(:,iparam));
    end

    [xndgrid{1:length(xGrid)}] = ndgrid(xGrid{:});
    xcombinations = cell2mat(cellfun(@(x) x(:), xndgrid, 'UniformOutput', false));

    vGrid = zeros(length(xcombinations),noutputs);
    for icomb = 1:length(xcombinations)
        idx = ismember(xTrain, xcombinations(icomb,:), 'rows');
        vGrid(icomb,:) = vTrain(idx,:);
    end
    nGrid = cellfun(@length,xGrid);
    vGrid = reshape(vGrid,[nGrid',noutputs]);

end

function mseValue = getMSE(y,v)
    mseValue = sum((y-v).^2,'all')/numel(y);
end

% LocalWords:  griddedInterpolant interpolant