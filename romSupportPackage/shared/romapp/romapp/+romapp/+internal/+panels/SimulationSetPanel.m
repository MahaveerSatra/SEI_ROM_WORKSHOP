classdef SimulationSetPanel <  handle
    %

    % SIMULATIONSETPANEL Panel to display and edit simulation set data
    %   

    % Copyright 2022-2023 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        Layout
        
        ConfigureAllPanel
        DataListeners
    end

    methods
        function this = SimulationSetPanel(tool,parent)
            % SIMULATIONSETPANEL 

            this.Tool = tool;

            %Build the panel and update it
            buildPanel(this,parent)
            updatePanel(this)

            %Connect the panel to the data source
            connectPanel(this)
        end

        function delete(this)
            %Delete the graphic panel component
            if ~isempty(this.DataListeners)
                delete(this.DataListeners)
            end
        end

        function refreshPanel(this)
            updatePanel(this)
            refreshPanel(this.ConfigureAllPanel)
        end

    end

    methods (Access=private)
        function buildPanel(this,parent)

            %Create grid to hold panel contents
            layout = uigridlayout(parent,[2 1]);
            layout.RowHeight = {'1x'};
            layout.ColumnWidth = {'1x'};
            layout.Padding = [0 0 0 0];
            layout.RowSpacing = 0;
            this.Layout = layout;
            this.Layout.Scrollable = 'on';

            %Create panel to configure simulation spec
            this.ConfigureAllPanel = romapp.internal.panels.SimulationSetConfigureAll(this.Tool,this.Layout);
        end

        function connectPanel(this)
            %Add listeners for when the tool data changes
            addlistener(this.Tool,'DataChanged', @(hSrc,hData) setDataListener(this));

            %Initialize Tool data listeners (these need to change as the
            %tool data can change)
            setDataListener(this)
        end

        function updatePanel(this)

        end

        function setDataListener(this)

            %Add listeners to update the panel when a spec is added or the
            %set changes
            data = getToolData(this.Tool);
            l = addlistener(data,'DataChanged',@(hSrc,hData) updatePanel(this));
            if ~isempty(this.DataListeners)
                delete(this.DataListeners)
            end
            this.DataListeners = l;
        end
    end

    methods(Hidden = true)
        function wdgts = getWidgets(this)

            wdgts = struct(...
                'ConfigAll', this.ConfigureAllPanel);
        end
    end
end

% LocalWords:  Dropdown uiradiobutton uidropdown lbl chk uicheckbox
