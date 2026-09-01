classdef SimulationSetConfigureAll <  handle
    %

    % SimulationSetConfigureAll

    % Copyright 2022-2025 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        Widgets
        SignalSpecPanel
        ParameterSpecPanel
        BoundarySpecPanel
        VisibleSpec

        Dirty logical
    end

    methods
        function this = SimulationSetConfigureAll(tool,parent)
            % SimulationSetConfigureAll

            this.Tool = tool;
            this.Widgets = struct();

            %Set the default visible spec
            data = getToolData(this.Tool);
            this.VisibleSpec = data.SimulationSpec(1);

            %Build the panel and update the panel
            buildPanel(this,parent)
            updatePanel(this)

            %Connect the panel to the data source
            connectPanel(this)

            %Set dirty flag
            this.Dirty = false;
        end

        function delete(~)

        end

        function refreshPanel(this)
            data = getToolData(this.Tool);
            setVisibleSpec(this, data.SimulationSpec(1));
            updatePanel(this)
            if romapp.internal.resources.Shipped
                refreshPanel(this.BoundarySpecPanel) %close the EditBoundariesDialog window if open
                toggleFactorPanels(this,true)
            end
        end

        function setVisibleSpec(this,spec)

            this.VisibleSpec = spec;
            if ~isempty(this.SignalSpecPanel)
                setVisibleSpec(this.SignalSpecPanel,spec)
            end
            if ~isempty(this.ParameterSpecPanel)
                setVisibleSpec(this.ParameterSpecPanel,spec)
            end
            if ~isempty(this.BoundarySpecPanel)
                setVisibleSpec(this.BoundarySpecPanel,spec)
            end
        end

        function toggleFactorPanels(this,tf)
            %factors panels are enabled when tf is true (boundary dialog is
            %not open)
            if tf
                state = 'on';
            else
                state = 'off';
            end
            components = findall(this.Widgets.tpnlSignals,'-property','Enable');
            for iComponent = 1:numel(components)
                components(iComponent).Enable = state;
            end
            components = findall(this.Widgets.tpnlParams,'-property','Enable');
            for iComponent = 1:numel(components)
                components(iComponent).Enable = state;
            end
        end

        function toggleBoundaryPanel(this)
            % enable BoundaryPanel when at least two eligible
            % signals/parameters
            DirtyVisibleSpec = getDirtyVisibleSpec(this);
            if isempty(DirtyVisibleSpec.SignalSpec)
                nSig = 0;
            else
                nSig = numel(DirtyVisibleSpec.SignalSpec.Signals);
            end
            if isempty(DirtyVisibleSpec.ParameterSpec)
                nParam = 0;
            else
                nParam = numel(DirtyVisibleSpec.ParameterSpec.Parameters);
            end
            if nSig+nParam<=1
                tf = 'off';
            elseif nParam>=1
                tf = 'on';
            else
                if isRandom(DirtyVisibleSpec.SignalSpec)
                    tf = 'on';
                else
                    tf = 'off';
                end
            end
            components = findall(this.Widgets.tpnlBoundaries,'-property','Enable');
            for iComponent = 1:numel(components)
                components(iComponent).Enable = tf;
            end
        end

        function DirtyVisibleSpec = getDirtyVisibleSpec(this)
            DirtyVisibleSpec = copy(this.VisibleSpec);
            if ~isempty(DirtyVisibleSpec.SignalSpec)
                updateDirtySpec(this.SignalSpecPanel,DirtyVisibleSpec);
            end
            if ~isempty(DirtyVisibleSpec.ParameterSpec)
                updateDirtySpec(this.ParameterSpecPanel,DirtyVisibleSpec);
            end
         end

    end

    methods (Access=private)
        function buildPanel(this,parent)

            haveSignals = ~isempty(this.VisibleSpec.SignalSpec);
            haveParams = ~isempty(this.VisibleSpec.ParameterSpec);

            panelConfig = uipanel(parent);
            panelConfig.Layout.Row = 1;
            panelConfig.Layout.Column = 1;
            panelConfig.Title = romapp.internal.resources.getString('lblConfigAllSignalsParameters');
            panelConfig.BorderType = 'none';

            layoutSection = uigridlayout(panelConfig,[2 1]);
            layoutSection.RowHeight = {'1x','fit'};
            layoutSection.ColumnWidth = {'1x'};
           
            %Add the signal and parameter focused widgets
            tabParams = [];
            tabSignals = [];
            grp = uitabgroup(layoutSection);
            grp.Layout.Row = 1;
            grp.Layout.Column = 1;
            if haveSignals && haveParams                
                tabSignals = uitab(grp,"Title", romapp.internal.resources.getString('lblSignalSpecTab'));
                this.SignalSpecPanel = romapp.internal.panels.SignalSpec(this,this.Tool,tabSignals);
                tabParams = uitab(grp,"Title", romapp.internal.resources.getString('lblParameterSpecTab'));
                this.ParameterSpecPanel = romapp.internal.panels.ParameterSpec(this.Tool,tabParams);
            elseif haveSignals
                tabSignals = uitab(grp,"Title", romapp.internal.resources.getString('lblSignalSpecTab'));
                this.SignalSpecPanel = romapp.internal.panels.SignalSpec(this,this.Tool,tabSignals);                
            elseif haveParams
                tabParams = uitab(grp,"Title", romapp.internal.resources.getString('lblParameterSpecTab'));
                this.ParameterSpecPanel = romapp.internal.panels.ParameterSpec(this.Tool,tabParams);
            end
            if romapp.internal.resources.Shipped
                tabBoundaries = uitab(grp,"Title", romapp.internal.resources.getString('lblBoundarySpecTab'));
                this.BoundarySpecPanel = romapp.internal.panels.BoundarySpec(this,this.Tool,tabBoundaries);
            else
                tabBoundaries = [];
            end

            %Widgets to apply changes and plot signal
            applyLayout = uigridlayout(layoutSection,[1 3]);
            applyLayout.RowHeight = {'fit'};
            applyLayout.ColumnWidth = {'fit','1x','fit'};
            applyLayout.Layout.Row = 2;
            applyLayout.Layout.Column = 1;
            applyLayout.Padding = [0 0 0 0];

            applyButton = uibutton(applyLayout);
            applyButton.Layout.Row = 1;
            applyButton.Layout.Column = 3;
            applyButton.Text = romapp.internal.resources.getString('lblApply');
            applyButton.Tooltip = romapp.internal.resources.getString('ttipSimulationSet_Apply');
            
            lblError = uilabel(applyLayout);
            lblError.Layout.Row = 1;
            lblError.Layout.Column = [1 2];
            lblError.Text = '';
            lblError.HorizontalAlignment = 'left';
            lblError.WordWrap = "on";

            %Store the widgets
            this.Widgets = struct(...
                'btnApply', applyButton, ...
                'lblError', lblError, ...
                'tpnlParams', tabParams, ...
                'tpnlSignals', tabSignals, ...
                'tpnlBoundaries', tabBoundaries);
        end

        function connectPanel(this)
            weak = romapp.internal.resources.WeakReference(this);
            addlistener(this.Widgets.btnApply,'ButtonPushed', @(hSrc,hData) cbApply(weak.Handle));
            
            if ~isempty(this.SignalSpecPanel)
                addlistener(this.SignalSpecPanel,'Dirty','PostSet', @(hSrc,hData) manageDirtyState(weak.Handle,hData));
            end

            if ~isempty(this.ParameterSpecPanel)
                addlistener(this.ParameterSpecPanel,'Dirty','PostSet', @(hSrc,hData) manageDirtyState(weak.Handle,hData));
            end

            if ~isempty(this.BoundarySpecPanel)
                addlistener(this.BoundarySpecPanel,'Dirty','PostSet', @(hSrc,hData) manageDirtyState(weak.Handle,hData));
            end
        end

        function updateSpec(this)

            if ~isempty(this.SignalSpecPanel)
                updateSpec(this.SignalSpecPanel)
            end
            if ~isempty(this.ParameterSpecPanel)
                updateSpec(this.ParameterSpecPanel)
            end
            if ~isempty(this.BoundarySpecPanel)
                updateSpec(this.BoundarySpecPanel)
            end
            sampleFactors(this.VisibleSpec)
            updateMessage(this)
        end

        function updatePanel(this)

            %Apply button
            updateApplyButton(this)
            
            %Signal settings
            if ~isempty(this.SignalSpecPanel)
                updatePanel(this.SignalSpecPanel)
            end

            %Parameter value settings
            if ~isempty(this.ParameterSpecPanel)
                updatePanel(this.ParameterSpecPanel)
            end
            
            %Boundary settings
            if ~isempty(this.BoundarySpecPanel)
                updatePanel(this.BoundarySpecPanel)
            end
            toggleBoundaryPanel(this)

            %Refresh warning/error message
            updateMessage(this)
        end

        function updateMessage(this)
            enoughSamples = hasEnoughSamples(this.VisibleSpec);
            ignoreBoundary = false;
            ignoreMethod = false;
            if (hasSignalBoundary(this.VisibleSpec)) && ~isempty(this.VisibleSpec.SignalSpec)
                if ~isRandom(this.VisibleSpec.SignalSpec)
                    ignoreBoundary = true;
                end
                if strcmpi(this.VisibleSpec.BoundarySpec.Method,'project') && strcmpi(this.VisibleSpec.SignalSpec.TYPE,"PRBS")
                    ignoreMethod = true;
                end
            end
            if ~enoughSamples
                matlab.graphics.internal.themes.specifyThemePropertyMappings(this.Widgets.lblError,'FontColor','--mw-color-error');
                this.Widgets.lblError.Text = romapp.internal.resources.getString('errNoFactors');
            elseif ignoreBoundary
                matlab.graphics.internal.themes.specifyThemePropertyMappings(this.Widgets.lblError,'FontColor','--mw-color-warning');
                this.Widgets.lblError.Text = romapp.internal.resources.getString('errIgnoreBoundaries');
            elseif ignoreMethod
                matlab.graphics.internal.themes.specifyThemePropertyMappings(this.Widgets.lblError,'FontColor','--mw-color-warning');
                this.Widgets.lblError.Text = romapp.internal.resources.getString('errIgnoreMethod');
            else
                this.Widgets.lblError.Text = "";
            end            
        end

        function inputsAreValid = validateInputs(this)
            if isempty(this.SignalSpecPanel)
                inputsAreValid = true;
            else
                inputsAreValid = validateInputs(this.SignalSpecPanel);
            end
        end

        function cbApply(this)
            if validateInputs(this)
                updateSpec(this)
                this.Dirty = false;
                updatePanel(this) 
            end
        end

        function manageDirtyState(this,hSrc)
            this.Dirty = hSrc.AffectedObject.Dirty;
            updateApplyButton(this)
        end

        function updateApplyButton(this)
            if this.Dirty
                this.Widgets.btnApply.Enable = 'on';
            else
                this.Widgets.btnApply.Enable = 'off';
            end
        end
    end

    methods(Hidden)
        function wdgts = getWidgets(this)

            wdgts = struct(...
                'SignalPanel', this.SignalSpecPanel, ...
                'ParameterPanel', this.ParameterSpecPanel, ...
                'BoundaryPanel', this.BoundarySpecPanel, ...
                'btnApply', this.Widgets.btnApply, ...
                'tpnlParams', this.Widgets.tpnlParams, ...
                'tpnlSignals', this.Widgets.tpnlSignals);
        end
        function tf = qeDirtyState(this,newvalue)
            if nargin < 2
                tf = this.Dirty;
            else
                this.Dirty = newvalue;
                updatePanel(this)
            end
        end
    end

end

% LocalWords: btn lbl edt ttip tpnl PRBS PRSS grp PRPS