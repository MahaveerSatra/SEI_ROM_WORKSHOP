classdef (Hidden) OverviewPlot < controllib.ui.internal.figuretool.FigureTool
    %

    %OverviewPlot Plot to show the workflow steps for the ROM app

    % Copyright 2023-2024 The MathWorks, Inc.

    properties(Constant)
        TYPE = 'Overview';
        NAME = romapp.internal.resources.getString('lblOverview_Name');
    end

    properties(Access=protected)

        Layout
        HTMLSource = string.empty;
    end

    methods
        function obj = OverviewPlot(tag,haveSimulinkModel)

            obj = obj@controllib.ui.internal.figuretool.FigureTool(tag,0)
            obj.Document.Title = obj.NAME;

            ipath = romapp.internal.resources.approot;
            if haveSimulinkModel
                obj.HTMLSource = fullfile(ipath,'+romapp','+internal','+resources','+html','overview.html');
            else
                obj.HTMLSource = fullfile(ipath,'+romapp','+internal','+resources','+html','overview_importdata.html');
            end

            createPlot(obj)
        end

        function delete(this)
            delete(this.Document)
        end

        function doc = getDocument(this)
            doc = this.Document;
        end

        function fig = getFigure(this)
            fig = this.Document.Figure;
        end

        function updatePlot(this)

        end
    end

    methods(Access = protected)
        function createPlot(this)

            layout = uigridlayout(this.Document.Figure,[1,1]);
            layout.RowHeight = {'1x'};
            layout.ColumnWidth = {'1x'};
            layout.Padding = 0;

            %uihtml
            html = uihtml(layout);
            html.Layout.Row = 1;
            html.Layout.Column = 1;
            html.HTMLSource = this.HTMLSource;

            this.Layout = layout;
        end
    end

    methods
        function panels  = qeGetPanels(this)

            panels = stuct(...
                'Timetrace', this.Timetrace, ...
                'Scatterplot', this.Scatterplot);
        end
    end
end

% LocalWords:  lbl uihtml Timetrace
