classdef ScalarOutputErrorPanel < handle
    %

    %ScalarOutputErrorPanel
    %
    %Class to create a plot to show errors in the
    %ScalarResultPlot. Is housed in a panel in the ScalarResultPlot
    %and the panel visibility toggled depending on result plot format.

    % Copyright 2024-2025 The MathWorks, Inc.

    properties (WeakHandle)
        ResultPlot romapp.internal.plots.ScalarResultPlot
    end
    
    properties(Access = protected)
        ParentContainer
        Table
        Widgets 
    end

    methods
        function obj = ScalarOutputErrorPanel(resultPlot,container)

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

            data = getParameterData(this.ResultPlot,true);
            isError = isResultError(this.ResultPlot);
            allErrors = all(isError);
            nError = sum(isError);
            if allErrors
                if ~isfield(this.Widgets,'lblError')
                    parent = uigridlayout(this.ParentContainer,[2 1]);
                    parent.RowHeight = {'1x','fit'};
                    parent.ColumnWidth = {'1x'};
                    lblError = uilabel('Parent',parent);
                    lblError.Layout.Row = 2;
                    lblError.Layout.Column = 1;
                    lblError.Text = romapp.internal.resources.getString('lblResultPlot_AllError', nError);
                end
            else
                parent = this.ParentContainer;
                lblError = [];
            end

            if isempty(this.Table) || ~isvalid(this.Table)
                %Create a table to display the errors
                colNames = [ ...
                    data(:,1); ...
                    {romapp.internal.resources.getString('lblResultPlot_Error')}];
                tblErrors = uitable('parent', ...
                    parent, ...
                    "ColumnName", colNames, ...
                    "ColumnEditable", false(1,numel(colNames)), ...
                    "RowName", {});
                if allErrors
                    tblErrors.Layout.Row = 1;
                    tblErrors.Layout.Column = 1;
                end
                
                this.Table = tblErrors;
                this.Widgets = struct(...
                    'lblError', lblError);
            end
        end

        function drawPlot(this)

            %Collect data to display in table
            results = getResultDatastore(this.ResultPlot);
            idx = isResultError(this.ResultPlot);
            results = subset(results,idx);
            nErr = sum(idx);
            if nErr > 0
                pData = getParameterData(this.ResultPlot,true);
                pData = [pData{:,2}];
                tData = cell(nErr,size(pData,2)+1);
                %Get the parameter data
                for ct=1:nErr
                    exp = read(results);
                    err = exp.Errors;
                    if strcmp(err.identifier,'MATLAB:MException:MultipleErrors') || ...
                            strcmp(err.identifier,'Simulink:Commands:SimInputPrePostFcnError')
                        err = err.cause{1};
                    end
                    tData(ct,:) = [num2cell(pData(ct,:)), ...
                        {err.message}];
                end
            else
                tData = {};
            end

            %Update the table
            this.Table.Data = tData;
        end
    end

    methods
        function wdgts = getWidgets(this)

            wdgts = struct(...
                'tblError', this.Table, ...
                'lblError', this.Widgets.lblError);
        end
    end
end

% LocalWords:  YTick tiledlayout replacechildren lbl xgrid ygrid tbl
