classdef RunOptionsDialog < controllib.ui.internal.dialog.AbstractDialog
    % Specify Simulation Options
    %

    % Copyright 2023-2026 The MathWorks, Inc.

    properties (SetAccess = private,Hidden, ...
            GetAccess=?matlab.unittest.TestCase)
        Widgets struct
        Data
    end

    methods
        function this = RunOptionsDialog(data)
            this = this@controllib.ui.internal.dialog.AbstractDialog();
            this.Data = data;

            this.Name = 'RunOptionsDialog';
            this.Title = romapp.internal.resources.getString('lblRunOptions');
        end

        function updateUI(this)
            %updateUI
            %

            %Get data to display
            data = this.Data.SimulationOptions;

            %Set Widget values
            switch data.SignalLogging
                case 'romonly'
                    this.Widgets.rbtnROMOnly.Value = true;
                case 'all'
                    this.Widgets.rbtnAll.Value = true;
            end
            this.Widgets.ckbLogStates.Value = data.LogStates;
            this.Widgets.ckbLogToFile.Value = data.LogToFile;
            this.Widgets.edtFileLocation.Value = data.FileLocation;
            this.Widgets.ckbUseParallel.Value = strcmp(data.UseParallel,"on");
            this.Widgets.ckbTransferBaseWorkspaceVariables.Value = strcmp(data.TransferBaseWorkspaceVariables,'on');
            this.Widgets.ckbTransferBaseWorkspaceVariables.Enable = strcmp(data.UseParallel,"on");
            this.Widgets.ckbClearLogPostSim.Value = data.ClearLogPostSim;

            configUI(this)
        end
    end


    methods (Access = protected)
        function buildUI(this)
            f = this.UIFigure;
            f.Tag = 'rom-run-options-dialog';
            mainGridLayout = uigridlayout(f, [10 4]);
            mainGridLayout.RowHeight = {'fit','fit','fit','fit','fit','fit','fit','fit','fit','fit','1x','fit'};
            mainGridLayout.ColumnWidth = {'fit','fit','1x','fit'};

            % Logging widgets
            lblLogging = uilabel(mainGridLayout);
            lblLogging.Layout.Row = 1;
            lblLogging.Layout.Column = [1 4];
            lblLogging.Text = romapp.internal.resources.getString('lblRunOptions_Logging');
            lblLogging.FontWeight = 'bold';
            ckbLogStates = uicheckbox(mainGridLayout);
            ckbLogStates.Layout.Row = 2;
            ckbLogStates.Layout.Column = [1 3];
            ckbLogStates.Text = romapp.internal.resources.getString('lblRunOptions_LogStates');
                        
            pnl = uipanel(mainGridLayout,'BorderType','none');
            pnl.Layout.Row = 3;
            pnl.Layout.Column = [1 4];
            gl = uigridlayout(pnl);
            gl.RowHeight = {45};
            gl.ColumnWidth = {'1x',5};
            gl.Padding = [0 0 0 0];
            rbgLogAll = uibuttongroup(gl);
            rbgLogAll.Layout.Row = 1;
            rbgLogAll.Layout.Column = [1 2];
            rbgLogAll.BorderType = 'none';
            rbtnAll = uiradiobutton(rbgLogAll);
            txt = romapp.internal.resources.getString('lblRunOptions_LogAll');
            w1 = lGetDisplayWidth(txt);
            rbtnAll.Text = txt;
            rbtnAll.Tag = 'rbtnAll';
            rbtnROMOnly = uiradiobutton(rbgLogAll);
            txt = romapp.internal.resources.getString('lblRunOptions_LogROMOnly');
            w2 = lGetDisplayWidth(txt);
            rbtnROMOnly.Text = txt;
            rbtnROMOnly.Tag = 'rbtnROMOnly';
            %Position radio buttons manually
            rbtnAll.Position(1:3) = [1 25 max(w1,w2)];
            rbtnROMOnly.Position(1:3) = [1 0 max(w1,w2)];
            ckbClearLogPostSim = uicheckbox(mainGridLayout);
            ckbClearLogPostSim.Layout.Row = 5;
            ckbClearLogPostSim.Layout.Column = [1 3];
            ckbClearLogPostSim.Text = romapp.internal.resources.getString('lblRunOptions_ClearLogPostSim');
            
            ckbLogToFile = uicheckbox(mainGridLayout);
            ckbLogToFile.Layout.Row = 6;
            ckbLogToFile.Layout.Column = [1 3];
            ckbLogToFile.Text = romapp.internal.resources.getString('lblRunOptions_LogToFile');
            lblFileLocation = uilabel(mainGridLayout);
            lblFileLocation.Layout.Row = 7;
            lblFileLocation.Layout.Column = 2;
            lblFileLocation.Text = romapp.internal.resources.getString('lblRunOptions_LogFileLocation');
            edtFileLocation = uieditfield(mainGridLayout);
            edtFileLocation.Layout.Row = 7;
            edtFileLocation.Layout.Column = 3;
            btnFileBrowse = uibutton(mainGridLayout);
            btnFileBrowse.Layout.Row = 7;
            btnFileBrowse.Layout.Column = 4;
            btnFileBrowse.Text = romapp.internal.resources.getString('lblRunOptions_BrowseFileLocation');
            btnFileBrowse.Icon = matlab.ui.internal.toolstrip.Icon.OPEN_16.getIconFile;

            %Simulation execution widgets
            lblExecution = uilabel(mainGridLayout);
            lblExecution.Layout.Row = 8;
            lblExecution.Layout.Column = [1 4];
            lblExecution.Text = romapp.internal.resources.getString('lblRunOptions_SimulationExecution');
            lblExecution.FontWeight = 'bold';
            ckbUseParallel = uicheckbox(mainGridLayout);
            ckbUseParallel.Layout.Row = 9;
            ckbUseParallel.Layout.Column = [1 4];
            ckbUseParallel.Text = romapp.internal.resources.getString('lblRunOptions_UseParallel');
            ckbTransferBaseWorkspace = uicheckbox(mainGridLayout);
            ckbTransferBaseWorkspace.Layout.Row = 10;
            ckbTransferBaseWorkspace.Layout.Column = [1 4];
            ckbTransferBaseWorkspace.Text = romapp.internal.resources.getString('lblRunOptions_TransferBaseWorkspaceVariables');

            %Ok, cancel, help buttons
            pnl = uipanel(mainGridLayout,'BorderType','none');
            pnl.Layout.Row = 12;
            pnl.Layout.Column = [1 4];
            pnlOCH = controllib.widget.internal.buttonpanel.ButtonPanel(pnl, ["Help" "OK" "Cancel"]);

            % store in a struct
            this.Widgets = struct(...
                'rbtnAll', rbtnAll, ...
                'rbtnROMOnly', rbtnROMOnly, ...
                'ckbLogStates', ckbLogStates, ...
                'ckbLogToFile', ckbLogToFile, ...
                'ckbClearLogPostSim', ckbClearLogPostSim, ...
                'edtFileLocation', edtFileLocation, ...
                'btnFileBrowse', btnFileBrowse, ...
                'ckbUseParallel', ckbUseParallel, ...
                'ckbTransferBaseWorkspaceVariables', ckbTransferBaseWorkspace, ...
                'pnlOCH', pnlOCH);

        end
        function connectUI(this)

            %Ok, cancel, help buttons
            this.Widgets.pnlOCH.OKButton.ButtonPushedFcn = @(hSrc,hData) cbOK(this);
            this.Widgets.pnlOCH.CancelButton.ButtonPushedFcn = @(hSrc,hData) cbCancel(this);
            this.Widgets.pnlOCH.HelpButton.ButtonPushedFcn = @(hSrc,hData) cbHelp(this);

            %Log to file checkbox
            this.Widgets.ckbLogToFile.ValueChangedFcn = @(hSrc,hData)cbLogToFile(this);

            %Browse button
            this.Widgets.btnFileBrowse.ButtonPushedFcn = @(hSrc,hData) cbBrowse(this);

            %Use parallel button
            this.Widgets.ckbUseParallel.ValueChangedFcn = @(hSrc,hData) configUI(this);
        end
        function configUI(this)
            %Enable disable widgets based graphical interactions
            this.Widgets.edtFileLocation.Enable = this.Widgets.ckbLogToFile.Value;
            this.Widgets.btnFileBrowse.Enable = this.Widgets.ckbLogToFile.Value;
            this.Widgets.ckbTransferBaseWorkspaceVariables.Enable = this.Widgets.ckbUseParallel.Value;
        end

        function cbLogToFile(this)

            configUI(this)
        end

        function cbOK(this)

            %Update app data
            updateData(this)

            %Close the dialog
            cbCancel(this)
        end

        function cbCancel(this)
            close(this)
        end

        function cbHelp(~)
            helpview('simulink','rom_run_options')
        end

        function cbBrowse(this)
            %cbBrowse Handle Browse button events

            dirname = uigetdir( ...
                this.Widgets.edtFileLocation.Value, ...
                romapp.internal.resources.getString('lblRunOptions_BrowseInstruction'));
            if ~isequal(dirname,0)
                if exist(dirname,'dir')
                    this.Widgets.edtFileLocation.Value = dirname;
                else
                    romapp.internal.resources.error('errRunOptions_BrowseLocation')
                end
            end
        end

        function updateData(this)
            %updateData push view data to backend data object
            %

            if this.Widgets.rbtnAll.Value
                this.Data.SimulationOptions.SignalLogging = 'all';
            elseif this.Widgets.rbtnROMOnly.Value
                this.Data.SimulationOptions.SignalLogging = 'romonly';
            end

            this.Data.SimulationOptions.LogStates = this.Widgets.ckbLogStates.Value;
            this.Data.SimulationOptions.LogToFile = this.Widgets.ckbLogToFile.Value;
            this.Data.SimulationOptions.ClearLogPostSim = this.Widgets.ckbClearLogPostSim.Value;
            this.Data.SimulationOptions.FileLocation = this.Widgets.edtFileLocation.Value;
            if this.Widgets.ckbUseParallel.Value
                this.Data.SimulationOptions.UseParallel = "on";
            else
                this.Data.SimulationOptions.UseParallel = "off";
            end
            if  this.Widgets.ckbTransferBaseWorkspaceVariables.Value
                this.Data.SimulationOptions.TransferBaseWorkspaceVariables = 'on';
            else
                this.Data.SimulationOptions.TransferBaseWorkspaceVariables = 'off';
            end
        end
    end
end

function width = lGetDisplayWidth(txt)
width = (matlab.internal.display.wrappedLength(txt) + 1) ...
    * get(0,'DefaultUicontrolFontSize');
end

% LocalWords:  lbl romonly rbtn ckb edt btn pnl cb
