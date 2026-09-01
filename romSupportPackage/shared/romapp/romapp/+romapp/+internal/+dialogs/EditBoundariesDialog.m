classdef EditBoundariesDialog < controllib.ui.internal.dialog.AbstractDialog
    % Select Inputs and Outputs of ROM from Simulink
    %

    % Copyright 2022-2025 The MathWorks, Inc.

    properties (SetAccess = private,Hidden, ...
            GetAccess=?matlab.unittest.TestCase)
        
        Spec  
        BoundarySpec %BoundarySpec panel that created this dialog, a tab under Configure Experiment
        Layout
        Widgets struct
        isValid = true
        nonConflicting = true
        StartupFactors
    end

    properties(Access = protected)
        BoundarySpecDefPanel %In Edit Boundaries dialog, either a PiecewiselinearBoundarySpec, or an EllipticalBoundarySpec
    end

    methods
        function this = EditBoundariesDialog(panel, spec, startupFactors)
            this = this@controllib.ui.internal.dialog.AbstractDialog();
            this.Spec = copy(spec);
            this.BoundarySpec = panel;   
            this.Name = 'EditBoundariesDialog';
            this.Title = romapp.internal.resources.getString('lblBoundary_EditBoundaries');
            this.StartupFactors = startupFactors;
        end

        function spec = getSpec(this)
            spec = this.BoundarySpec;
        end

        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
        end

        function pnl = getPanel(this)
            pnl = this.BoundarySpecDefPanel;
        end

        function updateUI(this)
            if isempty(this.StartupFactors)
                FactorNames = getFactorNames(this);
                this.Widgets.ddFactor1.Value = FactorNames{1};
                this.Widgets.ddFactor2.Value = FactorNames{2};
            else
                this.Widgets.ddFactor1.Value = this.StartupFactors{1};
                this.Widgets.ddFactor2.Value = this.StartupFactors{2};
            end

            %find if there is an existing boundary type for the two factors
            [existingPnlClass, ~] = pnlMatchesData(this.Widgets.ddFactor1.Value, this.Widgets.ddFactor2.Value, this.BoundarySpec.Spec);           
            %change drop-down to the existing type
            updateWidgets(this, existingPnlClass)
            %update the panel for none, piecewise linear, or elliptical
            configureBoundarySpecDefPanel(this,4,[1 3],existingPnlClass);
        end
    end

    methods (Access = protected)
        function buildUI(this)
            f = this.UIFigure;
            this.CloseMode = 'destroy';
            f.Tag = 'rom-edit-boundaries-dialog';
            f.Position(3:4) = [650 400];

            layout = uigridlayout(f,[5 3]);
            layout.RowHeight = {'fit','fit', 'fit','1x','fit','fit'};
            layout.ColumnWidth = {'fit','fit','1x'};

            FactorNames = getFactorNames(this);
            
            lblFactor1 = uilabel(layout);
            lblFactor1.Layout.Row = 1;
            lblFactor1.Layout.Column = 1;
            lblFactor1.Text = romapp.internal.resources.getString('lblBoundary_Factor1');

            ddFactor1 = uidropdown(layout);
            ddFactor1.Layout.Row = 1;
            ddFactor1.Layout.Column = 2;
            ddFactor1.Items = FactorNames;
            ddFactor1.Tag = 'Factor1';
            
            lblFactor2 = uilabel(layout);
            lblFactor2.Layout.Row = 2;
            lblFactor2.Layout.Column = 1;
            lblFactor2.Text = romapp.internal.resources.getString('lblBoundary_Factor2');

            ddFactor2 = uidropdown(layout);
            ddFactor2.Layout.Row = 2;
            ddFactor2.Layout.Column = 2;
            ddFactor2.Items = FactorNames;
            ddFactor2.Tag = 'Factor2';

            lblFactorErr = uilabel(layout);
            lblFactorErr.Layout.Row = 1;
            lblFactorErr.Layout.Column = 3;
            lblFactorErr.Text = '';
            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblFactorErr,'FontColor','--mw-color-error')

            lblBoundaryType = uilabel(layout);
            lblBoundaryType.Layout.Row = 3;
            lblBoundaryType.Layout.Column = 1;
            lblBoundaryType.Text = romapp.internal.resources.getString('lblBoundary_Type');

            ddBoundaryType = uidropdown(layout);
            ddBoundaryType.Layout.Row = 3;
            ddBoundaryType.Layout.Column = 2;
            ddBoundaryType.Items = {...
                romapp.internal.resources.getString('lblNone'), ...
                romapp.internal.resources.getString('lblBoundary_Piecewiselinear'), ...
                romapp.internal.resources.getString('lblBoundary_Elliptical')};
            ddBoundaryType.ItemsData = {'none','piecewiselinear','elliptical'};
            ddBoundaryType.Value = ddBoundaryType.ItemsData{1};
            
            % conflicting 
            lblConflictingErr = uilabel(layout);
            lblConflictingErr.Layout.Row = 5;
            lblConflictingErr.Layout.Column = [1 3];
            lblConflictingErr.Text = '';
            lblConflictingErr.WordWrap = 'on';
            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblConflictingErr,'FontColor','--mw-color-error')

            % ok, cancel, help buttons
            pnl = uipanel(layout,'BorderType','none');
            pnl.Layout.Row = 6;
            pnl.Layout.Column = [1 3];
            pnlOCH = controllib.widget.internal.buttonpanel.ButtonPanel(pnl, ["Help" "Apply" "OK" "Cancel"]);

            % store in a struct
            this.Widgets = struct(...
                'lblFactor1', lblFactor1, ...
                'ddFactor1', ddFactor1, ...
                'lblFactor2', lblFactor2, ...
                'ddFactor2', ddFactor2, ...
                'lblFactorErr', lblFactorErr, ...
                'lblBoundaryType', lblBoundaryType, ...
                'ddBoundaryType', ddBoundaryType, ...
                'lblConflictingErr', lblConflictingErr, ...
                'pnlOCH', pnlOCH);

            this.Layout = layout; 
        end

        function updateWidgets(this, pnlClass)
            switch pnlClass
                case 'romapp.internal.panels.NoneBoundarySpec'
                    this.Widgets.ddBoundaryType.Value = this.Widgets.ddBoundaryType.ItemsData{1};                
                case 'romapp.internal.panels.PiecewiselinearBoundarySpec'
                    this.Widgets.ddBoundaryType.Value = this.Widgets.ddBoundaryType.ItemsData{2};
                case 'romapp.internal.panels.EllipticalBoundarySpec'
                    this.Widgets.ddBoundaryType.Value = this.Widgets.ddBoundaryType.ItemsData{3};            
            end
        end

        function FactorNames = getFactorNames(this)
            FactorNames = getFactorNames(this.Spec);
        end

        function configureBoundarySpecDefPanel(this,row,col,pnlClass)        
                oldPnl = this.BoundarySpecDefPanel;                
                [~, ~, ind] = pnlMatchesData(this.Widgets.ddFactor1.Value, this.Widgets.ddFactor2.Value, this.BoundarySpec.Spec, pnlClass);
                switch pnlClass            
                    case 'romapp.internal.panels.PiecewiselinearBoundarySpec'         
                        [AxesLimits, isAxisAdjustable] = getAxesLimits(this.Spec, {this.Widgets.ddFactor1.Value,this.Widgets.ddFactor2.Value});
                        pnl = romapp.internal.panels.PiecewiselinearBoundarySpec(this.Widgets, this.BoundarySpec, this.Layout, row, col, ind, AxesLimits, isAxisAdjustable);
                    case 'romapp.internal.panels.EllipticalBoundarySpec'
                        [AxesLimits, isAxisAdjustable] = getAxesLimits(this.Spec, {this.Widgets.ddFactor1.Value,this.Widgets.ddFactor2.Value});
                        pnl = romapp.internal.panels.EllipticalBoundarySpec(this.Widgets, this.BoundarySpec, this.Layout, row, col, ind, AxesLimits, isAxisAdjustable);
                    case 'romapp.internal.panels.NoneBoundarySpec'
                        pnl = romapp.internal.panels.NoneBoundarySpec(this.Widgets, this.Layout, row, col);
                end
                this.BoundarySpecDefPanel = pnl;
                delete(oldPnl);
        end

        function connectUI(this)
            weak = romapp.internal.resources.WeakReference(this);
            addlistener(this.Widgets.ddFactor1,'ValueChanged', @(hSrc,hData) cbFactor(weak.Handle));
            addlistener(this.Widgets.ddFactor2,'ValueChanged', @(hSrc,hData) cbFactor(weak.Handle));
            addlistener(this.Widgets.ddBoundaryType,'ValueChanged', @(hSrc,hData) cbBoundaryType(weak.Handle));
            addlistener(this,'CloseEvent', @(hSrc,hData) cbClose(weak.Handle));

            %Ok, cancel, help buttons
            this.Widgets.pnlOCH.OKButton.ButtonPushedFcn = @(hSrc,hData) cbOK(this);
            this.Widgets.pnlOCH.CancelButton.ButtonPushedFcn = @(hSrc,hData) cbCancel(this);
            this.Widgets.pnlOCH.ApplyButton.ButtonPushedFcn = @(hSrc,hData) cbApply(this);
            this.Widgets.pnlOCH.HelpButton.ButtonPushedFcn = @(hSrc,hData) cbHelp(this);
        end
        
        function cbClose(this)
            toggleFactorPanels(this.BoundarySpec,true);
            close(this)    
        end

        function updateBtn(this)
            this.Widgets.pnlOCH.ApplyButton.Enable = this.isValid;
            this.Widgets.pnlOCH.OKButton.Enable = this.isValid & this.nonConflicting;   
        end

        function cbFactor(this)
            if isequal(this.Widgets.ddFactor1.Value, this.Widgets.ddFactor2.Value)
                this.Widgets.lblFactorErr.Text = romapp.internal.resources.getString('errBoundary_Factors');
                pnlClass = 'romapp.internal.panels.NoneBoundarySpec';
                this.Widgets.ddBoundaryType.Value = this.Widgets.ddBoundaryType.ItemsData{1};
                configureBoundarySpecDefPanel(this,4,[1 3],pnlClass)
                this.isValid = false;
                updateBtn(this)
                this.Widgets.ddBoundaryType.Enable = 'off';
                return 
            else
                this.Widgets.lblFactorErr.Text = '';
                this.isValid = true;              
                updateBtn(this)
                this.Widgets.ddBoundaryType.Enable = 'on';
            end
            cbBoundaryType(this)
        end

        function cbBoundaryType(this)      
            %get new boundary type
            type = this.Widgets.ddBoundaryType.Value;
            switch type
                case 'piecewiselinear'
                    pnlClass = 'romapp.internal.panels.PiecewiselinearBoundarySpec';
                case 'elliptical'
                    pnlClass = 'romapp.internal.panels.EllipticalBoundarySpec';
                case 'none'
                    pnlClass = 'romapp.internal.panels.NoneBoundarySpec';
            end
            %creates a new widget (none, piecewise linear, or elliptical) matching the new pnlClass
            configureBoundarySpecDefPanel(this,4,[1 3],pnlClass)
        end

        function cbOK(this)
            cbApply(this)  
            if this.nonConflicting
                cbCancel(this) % Close the dialog
            end
        end

        function cbCancel(this)
            cbClose(this)
        end

        function cbApply(this)
            [~,nonConflictingBoundaries,conflictingFactor] = validateIntervals(this.BoundarySpec);
            % warn the user of conflicting boundaries
            this.nonConflicting = nonConflictingBoundaries;
            if nonConflictingBoundaries
                this.Widgets.lblConflictingErr.Text = '';
                getSpec(this.BoundarySpec);
            else
                this.Widgets.lblConflictingErr.Text = romapp.internal.resources.getString('errBoundary_Conflicting',conflictingFactor);
            end
        end

        function cbHelp(~)
            helpview('simulink','rom_edit_boundaries')
        end
    end

    methods (Access = ?qe.ClassTestCase)
        function [AxesLimits, isAxisAdjustable] = qeGetAxesLimits(this, factorNames)
            [AxesLimits, isAxisAdjustable] = getAxesLimits(this.Spec, factorNames);
        end
    end

