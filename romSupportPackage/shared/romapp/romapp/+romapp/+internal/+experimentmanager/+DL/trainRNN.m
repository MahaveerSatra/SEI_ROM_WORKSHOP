function output = trainRNN(params,monitor)
%% Experiment to train a LSTM model
% Train a LSTM model. Hyper-parameters for training are:
%%
% * |NumberLayers| - The number of layers in the network, an integer > 0
% * |HiddenLayerSize| - The number of hidden units in each layer, an integer > 0
% * |SampleRate| - Sample rate of the model, a real > 0
%
%%
% The tuning follows the following automated steps:
%%
% # Extract and resample the training data
% # Train the LSTM model 
% # Evaluate model on test data (if available)
%
 
%   Copyright 2023-2026 The MathWorks, Inc.

% TestSplit - For multiple data sets the percentage of data sets to use
% for testing, a double in range [0 100]. The test data sets are selected
% randomly from the available data sets.
testSplit = 20; 

monitor.Status = "Loading and preprocessing data.";
[fs,nLayers,nUnits,learnrate] = getHyperparameters(params);

% Step-1: Collect and downsample data
% Load data
if isfield(params,'DataFileName')
    data = load(params.DataFileName,'results');
else
    data = load('trainingData.mat','results');
end
experimentDS = data.results;
reset(experimentDS);
result = read(experimentDS);
[iNames,oNames,pNames] = getDisplayNames(result);

%Randomly split results into training and test data sets
nresults = romapp.internal.experimentmanager.getNumResults(experimentDS);
rngState = rng(43210); %So that different hyper-parameter runs use the same split
experimentDS = shuffle(experimentDS);
rng(rngState) %restore 
ntrain = max([1,floor(nresults*(1-testSplit/100))]);
ntest = max([0,nresults-ntrain]);
haveTest = ntest > 0;
%Split the datastore into training and testing
trainDS = subset(experimentDS,1:ntrain);
testDS = subset(experimentDS,ntrain+1:nresults);

%Find input/output sizes and names
reset(experimentDS);
experiment = read(experimentDS);
[inputNames,outputNames,parameterNames] = getDisplayNames(experiment);
names = struct(...
    'outputNames', outputNames, ...
    'inputNames', inputNames, ...
    'parameterNames', parameterNames);
numInputs = numel(experiment.InputSignals)+numel(experiment.InputParameters);
numOutputs = numel(experiment.OutputSignals);

%Compute the training mean and std for normalization
dataDS = transform(trainDS,@(x) lExtractData(x,fs));
[v,m] = std(tall(dataDS));
[zSigma,zMu] = gather(v,m);
zSigma(zSigma(:) == 0) = 1; %Protect against any constant inputs

%Create a transformation on the datasets to return normalized data
ntrainDS = transform(trainDS,@(x) lExtractData(x,fs,zSigma,zMu));
ntestDS = transform(testDS,@(x) lExtractData(x,fs,zSigma,zMu));

% Configure progress monitor
romapp.internal.experimentmanager.configureMonitor(monitor,haveTest,true)

%% Step-2: Fit DL Model.
monitor.Status = "Creating mini-batch queue."; 

% Create mini-batch queue
mbq = createMinibatchqueue(ntrainDS,names);

% Create network layers and network
layers = sequenceInputLayer(numInputs);
for ct = 1:nLayers
    layers = [layers;lstmLayer(nUnits)]; %#ok<AGROW>
end
layers = [
    layers
    fullyConnectedLayer(nUnits)
    reluLayer()
    fullyConnectedLayer(numOutputs)];
net = dlnetwork(layers);

%% Step-3: Train DL Model.
monitor.Status = "Training LSTM model using mini-batched data."; 
% To speed up training we use dlaccelerate that replaces modelLoss with an
% optimized version.
lossFcn = dlaccelerate(@modelLoss);
clearCache(lossFcn);

% Initialize the configuration for adamupdate
avgG = [];
avgSqG = [];

% Initialize training loop variables.
iter = 0;
totalEpochs = 1000;
verificationToolboxInstalled = ~isempty(which("neuronPCA"));
if verificationToolboxInstalled 
    fineTuneMaxEpochs = 100;
    totalEpochs = totalEpochs+fineTuneMaxEpochs;
end

