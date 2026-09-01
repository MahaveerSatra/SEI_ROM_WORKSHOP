classdef SignalSpec <  matlab.mixin.SetGet
    %

    % SIGNALSPEC

    % Copyright 2022-2025 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        Widgets
        VisibleSpec
        Layout

        MethodSpecPanel
    end

    properties(SetAccess = private, WeakHandle)
        AllPanel romapp.internal.panels.SimulationSetConfigureAll = romapp.internal.panels.SimulationSetConfigureAll.empty;
    end

    properties(GetAccess = public, SetAccess = private, SetObservable = true)
        Dirty logical
    end

    methods
        function this = SignalSpec(AllPanel,tool,parent)
            % SIGNALSPEC
            this.AllPanel = AllPanel;
            this.Tool = tool;
            this.Widgets = struct();
            this.Dirty = true;

            %Set the default visible spec
            data = getToolData(this.Tool);
            this.VisibleSpec = data.SimulationSpec(1);

            %Build the panel and update the panel
            buildPanel(this,parent)
            %updatePanel(this)

            %Connect the panel to the data source
            connectPanel(this)
        end

        function delete(~)

        end

        function refreshPanel(this)
            data = getToolData(this.Tool);
            this.VisibleSpec = data.SignalSpec(1);
            setVisibleSpec(this.MethodSpecPanel,this.VisibleSpec)
            updatePanel(this)
        end

        function updatePanel(this)

            this.Widgets.ddMethod.Value = this.VisibleSpec.SignalSpec.TYPE;
            this.Widgets.ddMode.Value = this.VisibleSpec.SignalSpec.Mode;

            updatePanel(this.MethodSpecPanel)
        end
        
        function inputsAreValid = validateInputs(this)
            inputsAreValid = validateInputs(this.MethodSpecPanel);
        end

        function updateSpec(this)
            updateSpec(this.MethodSpecPanel)
        end

        function setVisibleSpec(this,spec)

            this.VisibleSpec = spec;
            if lPanelMatchesData(this.VisibleSpec.SignalSpec,this.MethodSpecPanel)
                setVisibleSpec(this.MethodSpecPanel,spec.SignalSpec)
            else
                configureMethodSpecPanel(this,2,[1 2])
            end
        end

        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
            wdgts.MethodSpecPanel = this.MethodSpecPanel;
        end
        
        function updateDirtySpec(this,spec)
            spec.SignalSpec = getIntermSignalSpec(this);
        end
        
    end

    methods(Access = protected)
        function setDirty(this,dirty)
            this.Dirty = dirty;
        end
    end

    methods (Access=private)
        function buildPanel(this,parent)

            layout = uigridlayout(parent,[3 2]);
            layout.RowHeight = {'fit','1x'};
            layout.ColumnWidth = {'fit','1x'};
            layout.Padding = [0 0 0 0];
            this.Layout = layout;

            %Method, & mode widgets
            layoutSimMM = uigridlayout(layout, [2 3]);
            layoutSimMM.Layout.Row = 1;
            layoutSimMM.Layout.Column = [1 2];
            layoutSimMM.RowHeight = {'fit', 'fit'};
            layoutSimMM.ColumnWidth = {'fit', 'fit', '1x'};
            layoutSimMM.Padding = 5;
            labelMode = uilabel(layoutSimMM);
            labelMode.Text = romapp.internal.resources.getString('lblInjectionMode');
            labelMode.Layout.Row = 1;
            labelMode.Layout.Column = 1;
            dropdownMode = uidropdown(layoutSimMM);
            dropdownMode.Layout.Row = 1;
            dropdownMode.Layout.Column = 2;
            dropdownMode.Items = [...
                string(romapp.internal.resources.getString('lblInjectionMode_Replace')), ...
                string(romapp.internal.resources.getString('lblInjectionMode_Add'))];
            dropdownMode.ItemsData = {'replace', 'add'};
            dropdownMode.Value = 'replace';
            labelMethods = uilabel(layoutSimMM);
            labelMethods.Text = romapp.internal.resources.getString('lblSignalSpecMethod');
            labelMethods.Layout.Row = 2;
            labelMethods.Layout.Column = 1;
            dropdownMethod = uidropdown(layoutSimMM);
            dropdownMethod.Layout.Row = 2;
            dropdownMethod.Layout.Column = 2;
            if ~isempty(ver('stats')) && license('test','Statistics_Toolbox')
                dropdownMethod.Items = [...
                    romapp.internal.data.PRSignalSpec.DESCRIPTION; ...
                    romapp.internal.data.PRBSSignalSpec.DESCRIPTION; ...
                    romapp.internal.data.PRSSSignalSpec.DESCRIPTION; ...
                    romapp.internal.data.FSCSignalSpec.DESCRIPTION; ...
                    romapp.internal.data.CustomSignalSpec.DESCRIPTION];
                dropdownMethod.ItemsData = {...
                    romapp.internal.data.PRSignalSpec.TYPE; ...
                    romapp.internal.data.PRBSSignalSpec.TYPE; ...
                    romapp.internal.data.PRSSSignalSpec.TYPE; ...
                    romapp.internal.data.FSCSignalSpec.TYPE; ...
                    romapp.internal.data.CustomSignalSpec.TYPE};
            else
                dropdownMethod.Items = [...
                    romapp.internal.data.PRSignalSpec.DESCRIPTION; ...
                    romapp.internal.data.PRBSSignalSpec.DESCRIPTION; ...
                    romapp.internal.data.FSCSignalSpec.DESCRIPTION; ...
                    romapp.internal.data.CustomSignalSpec.DESCRIPTION];
                dropdownMethod.ItemsData = {...
                    romapp.internal.data.PRSignalSpec.TYPE; ...
                    romapp.internal.data.PRBSSignalSpec.TYPE; ...
                    romapp.internal.data.FSCSignalSpec.TYPE; ...
                    romapp.internal.data.CustomSignalSpec.TYPE};
            end
            dropdownMethod.Value = romapp.internal.data.PRSignalSpec.TYPE;
            
            %Widgets for method panel
            configureMethodSpecPanel(this,2,[1 2])
            
            %Store the widgets
            this.Widgets = struct(...
                'ddMethod', dropdownMethod, ...
                'ddMode', dropdownMode);
        end

        function connectPanel(this)
            addlistener(this.Widgets.ddMethod,'ValueChanged', @(hSrc,hData) cbMethod(this));
            addlistener(this.Widgets.ddMode,'ValueChanged', @(hSrc,hData) cbMode(this));
        end

        function cbMethod(this)            
            if ~isequal(this.Widgets.ddMethod.Value,this.VisibleSpec.SignalSpec.TYPE)
                intermSignalSpec = getIntermSignalSpec(this);
                convertSignalSpec(this.VisibleSpec,this.Widgets.ddMethod.Value,intermSignalSpec)    
                setDirty(this,true)         
            end
            configureMethodSpecPanel(this,2,[1 2])
            toggleBoundaryPanel(this.AllPanel)
        end

        function intermSignalSpec = getIntermSignalSpec(this)
            if validateInputs(this)
                intermSignalSpec = copy(this.MethodSpecPanel.Spec);
                updateSpec(this.MethodSpecPanel,intermSignalSpec) %To push any edits to an intermediate spec so the conversion can use them     
            else
                intermSignalSpec = this.MethodSpecPanel.Spec; %If inputs are invalid, use the most updated signal spec
            end
        end

        function cbMode(this)
            mode = this.Widgets.ddMode.Value;
            if ~isequal(mode,this.VisibleSpec.SignalSpec.Mode)
                this.VisibleSpec.SignalSpec.Mode = mode;
                setDirty(this,true)
            end
        end

        function configureMethodSpecPanel(this, row, col)

            [matches,pnlClass] = lPanelMatchesData(this.VisibleSpec.SignalSpec,this.MethodSpecPanel);
            if ~matches
                switch pnlClass
                    case 'romapp.internal.panels.PRSignalSpec'
                        pnl = romapp.internal.panels.PRSignalSpec(this.Tool, this.VisibleSpec.SignalSpec, this.Layout, row, col);
                    case 'romapp.internal.panels.PRBSSignalSpec'
                        pnl = romapp.internal.panels.PRBSSignalSpec(this.Tool, this.VisibleSpec.SignalSpec, this.Layout, row, col);
                    case 'romapp.internal.panels.PRSSSignalSpec'
                        pnl = romapp.internal.panels.PRSSSignalSpec(this.Tool, this.VisibleSpec.SignalSpec, this.Layout, row, col);
                    case 'romapp.internal.panels.FSCSignalSpec'
                        pnl = romapp.internal.panels.FSCSignalSpec(this.Tool, this.VisibleSpec.SignalSpec, this.Layout, row, col);
                    case 'romapp.internal.panels.CustomSignalSpec'
                        pnl = romapp.internal.panels.CustomSignalSpec(this.Tool, this.VisibleSpec.SignalSpec, this.Layout, row, col);
                end
                oldPnl = this.MethodSpecPanel;
                this.MethodSpecPanel = pnl;
                delete(oldPnl)
                weak = romapp.internal.resources.WeakReference(this);
                addlistener(this.MethodSpecPanel,'ValueChanged',@(hSrc,hData) setDirty(weak.Handle,true));
            end
        end
    end

    methods(Access = public, Hidden = true)
        function qeSetDirty(this,value)
            setDirty(this,value)
        end
    end
end

function [tf,pnlClass] = lPanelMatchesData(data,panel)

switch class(data)
    case 'romapp.internal.data.PRSignalSpec'
        pnlClass = 'romapp.internal.panels.PRSignalSpec';
    case 'romapp.internal.data.PRBSSignalSpec'
        pnlClass = 'romapp.internal.panels.PRBSSignalSpec';
    case 'romapp.internal.data.PRSSSignalSpec'
        pnlClass = 'romapp.internal.panels.PRSSSignalSpec';
    case 'romapp.internal.data.FSCSignalSpec'
        pnlClass = 'romapp.internal.panels.FSCSignalSpec';
    case 'romapp.internal.data.CustomSignalSpec'
        pnlClass = 'romapp.internal.panels.CustomSignalSpec';
    otherwise
        romapp.internal.resources.error('errUnexpected','Unexpected parameter data class')
end

tf = isa(panel,pnlClass);
end

% LocalWords:  PRPS btn lbl edt PRBSSignalSpec PRSSSignalSpec FSCSignalSpec
