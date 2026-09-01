classdef ResultScatterplotPanel < handle
    %

    %ResultScatterplotPanel
    %
    %Class to create a scatter plot and parameter table to show in the
    %SimulationResultPlot. Is housed in a panel in the SimulationResultPlot
    %and the panel visibility toggled depending on result plot format.

    % Copyright 2023-2025 The MathWorks, Inc.

    properties (WeakHandle)
        ResultPlot romapp.internal.plots.SimulationResultPlot
    end
    
    properties(Access = protected)
        ParentContainer
        GridLayout %Container when have signals and parameters
        Panel %Container when only have signals
        hAx %Axis to hold the plot matrix
        ParamTable
        PlotParent

        wdgtsPlotMatrix %Holds plotmatrix subaxes
        ErrorText
    end

    methods
        function obj = ResultScatterplotPanel(resultPlot,container)

            obj.ResultPlot = resultPlot;
            obj.ParentContainer = container;
        end

        function updatePlot(this)

            configurePlot(this)
            drawPlot(this)
        end

        function configurePlot(this)
            %Get signal data from the result
            result = getResult(this.ResultPlot);

            %Only need a parameter table if there are parameters and we are
            %showing inputs and outputs
            nP = numel(result.InputParameters);
            havePTable = nP > 0 && ~this.ResultPlot.ShowOutputOnly;
            needAxis = false;
            if havePTable
                delete(this.Panel)
                if isempty(this.GridLayout) || ~isvalid(this.GridLayout)
                    this.GridLayout = uigridlayout(this.ParentContainer,[2,1]);
                    this.GridLayout.ColumnWidth = {'1x'};
                    this.GridLayout.RowHeight = {'4x','1x'};
                    this.GridLayout.Padding = [10 10 10 10];

                    %Create a panel and tiledlayout to host the plotmatrix
                    pParent = uipanel(this.GridLayout);
                    pParent.Layout.Row = 1;
                    pParent.Layout.Column = 1;
                    pParent.BorderType = 'none';
                    pParent.AutoResizeChildren = 'off';
                    tParent = tiledlayout(pParent,1,1);
                    this.PlotParent = tParent;

                    %Create a container to host the parameter table
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
                    needAxis = true;
                end
                errorInGridLayout = true;
            else
                delete(this.GridLayout) %Don't need the gridlayout
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
                end
                errorInGridLayout = false;
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

            %Create a panel to show errors
            if ~isempty(this.ErrorText)
                delete(this.ErrorText)
            end
            if errorInGridLayout
                txtError = uilabel('Parent',this.GridLayout);
                txtError.Layout.Row = 1;
                txtError.Layout.Column = 1;
            else
                txtError = uilabel('Parent',this.Panel);
                txtError.Position(3:4) = [800 60];
            end
            txtError.Interpreter = 'html';
            txtError.VerticalAlignment = 'center';
            txtError.HorizontalAlignment = 'center';
            txtError.WordWrap = 'on';
            txtError.Visible = false;
            this.ErrorText = txtError;
        end

        function drawPlot(this)

            %Collect data for plotmatrix
            result = getResult(this.ResultPlot);
            [nSigIn,nSigOut] = getNumSignals(this.ResultPlot);
            if isempty(result.Errors)
                this.ErrorText.Visible = false;
                plotData = [];
                if nSigIn > 0
                    Names = romapp.internal.data.ModelPorts.getDisplayName([result.InputSignals;result.OutputSignals]);
                else
                    Names = romapp.internal.data.ModelPorts.getDisplayName(result.OutputSignals);
                end
                for ct=1:nSigIn+nSigOut
                    if ct <= nSigIn
                        values = result.InputSignals(ct).Values;
                    else
                        values = result.OutputSignals(ct-nSigIn).Values;
                    end
                    plotData = [plotData, values.Data]; %#ok<AGROW>
                end

                %Create plotmatrix and configure
                [h,hSubAx] = plotmatrix(this.hAx,plotData);
                set(hSubAx,'xgrid','on','ygrid','on')
                this.wdgtsPlotMatrix = struct(...
                    'h', h, 'hSubAx', hSubAx);
                %set(this.ResultPlot.Document.Figure,'NextPlot','add')
                %Hide the upper triangle of plots
                idx = ~tril(true(nSigIn+nSigOut));
                if ~isempty(h)
                    set(h(idx),'Visible',false)
                end
                set(hSubAx(idx),'Visible',false)
                %Set the x-y labels to show variable names
                set(hSubAx(1),'YTick',[]);
                if nSigIn+nSigOut == 1
                    set(get(hSubAx(1),'xlabel'),'String',strrep(Names{1},'_','\_'));
                    set(get(hSubAx(1),'ylabel'),'String',"");
                else
                    for ct=1:nSigIn+nSigOut
                        l = [...
                            get(hSubAx(ct,1),'ylabel'); ...
                            get(hSubAx(nSigIn+nSigOut, ct),'xlabel')];
                        set(l,'String',strrep(Names{ct},'_','\_'));
                    end
                end
            else
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
                'PlotMatrix', this.wdgtsPlotMatrix, ...
                'ParamTable', this.ParamTable, ...
                'ErrorText', this.ErrorText);
        end
    end
end

% LocalWords:  YTick tiledlayout replacechildren lbl xgrid ygrid
