classdef (Hidden) SimulationResultPlot < controllib.ui.internal.figuretool.FigureTool
    %

    %SIMULATIONRESULTPLOT Plot for simulation results

    % Copyright 2022-2025 The MathWorks, Inc.

    properties(Constant)
        TYPE = 'SimulationResult';
        NAME = romapp.internal.resources.getString('lblResultPlot_Name');
    end

    properties(GetAccess = public, SetAccess = protected)
        ShowOutputOnly logical = false;
    end

    properties(Access=protected)
        Simset romapp.internal.data.SimulationSet
        SimResultTab
        ActiveResultIndex %Index of result being displayed 
        ResultData        %Experiment data for active result
        
        PlotType string {mustBeMember(PlotType,["timetrace","scatterplot"])} = "timetrace"
        TimetracePanel
        Timetrace
        ScatterplotPanel
        Scatterplot
    end

    properties(Access=private)
        ResultListeners
    end

    methods
        function obj = SimulationResultPlot(simset,tag)

            srTab = romapp.internal.tabs.SimulationResultsTab(romapp.internal.resources.getString('lblResultPlot_Name'), tag, ...
                isempty(simset.SimulationSpec));
            obj = obj@controllib.ui.internal.figuretool.FigureTool(tag,srTab.Tab)
            obj.SimResultTab = srTab;
            obj.SimResultTab.setPlot(obj)
            obj.ActiveResultIndex = 1;
           
            createPlot(obj)
            setResult(obj,simset)
        end

        function delete(this)
            if ~isempty(this.ResultListeners)
                delete(this.ResultListeners)
            end
            close(this.Document)
        end

        function doc = getDocument(this)
            doc = this.Document;
        end

        function fig = getFigure(this)
            fig = this.Document.Figure;
        end

        function tab = getTab(this)
            tab = this.SimResultTab;
        end

        function result = getResult(this)
            if isempty(this.ResultData)
                subDS = subset(this.Simset.Results,this.ActiveResultIndex);
                reset(subDS)
                result = read(subDS);
                this.ResultData = result;
            else
                result = this.ResultData;
            end
        end

        function simset = getSimset(this)
            simset = this.Simset;
        end

        function name = getSimsetName(this)
            name = this.Simset.Name;
        end

        function data = getParameterData(this)

            result = getResult(this);
            data = lGetParameterData(result.InputParameters);
        end

        function setIncludeForTraining(this, incl)
            this.Simset.IncludeForTraining(this.ActiveResultIndex) = incl;
        end

        function setIncludeForExportToWorkspace(this, incl)
            this.Simset.IncludeForExportToWorkspace(this.ActiveResultIndex) = incl;
        end

        function createPlot(this)

            this.TimetracePanel = uigridlayout(this.Document.Figure,[1 1]);
            this.TimetracePanel.RowHeight = {'1x'};
            this.TimetracePanel.ColumnWidth = {'1x'};
            this.Timetrace = romapp.internal.plots.ResultTimetracePanel(this, this.TimetracePanel);
            this.ScatterplotPanel = uipanel(this.Document.Figure,'BorderType','none');
            this.ScatterplotPanel.Visible = 'off';
            this.ScatterplotPanel.Units = 'normalized';
            this.ScatterplotPanel.Position = [0 0 1 1];
            this.Scatterplot = romapp.internal.plots.ResultScatterplotPanel(this, this.ScatterplotPanel);
        end

        function setResult(this,simset)
            this.Document.Title = romapp.internal.resources.getString('lblResultPlot_FigureTitle',simset.Name);
            nResults = simset.NumResults;
            if numel(simset.IncludeForTraining) ~= nResults
                % Re-initialize IncludeForTraining. Helps with backwards
                % compatibility
                simset.IncludeForTraining = true(nResults,1);
            end
            if numel(simset.IncludeForExportToWorkspace) ~= nResults
                % Re-initialize IncludeForExportToWorkspace. Helps with
                % backwards compatibility
                simset.IncludeForExportToWorkspace = true(nResults,1);
            end
            this.Simset = simset;
            if ~isempty(this.ResultListeners)
                delete(this.ResultListeners)
            end
            weak =romapp.internal.resources.WeakReference(this);
            L1 = addlistener(this.Simset,'ObjectBeingDestroyed', @(hSrc,hData) cbResultDestroyed(weak.Handle));
            this.ResultListeners = L1;
            updatePlot(this)
            update(this.SimResultTab)
        end

        function [idx,maxIdx] = getActiveResult(this)
            idx = this.ActiveResultIndex;
            if nargout > 1
                maxIdx = this.Simset.NumResults;
            end
        end

        function setActiveResult(this,idx)
            if idx >= 1 && idx <= this.Simset.NumResults && idx ~= this.ActiveResultIndex 
                this.ActiveResultIndex = idx;
                subDS = subset(this.Simset.Results,this.ActiveResultIndex);
                reset(subDS)
                this.ResultData = read(subDS);
                drawPlot(this)
            end
        end

        function setShowOutputOnly(this,showOutput)
            if ~isequal(this.ShowOutputOnly,showOutput)
                this.ShowOutputOnly = showOutput;
                updatePlot(this)
            end
        end

        function value = getShowOutputOnly(this)
            value = this.ShowOutputOnly;
        end

        function setPlotType(this,plottype)
            if ~isequal(this.PlotType,plottype)
                this.PlotType = plottype;
                updatePlot(this)
            end
        end

        function type = getPlotType(this)
            type = this.PlotType;
        end

        function drawPlot(this)
            %Refresh the data on the plot, no need to reconfigure/update
            %the entire plot
            switch this.PlotType
                case 'timetrace'
                    drawPlot(this.Timetrace)
                case 'scatterplot'
                    drawPlot(this.Scatterplot)
            end
        end

        function updatePlot(this)

            %Update the plot data
            this.ResultData = [];
            switch this.PlotType
                case 'timetrace'
                    this.ScatterplotPanel.Visible = 'off';
                    updatePlot(this.Timetrace)
                    this.TimetracePanel.Visible = 'on';
                case 'scatterplot'
                    this.TimetracePanel.Visible = 'off';
                    updatePlot(this.Scatterplot)
                    this.ScatterplotPanel.Visible = 'on';
            end
        end
  
        function [nSigIn,nSigOut] = getNumSignals(this)
            result = getResult(this);
            if this.ShowOutputOnly
                nSigIn = 0;
            else
                nSigIn = numel(result.InputSignals);
            end
            nSigOut = numel(result.OutputSignals); 
        end
    end

    methods
        function panels  = qeGetPanels(this)

            panels = struct(...
                'Timetrace', this.Timetrace, ...
                'Scatterplot', this.Scatterplot);
        end
    end

    methods(Access = protected)
        function cbResultDestroyed(this)
            delete(this)
        end
    end
end

function data = lGetParameterData(params)

np = numel(params);
data = cell(np,2);
names = romapp.internal.data.ModelPorts.getDisplayName(params);
for ct=1:np
    data{ct,1} = char(names(ct));
    data{ct,2} = params(ct).Value;
end
end

% LocalWords:  xdata ydata timetrace lbl
