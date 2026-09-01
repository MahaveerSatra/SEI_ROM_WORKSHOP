function configureMonitor(monitor,haveTestData,haveIterativeTraining)
%configureMonitor 
%
% Configure monitor object to show progress and results in
% Experiment Manager.
%
% configureMonitor(monitor,haveTestData,haveIterativeTraining)
%
% Inputs:
%    monitor - experiments.Monitor object to configure
%    haveTestData - logical flag indicating whether to add metrics and info
%                   to show test data characteristics. Default Value is
%                   true
%    haveIterativeTraining - logical flag to indicate whether to add a
%                            metric to show training loss while the
%                            training is in progress. Default value is
%                            true.
%

%   Copyright 2025 The MathWorks, Inc.

arguments
    monitor experiments.Monitor
    haveTestData(1,1) logical = true
    haveIterativeTraining(1,1) logical = true;
end

if haveIterativeTraining
    monitor.Metrics = "TrainingLoss";
    monitor.XLabel = "Iteration";
end
if haveTestData > 0
    monitor.Info = ["TrainingMSE", "TestMSE"];
else
    monitor.Info = "TrainingMSE";
end
end