% Training loop.
maxEpochs = 1000;
for epoch = 1:maxEpochs
    % Shuffle the data every epoch
    mbq.shuffle();
    while hasdata(mbq) && ~monitor.Stop
        % Increment the iteration counter.
        iter = iter+1;
        % Get a mini-batch of predictors X and targets T
        [X,T,mask] = mbq.next();
        % Compute the loss and its gradient with respect to the network
        % learnables using dlfeval.
        [loss,gradients] = dlfeval(lossFcn,X,T,mask,net);
        % Update the network with adamupdate.
        [net,avgG,avgSqG] = adamupdate(net,gradients,avgG,avgSqG,iter,learnrate);
        % Update monitor.
        recordMetrics(monitor,iter,TrainingLoss=loss);
    end
    monitor.Progress = 100*epoch/totalEpochs;
    if monitor.Stop
        break
    end
end

%% Step-4 Compression
if verificationToolboxInstalled && ~monitor.Stop
    monitor.Status = "Compressing network."; 
    % The network above may be highly over-parameterized. We can reduce this
    % considerably with projection via compressNetworkUsingProjection.
    learnablesReductionGoal = 0.8;
    
    % Reset the minibatchqueue and use it to initialize the neuronPCA object
    % that is passed to compressNetworkUsingProjection.
    mbq.reset();
    npca = neuronPCA(net,mbq,VerbosityLevel="off");
    net = compressNetworkUsingProjection(net,npca, ...
        LearnablesReductionGoal=learnablesReductionGoal, ...
        VerbosityLevel="off");
    
    % Compression may have some impact on the network's accuracy, so fine tune
    % the projected weights for a few epochs on the training data.
    % The following training loop is very similar to the previous one, except
    % using the projectednet output of compressNetworkUsingProjection.
    % The fine tuning is done for less epochs, and with a smaller learning rate
    % to prevent the previously trained (and projected) weights being
    % forgotten.
    monitor.Status = "Fine tuning compressed network."; 
    avgG = [];
    avgSqG = [];    
    
    for epoch = 1:fineTuneMaxEpochs
        % Shuffle the data every epoch
        mbq.shuffle();
        while hasdata(mbq) && ~monitor.Stop
            % Increment the iteration counter.
            iter = iter+1;
            % Get a mini-batch of predictors X and targets T
            [X,T,mask] = mbq.next();
            % Compute the loss and its gradient with respect to the network
            % learnables using dlfeval.
            [loss,gradients] = dlfeval(lossFcn,X,T,mask,net);
            % Update the network with adamupdate.
            [net,avgG,avgSqG] = adamupdate(net,gradients,avgG,avgSqG,iter,learnrate);
            % Update monitor.
            recordMetrics(monitor,iter,TrainingLoss=loss);
        end
        monitor.Progress = 100*(epoch+maxEpochs)/totalEpochs;
        if monitor.Stop
            break
        end
    end
end
monitor.Status = "Evaluating model fit on training data."; 
yTrain = cell(ntrain,1);
zTrain = cell(ntrain,1);
reset(ntrainDS)
ct = 1;
while hasdata(ntrainDS)
    zi = read(ntrainDS);
    actualInput = zi(:,1:numInputs);
    ypred = predict(net,actualInput);
    yTrain{ct} = array2timetable(ypred,'SampleRate',fs,'VariableNames',oNames);
    zTrain{ct} = array2timetable(zi,'SampleRate',fs,'VariableNames',[iNames(:);pNames(:);oNames(:)]);
    ct = ct + 1;
end
[yTrain,zTrain] = lDenormalize(yTrain,zTrain,zSigma,zMu);
trainMSE = computeMSE(yTrain,zTrain,oNames);
updateInfo(monitor,TrainingMSE=trainMSE);


%% Step-5: Evaluate model on test data
if haveTest    
    monitor.Status = "Evaluating model fit on test data."; 
    yTest = cell(ntest,1);
    zTest = cell(ntest,1);
    reset(ntestDS)
    ct=1;
    while hasdata(ntestDS)
        zi = read(ntestDS);
        actualInput = zi(:,1:numInputs);
        ypred = predict(net,actualInput);
        yTest{ct} = array2timetable(ypred,'SampleRate',fs,'VariableNames',oNames);
        zTest{ct} = array2timetable(zi,'SampleRate',fs,'VariableNames',[iNames(:);pNames(:);oNames(:)]);
        ct = ct + 1;
    end
    [yTest,zTest] = lDenormalize(yTest,zTest,zSigma,zMu);
    testMSE = computeMSE(yTest,zTest,oNames);
    updateInfo(monitor,TestMSE=testMSE);
