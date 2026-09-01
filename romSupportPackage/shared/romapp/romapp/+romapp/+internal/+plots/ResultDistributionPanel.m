classdef ResultDistributionPanel < handle
    %

    %ResultDistributionPanel
    %
    %Class to create a distribution plot to show in the
    %ScalarResultPlot. Is housed in a panel in the ScalarResultPlot
    %and the panel visibility toggled depending on result plot format.

    % Copyright 2024-2025 The MathWorks, Inc.

    properties (WeakHandle)
        ResultPlot romapp.internal.plots.ScalarResultPlot
    end
    
    properties(Access = protected)
        ParentContainer
        Panel   %Parent for the tiled layout
        Layout  %Tiled layout for outputs
        hAx %Axes for each histogram
    end

    methods
        function obj = ResultDistributionPanel(resultPlot,container)

            obj.ResultPlot = resultPlot;
            obj.ParentContainer = container;
        end

        function updatePlot(this)

            configurePlot(this)
            drawPlot(this)
        end

        function configurePlot(this)
            %

            %Get signal data from the result
            oData = getOutputData(this.ResultPlot);
            nOut = size(oData,1);
            %For n outputs determine layout size.
            col = ceil(sqrt(nOut)); %Square layout to house all
            %Determine how many rows are needed
            if mod(nOut,col) > 0
                row = floor(nOut/col)+1; 
            else
                row = nOut/col;
            end
            
            if isempty(this.Panel) || ~isvalid(this.Panel)
                pParent = uipanel(this.ParentContainer);
                pParent.Layout.Row = 1;
                pParent.Layout.Column = 1;
                pParent.BorderType = 'none';
                this.Panel = pParent;
            end
            
            %Create a subplot for each signal
            if (~isempty(this.Layout) && isvalid(this.Layout)) && ~isequal(this.Layout.GridSize,[row,col])
                %Number of subplots changed
                delete(this.Layout)
            end
            if isempty(this.Layout) || ~isvalid(this.Layout)
                this.Layout = tiledlayout(this.Panel,row,col);
                hAx = [];
                for ct=1:nOut
                    ax = axes('Parent',this.Layout, ...
                        'xgrid','on','ygrid','on');
                    ax.Layout.Tile = ct;
                    ax.Layout.TileSpan = [1 1];
                    hAx = [hAx; ax];
                end
                this.hAx = hAx;
            end
        end

        function drawPlot(this)

            %Set the line data for each signal
            oData = getOutputData(this.ResultPlot);
            for ct=1:size(oData,1)
                histogram(this.hAx(ct), oData{ct,2});
                this.hAx(ct).XLabel.String = strrep(string(oData{ct,1}),'_','\_');
            end
        end
    end

    
    methods
        function wdgts = getWidgets(this)

            wdgts = struct(...
                'AxisLayout', this.Layout, ...
                'Axes', this.hAx);
        end
    end
end

% LocalWords:  timetrace Tiledlayout xdata ydata lbl xgrid ygrid
