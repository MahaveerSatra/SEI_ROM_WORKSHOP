classdef ParameterSpec <  matlab.mixin.SetGet
    %

    % ParameterSpec
    %
    % Panel to display parameter data

    % Copyright 2023-2025 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        ParameterTable
        Widgets
        VisibleSpec
        Layout %Layout container for all the widgets

        MethodSpecPanel
    end

    properties(GetAccess = public, SetAccess = private, SetObservable = true)
        Dirty logical
    end

    methods
        function this = ParameterSpec(tool,parent)
            % ParameterSpec

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
        end

        function delete(~)

        end

        function refreshPanel(this)
            data = getToolData(this.Tool);
            this.VisibleSpec = data.ParameterSpec(1);
            configure
            setVisibleSpec(this.MethodSpecPanel,this.VisibleSpec);
            updatePanel(this)
        end

        function updatePanel(this)

            switch class(this.VisibleSpec.ParameterSpec)
                case 'romapp.internal.data.GriddedParameterSpec'
                    this.Widgets.ddMethod.Value = 'gridded';
                case 'romapp.internal.data.RandomParameterSpec'
                    this.Widgets.ddMethod.Value = 'random';
            end
            updatePanel(this.MethodSpecPanel)
        end

        function updateSpec(this)
            updateSpec(this.MethodSpecPanel)
        end

        function updateDirtySpec(this,spec)
            intermParameterSpec = copy(this.MethodSpecPanel.Spec);
            updateDirtySpec(this.MethodSpecPanel,intermParameterSpec);
            spec.ParameterSpec = intermParameterSpec;
        end

        function setVisibleSpec(this,spec)
            this.VisibleSpec = spec; %spec.ParameterSpec;
            configureMethodSpecPanel(this,2,[1 3])
            setVisibleSpec(this.MethodSpecPanel,this.VisibleSpec.ParameterSpec)
            updatePanel(this)
        end

        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
            wdgts.MethodSpecPanel = this.MethodSpecPanel;
        end
    end

    methods(Access = protected)
        function setDirty(this,dirty)
            this.Dirty = dirty;
        end
    end

    methods (Access=private)
        function buildPanel(this,parent)

            
            layout = uigridlayout(parent,[3 3]);
            layout.RowHeight = {'fit','1x','fit'};
            layout.ColumnWidth = {'fit','fit','1x'};
            layout.Padding = 5;
            this.Layout = layout;

            %Method combobox
            lblMethod = uilabel(layout);
            lblMethod.Layout.Row = 1;
            lblMethod.Layout.Column = 1;
            lblMethod.Text = romapp.internal.resources.getString('lblParameterSpecMethod');
            ddMethod = uidropdown(layout);
            ddMethod.Layout.Row = 1;
            ddMethod.Layout.Column = 2;
            ddMethod.Items = {...
                romapp.internal.resources.getString('lblParameterSpecMethod_Values'), ...
                romapp.internal.resources.getString('lblParameterSpecMethod_Distribution')};
            ddMethod.ItemsData = {'gridded','random'};
            ddMethod.Value = ddMethod.ItemsData{1};

            %Widgets for parameter selection method
            configureMethodSpecPanel(this,2,[1 3])
                        
            %Store the widgets
            this.Widgets = struct(...
                'ddMethod', ddMethod);
        end

        function configureMethodSpecPanel(this,row,col)

            
            [matches,pnlClass] = lPanelMatchesData(this.VisibleSpec.ParameterSpec,this.MethodSpecPanel);
            if ~matches
                switch pnlClass
                    case 'romapp.internal.panels.GriddedParameterSpec'
                        pnl = romapp.internal.panels.GriddedParameterSpec(this.Tool, this.VisibleSpec.ParameterSpec, this.Layout, row, col);
                    case 'romapp.internal.panels.RandomParameterSpec'
                        pnl = romapp.internal.panels.RandomParameterSpec(this.Tool, this.VisibleSpec.ParameterSpec, this.Layout, row, col);
                end
                oldPnl = this.MethodSpecPanel;
                this.MethodSpecPanel = pnl;
                delete(oldPnl)
                weak = romapp.internal.resources.WeakReference(this);
                addlistener(this.MethodSpecPanel,'ValueChanged',@(hSrc,hData) setDirty(weak.Handle,true));
            end
        end

        function connectPanel(this)
            weak = romapp.internal.resources.WeakReference(this);
            addlistener(this.Widgets.ddMethod,'ValueChanged', @(hSrc,hData) cbMethod(weak.Handle));
        end

        function cbMethod(this)

            method = this.Widgets.ddMethod.Value;

            switch method
                case 'gridded'
                    convertToGridded(this.VisibleSpec)
                case 'random'
                    convertToRandom(this.VisibleSpec,getParameterRanges(this.MethodSpecPanel))
            end
            configureMethodSpecPanel(this,2,[1 3])
            setDirty(this,true)
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
    case 'romapp.internal.data.GriddedParameterSpec'
        pnlClass = 'romapp.internal.panels.GriddedParameterSpec';
    case 'romapp.internal.data.RandomParameterSpec'
        pnlClass = 'romapp.internal.panels.RandomParameterSpec';
    otherwise
        romapp.internal.resources.error('errUnexpected','Unexpected parameter data class')
end

tf = isa(panel,pnlClass);
end

% LocalWords:  btn lbl edt
