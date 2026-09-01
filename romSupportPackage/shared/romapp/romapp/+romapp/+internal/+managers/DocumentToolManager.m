classdef DocumentToolManager < controllib.ui.internal.figuretool.FigureToolManager
    %

    % Copyright 2020-2024 The MathWorks, Inc.

    methods
        function this = DocumentToolManager(tag, appcontainer, title)
            this = this@controllib.ui.internal.figuretool.FigureToolManager(tag, ...
                appcontainer);

            setTitle(this, title);
            pnl = matlab.ui.internal.FigurePanel();
            this.addPanel(pnl);
        end

        function pnl = getPanel(this)
            pnl = this.Panel;
        end

        function val = isTabBuilt(this)
            lookupValue = strcat(this.Tag, '-tab');
            val = hasTab(this, lookupValue);
        end

        function closeTool(this,id)
            %closeTool
            if nargin > 1
                tool = findTool(this,id);
            elseif ~isempty(this.ToolMap)
                tool = this.ToolMap.values;
            else
                %No tools
                tool = [];
            end
            for ct=1:numel(tool)
                close(tool{ct}.Document)
            end
        end
    end
    methods(Access = protected)
        function customUpdateTabState(this,tag) %#ok<INUSD>
            % nothing to do here?
        end
    end
end