classdef (Hidden) ToolManager < handle & ...
        matlab.mixin.SetGet
    % 

    % ToolManager manage plots and tools created by the app

    %
    % Copyright 2021-2024 The MathWorks, Inc.

    properties
        App
        
        SimSetDocToolMgr
        PlotToolMgr

        IsDirty
    end

    methods
        function this = ToolManager(app)

            % get  data and the app
            this.App = app;

            % Create manager for tools with documents, tabs, & panels
            grpTag = char(strcat(app.ID, '-', romapp.internal.tools.SimulationSetTool.TYPE));
            this.SimSetDocToolMgr = romapp.internal.managers.DocumentToolManager( ...
                grpTag , app.Container, romapp.internal.resources.getString('lblSimulationSet'));

            %Create manager for tools with documents & tabs
            grpTag = char(strcat(app.ID,'-','plots'));
            this.PlotToolMgr = romapp.internal.managers.PlotManager(...
                grpTag, app.Container);
        end

        function tool = openTool(this, type, data, varargin)
            if nargin == 4
                bringToFocus = varargin{1};
            else
                bringToFocus = true;
            end
            id = strcat(this.App.ID,'-',type);
            tool = getFigureTool(this.SimSetDocToolMgr,id);
            if ~isempty(tool)
                setToolData(tool,data)
                if bringToFocus
                    figure(tool.Document.Figure) %Bring into focus
                end
            else
                switch type
                    case romapp.internal.tools.SimulationSetTool.TYPE
                        openingMsg = romapp.internal.resources.getString('msgOpenSimulationSet');
                        setWaiting(this.App, true, openingMsg);
                        tool = romapp.internal.tools.SimulationSetTool( ...
                            this.App, ...
                            this.App.ID, ...
                            data);

                        this.SimSetDocToolMgr.addFigureTool(tool)
                        installPanel(tool,this.SimSetDocToolMgr)

                    case romapp.internal.plots.SimulationSpecPlot.TYPE
                        hPlot = romapp.internal.plots.SimulationSpecPlot(data,id);
                        this.SimSetDocToolMgr.addFigureTool(hPlot)
                end
                setWaiting(this.App, false);
            end
        end

        function closeTool(this,varargin)
            %closeTool

            closeTool(this.SimSetDocToolMgr,varargin{:})
        end

        function tool = findTool(this, type)
            id = strcat(this.App.ID,'-',type);
            tool = getFigureTool(this.SimSetDocToolMgr,id);
        end 

        function openPlot(this,type,data)

            if isempty(data) || islogical(data)
                id = strcat(this.App.ID,'-',type);
            else
                id = strcat(this.App.ID,'-',type,'-',getUID(data));
            end

            plot = getFigureTool(this.PlotToolMgr,id);
            if isempty(plot)
                switch type
                    case romapp.internal.plots.SimulationResultPlot.TYPE
                        hPlot = romapp.internal.plots.SimulationResultPlot(data,id);
                    case romapp.internal.plots.ScalarResultPlot.TYPE
                        hPlot = romapp.internal.plots.ScalarResultPlot(data,id);
                    case romapp.internal.plots.OverviewPlot.TYPE
                        hPlot = romapp.internal.plots.OverviewPlot(id,data);
                end
                addFigureTool(this.PlotToolMgr,hPlot);
            else
                updatePlot(plot);
                plot.Document.Selected = true;
                plot.Document.Showing = true;
            end
        end

        function closePlot(this,varargin)
            %closePlot 
            
            closePlot(this.PlotToolMgr,varargin{:})
        end

        function delete(~)
           
        end

        function TGroup = getToolGroup(this)
            TGroup = this.App;
        end
        function TData = getToolData(this)
            TData = this.Data;
        end
        function Widgets = getWidgets(this)
            Widgets.ToolData = getToolData(this);
            Widgets.ToolTab = getToolTab(this);
            Widgets.ToolPlot = getToolPlot(this);
        end

        function setDirty(this, flag)
            setDirty(this.Data, flag);
        end

        function Flag = getDirty(this)
            Flag = this.Data.IsDirty;
        end
    end
    events
        CreateReducedModel
    end
end

% LocalWords:  lbl