end

%Create a validation plot
if haveTest
    figure(Name = "Test Data: Actual vs Predicted")
    romapp.internal.experimentmanager.performancePlot(zTest,yTest,oNames)
    figure(Name = "Test Data: Predicted Response")
    romapp.internal.experimentmanager.responsePlot(zTest,yTest,oNames);
else
    figure(Name = "Training Data: Actual vs Predicted")
    romapp.internal.experimentmanager.performancePlot(zTrain,yTrain,oNames)
    figure(Name = "Training Data: Predicted Response")
    romapp.internal.experimentmanager.responsePlot(zTrain,yTrain,oNames);
end

output.Network = net;

%Save Normalization with groups
sigIn = zSigma(1 : numInputs);
muIn  = zMu(1 : numInputs);

sigOut = zSigma(numInputs + 1 : end);
muOut  = zMu(numInputs + 1 : end);

% Build the Normalization struct with single-row tables
output.Normalization = struct( ...
    'Inputs', struct( ...
    'Sigma', array2table(sigIn, 'VariableNames', [inputNames; parameterNames]), ...
    'Mu',    array2table(muIn,  'VariableNames', [inputNames; parameterNames]) ...
    ), ...
    'Outputs', struct( ...
    'Sigma', array2table(sigOut, 'VariableNames', outputNames), ...
    'Mu',    array2table(muOut,  'VariableNames', outputNames) ...
    ));

pNames = string({experiment.InputParameters.Name});
pVals  = [experiment.InputParameters.Value];
output.Parameters = cell2table(num2cell(pVals), 'VariableNames', cellstr(pNames));
end

function mbq = createMinibatchqueue(datastore,names)

    %Create mini-batch processor to split data into input and output data
    function [x,y,mask] = minibatch(data)
        nIn = numel(names.inputNames)+numel(names.parameterNames);
        nOut = numel(names.outputNames);
        maxT = max(cellfun(@(x)size(x,1),data));
        nb = numel(data);

        x = zeros(maxT,nIn,nb);
        y = zeros(maxT,nOut,nb);
        mask = zeros(maxT,nOut,nb,'single');
        for ct=1:nb
            d = data{ct};
            nt = size(d,1);
            mask(1:nt,:,ct) = 1;
            x(1:nt,1:nIn,ct) = d(:,1:nIn);
            y(1:nt,1:nOut,ct) = d(:,nIn+1:end);
        end
    end
mbq = minibatchqueue(datastore,3, ...
    MiniBatchFcn = @minibatch, ...
    MiniBatchFormat=["TCB","TCB","TCB"]);
end

function [loss,gradients] = modelLoss(X,T,mask,net)
% The modelLoss function takes the input data x and output data y as
% formatted dlarray-s, passes x through the forward method of the
% dlnetwork net, and computes the mse loss of the network-s output with y.
%
% If a 2nd output is requested from modelLoss we compute the gradient of the
% loss with respect to the network learnable parameters as grad via dlgradient.
Y = forward(net,X);
loss = l2loss(Y,T,Mask=mask,NormalizationFactor="mask-included");
if nargout>1
    gradients = dlgradient(loss,net.Learnables);
end
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

function [fs,nLayers,nUnits,learnRate] = getHyperparameters(params)
% Get hyper-parameter values
if isfield(params,'SampleRate')
    fs = params.SampleRate;
else
    fs = 1;
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
if isfield(params,'InitialLearnRate')
    learnRate = params.InitialLearnRate;
else
    learnRate = 1e-3;
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

function data = lExtractData(experiment,fs,zSigma,zMu)

ttData = romapp.internal.experimentmanager.extractSignalData(experiment,'SampleRate',fs);
data = ttData.Variables;
if nargin > 2
    %Normalize data
    data = (data-zMu)./zSigma;
end
end

% LocalWords:  minibatchqueue dlaccelerate adamupdate learnables dlfeval projectednet TCB dlarray
% LocalWords:  dlnetwork dlgradient LSTM xtest ypred ytest
