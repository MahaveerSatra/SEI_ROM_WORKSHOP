classdef (Hidden) SimulationSpecPlot < controllib.ui.internal.figuretool.FigureTool
    %

    %SIMULATIONSPECPLOT Plot for simulation specs

    % Copyright 2022-2026 The MathWorks, Inc.

    properties(Constant)
        TYPE = 'SimulationSpec';
        NAME = romapp.internal.resources.getString('lblSimulationSpecPlot_Name');
    end

    properties(Access=protected)
        Spec
        Layout
        hAx
    end

    properties(Access = private)
        SpecListeners
    end

    methods
        function obj = SimulationSpecPlot(data,tag)


            obj = obj@controllib.ui.internal.figuretool.FigureTool(tag,0)
            createPlot(obj)
            setToolData(obj,data)
        end

        function delete(this)
            close(this.Document)
            if isvalid(this.SpecListeners)
                delete(this.SpecListeners)
                this.SpecListeners = [];
            end
        end

        function doc = getDocument(this)
            doc = this.Document;
        end

        function createPlot(this)

            this.hAx = axes(this.Document.Figure);
        end

        function setToolData(this,simset)
            spec = simset.SimulationSpec;
            this.Spec = spec;
            if ~isempty(this.SpecListeners)
                delete(this.SpecListeners)
            end
            L1 = addlistener(spec.FactorValues,'DataChanged', @(hSrc,hData) cbFactorValuesChanged(this));
            L2 = addlistener(spec,'ObjectBeingDestroyed', @(hSrc,hData) cbSpecDestroyed(this));
            this.SpecListeners = [L1, L2];
            this.Document.Title = romapp.internal.resources.getString('lblSimulationSpecPlot_Title',simset.Name);
            updatePlot(this)
        end
    
        function updatePlot(this)

            %Get signal data from the spec
            if isempty(this.Spec.SignalSpec)
                nSig = 0;
            else
                sValues = getSignalValues(this.Spec);
                [~,sRanges] = getSignalPlotData(this.Spec);
                nSig = size(sRanges,1);
            end
            %Get parameter data from the spec
            if isempty(this.Spec.ParameterSpec)
                nParam = 0;
            else
                [pValues,pRanges] = getParameterPlotData(this.Spec);
                %Expand pRanges by 5% so that axes limits don't match data
                %exactly.
                pRanges(:,1) = (1-0.05*sign(pRanges(:,1))).*pRanges(:,1);
                pRanges(:,2) = (1+0.05*sign(pRanges(:,2))).*pRanges(:,2);
                %Protect against range [0 0]
                idx = pRanges(:,1) == pRanges(:,2);
                pRanges(idx,:) = repmat([-1 1],sum(idx),1);
                nParam = size(pRanges,1);
            end
            
            %Create a subplot for each signal and parameter
            this.Layout = tiledlayout(this.Document.Figure,nSig+nParam,1);
            colorValue = '--mw-graphics-colorOrder-1-primary';

            % Names = [getShortPortName(data,ports), getShortPortName(data,params)];
            % if numel(Names) ~= numel(unique(Names))
            %     Names = [getFullPortName(data,ports), getFullPortName(data,params)];
            % end

            %Create the signal plots
            if nSig > 0
                names = romapp.internal.data.ModelPorts.getDisplayName(this.Spec.SignalSpec.Signals);
                for ct=1:nSig
                    ax = axes('Parent',this.Layout, ...
                        'xgrid','on', 'ygrid','on');
                    ax.Layout.Tile = ct;
                    ax.Layout.TileSpan = [1 1];
                    if isequal(min(sRanges(ct,:)), max(sRanges(ct,:)))
                        ax.YLim = [min(sRanges(ct,:))-1, max(sRanges(ct,:))+1];
                    else
                        ax.YLim = sRanges(ct,:);
                    end
                    if ~isempty(sValues)
                        l = line('parent',ax, ...
                            'xdata',seconds(sValues{ct}.Time), 'ydata', sValues{ct}.Data);
                        matlab.graphics.internal.themes.specifyThemePropertyMappings(l,'color',colorValue)
                    end
                    ax.Title.String = strrep(names(ct),'_','\_');
                    if this.Spec.SignalSpec.Mode == "add"
                        ax.Title.String = "\Delta"+ax.Title.String;
                    end
                    ax.XLabel.String = romapp.internal.resources.getString('lblSimulationSpecPlot_TimeAxis');
                end
            end

            %Create the parameter plots
            if nParam > 0
                names = romapp.internal.data.ModelPorts.getDisplayName(this.Spec.ParameterSpec.Parameters);    
                for ct=1:nParam
                    ax = axes('Parent',this.Layout, ...
                        'xgrid','on','ygrid','on');
                    ax.Layout.Tile = nSig+ct;
                    ax.Layout.TileSpan = [1 1];
                    ax.YLim = pRanges(ct,:);
                    if ~isempty(pValues)
                        l = line('parent',ax, 'LineStyle','none', 'marker', 'o', ...
                            'xdata',1:size(pValues,1), 'ydata', pValues(:,ct)');
                        matlab.graphics.internal.themes.specifyThemePropertyMappings(l,'MarkerEdgeColor',colorValue)
                        matlab.graphics.internal.themes.specifyThemePropertyMappings(l,'MarkerFaceColor',colorValue)
                    end

                    %Reduce X-axis tick density if more than 25 (arbitrary
                    %number for visual aesthetic) GeckID: g3820056
                    desiredTicks = 25; % target number of ticks for reducing tick density
                    maxTick = size(pValues,1);

                    xtick = 1:maxTick;
                    if maxTick > desiredTicks
                        minVal = xtick(1);    % Will always be 1
                        maxVal = xtick(end);

                        % Compute integer step size
                        rangeVal = maxVal - minVal;
                        step = max(1, ceil(rangeVal / (desiredTicks - 1)));

                        % Generate uniform integer ticks
                        xtick = minVal:step:maxVal;

                        % Ensure axis goes exactly to the last tick
                        ax.XLim = [minVal maxVal];
                    end

                    ax.XTick = xtick;
                    ax.Title.String = strrep(names(ct),'_','\_');
                    ax.XLabel.String = romapp.internal.resources.getString('lblSimulationSpecPlot_SimulationAxis');
                end
            end
        end
    end

    methods(Access = public, Hidden = true)
        function tl = qeGetLayout(this)
            tl = this.Layout; 
        end
    end

    methods(Access = protected)
        function cbFactorValuesChanged(this)
            updatePlot(this)
        end
        function cbSpecDestroyed(this)
            delete(this)
        end
    end
end

% LocalWords:  xdata ydata mw lbl xgrid ygrid
