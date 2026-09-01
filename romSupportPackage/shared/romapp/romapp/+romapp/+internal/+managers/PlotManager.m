classdef (Hidden) PlotManager < controllib.ui.internal.figuretool.FigureToolManager
    % Plot Manager class

    % Copyright 2024 The MathWorks, Inc.

    methods
        function obj = PlotManager(parentTag,container)

            tag = strcat(parentTag,'-plots');
            obj = obj@controllib.ui.internal.figuretool.FigureToolManager(tag,container);
        end
        function closePlot(this,id)
            %closePlot

            if nargin > 1
                tool = findTool(this,id);
            elseif ~isempty(this.ToolMap)
                tool = this.ToolMap.values;
            else
                %No tools
                tool = [];
            end
            for ct=1:numel(tool)
                if ~strcmp(tool{ct}.TYPE,romapp.internal.plots.OverviewPlot.TYPE)
                    %Close the non-overview plots
                    close(tool{ct}.Document)
                end
            end

        end
    end
end
