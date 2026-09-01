classdef ChooseAppModeDialog < controllib.ui.internal.dialog.AbstractDialog
    % Choose Reduced Order Modeler Mode
    %
    % If the reduced order modeler app is launched without input arguments
    % this dialog is opened and prompts the user to either select a
    % simulink model or a workspace variable to use to create a ROM
    %

    % Copyright 2024-2025 The MathWorks, Inc.

    properties (SetAccess = protected, GetAccess={?matlab.unittest.TestCase})
        Widgets struct
    end

    properties(Dependent = true, GetAccess = public, SetAccess = private)
        SelectedMode
        ModelName
        VariableName
    end

    properties(GetAccess = public)
        GetDataFcn function_handle = @(expr) evalin('base',expr);
        FilterWorkspaceVariableFcn function_handle = @(x) romapp.internal.dialogs.ImportDataDialog.isValidImportData(x);
    end

    events(NotifyAccess = protected, ListenAccess = public)
        OKPushed
        CancelPushed
    end

    methods
        function this = ChooseAppModeDialog()
            this = this@controllib.ui.internal.dialog.AbstractDialog();

            this.Name = 'ChooseAppModeDialog';
            this.Title = romapp.internal.resources.getString('lblAppName');
            this.FilterWorkspaceVariableFcn = @(x) lFilterWorkspaceFcn(x);
        end

        function updateUI(this)
            %updateUI
            %

            this.Widgets.pnlModel.Visible = this.Widgets.rbtnModel.Value;
            this.Widgets.pnlVariable.Visible = this.Widgets.rbtnVariable.Value;

            this.Widgets.pnlOCH.OKButton.Enable = this.Widgets.rbtnModel.Value || ...
                ~isequal(this.Widgets.ddVariable.Value, 'select variable');
        end

        function h = getFigure(this)
            %getFigure

            h = this.UIFigure;
        end
    end

    methods
        function mode = get.SelectedMode(this)
            
            mode = '';
            if this.Widgets.rbtnModel.Value
                mode = 'SimulinkModel';
            end
            if this.Widgets.rbtnVariable.Value
                mode = 'WorkspaceVariable';
            end
        end
        function mdl = get.ModelName(this)
            mdl = this.Widgets.edtModel.Value;
        end
        function var = get.VariableName(this)
            var = this.Widgets.ddVariable.Value;
        end
    end

    methods (Access = protected)
        function buildUI(this)
            f = this.UIFigure;
            f.Tag = 'rom-choose-mode-dialog';
            f.Position(3:4) = [370 200];
            mainGridLayout = uigridlayout(f, [5 1]);
            mainGridLayout.RowHeight = {'fit','fit','fit','1x','fit'};
            mainGridLayout.ColumnWidth = {'1x'};
            mainGridLayout.RowSpacing = 0;

            %Choice widgets
            lblChooseMode = uilabel(mainGridLayout);
            lblChooseMode.Layout.Row = 1;
            lblChooseMode.Layout.Column = 1;
            lblChooseMode.Text = romapp.internal.resources.getString('lblChooseMode_ChooseOption');
            pnl = uipanel(mainGridLayout,'BorderType','none');
            pnl.Layout.Row = 2;
            pnl.Layout.Column = 1;
            gl = uigridlayout(pnl);
            gl.RowHeight = {45};
            gl.ColumnWidth = {'1x',5};
            gl.Padding = [10 0 0 10];
            rbgChooseMode = uibuttongroup(gl);
            rbgChooseMode.Layout.Row = 1;
            rbgChooseMode.Layout.Column = [1 2];
            rbgChooseMode.BorderType = 'none';
            rbtnModel = uiradiobutton(rbgChooseMode);
            txt = romapp.internal.resources.getString('lblChooseMode_Option_Model');
            rbtnModel.Text = txt;
            w1 = lGetDisplayWidth(txt);
            rbtnVariable = uiradiobutton(rbgChooseMode);
            txt = romapp.internal.resources.getString('lblChooseMode_Option_Variable');
            rbtnVariable.Text = txt;
            w2 = lGetDisplayWidth(txt);
            %Position radio buttons manually
            rbtnModel.Position(1:3) = [1 25 max(w1,w2)];
            rbtnVariable.Position(1:3) = [1 0 max(w1,w2)];

            %Model name widgets
            pnlModel = uigridlayout(mainGridLayout,[1 2]);
            pnlModel.Layout.Row = 3;
            pnlModel.Layout.Column = 1;
            lblModel = uilabel(pnlModel);
            lblModel.Layout.Row = 1;
            lblModel.Layout.Column = 1;
            lblModel.Text = romapp.internal.resources.getString('lblChooseMode_ModelName');
            edtModel = uieditfield(pnlModel);
            edtModel.Layout.Row = 1;
            edtModel.Layout.Column = 2;
            
            %Variable name widgets
            pnlVariable = uigridlayout(mainGridLayout,[1 2]);
            pnlVariable.Layout.Row = 3;
            pnlVariable.Layout.Column = 1;
            lblVariable = uilabel(pnlVariable);
            lblVariable.Layout.Row = 1;
            lblVariable.Layout.Column = 1;
            lblVariable.Text = romapp.internal.resources.getString('lblChooseMode_Variable');
            ddVariable = matlab.ui.control.internal.model.WorkspaceDropDown('Parent',pnlVariable);
            ddVariable.FilterVariablesFcn = this.FilterWorkspaceVariableFcn;
            ddVariable.Layout.Row = 1;
            ddVariable.Layout.Column = 2;
            ddVariable.Editable = false; %Don't allow random entries
              
            %Ok, cancel, help buttons
            pnl = uipanel(mainGridLayout,'BorderType','none');
            pnl.Layout.Row = 5;
            pnl.Layout.Column = 1;
            pnlOCH = controllib.widget.internal.buttonpanel.ButtonPanel(pnl,...
                ["Help", "OK", "Cancel"]);

            % store in a struct
            this.Widgets = struct(...
                'rbgMode', rbgChooseMode, ...
                'rbtnModel', rbtnModel, ...
                'rbtnVariable', rbtnVariable, ...
                'pnlModel', pnlModel, ...
                'edtModel', edtModel, ...
                'pnlVariable', pnlVariable, ...
                'ddVariable', ddVariable, ...
                'pnlOCH', pnlOCH);
        end

        function connectUI(this)

            weak = romapp.internal.resources.WeakReference(this);

            %Radio button group
            this.Widgets.rbgMode.SelectionChangedFcn = @(hSrc,hData) updateUI(weak.Handle);
            addlistener(this.Widgets.ddVariable,'ValueChanged', @(hSrc,hData) updateUI(weak.Handle));
            
            %Ok, cancel, help buttons
            this.Widgets.pnlOCH.OKButton.ButtonPushedFcn = @(hSrc,hData) cbOK(weak.Handle);
            this.Widgets.pnlOCH.CancelButton.ButtonPushedFcn = @(hSrc,hData) cbCancel(weak.Handle);
            this.Widgets.pnlOCH.HelpButton.ButtonPushedFcn = @(hSrc,hData) cbHelp(weak.Handle);
        end

        function cbOK(this)
            %cbOK Manage OK button events

            notify(this,'OKPushed')
        end

        function cbCancel(this)
            close(this)
            notify(this,'CancelPushed')
        end

        function cbHelp(~)
            helpview('simulink','reduced_order_modeler_dialog')
        end
    end
end

function width = lGetDisplayWidth(txt)
width = (matlab.internal.display.wrappedLength(txt) + 1) ...
    * get(0,'DefaultUicontrolFontSize');
end

function tf = lFilterWorkspaceFcn(x)
if ~isempty(ver('control')) && license('test','Control_Toolbox')
    %Have CST, can reduce LTI objects
    tf =  mrtool.internal.util.isValidSystem({x});
    tf = tf || romapp.internal.dialogs.ImportDataDialog.isValidImportData(x);
else 
    tf = romapp.internal.dialogs.ImportDataDialog.isValidImportData(x);
end
end

% LocalWords:  lbl rbgMode rbtn pnl edt cb