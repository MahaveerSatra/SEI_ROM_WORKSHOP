classdef NewPostSimFcnDialog < controllib.ui.internal.dialog.AbstractDialog
    % Select results to export to MATLAB workspace
    %

    % Copyright 2023-2025 The MathWorks, Inc.

    properties (SetAccess = private,Hidden, ...
            GetAccess=?matlab.unittest.TestCase)
        Widgets struct
    end

    methods
        function this = NewPostSimFcnDialog()
            this = this@controllib.ui.internal.dialog.AbstractDialog();
                        
            this.Name = 'NewPostSimFcnDialog';
            this.Title = romapp.internal.resources.getString('lblPostSimFcnDlg_Title');
        end

        function updateUI(this)
            %updateUI
            %
           
        end
    end

    methods (Access = protected)
        function buildUI(this)
            f = this.UIFigure;
            f.Tag = 'rom-new-postsimfcn-dialog';
            mainGridLayout = uigridlayout(f, [3 1]);
            mainGridLayout.RowHeight = {'fit','1x','fit'};
            mainGridLayout.ColumnWidth = {'1x'};

            %Label
            lblTemplate = uilabel(mainGridLayout);
            lblTemplate.Layout.Row = 1;
            lblTemplate.Layout.Column = 1;
            lblTemplate.Text = romapp.internal.resources.getString('lblPostSimFcnDlg_Label');

            %Template list
            lstTemplate = uilistbox(mainGridLayout);
            lstTemplate.Layout.Row = 2;
            lstTemplate.Layout.Column = 1;
            lstTemplate.Items = [...
                string(romapp.internal.resources.getString('lblPostSimFcnDlg_L2')), ...
                string(romapp.internal.resources.getString('lblPostSimFcnDlg_Linf')), ...
                string(romapp.internal.resources.getString('lblPostSimFcnDlg_Min')), ...
                string(romapp.internal.resources.getString('lblPostSimFcnDlg_Max')), ...
                string(romapp.internal.resources.getString('lblPostSimFcnDlg_Mean')), ...
                string(romapp.internal.resources.getString('lblPostSimFcnDlg_STD')), ...
                string(romapp.internal.resources.getString('lblPostSimFcnDlg_FinalValue')), ...
                string(romapp.internal.resources.getString('lblPostSimFcnDlg_Custom'))];
            lstTemplate.ItemsData = {...
                'romapp.internal.data.PostSimFcn.L2', ...
                'romapp.internal.data.PostSimFcn.Linf',...
                'romapp.internal.data.PostSimFcn.min',...
                'romapp.internal.data.PostSimFcn.max',....
                'romapp.internal.data.PostSimFcn.mean',...
                'romapp.internal.data.PostSimFcn.std',...
                'romapp.internal.data.PostSimFcn.FinalValue',...
                'romapp.internal.data.PostSimFcn.CustomTransform'};
            lstTemplate.Multiselect = false;
            
            %Ok, cancel, help buttons
            pnl = uipanel(mainGridLayout,'BorderType','none');
            pnl.Layout.Row = 3;
            pnl.Layout.Column = 1;
            pnlOCH = controllib.widget.internal.buttonpanel.ButtonPanel(pnl, ["Help" "OK" "Cancel"]);

            % store in a struct
            this.Widgets = struct(...
                'lstTemplate', lstTemplate, ...
                'pnlOCH', pnlOCH, ...
                'lblTemplate', lblTemplate);

        end
        function connectUI(this)

            %Ok, cancel, help buttons
            this.Widgets.pnlOCH.OKButton.ButtonPushedFcn = @(hSrc,hData) cbOK(this);
            this.Widgets.pnlOCH.CancelButton.ButtonPushedFcn = @(hSrc,hData) cbCancel(this);
            this.Widgets.pnlOCH.HelpButton.ButtonPushedFcn = @(hSrc,hData) cbHelp(this);
        end
        
        function cbOK(this)

            item = this.Widgets.lstTemplate.ValueIndex;
            fname = this.Widgets.lstTemplate.ItemsData{item};
            generateCode(this,fname);
                        
            %Close the dialog
            cbCancel(this)
        end

        function cbCancel(this)
            close(this)
        end

        function cbHelp(~)
            helpview('simulink','rom_post_simulation_functions')
        end
        
        function generateCode(this,fname)

            fullpath = which(fname);
            str = string(fileread(fullpath));
            controllib.internal.codegen.showGeneratedMATLABCode(str)
        end
    end
end

% LocalWords:  tblExport pnlOCH lbl experimentmanager postsimfcn
