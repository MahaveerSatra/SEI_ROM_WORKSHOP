classdef (Hidden) SimulationResultsTab < handle
    %

    % Simulation Results Tab of ROM App that goes with the Simulation
    % Results Plot
    
    % Copyright 2023-2025 The MathWorks, Inc.    
    
    properties (Access = protected)
        Widgets
        IsImportedData
    end

    properties (Access = protected, WeakHandle)
        Plot romapp.internal.plots.SimulationResultPlot
    end
    
    properties(GetAccess = public, SetAccess = protected)
        Tab
    end

    methods
        function this = SimulationResultsTab(title,parentTag,isimporteddata)

            this.Tab = matlab.ui.internal.toolstrip.Tab(title);
            this.Tab.Tag = strcat(parentTag,'-tab');
            this.IsImportedData = isimporteddata;
            buildUI(this);
            updateUI(this);
            connectUI(this);
        end

        function setPlot(this,plot)
            this.Plot = plot;
        end

        function plt = getPlot(this)
            plt = this.Plot;
        end

        function update(this)
            updateUI(this)
        end

        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
        end

    end
    methods (Access=protected)
       
        function cbShowExcludedResults(this)
            titleStr = this.Plot.Document.Title;
            simset = this.Plot.getSimset();

            isError = simset.IsError;

            isExcludeTraining = ~simset.IncludeForTraining;
            isExcludeExport = ~simset.IncludeForExportToWorkspace;
            if any(isError)
                errorStr = strjoin(string(find(isError)), ", ");
                isExcludeTraining = isExcludeTraining & ~isError; % If the error caused the exclusion, don't count it towards manual exclusion
            else
                errorStr = romapp.internal.resources.getString('lblNone');
            end
            if any(isExcludeTraining)
                manualStr_train = strjoin(string(find(isExcludeTraining)), ", ");
            else
                manualStr_train = romapp.internal.resources.getString('lblNone');
            end
            if any(isExcludeExport)
                manualStr_export = strjoin(string(find(isExcludeExport)), ", ");
            else
                manualStr_export = romapp.internal.resources.getString('lblNone');
            end
            bodyStr = romapp.internal.resources.getString('msgSimulationResults_ExcludedResultsList', errorStr, manualStr_train, manualStr_export);
            uialert(this.Plot.Document.Figure, bodyStr, titleStr, 'Icon', 'info', 'Modal', false);
        end

        function cbIncludeForTraining(this, es)
            this.Plot.setIncludeForTraining(es.Selected);
        end

        function cbIncludeForExportToWorkspace(this, es)
            this.Plot.setIncludeForExportToWorkspace(es.Selected);
        end

        function cbExportButton(this)
            result = this.Plot.getResult();
            name = this.Plot.getSimsetName() + "_Result" + num2str(this.Plot.getActiveResult());
            name = matlab.lang.makeValidName(name);
            name = matlab.lang.makeUniqueStrings(name,evalin('base','who'));
            assignin('base',name,result)

            fig = this.Plot.Document.Figure;
            if this.Plot.Document.Opened
                uialert(fig,...
                    romapp.internal.resources.getString('msgSimulationResults_ExportedToWorkspace', name), ...
                    romapp.internal.resources.getString('lblExportResults'), ...
                    'Icon', 'success', 'Modal', false);
            end
        end

        function buildUI(this)
                        
            % Simulation results or Imported data
            if this.IsImportedData
                secLabel = romapp.internal.resources.getString('lblImportedData');
                resultLabel = romapp.internal.resources.getString('lblImportedData');
            else
                secLabel = romapp.internal.resources.getString('lblSimulationResults');
                resultLabel = romapp.internal.resources.getString('lblSimulationResults_Result');
            end
            secSimulationResult = matlab.ui.internal.toolstrip.Section(secLabel);

            column = matlab.ui.internal.toolstrip.Column('HorizontalAlignment', 'center');
            add(secSimulationResult, column);
            panel = matlab.ui.internal.toolstrip.Panel();
            lblResult  = matlab.ui.internal.toolstrip.Label(resultLabel);
            panelColumn1 = matlab.ui.internal.toolstrip.Column();
            panelColumn1.add(lblResult);
            panel.add(panelColumn1);
            spnResult = matlab.ui.internal.toolstrip.Spinner;
            panelColumn2 = matlab.ui.internal.toolstrip.Column();
            panelColumn2.add(spnResult);
            panel.add(panelColumn2);
            lblOfN  = matlab.ui.internal.toolstrip.Label(...
                romapp.internal.resources.getString('lblSimulationResults_ofN', "0"));
            panelColumn3 = matlab.ui.internal.toolstrip.Column();
            panelColumn3.add(lblOfN);
            panel.add(panelColumn3);
            column.add(panel);

            btnShowExcludedResults = matlab.ui.internal.toolstrip.Button(romapp.internal.resources.getString('lblSimulationResults_ShowExcludedResults'), 'simpleList');
            column.add(btnShowExcludedResults);

            % Plot options
            secPlotOptions = matlab.ui.internal.toolstrip.Section(romapp.internal.resources.getString('lblSimulationResults_Options'));
            
            column = matlab.ui.internal.toolstrip.Column();
            add(secPlotOptions, column);
            chkOutputOnly  = matlab.ui.internal.toolstrip.CheckBox(...
                romapp.internal.resources.getString('lblSimulationResults_OutputOnly'));
            column.add(chkOutputOnly);
            chkScatterPlot  = matlab.ui.internal.toolstrip.CheckBox(...
                romapp.internal.resources.getString('lblSimulationResults_ScatterPlot'));
            column.add(chkScatterPlot);

            % Export
            secExport = matlab.ui.internal.toolstrip.Section(romapp.internal.resources.getString('lblSimulationResults_ExportResult'));
            
            column = matlab.ui.internal.toolstrip.Column();
            add(secExport, column);
            lblInclFor = matlab.ui.internal.toolstrip.Label(...
                romapp.internal.resources.getString('lblSimulationResults_IncludeResultN', 1));
            column.add(lblInclFor);
            chkInclForTraining  = matlab.ui.internal.toolstrip.CheckBox(...
                romapp.internal.resources.getString('lblSimulationResults_ForTraining'), true);
            column.add(chkInclForTraining);
            chkInclForExport  = matlab.ui.internal.toolstrip.CheckBox(...
                romapp.internal.resources.getString('lblSimulationResults_WhenExporting'), true);
            column.add(chkInclForExport);

            column = matlab.ui.internal.toolstrip.Column();
            add(secExport, column);
            str = romapp.internal.resources.getString('lblExportToWorkspace');
            btnExport = matlab.ui.internal.toolstrip.Button(str, 'export_data');
            column.add(btnExport);
            
            % Store widgets
            this.Widgets =  struct(...
                'spnResult',spnResult, ...
                'lblOfN', lblOfN, ...
                'btnShowExcludedResults', btnShowExcludedResults, ...
                'chkOutputOnly', chkOutputOnly, ...
                'chkScatterPlot', chkScatterPlot, ...
                'lblInclFor', lblInclFor, ...
                'chkInclForTraining', chkInclForTraining, ...
                'chkInclForExport', chkInclForExport, ...
                'btnExport', btnExport);                                                                                                    
            
            % ADD SECTIONS
            add(this.Tab, secSimulationResult);
            add(this.Tab, secPlotOptions);
            add(this.Tab, secExport);
        end

        function updateUI(this)

            if isempty(this.Plot)
                idx = 1; 
                maxIdx = 1;
                vOutputOnly = false; 
                vScatterPlot = false;
            else
                [idx,maxIdx] = getActiveResult(this.Plot);
                vOutputOnly = getShowOutputOnly(this.Plot);
                switch getPlotType(this.Plot)
                    case 'scatterplot'
                        vScatterPlot = true;
                    otherwise
                        vScatterPlot = false;
                end
            end

            %Update the spinner value and limits
            this.Widgets.spnResult.Limits = [1 maxIdx];
            this.Widgets.spnResult.Value = idx;

            %Update the spinner 'of N' label
            this.Widgets.lblOfN.Text = romapp.internal.resources.getString('lblSimulationResults_ofN', num2str(maxIdx));

            %Update show outputs only
            this.Widgets.chkOutputOnly.Value = vOutputOnly; 

            %Update plot type
            this.Widgets.chkScatterPlot.Value = vScatterPlot;

            % Update export options checkboxes
            if ~isempty(this.Plot)
                updateExportOptions(this);
            end
        end

        function connectUI(this)
            weak = romapp.internal.resources.WeakReference(this);
            this.Widgets.spnResult.ValueChangedFcn = @(hSrc,hData) cbResult(weak.Handle);
            this.Widgets.btnShowExcludedResults.ButtonPushedFcn = @(hSrc,hData)cbShowExcludedResults(weak.Handle);
            this.Widgets.chkOutputOnly.ValueChangedFcn = @(hSrc,hData) cbOutputOnly(weak.Handle);
            this.Widgets.chkScatterPlot.ValueChangedFcn = @(hSrc,hData) cbScatterPlot(weak.Handle);
            this.Widgets.chkInclForTraining.ValueChangedFcn = @(hSrc,hData)cbIncludeForTraining(weak.Handle,hSrc);
            this.Widgets.chkInclForExport.ValueChangedFcn = @(hSrc,hData)cbIncludeForExportToWorkspace(weak.Handle,hSrc);
            this.Widgets.btnExport.ButtonPushedFcn = @(hSrc,hData)cbExportButton(weak.Handle);
        end

        function cbResult(this)
            % Update the active result
            idx = this.Widgets.spnResult.Value;
            setActiveResult(this.Plot,idx)

            % Update the checkboxes for export options based on the new
            % active result
            updateExportOptions(this);
        end

        function updateExportOptions(this)
            simset = this.Plot.getSimset();
            idx = this.Plot.getActiveResult();
            this.Widgets.lblInclFor.Text = romapp.internal.resources.getString('lblSimulationResults_IncludeResultN', idx);
            noError = ~simset.IsError;
            if ~isempty(noError)
                this.Widgets.chkInclForTraining.Enabled = noError(idx);
                if ~isempty(simset.IncludeForTraining)
                    this.Widgets.chkInclForTraining.Value = noError(idx) && simset.IncludeForTraining(idx);
                    this.Widgets.chkInclForExport.Value = simset.IncludeForExportToWorkspace(idx);
                end
            end
        end

        function cbOutputOnly(this)

            setShowOutputOnly(this.Plot,this.Widgets.chkOutputOnly.Value)
        end

        function cbScatterPlot(this)

            if this.Widgets.chkScatterPlot.Value
                setPlotType(this.Plot,'scatterplot')
            else
                setPlotType(this.Plot,'timetrace')
            end
        end
    end
end

% LocalWords:  Editfield lbl spn chk timetrace btn
