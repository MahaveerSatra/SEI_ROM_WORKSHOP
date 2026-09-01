function output = trainMLP(params,monitor)
%% Experiment to train a MLP model
% Train a multi-layer perceptron neural network. Hyper-parameters for training are:
%%
% * |NumberLayers| - The number of layers in the MLP, an integer > 0
% * |HiddenLayerSize| - The number of hidden units in the sigmoid layer, an integer > 0
%
%%
% The tuning follows the following automated steps:
%%
% # Extract the training data and create a mini-batch queue
% # Train the MLP network model 
% # Evaluate model on test data (if available)
% 

%   Copyright 2024-2026 The MathWorks, Inc.

% Get hyper-parameter values
[nLayers,nUnits] = getHyperparameters(params);

% Step-1: Collect data
% Load data
monitor.Status = "Loading and processing data."; 
if isfield(params,'DataFileName')
    data = load(params.DataFileName,'results');
else
    data = load('trainingData.mat','results');
end
experimentDS = data.results;

%Find number and name of inputs/outputs/parameters
reset(experimentDS);
experiment = read(experimentDS);
[inputNames,outputNames,parameterNames] = getDisplayNames(experiment);
numInputs = numel(inputNames);
numParameters = numel(parameterNames);
numOutputs = numel(outputNames);
haveSignalData = size(experiment.OutputSignals(1).Values,1) > 1;
names = struct(...
    'OutputNames', outputNames, ...
    'InputNames', inputNames, ...
    'ParameterNames', parameterNames);

%Transform the experiment datastore to return the data in table format.
dataDS = transform(experimentDS, @(x) romapp.internal.experimentmanager.extractData(x));

%Split the data into training and test data-stores.
testSplit = 20;
if haveSignalData
    countDS = transform(dataDS, @(x) size(x,1));
    counts = readall(countDS);
    maxNumPts = max(counts);
    nresults = sum(counts);
else
    nresults = romapp.internal.experimentmanager.getNumResults(experimentDS);
    maxNumPts = 1;
end
haveTest = nresults > 10;
if haveTest
    if haveSignalData
        %Randomly split results into training and test data sets
        rngState = rng(43210); %So that different hyper-parameter runs use the same split
        shuffle = randperm(maxNumPts);
        rng(rngState) %restore

        trainDS  = transform(dataDS, @(x) lExtractData(x,shuffle,testSplit,'train'));
        testDS = transform(dataDS, @(x) lExtractData(x,shuffle,testSplit,'test'));
    else
        rngState = rng(43210); %So that different hyper-parameter runs use the same split
        shuffle = randperm(nresults);
        rng(rngState) %restore
        ntrain = max([1,floor(nresults*(1-testSplit/100))]);
        trainDS = transform(subset(dataDS,shuffle(1:ntrain)),@(x) lExtractData(x));
        testDS = transform(subset(dataDS,shuffle(ntrain+1:nresults)),@(x) lExtractData(x));
    end
else
    %Only small amount of data, use it all for training
    trainDS  = transform(dataDS, @(x) lExtractData(x));
end

%Compute the training mean and std for normalization
[v,m] = std(tall(trainDS));
[zSigma,zMu] = gather(v,m);
zSigma(zSigma(:) == 0) = 1; %Protect against any constant inputs

%Create a transformation on the datasets to return normalized data
ntrainDS = transform(trainDS,@(x) lNormalize(x,zSigma,zMu));
if haveTest
    ntestDS = transform(testDS,@(x) lNormalize(x,zSigma,zMu));
end

% Configure progress monitor
romapp.internal.experimentmanager.configureMonitor(monitor,haveTest,true)

%% Step-2: Fit DL Model.

% Create mini-batch queue and network layers
mbq = createMinibatchqueue(ntrainDS,names,nresults);
monitor.Status = "Creating MLP neural network.";

layers = featureInputLayer(numInputs+numParameters,Name=makeLayerName([names.InputNames;names.ParameterNames]));
for i = 1:nLayers
    layers = [layers;fullyConnectedLayer(nUnits);tanhLayer()]; %#ok<AGROW>
end
layers = [ ...
    layers; ...
    fullyConnectedLayer(numOutputs,Name=makeLayerName(names.OutputNames))];
net = dlnetwork(layers);

