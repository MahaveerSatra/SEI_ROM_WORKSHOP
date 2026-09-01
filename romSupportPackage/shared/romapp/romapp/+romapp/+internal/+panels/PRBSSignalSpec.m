classdef PRBSSignalSpec <  matlab.mixin.SetGet
    %

    % PRBSSIGNALSPEC

    % Copyright 2023 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        SignalTable
        Widgets
        Spec romapp.internal.data.PRBSSignalSpec
    end

    events(NotifyAccess = protected)
        ValueChanged
    end

    methods
        function this = PRBSSignalSpec(tool,spec,parent,row,col)
            % PRBSSIGNALSPEC

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

        function setVisibleSpec(this,spec)
            this.Spec = spec;
        end

        function updatePanel(this)

            data = getToolData(this.Tool);

            this.Widgets.edtPulseWidth.Value = this.Spec.PulseWidth;
            this.Widgets.edtNumPulse.Value = this.Spec.NumPulse;
            this.Widgets.edtOrder.Value = this.Spec.SequenceOrder;
            names = getShortPortName(data,this.Spec.Signals);
            ranges = this.Spec.Ranges;
            nInputs = numel(names);
            tbldata = cell(nInputs,3);
            for ct=1:nInputs
                tbldata{ct,1} = char(names(ct));
                tbldata{ct,2} = ranges(ct,1);
                tbldata{ct,3} = ranges(ct,2);
            end
            this.SignalTable.Data = tbldata;
        end
        
        function inputsAreValid = validateInputs(this)
            inputsAreValid = true;
        end

        function updateSpec(this,varargin)
            pw = this.Widgets.edtPulseWidth.Value;
            np = this.Widgets.edtNumPulse.Value;
            order = this.Widgets.edtOrder.Value;
            ranges = cell2mat(this.SignalTable.Data(:,2:3));
            if nargin == 1
                setValues(this.Spec,pw,np,order,ranges); % update signal spec of this panel
            elseif nargin>1
                setValues(varargin{1},pw,np,order,ranges); % update a standalone signal spec
            end
        end

        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
            wdgts.SignalTable = this.SignalTable;
        end
    end

    methods (Access=private)
        function buildPanel(this,parent,row,col)

            %Create widgets to display/edit the spec
            layoutOptions = uigridlayout(parent, [7 2]);
            layoutOptions.Layout.Row = row;
            layoutOptions.Layout.Column = col;
            layoutOptions.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            layoutOptions.ColumnWidth = {'fit', '1x'};
            layoutOptions.Padding = [5 5 5 0]; %No top padding to keep horizontal-spacing with common widgets
            layoutOptions.Scrollable = 'on';
            labelPulseWidth = uilabel(layoutOptions);
            labelPulseWidth.Text = romapp.internal.resources.getString('lblPRSignalSpec_PulseWidth');
            labelPulseWidth.Layout.Row = 1;
            labelPulseWidth.Layout.Column = 1;
            editFieldPW = uieditfield(layoutOptions,'numeric');
            editFieldPW.Layout.Row = 1;
            editFieldPW.Layout.Column = 2;
            editFieldPW.Value = 2;
            labelNumPulse = uilabel(layoutOptions);
            labelNumPulse.Text = romapp.internal.resources.getString('lblPRSignalSpec_NumPulse');
            labelNumPulse.Layout.Row = 2;
            labelNumPulse.Layout.Column = 1;
            editFieldNumP = uispinner(layoutOptions);
            editFieldNumP.Layout.Row = 2;
            editFieldNumP.Layout.Column = 2;
            editFieldNumP.Limits = [1 inf];
            editFieldNumP.RoundFractionalValues = 'on';
            editFieldNumP.UpperLimitInclusive = 'off';
            editFieldNumP.Value = 2;
            labelOrder = uilabel(layoutOptions);
            labelOrder.Text = romapp.internal.resources.getString('lblPRBSSignalSpec_Order');
            labelOrder.Layout.Row = 3;
            labelOrder.Layout.Column = 1;
            editFieldOrder = uispinner(layoutOptions);
            editFieldOrder.Layout.Row = 3;
            editFieldOrder.Layout.Column = 2;
            editFieldOrder.RoundFractionalValues = true;
            editFieldOrder.Limits = [3 20];
            editFieldOrder.Value = 10;
            labelSignalLimits = uilabel(layoutOptions);
            labelSignalLimits.Text = romapp.internal.resources.getString('lblPRBSSignalSpec_Limits');
            labelSignalLimits.Layout.Row = 4;
            labelSignalLimits.Layout.Column = 1;
            signalTable = uitable(layoutOptions);
            signalTable.Layout.Row = 5;
            signalTable.Layout.Column = [1 2];
            vars = {...
                romapp.internal.resources.getString('lblPRSignalSpec_SignalName'),...
                romapp.internal.resources.getString('lblPRSignalSpec_SignalMin'), ...
                romapp.internal.resources.getString('lblPRSignalSpec_SignalMax')};
            signalTable.ColumnName = vars;
            signalTable.ColumnWidth = {'fit', '1x', '1x'};
            signalTable.ColumnEditable = [false true true];
            signalTable.ColumnFormat = {'char', 'char', 'char'};
            rightAlignStyle = uistyle('HorizontalAlignment', 'right');
            addStyle(signalTable, rightAlignStyle, "column", [2 3]);
            this.SignalTable = signalTable;

            %Store the widgets
            this.Widgets = struct(...
                'edtOrder', editFieldOrder, ...
                'edtPulseWidth', editFieldPW, ...
                'edtNumPulse', editFieldNumP); 
        end

        function connectPanel(this)
            
            addlistener(this.SignalTable,'CellEdit',@(hSrc,hData) cbCellEdited(this,hSrc,hData));

            addlistener(this.Widgets.edtOrder,'ValueChanged', @(hSrc,hData) notify(this,'ValueChanged'));
            addlistener(this.Widgets.edtPulseWidth,'ValueChanged', @(hSrc,hData) cbPulseWidthEdited(this,hSrc,hData));
            addlistener(this.Widgets.edtNumPulse,'ValueChanged', @(hSrc,hData) notify(this,'ValueChanged'));
        end

        function cbCellEdited(this,hSrc,hData)

            row = hData.Indices(1);
            col = hData.Indices(2);
            if col > 1 %Min & max columns
                value = hSrc.Data{row,col};
                if isfinite(value) && isreal(value) && isscalar(value)
                    %Valid value, sort min/max correctly
                    data = sort([hSrc.Data{row,[2 3]}]);
                    hSrc.Data(row,[2 3]) = {data(1), data(2)};
                    notify(this,'ValueChanged')
                else
                    %Revert to last known good value
                    oldValue = this.Spec.Ranges(row,col-1);
                    hSrc.Data{row,col} = oldValue;
                end
            end
        end

        function cbPulseWidthEdited(this,hSrc,hData)

            value = hSrc.Value;
            if isfinite(value) && isreal(value) && isscalar(value) && value > 0
                %Valid Value
                notify(this,'ValueChanged')
            else
                %Revert to previous valid value (May or may not be a dirty state value)
                oldValue = hData.PreviousValue;
                hSrc.Value = oldValue;
            end
        end
    end
end

% LocalWords:  PRBS btn lbl edt