end

function [oldPnlClass, tf, ind] = pnlMatchesData(nFactor1, nFactor2, BoundarySpec, varargin)
    % This code does the following.
    % 
    % Checks if for selected factors, the type in 
    % data.BoundarySpec matches that of the new panel
    %
    % Returns false if 
    % a) no existing boundary for selected factors
    % b) a boundary exists but is different from the new panel
    % c) a new panel is not given 
    %
    % Returns true and ind if a boundary exists and matches the new panel
    if isempty(BoundarySpec.Factors)
        oldPnlClass = 'romapp.internal.panels.NoneBoundarySpec';
        tf = false;
        ind = []; 
        return
    end
    
    if nargin>3
        pnlClass = varargin{1};
    end

    nBoundaries = numel(BoundarySpec.Factors);
    for iBoundary = 1:nBoundaries
        eFactors = BoundarySpec.Factors{iBoundary};
        eFactor1 = eFactors(1);
        eFactor2 = eFactors(2);
        if (strcmp(eFactor1,nFactor1) && strcmp(eFactor2,nFactor2)) || ...
                       (strcmp(eFactor1,nFactor2) && strcmp(eFactor2,nFactor1))
            switch BoundarySpec.Type{iBoundary}
                case 'piecewiselinear'
                    oldPnlClass = 'romapp.internal.panels.PiecewiselinearBoundarySpec';
                case 'elliptical'
                    oldPnlClass = 'romapp.internal.panels.EllipticalBoundarySpec';
            end
            if nargin>3
                tf = strcmpi(oldPnlClass,pnlClass);
                if tf
                    ind = iBoundary;
                else
                    ind = [];
                end
            else
                tf = false;
                ind = []; 
            end
            return
        end    
        oldPnlClass = 'romapp.internal.panels.NoneBoundarySpec';
        tf = false;
        ind = []; 
    end      

