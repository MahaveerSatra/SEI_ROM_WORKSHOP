classdef SamplingMethod < handle
    %

    % SamplingMethod
    %
    % Panel to display/set the sampling method for random parameters

    % Copyright 2023 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        HaveStats

        ParameterTable
        Widgets
        
        Spec romapp.internal.data.RandomParameterSpec
    end

    methods
        function this = SamplingMethod(spec,havestats,parent,row,col)
            %SamplingMethod

            this.Widgets = struct();

            %Set spec
            this.Spec = spec;
            this.HaveStats = havestats;
           
            %Build the panel and update the panel
            buildPanel(this,parent,row,col)
            updatePanel(this)

            %Connect the panel to the data source
            connectPanel(this)
        end

        function delete(~)

        end

        function updatePanel(this)

            this.Widgets.ddMethod.Value = this.Spec.Options.Method;

            % If method is Sobol, Halton or Copula, make the options panel
            % visible and set widgets appropriately
            if this.HaveStats
                switch this.Spec.Options.Method
                    case 'sobol'
                        this.Widgets.ddScramble.Items = {...
                            romapp.internal.resources.getString('lblEditDistributions_QRScrambleOptions_None'); ...
                            romapp.internal.resources.getString('lblEditDistributions_QRScrambleOptions_MatousekOwen')};
                        this.Widgets.ddScramble.ItemsData = {...
                            'none'; ...
                            'matousekowen'};
                        this.Widgets.lblPointOrder.Visible = true;
                        this.Widgets.ddPointOrder.Visible = true;
                        this.Widgets.pnlOptions.Visible = true;
                        this.Widgets.qrLayout.Visible = true;
                        this.Widgets.copulaLayout.Visible = false;
                    case 'halton'
                        this.Widgets.ddScramble.Items = {...
                            romapp.internal.resources.getString('lblEditDistributions_QRScrambleOptions_None'); ...
                            romapp.internal.resources.getString('lblEditDistributions_QRScrambleOptions_RR2')};
                        this.Widgets.ddScramble.ItemsData = {...
                            'none'; ...
                            'RR2'};
                        this.Widgets.lblPointOrder.Visible = false;
                        this.Widgets.ddPointOrder.Visible = false;
                        this.Widgets.pnlOptions.Visible = true;
                        this.Widgets.qrLayout.Visible = true;
                        this.Widgets.copulaLayout.Visible = false;
                    case 'copula'

                        this.Widgets.ddFamily.Value = this.Spec.Options.MethodOptions.Family;

                        if strcmp(this.Spec.Options.MethodOptions.Family,'Gaussian')
                            this.Widgets.lblDOF.Visible = false;
                            this.Widgets.edtDOF.Visible = false;
                        elseif strcmp(this.Spec.Options.MethodOptions.Family,'t')
                            this.Widgets.lblDOF.Visible = true;
                            this.Widgets.edtDOF.Visible = true;
                        end
                        this.Widgets.pnlOptions.Visible = true;
                        this.Widgets.qrLayout.Visible = false;
                        this.Widgets.copulaLayout.Visible = true;

                    otherwise
                        this.Widgets.pnlOptions.Visible = false;
                        this.Widgets.qrLayout.Visible = false;
                        this.Widgets.copulaLayout.Visible = false;
                end
            end

        end

        function updateSpec(this)

            if this.HaveStats
                switch this.Spec.Options.Method
                    case 'sobol'
                        this.Spec.Options.MethodOptions.Skip = this.Widgets.edtSkip.Value;
                        this.Spec.Options.MethodOptions.Leap = this.Widgets.edtLeap.Value;
                        if strcmp(this.Widgets.ddScramble.Value,'none')
                            this.Spec.Options.MethodOptions.ScrambleMethod = [];
                        elseif strcmp(this.Widgets.ddScramble.Value,'matousekowen')
                            this.Spec.Options.MethodOptions.ScrambleMethod = struct('Type','MatousekAffineOwen','Options',[]);
                        end
                        this.Spec.Options.MethodOptions.PointOrder = this.Widgets.ddPointOrder.Value;
                    case 'halton'
                        this.Spec.Options.MethodOptions.Skip = this.Widgets.edtSkip.Value;
                        this.Spec.Options.MethodOptions.Leap = this.Widgets.edtLeap.Value;
                        if strcmp(this.Widgets.ddScramble.Value,'none')
                            this.Spec.Options.MethodOptions.ScrambleMethod = [];
                        elseif strcmp(this.Widgets.ddScramble.Value,'RR2')
                            this.Spec.Options.MethodOptions.ScrambleMethod = struct('Type','RR2','Options',[]);
                        end
                    case 'copula'
                        this.Spec.Options.MethodOptions.Family = this.Widgets.ddFamily.Value;
                        this.Spec.Options.MethodOptions.Type = this.Widgets.ddType.Value;
                        if strcmp(this.Spec.Options.MethodOptions.Family,'t')
                            this.Spec.Options.MethodOptions.DOF = this.Widgets.edtDOF.Value;
                        end
                end
            end
        end
    end

    methods (Access=private)
        function buildPanel(this,parent,row,col)

            wdgts = struct(); %to Store the UI widgets
            
            layout = uigridlayout(parent,[2 1]);
            layout.RowHeight = {'fit','1x'};
            layout.ColumnWidth = {'fit','fit','1x'};
            layout.Padding = [0 0 0 0];
            layout.Layout.Row = row;
            layout.Layout.Column = col;

            %Sampling method combobox
            lblMethod = uilabel(layout);
            lblMethod.Layout.Row = 1;
            lblMethod.Layout.Column = 1;
            lblMethod.Text = romapp.internal.resources.getString('lblEditDistributions_SampleMethod');
            ddMethod = uidropdown(layout);
            ddMethod.Layout.Row = 1;
            ddMethod.Layout.Column = 2;
            if this.HaveStats
                ddMethod.Items = {...
                    romapp.internal.resources.getString('lblEditDistributions_SampleMethod_Random'), ...
                    romapp.internal.resources.getString('lblEditDistributions_SampleMethod_LHS'), ...
                    romapp.internal.resources.getString('lblEditDistributions_SampleMethod_Sobol'), ...
                    romapp.internal.resources.getString('lblEditDistributions_SampleMethod_Halton'), ...
                    romapp.internal.resources.getString('lblEditDistributions_SampleMethod_Copula')};
                ddMethod.ItemsData = {'random','lhs','sobol','halton','copula'};
            else
                 ddMethod.Items = {...
                    romapp.internal.resources.getString('lblEditDistributions_SampleMethod_Random'), ...
                    romapp.internal.resources.getString('lblEditDistributions_SampleMethod_LHS')};
                ddMethod.ItemsData = {'random','lhs'};
            end
            ddMethod.Value = ddMethod.ItemsData{1};
            wdgts.ddMethod = ddMethod;

            %Sampling method options (only needed if have Stats)
            if this.HaveStats
                pnl = uipanel(layout,"BorderType","none");
                pnl.Layout.Row = 2;
                pnl.Layout.Column = [1 3];

                wdgts = createQRandomWidgets(this,wdgts,pnl);
                wdgts = createCopulaWidgets(this,wdgts,pnl);

                wdgts.pnlOptions = pnl;
            end
            
            %Store the widgets
            this.Widgets = wdgts;
        end

        function connectPanel(this)
            
            addlistener(this.Widgets.ddMethod,'ValueChanged', @(hSrc,hData) cbMethod(this,hSrc));
            if this.HaveStats
                addlistener(this.Widgets.ddFamily,'ValueChanged', @(hSrc,hData) cbCopulaFamily(this,hSrc));
            end
        end

        function cbMethod(this,hSrc)

            % Update data based on widget selection
            if isequal(this.Spec.Options.Method,hSrc.Value)
                %Nothing to do, quick return
                return
            end

            %Update the spec options and refresh the panel.
            this.Spec.Options.Method = hSrc.Value;
            updatePanel(this)
        end

        function cbCopulaFamily(this,source)

            if isequal(this.Widgets.ddFamily,source.Value)
                %Nothing to do, quick return
                return
            end

            %Update the spec and refresh the panel
            this.Spec.Options.MethodOptions.Family = source.Value;
            updatePanel(this)
        end

        function wdgts = createQRandomWidgets(~,wdgts,parent)

            qrLayout = uigridlayout(parent,[1 9]);
            qrLayout.RowHeight = {'fit'};
            qrLayout.ColumnWidth = {'fit','fit','fit','fit','fit','fit','fit','fit','1x'};
            qrLayout.ColumnWidth = [repmat({'fit'},1,12),{'1x'}];

            lblSkip = uilabel(qrLayout);
            lblSkip.Layout.Row = 1;
            lblSkip.Layout.Column = 1;
            lblSkip.Text = romapp.internal.resources.getString('lblEditDistributions_QRSampleOptions_Skip');
            lblSkip.HorizontalAlignment = 'right';
            edtSkip = uieditfield(qrLayout,'numeric');
            edtSkip.Layout.Row = 1;
            edtSkip.Layout.Column = 2;
            edtSkip.Value = 1;

            lblPad = uilabel(qrLayout);
            lblPad.Layout.Row = 1;
            lblPad.Layout.Column = 3;
            lblPad.Text = '';

            lblLeap = uilabel(qrLayout);
            lblLeap.Layout.Row = 1;
            lblLeap.Layout.Column = 4;
            lblLeap.Text = romapp.internal.resources.getString('lblEditDistributions_QRSampleOptions_Leap');
            lblLeap.HorizontalAlignment = 'right';
            edtLeap = uieditfield(qrLayout,'numeric');
            edtLeap.Layout.Row = 1;
            edtLeap.Layout.Column = 5;
            edtLeap.Value = 0;

            lblPad = uilabel(qrLayout);
            lblPad.Layout.Row = 1;
            lblPad.Layout.Column = 6;
            lblPad.Text = '';

            lblScramble = uilabel(qrLayout);
            lblScramble.Layout.Row = 1;
            lblScramble.Layout.Column = 7;
            lblScramble.Text = romapp.internal.resources.getString('lblEditDistributions_QRSampleOptions_Scramble');
            lblScramble.HorizontalAlignment = 'right';
            ddScramble = uidropdown(qrLayout);
            ddScramble.Layout.Row = 1;
            ddScramble.Layout.Column = 8;
            %Add all options though Sobol/Halton will restrict them
            ddScramble.Items = {...
                romapp.internal.resources.getString('lblEditDistributions_QRScrambleOptions_None'); ...
                romapp.internal.resources.getString('lblEditDistributions_QRScrambleOptions_MatousekOwen'); ...
                romapp.internal.resources.getString('lblEditDistributions_QRScrambleOptions_RR2')};
            ddScramble.ItemsData = {...
                'none'; ...
                'matousekowen'; ...
                'rr2'};

            lblPad = uilabel(qrLayout);
            lblPad.Layout.Row = 1;
            lblPad.Layout.Column = 9;
            lblPad.Text = '';

            lblPointOrder = uilabel(qrLayout);
            lblPointOrder.Layout.Row = 1;
            lblPointOrder.Layout.Column = 10;
            lblPointOrder.Text = romapp.internal.resources.getString('lblEditDistributions_QRSampleOptions_PointOrder');
            lblPointOrder.HorizontalAlignment = 'right';
            ddPointOrder = uidropdown(qrLayout);
            ddPointOrder.Layout.Row = 1;
            ddPointOrder.Layout.Column = 11;
            ddPointOrder.Items = {...
                romapp.internal.resources.getString('lblEditDistributions_QRPointOptions_Standard'); ...
                romapp.internal.resources.getString('lblEditDistributions_QRPointOptions_Gray')};
            ddPointOrder.ItemsData = {...
                'standard'; ...
                'graycode'};

            %Store widgets
            wdgts.qrLayout = qrLayout;
            wdgts.edtSkip = edtSkip;
            wdgts.edtLeap = edtLeap;
            wdgts.ddScramble = ddScramble;
            wdgts.lblPointOrder = lblPointOrder;
            wdgts.ddPointOrder = ddPointOrder;
        end

        function wdgts = createCopulaWidgets(~,wdgts,parent)

            copulaLayout = uigridlayout(parent,[1 9]);
            copulaLayout.RowHeight = {'fit'};
            copulaLayout.ColumnWidth = [repmat({'fit'},1,8),{'1x'}];

            lblFamily = uilabel(copulaLayout);
            lblFamily.Layout.Row = 1;
            lblFamily.Layout.Column = 1;
            lblFamily.Text = romapp.internal.resources.getString('lblEditDistributions_CopulaOptions_Family');
            lblFamily.HorizontalAlignment = 'right';
            ddFamily = uidropdown(copulaLayout);
            ddFamily.Layout.Row = 1;
            ddFamily.Layout.Column = 2;
            ddFamily.Items = {...
                romapp.internal.resources.getString('lblEditDistributions_CopulaFamilyOptions_Gaussian'); ...
                romapp.internal.resources.getString('lblEditDistributions_CopulaFamilyOptions_t')};
            ddFamily.ItemsData = { ...
                'Gaussian'; ...
                't'};

            lblPad = uilabel(copulaLayout);
            lblPad.Layout.Row = 1;
            lblPad.Layout.Column = 3;
            lblPad.Text = '';

            lblType = uilabel(copulaLayout);
            lblType.Layout.Row = 1;
            lblType.Layout.Column = 4;
            lblType.Text = romapp.internal.resources.getString('lblEditDistributions_CopulaOptions_Type');
            lblType.HorizontalAlignment = 'right';
            ddType = uidropdown(copulaLayout);
            ddType.Layout.Row = 1;
            ddType.Layout.Column = 5;
            ddType.Items = {...
                romapp.internal.resources.getString('lblEditDistributions_CopulaTypeOptions_Spearman'); ...
                romapp.internal.resources.getString('lblEditDistributions_CopulaTypeOptions_Kendall')};
            ddType.ItemsData = { ...
                'Spearman'; ...
                'Kendall'};

            lblPad = uilabel(copulaLayout);
            lblPad.Layout.Row = 1;
            lblPad.Layout.Column = 6;
            lblPad.Text = '';

            lblDOF = uilabel(copulaLayout);
            lblDOF.Layout.Row = 1;
            lblDOF.Layout.Column = 7;
            lblDOF.Text = romapp.internal.resources.getString('lblEditDistributions_CopulaOptions_DOF');
            lblDOF.HorizontalAlignment = 'right';
            edtDOF = uieditfield(copulaLayout,'numeric');
            edtDOF.Layout.Row = 1;
            edtDOF.Layout.Column = 8;
            edtDOF.Value = 2;

            wdgts.copulaLayout = copulaLayout;
            wdgts.ddFamily = ddFamily;
            wdgts.ddType = ddType;
            wdgts.lblDOF = lblDOF;
            wdgts.edtDOF = edtDOF;
        end

    end
end

% LocalWords:  Sobol Halton sobol lbl Matousek matousekowen halton rr graycode DOF
% LocalWords:  MatousekAffineOwen
