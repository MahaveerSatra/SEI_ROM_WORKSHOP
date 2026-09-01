classdef ResultTimetracePanel < handle
    %

    %ResultTimetracePanel
    %
    %Class to create a timetrace plot and parameter table to show in the
    %SimulationResultPlot. Is housed in a panel in the SimulationResultPlot
    %and the panel visibility toggled depending on result plot format.

    % Copyright 2023-2025 The MathWorks, Inc.

    properties (WeakHandle)
        ResultPlot romapp.internal.plots.SimulationResultPlot
    end
    
    properties(Access = protected)
        ParentContainer
        GridLayout %Container for signals and parameter table
        Panel   %Parent for the tiled layout when only have signals
        PlotParent %Switches between panel (signal only) and panel in gridlayout (signal and parameters)
        Layout  %Tiledlayout for signals
        ParamTable
        hLine %Signal lines
        ErrorText
    end

    methods
        function obj = ResultTimetracePanel(resultPlot,container)

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
            result = getResult(this.ResultPlot);
            [nSigIn,nSigOut] = getNumSignals(this.ResultPlot);

            %Only need a parameter table if there are parameters and we are
            %showing inputs and outputs
            nP = numel(result.InputParameters);
            havePTable = nP > 0 && ~this.ResultPlot.ShowOutputOnly;
            
            if havePTable
                delete(this.Panel) %don't need the panel
                if isempty(this.GridLayout) || ~isvalid(this.GridLayout)
                    this.GridLayout = uigridlayout(this.ParentContainer,[2,1]);
                    this.GridLayout.Layout.Row = 1;
                    this.GridLayout.Layout.Column = 1;
                    this.GridLayout.ColumnWidth = {'1x'};
                    this.GridLayout.RowHeight = {'4x','1x'};
                    this.GridLayout.Padding = [10 10 10 10];
                    pParent = uipanel(this.GridLayout);
                    pParent.Layout.Row = 1;
                    pParent.Layout.Column = 1;
                    pParent.BorderType = 'none';
                    this.PlotParent = pParent;
                    tPanel = uigridlayout(this.GridLayout,[1 1]);
                    tPanel.Layout.Row = 2;
                    tPanel.Layout.Column = 1;
                    tPanel.Padding = [25 0 10 0]; %To left/right indent table
                    colNames = {...
                        romapp.internal.resources.getString('lblResultPlot_Parameter'), ...
                        romapp.internal.resources.getString('lblResultPlot_Value')};
                    pTable = uitable(tPanel, ...
                        "ColumnName", colNames, ...
                        "ColumnEditable", [false, false], ...
                        "RowName",{}, ...
                        "ColumnWidth",{'9x','1x'});
                    pTable.Layout.Row = 1;
                    pTable.Layout.Column = 1;
                    this.ParamTable = pTable;
                end
                errorInGridLayout = true;
            else
                delete(this.GridLayout) %Don't need the gridlayout
                if isempty(this.Panel) || ~isvalid(this.Panel)
                    pParent = uipanel(this.ParentContainer);
                    pParent.Layout.Row = 1;
                    pParent.Layout.Column = 1;
                    pParent.BorderType = 'none';
                    this.Panel = pParent;
                end
                this.PlotParent = this.Panel;
                errorInGridLayout = false;
            end
            
            %Create a subplot for each signal
            if (~isempty(this.Layout) && isvalid(this.Layout)) && ~isequal(this.Layout.GridSize,[nSigIn+nSigOut,1])
                %Number of subplots changed
                delete(this.Layout)
            end
            if isempty(this.Layout) || ~isvalid(this.Layout)
                this.Layout = tiledlayout(this.PlotParent,nSigIn+nSigOut,1);
                if havePTable > 0
                    this.Layout.Padding = 'tight';
                end
                lines = [];
                if nSigIn > 0
                    names = romapp.internal.data.ModelPorts.getDisplayName([result.InputSignals;result.OutputSignals]);
                else
                    names = romapp.internal.data.ModelPorts.getDisplayName(result.OutputSignals);
                end
                for ct=1:nSigIn+nSigOut
                    ax = axes('Parent',this.Layout, ...
                        'xgrid','on','ygrid','on');
                    ax.Layout.Tile = ct;
                    ax.Layout.TileSpan = [1 1];
                    if ct <= nSigIn
                        name = romapp.internal.resources.getString('lblSimulationResults_Input')...
                            + " " + names(ct);
                    else
                        name = romapp.internal.resources.getString('lblSimulationResults_Output')...
                            + " " + names(ct);
                    end
                    l = line('parent',ax, 'color', 'blue');
                    lines = [lines;l]; %#ok<AGROW>
                    ax.Title.String = strrep(name,'_','\_');
                    ax.XLabel.String = romapp.internal.resources.getString('lblSimulationResults_TimeAxis');
                end
                this.hLine = lines;
            end

            %Create a panel to show errors
            if ~isempty(this.ErrorText)
                delete(this.ErrorText)
            end
            if errorInGridLayout
                txtError = uilabel('Parent',this.GridLayout);
            else
                txtError = uilabel('Parent',this.ParentContainer);
            end
            txtError.Layout.Row = 1;
            txtError.Layout.Column = 1;
            txtError.Interpreter = 'html';
            txtError.VerticalAlignment = 'center';
            txtError.HorizontalAlignment = 'center';
            txtError.WordWrap = 'on';
            txtError.Visible = false;
            this.ErrorText = txtError;
        end

        function drawPlot(this)

            %Set the line data for each signal
            result = getResult(this.ResultPlot);
            [nSigIn,nSigOut] = getNumSignals(this.ResultPlot);
            if isempty(result.Errors)
                this.ErrorText.Visible = false;
                for ct=1:nSigIn+nSigOut
                    if ct <= nSigIn
                        values = result.InputSignals(ct).Values;
                    else
                        values = result.OutputSignals(ct-nSigIn).Values;
                    end
                    set(this.hLine(ct), ...
                        'xdata',seconds(values.Time), 'ydata', values.Data);
                end
            else
                for ct=1:nSigIn+nSigOut
                    set(this.hLine(ct), ...
                        'xdata',[], 'ydata', []);
                end
                txt = "<table style=""background-color:#FFFFFF;border:2pt solid grey;font-size:16pt;"">";
                txt = txt + "<tr>" + "<td align=""left"">";
                txt = txt+"<font color = ""red"">"+ ...
                    romapp.internal.resources.getString("lblResultPlot_SimulationError") + "</font>";
                txt = txt + "</BR>";
                err = result.Errors;
                if strcmp(err.identifier,'MATLAB:MException:MultipleErrors')
                    err = err.cause{1};
                end
                txt = txt+err.message;
                txt = txt + "</td>" + "</tr>";
                txt = txt + "</table>";
                this.ErrorText.Text = txt;
                this.ErrorText.Visible = true;
            end

            nP = numel(result.InputParameters);
            havePTable = nP > 0 && ~this.ResultPlot.ShowOutputOnly;
            if havePTable
                this.ParamTable.Data = getParameterData(this.ResultPlot);
            end
        end
    end

    
    methods
        function wdgts = getWidgets(this)

            wdgts = struct(...
                'AxisLayout', this.Layout, ...
                'ParamTable', this.ParamTable, ...
                'SignalLines', this.hLine, ...
                'ErrorText', this.ErrorText);
        end
    end
end

% LocalWords:  timetrace Tiledlayout xdata ydata lbl xgrid ygrid