%% Step-3: Train DL Model.
monitor.Status = "Training MLP using mini-batched data."; 
% To speed up training we use dlaccelerate that replaces modelLoss with an
% optimized version.
lossFcn = dlaccelerate(@modelLoss);
clearCache(lossFcn);

% Initialize the configuration for adamupdate
avgG = [];
avgSqG = [];

% Initialize training loop variables.
iter = 0;

% Training loop.
maxEpochs = 1000;
learnrate = 1e-3; 
for epoch = 1:maxEpochs
    % Shuffle the data every epoch
    mbq.shuffle();
    while hasdata(mbq) && ~monitor.Stop
        % Increment the iteration counter.
        iter = iter+1;
        % Get a mini-batch of predictors X and targets T
        [X,T] = mbq.next();
        % Compute the loss and its gradient with respect to the network
        % learnables using dlfeval.
        [loss,gradients] = dlfeval(lossFcn,X,T,net);
        % Update the network with adamupdate.
        [net,avgG,avgSqG] = adamupdate(net,gradients,avgG,avgSqG,iter,learnrate);
        % Update monitor.
        recordMetrics(monitor,iter,TrainingLoss=loss);
    end
    monitor.Progress = 100*epoch/maxEpochs;
    if monitor.Stop
        break
    end
end
output.Network = net;
%Compute training error for all data
monitor.Status = "Evaluating model fit on training data."; 
reset(ntrainDS)
ct = 1;
while hasdata(ntrainDS)
    zi = read(ntrainDS);
    actualInput = zi(:,1:(numInputs+numParameters));
    ypred = predict(net,actualInput);
    yTrain{ct} = array2table(ypred,'VariableNames',names.OutputNames);
    zTrain{ct} = array2table(zi,'VariableNames',[names.InputNames;names.ParameterNames(:);names.OutputNames(:)]);
    ct = ct + 1;
end
[yTrain,zTrain] = lDenormalize(yTrain,zTrain,zSigma,zMu);
trainMSE = computeMSE(yTrain,zTrain,names.OutputNames);
updateInfo(monitor,TrainingMSE=trainMSE);
output.TrainingLoss = trainMSE;
 
%% Step-4: Evaluate model on test data
if haveTest  
    monitor.Status = "Evaluating model fit on test data."; 
    reset(ntestDS)
    ct = 1;
    while hasdata(ntestDS)
        zi = read(ntestDS);
        actualInput = zi(:,1:(numInputs+numParameters));
        ypred = predict(net,actualInput);
        yTest{ct} = array2table(ypred,'VariableNames',names.OutputNames);
        zTest{ct} = array2table(zi,'VariableNames',[names.InputNames;names.ParameterNames(:);names.OutputNames(:)]);
        ct = ct + 1;
    end
    [yTest,zTest] = lDenormalize(yTest,zTest,zSigma,zMu);
    testMSE = computeMSE(yTest,zTest,names.OutputNames);
    updateInfo(monitor,TestMSE=testMSE);
    output.TestLoss=testMSE;
end