end

function [AxesLimits, isAxisAdjustable] = getAxesLimits(spec, factorNames)
    isAxisAdjustable = [false, false];
    AxesLimits = zeros(2,2);
    for iFactor = 1:2
        factorName = factorNames{iFactor};
        if ~isempty(spec.SignalSpec)
            signalNames = {spec.SignalSpec.Signals.Name};
        else
            signalNames = [];
        end
        if ~isempty(spec.ParameterSpec)
            nParams = numel(spec.ParameterSpec.Parameters);
        else
            nParams = 0;
        end
        [isSignal, ind] = ismember(factorName, signalNames);
        if isSignal
            AxesLimits(iFactor,:) = spec.SignalSpec.Ranges(ind,:);    
        else
            for iParam = 1:nParams
                paramName = char(romapp.internal.data.ModelPorts.getDisplayName(spec.ParameterSpec.Parameters(iParam)));
                if isequal(paramName, factorName)
                    if ~isRandom(spec.ParameterSpec)
                        %gridded 
                        paramValues = spec.ParameterSpec.Values{iParam};
                        AxesLimits(iFactor,:) = [min(paramValues)-1 max(paramValues)+1];
                    elseif isa(spec.ParameterSpec.Distributions(1),'prob.UniformDistribution')
                        %uniform
                        AxesLimits(iFactor,:) = getDistributionLimits(spec.ParameterSpec,iParam);
                    else
                        %other distribution
                        AxesLimits(iFactor,:) = getDistributionLimits(spec.ParameterSpec,iParam);
                        isAxisAdjustable(iFactor) = true;
                    end
                    break
                end
            end
        end
    end
end

% LocalWords: uigridlayout tbl btn lbl  mw Piecewiselinear piecewiselinear pnl BirnBaumSaunders
% LocalWords:  Loglogistic Nakagami PRPS PRBS PRSS