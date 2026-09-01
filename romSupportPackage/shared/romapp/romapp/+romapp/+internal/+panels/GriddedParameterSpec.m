classdef GriddedParameterSpec <  handle
    %

    % GriddedParameterSpec
    %
    % Panel to display/set gridded parameter data

    % Copyright 2023-2025 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        ParameterTable
        Widgets
        
        Spec romapp.internal.data.GriddedParameterSpec
    end

    events(NotifyAccess = protected)
        ValueChanged
    end

    methods
        function this = GriddedParameterSpec(tool,spec,parent,row,col)
            % GriddedParameterSpec

            this.Widgets = struct();

            %Set the tool and spec
            this.Tool = tool;
            this.Spec = spec;
           

            %Build the panel and update the panel
            buildPanel(this,parent,row,col)
            updatePanel(this)

            %Connect the panel to the data source
            connectPanel(this)
        end

        function delete(~)

        end

        function updatePanel(this)

            %Parameter value settings
            spec = this.Spec;
            names = romapp.internal.data.ModelPorts.getDisplayName(spec.Parameters);
            values = spec.Values;
            nParam = numel(names);
            tbldata = cell(nParam,2);
            for ct=1:nParam
                tbldata{ct,1} = char(names(ct));
                tbldata{ct,2} = mat2str(values{ct});
            end
            this.ParameterTable.Data = tbldata;
        end

        function updateSpec(this)

            strValues = this.ParameterTable.Data(:,2);
            %Convert values from string to numeric. Parameter spec
            %requires values in a cell array.
            nParams = numel(strValues);
            values = cell(1,nParams);
            for ct=1:nParams
                strVal = strValues{ct};
                val = eval(strVal);
                values{ct} = val;
            end
            setValues(this.Spec,values)
        end

        function updateDirtySpec(this,spec)
            %spec is dirty spec to pass information to the boundary panel
            strValues = this.ParameterTable.Data(:,2);
            %Convert values from string to numeric. Parameter spec
            %requires values in a cell array.
            nParams = numel(strValues);
            values = cell(1,nParams);
            for ct=1:nParams
                strVal = strValues{ct};
                val = eval(strVal);
                values{ct} = val;
            end
            setValues(spec,values)
        end 

        function setVisibleSpec(this,spec)

            this.Spec = spec;
        end

        function wdgts = getWidgets(this)
            wdgts = struct('ParameterTable', this.ParameterTable);
        end

        function ranges = getParameterRanges(this)
            %getParameterRanges
            %
            %  Returns the min/max ranges of the parameters displayed on
            %  the panel. Note this can be different from the min/max
            %  values stored in the parameter spec object as the displayed
            %  values may not have been applied to the spec object.

            strValues = this.ParameterTable.Data(:,2);
            %Convert values from string to numeric. 
            nParam = numel(strValues);
            ranges = nan(nParam,2);
            for ct=1:nParam
                value = eval(strValues{ct});
                ranges(ct,:) = [min(value), max(value)];
            end
        end
    end

    methods (Access=private)
        function buildPanel(this,parent,row,col)

            
            layout = uigridlayout(parent,[1 1]);
            layout.RowHeight = {'1x'};
            layout.ColumnWidth = {'1x'};
            layout.Padding = [1 1 1 1];
            layout.Layout.Row = row;
            layout.Layout.Column = col;

            %Table for values
            parameterTable = uitable(layout);
            parameterTable.Layout.Row = 1;
            parameterTable.Layout.Column = 1;
            vars = {...
                romapp.internal.resources.getString('lblParameterSpec_Parameter'), ...
                romapp.internal.resources.getString('lblParameterSpec_Value')};
            parameterTable.ColumnName = vars;
            parameterTable.ColumnWidth = {'1x', '1x'};
            parameterTable.ColumnEditable = [false true];
            parameterTable.ColumnFormat = {'char','char'};
            this.ParameterTable = parameterTable;

            %Store the widgets
            this.Widgets = struct(...
                'tbl', parameterTable);
        end

        function connectPanel(this)
            addlistener(this.ParameterTable,'CellEdit',@(hSrc,hData) cbCellEdited(this,hSrc,hData));
        end

        function cbCellEdited(this,hSrc,hData)   
            row = hData.Indices(1);
            col = hData.Indices(2);
            value = hSrc.Data{row,col};
            try 
                val = eval(value);
                if isnumeric(val) && isvector(val) && isreal(val) && (sum(isfinite(val),'all')==numel(val))                
                    notify(this,'ValueChanged')
                else
                    revertCell(this,hSrc,row,col);                    
                end
            catch
                revertCell(this,hSrc,row,col);
            end

            function revertCell(this,hSrc,row,col)
                oldValue = this.Spec.Values{row};
                hSrc.Data{row,col} = mat2str(oldValue);
            end
        end

    end
end

% LocalWords:  btn lbl edt tbl
