classdef (Hidden) ScalarResultsTab < handle
    %

    % Scalar Results Tab of ROM App that goes with the Scalar
    % Results Plot
    
    % Copyright 2024-2025 The MathWorks, Inc.    
    
    properties (Access=protected)
        Widgets
    end

    properties (Access=protected, WeakHandle)
        Plot romapp.internal.plots.ScalarResultPlot   
    end
    
    properties(GetAccess = public, SetAccess = protected)
        Tab
    end

    methods
        function this = ScalarResultsTab(title,parentTag)
            
            this.Tab = matlab.ui.internal.toolstrip.Tab(title);
            this.Tab.Tag = strcat(parentTag,'-tab');
            buildUI(this);
        end

        function setPlot(this,plot)
            this.Plot = plot;
        end

        function plt = getPlot(this)
            plt = this.Plot;
        end

        function update(this)
            updateUI(this);
            connectUI(this);
        end

        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
        end

    end
    methods (Access=protected)
       
        function buildUI(this)
                        
            % Plot options
            secPlotOptions = matlab.ui.internal.toolstrip.Section(romapp.internal.resources.getString('lblSimulationResults_Options'));
            
            column = matlab.ui.internal.toolstrip.Column();
            add(secPlotOptions, column);
            rGroup = matlab.ui.internal.toolstrip.ButtonGroup;
            rbtnScatterPlot  = matlab.ui.internal.toolstrip.RadioButton(rGroup,...
                romapp.internal.resources.getString('lblSimulationResults_ScatterPlot'));
            column.add(rbtnScatterPlot);
            rbtnDistribution  = matlab.ui.internal.toolstrip.RadioButton(rGroup,...
                romapp.internal.resources.getString('lblSimulationResults_Distribution'));
            column.add(rbtnDistribution);
            rbtnErrors = matlab.ui.internal.toolstrip.RadioButton(rGroup,...
                romapp.internal.resources.getString('lblSimulationResults_Errors'));
            column.add(rbtnErrors);

            % Store widgets
            this.Widgets =  struct(...
                'rGroup', rGroup, ...
                'rbtnScatterPlot', rbtnScatterPlot, ...
                'rbtnDistribution', rbtnDistribution, ...
                'rbtnErrors', rbtnErrors);                                                                                                    
            
            % ADD SECTIONS
            add(this.Tab, secPlotOptions);
        end

        function updateUI(this)

            idxError = isResultError(this.Plot);
            if all(idxError)
                this.Widgets.rbtnErrors.Value = true;
                this.Widgets.rbtnScatterPlot.Enabled = false;
                this.Widgets.rbtnDistribution.Enabled = false;
            else
                this.Widgets.rbtnScatterPlot.Enabled = true;
                this.Widgets.rbtnDistribution.Enabled = true;
                this.Widgets.rbtnErrors.Enabled = any(idxError);
                switch getPlotType(this.Plot)
                    case 'scatterplot'
                        this.Widgets.rbtnScatterPlot.Value = true;
                    case 'distribution'
                        this.Widgets.rbtnDistribution.Value = true;
                    case 'errors'
                        this.Widgets.rbtnErrors.Value = true;
                    otherwise
                        this.Widgets.rbtnScatterPlot.Value = true;
                end
            end
        end

        function connectUI(this)
            weak = romapp.internal.resources.WeakReference(this);
            addlistener(this.Widgets.rbtnScatterPlot,'ValueChanged',@(hSrc,hData) cbRButtonChanged(weak.Handle,hSrc));
            addlistener(this.Widgets.rbtnDistribution,'ValueChanged',@(hSrc,hData) cbRButtonChanged(weak.Handle,hSrc));
            addlistener(this.Widgets.rbtnErrors,'ValueChanged',@(hSrc,hData) cbRButtonChanged(weak.Handle,hSrc));
        end

        function cbRButtonChanged(this,hSrc)
            %cbRButtonChanged
            %
            %  Manage radio button selection changes

            if hSrc.Value
                if isequal(hSrc,this.Widgets.rbtnScatterPlot)
                    setPlotType(this.Plot,'scatterplot')
                elseif isequal(hSrc,this.Widgets.rbtnDistribution)
                    setPlotType(this.Plot,'distribution')
                else
                     setPlotType(this.Plot,'errors')
                end
            end
           
            
        end
    end
end

% LocalWords:  Editfield lbl spn chk timetrace rbtn cbRButtonChanged
