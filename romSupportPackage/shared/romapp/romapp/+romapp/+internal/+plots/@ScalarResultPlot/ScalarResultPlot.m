classdef (Hidden) ScalarResultPlot < controllib.ui.internal.figuretool.FigureTool
    %

    %ScalarResultPlotT Plot for simulation results for static ROM

    % Copyright 2024-2025 The MathWorks, Inc.

    properties(Constant)
        TYPE = 'ScalarResult';
        NAME = romapp.internal.resources.getString('lblResultPlot_Name');
    end

    properties(Access=protected)
        Simset romapp.internal.data.SimulationSet
        SimResultTab
        
        PlotType string {mustBeMember(PlotType,["scatterplot","distribution","errors"])} = "scatterplot"
        DistributionPanel
        Distribution
        ScatterplotPanel
        Scatterplot
        ErrorPanel
        Errorplot
    end

    properties(Access=private)
        ResultListeners
    end

    methods
        function obj = ScalarResultPlot(simset,tag)

            srTab = romapp.internal.tabs.ScalarResultsTab(romapp.internal.resources.getString('lblResultPlot_Name'), tag);
            obj = obj@controllib.ui.internal.figuretool.FigureTool(tag,srTab.Tab)
            obj.SimResultTab = srTab;
            obj.SimResultTab.setPlot(obj)
           
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

        function ds = getResultDatastore(this)

            ds = this.Simset.Results;
        end

        function data = getParameterData(this,errorFlag)

            if nargin < 2
                errorFlag = false;
            end

            experimentDS = getResultDatastore(this);

            %Determine parameter names
            reset(experimentDS)
            experiment = read(experimentDS);
            names = romapp.internal.data.ModelPorts.getDisplayName(experiment.InputParameters);
            nName = numel(names);

            %Get all the parameter values
            dataDS = transform(experimentDS,@(x) lGetParameterData(x,errorFlag));
            values = readall(dataDS);

            data = cell(nName,2);
            for ct=1:nName
                data{ct,1} = names(ct);
                data{ct,2} = values(:,ct);
            end
        end

        function data = getOutputData(this)

            experimentDS = getResultDatastore(this);

            %Determine output names
            experiment = read(experimentDS);
            while ~isempty(experiment.Errors) && hasdata(experimentDS)
                experiment = read(experimentDS);
            end
            names = romapp.internal.data.ModelPorts.getDisplayName(experiment.OutputSignals);
            nName = numel(names);

            %Get all the output values
            dataDS = transform(experimentDS, @(x) lGetOutputData(x,nName));
            values = readall(dataDS);

            data = cell(nName,2);
            for ct=1:nName
                data{ct,1} = names(ct);
                data{ct,2} = values(:,ct);
            end
        end

        function tf = isResultError(this)

            experimentDS = getResultDatastore(this);
            noErrorsDS = transform(experimentDS, @(x) isempty(x.Errors));
            tf = ~readall(noErrorsDS);
        end

        function createPlot(this)

            this.DistributionPanel = uigridlayout(this.Document.Figure,[1 1]);
            this.DistributionPanel.RowHeight = {'1x'};
            this.DistributionPanel.ColumnWidth = {'1x'};
            this.Distribution = romapp.internal.plots.ResultDistributionPanel(this, this.DistributionPanel);
            this.ScatterplotPanel = uipanel(this.Document.Figure,'BorderType','none');
            this.ScatterplotPanel.Visible = 'off';
            this.ScatterplotPanel.Units = 'normalized';
            this.ScatterplotPanel.Position = [0 0 1 1];
            this.Scatterplot = romapp.internal.plots.ScalarOutputScatterplotPanel(this, this.ScatterplotPanel);
            this.ErrorPanel = uigridlayout(this.Document.Figure,[1 1]);
            this.ErrorPanel.RowHeight = {'1x'};
            this.ErrorPanel.ColumnWidth = {'1x'};
            this.Errorplot = romapp.internal.plots.ScalarOutputErrorPanel(this, this.ErrorPanel);
        end

        function setResult(this,simset)
            this.Document.Title = romapp.internal.resources.getString('lblResultPlot_FigureTitle',simset.Name);
            this.Simset = simset;
            if ~isempty(this.ResultListeners)
                delete(this.ResultListeners)
            end
            weak = romapp.internal.resources.WeakReference(this);
            L1 = addlistener(this.Simset,'ObjectBeingDestroyed', @(hSrc,hData) cbResultDestroyed(weak.Handle));
            this.ResultListeners = L1;

            if all(isResultError(this))
                this.PlotType = 'errors';
            end
            
            updatePlot(this)
            update(this.SimResultTab)
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
                case 'distribution'
                    drawPlot(this.Distribution)
                case 'scatterplot'
                    drawPlot(this.Scatterplot)
                case 'errors'
                    drawPlot(this.Errorplot)
            end
        end

        function updatePlot(this)

            
            %Update the plot data
            switch this.PlotType
                case 'distribution'
                    this.ScatterplotPanel.Visible = 'off';
                    this.ErrorPanel.Visible = 'off';
                    updatePlot(this.Distribution)
                    this.DistributionPanel.Visible = 'on';
                case 'scatterplot'
                    this.DistributionPanel.Visible = 'off';
                    this.ErrorPanel.Visible = 'off';
                    updatePlot(this.Scatterplot)
                    this.ScatterplotPanel.Visible = 'on';
                case 'errors'
                    this.DistributionPanel.Visible = 'off';
                    this.ScatterplotPanel.Visible = 'off';
                    updatePlot(this.Errorplot)
                    this.ErrorPanel.Visible = 'on';
            end
        end
    end

    methods
        function panels  = qeGetPanels(this)

            panels = struct(...
                'Distribution', this.Distribution, ...
                'Scatterplot', this.Scatterplot, ...
                'Errors', this.Errorplot);
        end
    end

    methods(Access = protected)
        function cbResultDestroyed(this)
            delete(this)
        end
    end
end

function data = lGetParameterData(experiment,returnErrors)

params = experiment.InputParameters;
np = numel(params);

%Return parameter values for either results that have an error or results
%that don't have an error
isError = ~isempty(experiment.Errors);
if ~isequal(returnErrors,isError)
    %No data to return
    data = zeros(0,np);
    return
end

data = nan(1,np);
for ct=1:np
    data(1,ct) = params(ct).Value;
end
end

function data = lGetOutputData(experiment,nsig)

if ~isempty(experiment.Errors)
    data = zeros(0,nsig);
    return
end

sigs = experiment.OutputSignals;
data = nan(1,nsig);
for ct=1:nsig
    data(1,ct) = sigs(ct).Values{1,1};
end
end

% LocalWords:  xdata ydata timetrace lbl
