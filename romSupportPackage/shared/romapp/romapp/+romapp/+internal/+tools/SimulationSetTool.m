classdef (Hidden) SimulationSetTool < controllib.ui.internal.figuretool.FigureTool
    %

    % Copyright 2022-2025 The MathWorks, Inc.

    properties(Access = protected)
        Data
        App
        SimSetPanel
        SimSetTab
        SimSetPlot

        DataListener
    end

    events(NotifyAccess = protected)
        DataChanged
    end
    
    properties(Constant)
        TYPE = 'SimulationSet';
        NAME = romapp.internal.resources.getString('lblSimulationSet');
    end
         
    methods
        function this = SimulationSetTool(app, parentTag, data)
           
            tag = strcat(parentTag,'-',romapp.internal.tools.SimulationSetTool.TYPE);
            ssTab = romapp.internal.tabs.SimulationSetTab(romapp.internal.tools.SimulationSetTool.NAME, tag);
            this = this@controllib.ui.internal.figuretool.FigureTool(tag,0);
            this.Document.Title = data.Name;

            this.App = app;
            this.SimSetTab = ssTab;
            setData(this,data)
            this.SimSetPlot = romapp.internal.plots.SimulationSetPlot(this);
        end
        
        function installPanel(this,mgr)
            if isempty(this.SimSetPanel) || ~isvalid(this.SimSetPanel)
                figPanel = getPanel(mgr);
                this.SimSetPanel = romapp.internal.panels.SimulationSetPanel(this, figPanel.Figure);
            end
        end

        function app = getApp(this)

            app = this.App;
        end

        function setToolData(this,data)

            %Set Data property
            setData(this,data)

            %Refresh the tab, panel, and plot
            if ~isempty(this.SimSetPanel) && isvalid(this.SimSetPanel)
                refreshPanel(this.SimSetPanel);
            end
            if ~isempty(this.SimSetPlot) && isvalid(this.SimSetPlot)
                updatePlot(this.SimSetPlot)
            end
            if ~isempty(this.SimSetTab) && isvalid(this.SimSetTab)
                update(this.SimSetTab)
            end
        end

        function data = getToolData(this)
            data = this.Data;
        end

        function delete(this)

            if ~isempty(this.DataListener)
                delete(this.DataListener)
            end
            close(this.Document)
            if ~isempty(this.SimSetPanel)
                delete(this.SimSetPanel)
            end
            if ~isempty(this.SimSetPlot)
                delete(this.SimSetPlot)
            end
        end
    end

    methods(Hidden = true)
        function qeFireDataChanged(this)
            notify(this,'DataChanged')
        end
        function wdgts = getWidgets(this)

            wdgts = struct(...
                'Plot', this.SimSetPlot, ...
                'Tab', this.SimSetTab, ...
                'Panel', this.SimSetPanel);
        end
    end

    methods(Access = protected)
        function setData(this,data)
            weak = romapp.internal.resources.WeakReference(this);
            l =  addlistener(data,'ObjectBeingDestroyed', @(src,data) delete(weak.Handle));
            if ~isempty(this.DataListener)
                delete(this.DataListener)
            end
            this.DataListener = l;
            this.Data = data;
            notify(this,'DataChanged')
        end
    end
end

% LocalWords:  lbl
