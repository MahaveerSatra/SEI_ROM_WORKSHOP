function performancePlot(zData,yData,outputNames)
%performancePlot
%
% Create actual vs predicted and error histogram plots for each output.
%
% performancePlot(zData,yData,outputNames)
% performancePlot(act,pred,outputNames)
% 
% Inputs
%   zData - cell array of timetables containing the experiment data 
%   yData - cell array of timetables containing the predicted data for
%           each element in zData
%   act - nxm array with n actual values for m outputs
%   pred - nxm array with n predicted values for m outputs
%   outputNames - cell array of output names contained in the data

%   Copyright 2025 The MathWorks, Inc.

numOutputs = numel(outputNames);
if iscell(zData)
    act = [];
    pred = [];
    for ct=1:numel(zData)
        if ~isempty(zData{ct}) && ~isempty(yData{ct})
            z = table2array(zData{ct}(:,outputNames));
            act = vertcat(act,z);
            y = table2array(yData{ct}(:,outputNames));
            pred = vertcat(pred,y);
        end
    end
elseif istimetable(zData)
    act = table2array(zData(:,outputNames));
    pred = table2array(yData(:,outputNames));
else
    act = zData;
    pred = yData;
end
err =  pred - act;

%Create a tiled layout to host plots
tl = tiledlayout(2,numOutputs); %#ok<NASGU>
%Create actual vs predicted plots
for ct=1:numOutputs
    nexttile
    plot(act(:,ct),pred(:,ct),'.',...
        [min(act(:,ct)),max(act(:,ct))],[min(act(:,ct)),max(act(:,ct))],'k--'), 
    title(strrep(outputNames{ct},'_','\_'))
    xlabel(romapp.internal.resources.getString('lblPerformancePlot_Actual'))
    ylabel(romapp.internal.resources.getString('lblPerformancePlot_Predicted'))
    grid on
end
%Create error histogram plots
for ct=1:numOutputs
    nexttile
    histogram(err(:,ct)), title(strrep(outputNames{ct},"_","\_"))
    xlabel(romapp.internal.resources.getString('lblPerformancePlot_PredictionError'))
end
end

% LocalWords:  pred nxm lbl