% Save the Normalization struct with single-row tables
allVarNames = [inputNames(:).' , parameterNames(:).' , outputNames(:).'];
output.Normalization = struct( ...
    'Sigma', array2table(zSigma(:).', 'VariableNames', allVarNames), ...
    'Mu',    array2table(zMu(:).' , 'VariableNames', allVarNames) ...
    );

pNames = string({experiment.InputParameters.Name});
pVals  = [experiment.InputParameters.Value];
output.Parameters = cell2table(num2cell(pVals), 'VariableNames', cellstr(pNames));

%Create a validation plot
if haveTest
    figure(Name = "Test Data: Actual vs Predicted")
    romapp.internal.experimentmanager.performancePlot(zTest,yTest,names.OutputNames);
    if haveSignalData
        lSignalResponsePlot(experimentDS,"Predicted Response", net,...
            names,zSigma,zMu)        
    end
else
    figure(Name = "Training Data: Actual vs Predicted")
    romapp.internal.experimentmanager.performancePlot(zTrain,yTrain,names.OutputNames);
    if haveSignalData
        lSignalResponsePlot(experimentDS,"Predicted Response", net,...
            names,zSigma,zMu)        
    end
end
end

function mbq = createMinibatchqueue(datastore,names,nresults)

    function [x,y] = minibatch(data)
        nIn = numel(names.InputNames)+numel(names.ParameterNames);
        x = [];
        y = [];
        for ct=1:size(data,1)
            d = data{ct};
            x = vertcat(x,d(:,1:nIn));
            y = vertcat(y,d(:,nIn+1:end));
        end
    end

mbq = minibatchqueue(datastore,2, ...
    MiniBatchFcn = @minibatch, ...
    MiniBatchFormat=["BC","BC"], ...
    MiniBatchSize=floor(nresults/5));
end

function [loss,gradients] = modelLoss(X,T,net)
% The modelLoss function takes the input data x and output data y as
% formatted dlarray-s, passes x through the forward method of the
% dlnetwork net, and computes the mse loss of the network-s output with y.
%
% If a 2nd output is requested from modelLoss we compute the gradient of the
% loss with respect to the network learnable parameters as grad via dlgradient.
Y = forward(net,X);
loss = l2loss(Y,T,NormalizationFactor="batch-size");
if nargout>1
    gradients = dlgradient(loss,net.Learnables);
end
end

function [nLayers,nUnits] = getHyperparameters(params)
%Helper function to set hyper-parameters
if isfield(params,'NumberLayers')
    nLayers = params.NumberLayers;
else
    nLayers = 2;
end
if isfield(params,'HiddenLayerSize')
    nUnits = params.HiddenLayerSize;
else
    nUnits = 10;
end
end

function name = makeLayerName(names)

name = '';
for ct=1:numel(names)
    name = sprintf('%s, %s', name, names{ct});
end
name = name(3:end);
end

function data = lExtractData(data,shuffle,testSplit,mode)

if nargin == 1
    data = data.Variables; %return numeric data
    return
end

ndata = size(data,1);
ntrain = max([1,floor(ndata*(1-testSplit/100))]);
shuffle(shuffle>ndata) = []; %Remove indices that we don't have data for.
switch mode
    case 'train'
        data = data(shuffle(1:ntrain),:);
    case 'test'
        data = data(shuffle(ntrain+1:ndata),:);
end
data = data.Variables; %Return numeric data
end

function data = lNormalize(data,zSigma,zMu)
data = (data-zMu)./zSigma;
end

function [y,z] = lDenormalize(yn,zn,sigma,mu)

if iscell(zn)
    y = cell(size(yn));
    z = cell(size(zn));

    [~,iremove] = setdiff(zn{1}.Properties.VariableNames,yn{1}.Properties.VariableNames);
    sigmaY = sigma;
    sigmaY(iremove) = [];
    muY = mu;
    muY(iremove) = [];
    for ct=1:numel(zn)
        z{ct} = zn{ct}.*sigma+mu;
        y{ct} = yn{ct}.*sigmaY+muY;
    end
else
    z = zn.*sigma+mu;
    [~,iremove] = setdiff(zn.Properties.VariableNames,yn.Properties.VariableNames);

    sigma(iremove) = [];
    mu(iremove) = [];
    y = yn.*sigma+mu;
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

function lSignalResponsePlot(experimentDS,figureName,net,names,zSigma,zMu)

numInputs = numel(names.InputNames);
numParameters = numel(names.ParameterNames);

reset(experimentDS)
result = read(experimentDS);
sig = result.OutputSignals(1);
t = seconds(sig.Values.Time);
fs = romapp.internal.experimentmanager.getEffectiveFs(t);
tfcn = @(x) romapp.internal.experimentmanager.extractSignalData(x,'SampleRate',fs);
testDS = transform(experimentDS,tfcn);
ntestDS = transform(testDS,@(x) lNormalize(x,zSigma,zMu));
zi = read(ntestDS);
actualInput = zi(:,1:(numInputs+numParameters));
actualInput = actualInput{:,:};
ypred = predict(net,actualInput);
yTest = array2timetable(ypred,'VariableNames',names.OutputNames,'SampleRate',fs);
zTest = array2timetable(zi{:,:},'VariableNames',[names.InputNames;names.ParameterNames(:);names.OutputNames(:)],'SampleRate',fs);
[yTest,zTest] = lDenormalize(yTest,zTest,zSigma,zMu);
figure(Name = figureName)
romapp.internal.experimentmanager.responsePlot(zTest,yTest,names.OutputNames)
end

% LocalWords:  minibatchqueue dlaccelerate adamupdate learnables dlfeval projectednet TCB dlarray
% LocalWords:  dlnetwork dlgradient MLP perceptron
