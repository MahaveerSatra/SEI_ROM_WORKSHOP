classdef ScalarOutputScatterplotPanel < handle
    %

    %ScalarOutputScatterplotPanel
    %
    %Class to create a scatter plot to show in the
    %ScalarResultPlot. Is housed in a panel in the ScalarResultPlot
    %and the panel visibility toggled depending on result plot format.

    % Copyright 2024-2025 The MathWorks, Inc.

    properties (WeakHandle)
        ResultPlot romapp.internal.plots.ScalarResultPlot
    end
    
    properties(Access = protected)
        ParentContainer
        GridLayout %Container when have signals and parameters
        Panel %Container when only have signals
        hAx %Axis to hold the plot matrix
        PlotParent

        wdgtsPlotMatrix %Holds plotmatrix subaxes
    end

    methods
        function obj = ScalarOutputScatterplotPanel(resultPlot,container)

            obj.ResultPlot = resultPlot;
            obj.ParentContainer = container;
        end

        function updatePlot(this)

            configurePlot(this)
            drawPlot(this)
        end

        function configurePlot(this)
            %configurePlot
            %

            if isempty(this.Panel) || ~isvalid(this.Panel)
                %Create panel and tiledlayout to host plotmatrix
                pParent = uipanel(this.ParentContainer);
                pParent.BorderType = 'none';
                pParent.AutoResizeChildren = false;
                pParent.Units = 'Normalized';
                pParent.Position = [0 0 1 1];
                this.Panel = pParent;
                tParent = tiledlayout(pParent,1,1);
                this.PlotParent = tParent;
                needAxis = true;
            else 
                needAxis = false;
            end

            %Create new axis in the tiledlayout. This is to prevent
            %plotmatrix from setting the figure 'NextPlot' property to
            %replacechildren (the default behavior) which then destroys the
            %rest of the figure widgets when we refresh/recreate the
            %plotmatrix.
            if needAxis
                delete(this.hAx)
                this.hAx = nexttile(this.PlotParent);
            end
        end

        function drawPlot(this)

            %Collect data for plotmatrix
            pData = getParameterData(this.ResultPlot);
            oData = getOutputData(this.ResultPlot);
            if ~isempty(oData)
                
                xData = [pData{:,2}];
                xNames = pData(:,1);
                yData = [oData{:,2}];
                yNames = oData(:,1);

                %Create plotmatrix and configure
                [h,hSubAx] = plotmatrix(this.hAx,xData,yData);
                set(hSubAx,'xgrid','on','ygrid','on')
                this.wdgtsPlotMatrix = struct(...
                    'h', h, 'hSubAx', hSubAx);
                for ct=1:numel(xNames)
                    l = get(hSubAx(numel(yNames),ct),'xlabel');
                    set(l,'String',strrep(xNames{ct},'_','\_'));
                end
                for ct=1:numel(yNames)
                    l = get(hSubAx(ct,1),'ylabel');
                    set(l,'String',strrep(yNames{ct},'_','\_'));
                end
            end
        end
    end

    methods
        function wdgts = getWidgets(this)

            wdgts = struct(...
                'PlotMatrix', this.wdgtsPlotMatrix);
        end
    end
end

% LocalWords:  YTick tiledlayout replacechildren lbl xgrid ygrid
