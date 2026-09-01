classdef EditDistributionsDialog < controllib.ui.internal.dialog.AbstractDialog
    % Select Inputs and Outputs of ROM from Simulink
    %

    % Copyright 2022-2025 The MathWorks, Inc.

    properties (SetAccess = private,Hidden, ...
            GetAccess=?matlab.unittest.TestCase)
        Widgets struct
        Spec
    end

    properties(SetAccess = protected, GetAccess=?matlab.unittest.TestCase)
        SamplingMethodPanel
        DistributionPanel
        CorrelationPanel
    end

    properties(GetAccess = public, SetAccess = private)
        HaveStats logical = false;
    end

    events(NotifyAccess = protected)
        SpecChanged
    end


    methods
        function this = EditDistributionsDialog(spec)
            this = this@controllib.ui.internal.dialog.AbstractDialog();
            this.Spec = copy(spec);
            
            this.Name = 'EditDistributionsDialog';
            this.Title = romapp.internal.resources.getString('lblEditDistributions');

            this.HaveStats =  license('test', 'Statistics_Toolbox')  &&  ~isempty(ver('stats'));
        end

        function updateSpec(this)

            %Update the spec with any data from the UI that still needs to
            %be pushed to the spec
            updateSpec(this.SamplingMethodPanel)
            updateSpec(this.DistributionPanel)
            updateSpec(this.CorrelationPanel)
        end

        function spec = getSpec(this)
            spec = this.Spec;
        end

        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
        end

        function updateUI(this)

            updatePanel(this.DistributionPanel);
            updatePanel(this.CorrelationPanel);
            updatePanel(this.SamplingMethodPanel);
        end
    end


    methods (Access = protected)
        function buildUI(this)
            f = this.UIFigure;
            f.Tag = 'rom-edit-distributions-dialog';
            f.Position(3:4) = [700 400];
            mainGridLayout = uigridlayout(f, [3 1]);
            mainGridLayout.RowHeight = {'fit','1x', 'fit'};
            mainGridLayout.ColumnWidth = {'1x'};

            %Panel for SamplingMethod
            this.SamplingMethodPanel = romapp.internal.panels.SamplingMethod(this.Spec,this.HaveStats,mainGridLayout,1,1);

            %Tab group for distribution and correlation information
            tabGroup = uitabgroup(mainGridLayout, ...
                'Tag', 'DistributionTabGroup');
            tabGroup.Layout.Row = 2;
            tabGroup.Layout.Column = 1;
            tabDistribution = uitab(...
                'Parent', tabGroup, ...
                'Tag', 'tabDistributions', ...
                'Title', romapp.internal.resources.getString('lblEditDistributions_DistributionParameters'));
            tabCorrelation = uitab(...
                'Parent', tabGroup, ...
                'Tag', 'tabDistributions', ...
                'Title', romapp.internal.resources.getString('lblEditDistributions_Correlation'));
            this.CorrelationPanel = romapp.internal.panels.CorrelationData(this.Spec,tabCorrelation);
            this.DistributionPanel = romapp.internal.panels.DistributionParameters(this.Spec,this.HaveStats,this.CorrelationPanel,tabDistribution);
            
            %Ok, cancel, help buttons
            pnl = uipanel(mainGridLayout,'BorderType','none');
            pnl.Layout.Row = 3;
            pnl.Layout.Column = 1;
            pnlOCH = controllib.widget.internal.buttonpanel.ButtonPanel(pnl, ["Help" "OK" "Cancel"]);
            
            % store in a struct
            this.Widgets = struct(...
                'pnlOCH', pnlOCH);

        end
        function connectUI(this)

            %Ok, cancel, help buttons
            this.Widgets.pnlOCH.OKButton.ButtonPushedFcn = @(hSrc,hData) cbOK(this);
            this.Widgets.pnlOCH.CancelButton.ButtonPushedFcn = @(hSrc,hData) cbCancel(this);
            this.Widgets.pnlOCH.HelpButton.ButtonPushedFcn = @(hSrc,hData) cbHelp(this);
        end

        function cbOK(this)

            updateSpec(this)

            notify(this,'SpecChanged')

            %Close the dialog
            cbCancel(this)
        end

        function cbCancel(this)
            close(this)
        end

        function cbHelp(~)
           helpview('simulink','rom_edit_distributions')
        end

    end

    methods(Static = true)
        function fig = getFigure(comp)

            %Recurse up parent tree until we find a uifigure
            parent = comp.Parent;
            if isa(parent,'matlab.ui.Figure')
                fig = parent;
            else
                fig = romapp.internal.dialogs.EditDistributionsDialog.getFigure(parent);
            end
        end
    end
end

% LocalWords:  GL uigridlayout uiaxes YTick tbl btn lbl GETCANDIDATEOUTPUTS GETMODELINPUTS pnl
