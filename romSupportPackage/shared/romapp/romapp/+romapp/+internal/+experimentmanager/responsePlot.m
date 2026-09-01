function responsePlot(zData,yData,outputNames)
%responsePlot
%
% Create actual signal vs predicted signal for each output.
%
% performancePlot(zData,yData,outputNames)
% 
% Inputs
%   zData - cell array of timetables containing the experiment data 
%   yData - cell array of timetables containing the predicted data for
%           each element in zData
%   outputNames - cell array of output names contained in the data

%   Copyright 2025 The MathWorks, Inc.

numOutputs = numel(outputNames);
if iscell(zData)
    ct = numel(zData);
    found = false;
    while ct >= 1 && ~found
        if ~isempty(zData{ct}) && ~isempty(yData{ct})
            act = zData{ct};
            pred = yData{ct};
            found = true;
        else
            ct = ct - 1;
        end
    end
    if ~found
        return
    end
else
    act = zData;
    pred = yData;
    if isempty(pred)
        return
    end
end

%Extract signal data
t = seconds(act.Properties.RowTimes);
act = table2array(act(:,outputNames));
pred = table2array(pred(:,outputNames));

%Create a tiled layout to host plots
tl = tiledlayout(2,numOutputs); %#ok<NASGU>
%Create actual vs predicted plots
for ct=1:numOutputs
    nexttile
    plot(t,act(:,ct),t,pred(:,ct)), 
    title(strrep(outputNames{ct},'_','\_'))
    xlabel(romapp.internal.resources.getString('lblResponsePlot_Time'))
    ylabel(romapp.internal.resources.getString('lblResponsePlot_Signal'))
    grid on
end
legend(romapp.internal.resources.getString('lblResponsePlot_Actual'),...
    romapp.internal.resources.getString('lblResponsePlot_Predicted'))

%Create error signal plots
for ct=1:numOutputs
    nexttile
    plot(t,act(:,ct)-pred(:,ct)), 
    title(romapp.internal.resources.getString('lblResponsePlot_ActualMinusPredicted'))
    ylabel(romapp.internal.resources.getString('lblResponsePlot_PredictionError'))
    xlabel(romapp.internal.resources.getString('lblResponsePlot_Time'))
end
end

% LocalWords:  pred  lbl
