classdef (Hidden) SimulationSetPlot < handle
    %

    %SIMULATIONSETPLOT Plot for simulation sets

    % Copyright 2022-2025 The MathWorks, Inc.

    properties (Access = protected)
        hAx
        PlotWidgets
        DataListeners
    end

    properties (Access = protected, WeakHandle)
        Tool romapp.internal.tools.SimulationSetTool 
    end

    methods
        function this = SimulationSetPlot(tool)
            this.Tool = tool;

            %Create the plot
            createPlot(this);

            %Connect the plot to the data source
            connectPlot(this)
        end

        function connectPlot(this)
            %Add listeners for when the tool data changes
            addlistener(this.Tool,'DataChanged', @(hSrc,hData) setDataListener(this));

            %Initialize Tool data listeners (these need to change as the
            %tool data can change)
            setDataListener(this)
        end

        function createPlot(this)

            fig = this.Tool.Document.Figure;
            fig.AutoResizeChildren = 'off';
            this.hAx = axes('parent',fig);
            updatePlot(this)
        end

        function setDataListener(this)
            %Add listener to update plot when data changes
            data = getToolData(this.Tool);
            l = addlistener(data.SimulationSpec.FactorValues,'DataChanged',@(hSrc,hData) updatePlot(this));
            if ~isempty(this.DataListeners)
                delete(this.DataListeners)
            end
            this.DataListeners = l;
        end
    
        function updatePlot(this)

            data = getToolData(this.Tool);
            this.Tool.Document.Title = data.Name;

            ports = getPort(data,romapp.internal.data.PortType.SimulationInput);
            params =getPort(data,romapp.internal.data.PortType.SimulationParameter);
            nports = numel(ports) + numel(params);

            [values,ranges] = getPlotData(data);
            if isempty(values)
                values = zeros(0,nports);
            end
            if isempty(ranges)
                ranges = ones(nports,1)*[-1 1];
            else
                %Choose axes limits to be 5% larger than data range
                ranges(:,1) = (1-0.05*sign(ranges(:,1))).*ranges(:,1);
                ranges(:,2) = (1+0.05*sign(ranges(:,2))).*ranges(:,2);
                %Protect against range [0 0]
                idx = ranges(:,1) == ranges(:,2);
                ranges(idx,:) = repmat([-1 1],sum(idx),1);
            end

            [h,hSubAx,P] = plotmatrix(this.hAx,values);
            set(hSubAx,'xgrid','on','ygrid','on')
            %Hide the upper triangle of plots
            idx = ~tril(true(nports));
            if ~isempty(h)
                set(h(idx),'Visible',false)
            end
            set(hSubAx(idx),'Visible',false)
            %Set the axes limits
            this.PlotWidgets = struct(...
                'hLines', h, ...
                'hSubAx', hSubAx, ...
                'hHist', P);
            
            %Set the x-y labels to show variable names
            set(hSubAx(1),'YTick',[]);
            Names = [getShortPortName(data,ports); getShortPortName(data,params)];
            if numel(Names) ~= numel(unique(Names))
                Names = [getFullPortName(data,ports); getFullPortName(data,params)];
            end
            if nports == 1
                set(get(hSubAx(1),'xlabel'),'String',strrep(Names{1},'_','\_'));
                set(get(hSubAx(1),'ylabel'),'String',"");
            else
                for ct=1:nports
                    l = [...
                        get(hSubAx(ct,1),'ylabel'); ...
                        get(hSubAx(nports, ct),'xlabel')];
                    set(l,'String',strrep(Names{ct},'_','\_'));
                    set(hSubAx(ct,1:ct),'ylim',ranges(ct,:))
                    set(hSubAx(ct:nports, ct),'xlim',ranges(ct,:))
                end
            end
        end

        function delete(this)

            if ~isempty(this.DataListeners)
                delete(this.DataListeners)
            end
        end
    end

    methods(Hidden = true)
        function wdgts = getWidgets(this)
            wdgts = struct(...
                'PlotWidgets', this.PlotWidgets);
        end
    end
end

% LocalWords:  evt YTick xgrid ygrid
