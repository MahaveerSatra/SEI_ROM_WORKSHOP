classdef BoundarySpec < handle
    %

    % BoundarySpec
    %
    % Panel to display boundary data

    % Copyright 2024-2025 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        VisibleSpec

        Widgets

        Spec % local BoundarySpec
    end

    properties(SetAccess=?matlab.unittest.TestCase)
        EditBoundariesDialog
    end

    properties(SetAccess = private, WeakHandle)
        AllPanel romapp.internal.panels.SimulationSetConfigureAll = romapp.internal.panels.SimulationSetConfigureAll.empty;
    end

    events(NotifyAccess = protected)
        ValueChanged
    end

    properties(GetAccess = public, SetAccess = private, SetObservable = true)
        Dirty logical
    end

    methods
        function this = BoundarySpec(AllPanel, tool, parent)
            %BoundarySpec
            this.AllPanel = AllPanel;
            this.Tool = tool;
            data = getToolData(this.Tool);
            this.VisibleSpec = data.SimulationSpec(1);
            this.Spec = copy(this.VisibleSpec.BoundarySpec);
            this.Widgets = struct();

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
            this.VisibleSpec = data.SimulationSpec(1);
            if ~isempty(this.EditBoundariesDialog)
                close(this.EditBoundariesDialog);
                this.EditBoundariesDialog = [];
            end
            updatePanel(this)
        end

        function setVisibleSpec(this,spec)
            this.VisibleSpec = spec;
            this.Spec = copy(this.VisibleSpec.BoundarySpec);
        end

        function updateTable(this,varargin)
            if nargin>1
                spec = varargin{1};
            else
                spec = this.Spec;
            end
            tbldata = cell(0,3);
            if ~isempty(spec.Factors)
                nBoundaries = numel(spec.Factors);
                for iBoundary = 1:nBoundaries
                    factors = spec.Factors{iBoundary};
                    tbldata{iBoundary,1} = char(factors(1));
                    tbldata{iBoundary,2} = char(factors(2));
                    tbldata{iBoundary,3} = getTypeString(spec,iBoundary);
                end
            end
            tbldata{end+1,1} = '';
            this.Widgets.tblBdry.Data = tbldata;
        end

        function updateDropdown(this)
            if isempty(this.Spec.Method)
                this.Widgets.ddMethod.Value = 'resample';
            else
                this.Widgets.ddMethod.Value = this.Spec.Method;
            end
        end

        function updatePanel(this)
            updateDropdown(this)
            updateTable(this,this.VisibleSpec.BoundarySpec)
        end

        function updateSpec(this)
            replaceBoundaries(this.VisibleSpec.BoundarySpec, this.Spec);
        end

        function dirtySpec = getDirtySpec(this)
            % create a new data.BoundarySpec to store the dirty inputs to
            % check for conflicting boundaries.
            % there are three data.BoudarySpec in use.
            % - one associated with the SimulationSpec, this.VisibleSpec
            % - one associated with EditBoundaryDialog to store before
            % pushing to SimulationSpec, this.Spec
            % - one stores dirty inputs to check for conflicting boundaries,
            % dirtySpec

            % get the panel inputs
            wdgts = getWidgets(this.EditBoundariesDialog);
            nameFactor1 = wdgts.ddFactor1.Value;
            nameFactor2 = wdgts.ddFactor2.Value;
            nType = wdgts.ddBoundaryType.Value;
            ind = findBoundaryIndex(nameFactor1, nameFactor2, this.Spec);
            pnl = getPanel(this.EditBoundariesDialog);

            dirtySpec = copy(this.Spec);
            if strcmpi('piecewiselinear',nType)
                Factors = [string(nameFactor1), string(nameFactor2)];
                Type = string(nType);
                Inequality = pnl.Widgets.ddIneq.Value;
                Data = pnl.Data;
                Connect = pnl.Widgets.chkConnect.Value;
                setProps(dirtySpec, ind, Factors, Type, Inequality, Data, Connect);
            elseif strcmpi('elliptical',nType)
                Factors = [string(nameFactor1), string(nameFactor2)];
                Type = string(nType);
                Inequality = pnl.Widgets.ddIneq.Value;
                Data = pnl.Data;
                Connect = [];
                setProps(dirtySpec, ind, Factors, Type, Inequality, Data, Connect);
            elseif strcmpi('none',nType)
                if ~isempty(this.Spec.Factors)
                    nBoundaries = numel(this.Spec.Factors);
                    if ind<=nBoundaries
                        setProps(dirtySpec,ind);
                    end
                end
            else
                error('Invalid boundary type')
            end
        end

        function [dirtySpec,nonConflicting,conflictingFactor] = validateIntervals(this)
            %Check if the dirtySpec is feasible
            if isempty(this.EditBoundariesDialog)
                nonConflicting = true;
                conflictingFactor = [];
                dirtySpec = romapp.internal.data.BoundarySpec;
                return
            end
            dirtySpec = getDirtySpec(this);
            wdgts = getWidgets(this.EditBoundariesDialog);
            nameFactor1 = wdgts.ddFactor1.Value;
            nameFactor2 = wdgts.ddFactor2.Value;
            [nonConflicting,conflictingFactor] = validateIntervals(dirtySpec,nameFactor1,this.VisibleSpec);
            if ~nonConflicting
                return
            else
                [nonConflicting,conflictingFactor] = validateIntervals(dirtySpec,nameFactor2,this.VisibleSpec);
            end
        end

        function getSpec(this)
            if isempty(this.EditBoundariesDialog)
                return
            end
            
            % This code should be called after checking for conflicting
            % boundaries in dirtySpec. 
            % Update this.Spec to dirtySpec to include/update the in-view
            % boundary. 
            dirtySpec = getDirtySpec(this);
            this.Spec = copy(dirtySpec);
            updateTable(this,this.Spec);
            setDirty(this,true);
        end

        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
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
            layout.ColumnWidth = {'fit','1x'};
            layout.Padding = 5;

            %Point removal method combobox
            lblMethod = uilabel(layout);
            lblMethod.Layout.Row = 1;
            lblMethod.Layout.Column = 1;
            lblMethod.Text = romapp.internal.resources.getString('lblBoundary_RemovalMethod');

            ddMethod = uidropdown(layout);
            ddMethod.Layout.Row = 1;
            ddMethod.Layout.Column = 2;
            ddMethod.Items = {...
                romapp.internal.resources.getString('lblBoundary_RejectPoint'), ...
                romapp.internal.resources.getString('lblBoundary_ProjectPoint')};
            ddMethod.ItemsData = {'resample','project'};
            ddMethod.Value = ddMethod.ItemsData{1};

            %Boundary table
            tblBdry = uitable(layout);
            tblBdry.Layout.Row = 2;
            tblBdry.Layout.Column = [1 2];
            vars = {...
                romapp.internal.resources.getString('lblBoundary_Factor1_twolines'), ...
                romapp.internal.resources.getString('lblBoundary_Factor2_twolines'), ...
                romapp.internal.resources.getString('lblBoundary')};
            tblBdry.ColumnName = vars;
            tblBdry.ColumnWidth = {'1x', '1x', '1x'};
            tblBdry.ColumnEditable = [false,false,false];
            tblBdry.ColumnFormat = {'char','char','char'};
            tblBdry.SelectionType = 'row';
            tblBdry.ContextMenu = createBoundaryTableContextMenu(this,parent);

            btnEdit = uibutton(layout);
            btnEdit.Layout.Row = 3;
            btnEdit.Layout.Column = 1;
            btnEdit.Text = romapp.internal.resources.getString('lblBoundary_EditBoundaries_Btn');

            %Store the widgets
            this.Widgets = struct(...
                'txtMethod', lblMethod,...
                'ddMethod', ddMethod,...
                'tblBdry', tblBdry,...
                'btnEdit', btnEdit);
        end

        function cbEditBoundaries(this,StartupFactors)
            % If a dialog is already visible, don't do anything after
            % button/table clicked.
            dlgVisible = false;
            if ~isempty(this.EditBoundariesDialog)
                if this.EditBoundariesDialog.IsVisible
                    dlgVisible = true;
                end
            end
            % If an EditBoundaries dialog window is now visible:
            %
            % Get the latest spec
            %
            % Create a new dialog and attach it to this class. This will
            % ensure only one dialog is visible and attached to this class.
            %
            % Show the dialog window.
            %
            % Disable all factor panels if the dialog is visible.
            if ~dlgVisible
                DirtyVisibleSpec = getDirtyVisibleSpec(this.AllPanel);
                dlg = romapp.internal.dialogs.EditBoundariesDialog(this, DirtyVisibleSpec, StartupFactors);
                this.EditBoundariesDialog = dlg;
                appContainer = get(getApp(this.Tool), 'Container');
                show(dlg, appContainer, 'CENTER')
                toggleFactorPanels(this,false);
                wd = dlg.getWidget;
                alreadyRegistered = hasDialog(getApp(this.Tool), wd.Tag);
                if ~alreadyRegistered
                    registerDialog(getApp(this.Tool),wd)
                end
            end
        end

        function connectPanel(this)
            weak = romapp.internal.resources.WeakReference(this);
            addlistener(this.Widgets.btnEdit,'ButtonPushed', @(hSrc,hData) cbEditBoundaries(weak.Handle,[]));
            addlistener(this,'ValueChanged',@(hSrc,hData) setDirty(weak.Handle,true));
            this.Widgets.ddMethod.ValueChangedFcn = @(hSrc,hData) cbRemovalMethod(weak.Handle);
            this.Widgets.tblBdry.DoubleClickedFcn = @(hSrc,hData) cbDoubleClickTable(weak.Handle,hSrc,hData);
        end

        function cbDoubleClickTable(this,hSrc,hData)
            row = hData.InteractionInformation.DisplayRow;
            if isempty(row)
                StartupFactors = [];
            else
                StartupFactors = hSrc.Data(row,[1,2]);
            end
            if iscell(StartupFactors)
                if all(cellfun(@isempty, StartupFactors))
                    StartupFactors = [];
                end
            end
            cbEditBoundaries(this,StartupFactors);
        end

        function cbClose(this)
            toggleFactorPanels(this,true)
        end

        function contextMenu = createBoundaryTableContextMenu(this,parent)
            contextMenu = uicontextmenu('Parent',romapp.internal.dialogs.findParentFigure(parent));
            editMenuItem = uimenu(contextMenu, ...
                'Text', romapp.internal.resources.getString('lblEditWithEllipses'), ...
                'Tag','EditBoundaries');
            deleteMenuItem = uimenu(contextMenu, ...
                'Text', romapp.internal.resources.getString('lblDelete'), ...
                'Tag','DeleteBoundaries');
            weak = romapp.internal.resources.WeakReference(this);
            contextMenu.ContextMenuOpeningFcn = @(src,evt) cbSelectRow(weak.Handle,src,evt);
            editMenuItem.MenuSelectedFcn = @(src,evt) cbEditMenu(weak.Handle,src,evt);
            deleteMenuItem.MenuSelectedFcn = @(src,evt) cbDeleteMenu(weak.Handle,evt);

        end

        function cbSelectRow(this,src,evt)
            row = evt.InteractionInformation.DisplayRow;
            this.Widgets.tblBdry.Selection = row;
        end

        function cbEditMenu(this,src,evt)
            row = evt.InteractionInformation.DisplayRow;
            if isempty(row)
                StartupFactors = [];
            else
                StartupFactors =this.Widgets.tblBdry.Data(row,[1,2]);
            end
            if all(cellfun(@isempty, StartupFactors))
                StartupFactors = [];
            end
            cbEditBoundaries(this,StartupFactors);
        end

        function cbDeleteMenu(this,evt)
            row = evt.InteractionInformation.DisplayRow;
            removeBoundary(this,row);
            setDirty(this,true);
        end

        function removeBoundary(this,row)
            removeBoundary(this.Spec,row);
            updateTable(this);
        end

        function cbRemovalMethod(this)
            setMethod(this.Spec, this.Widgets.ddMethod.Value)
            setDirty(this,true)
        end
    end

    methods(Access=public)
        function toggleFactorPanels(this,tf)
            toggleFactorPanels(this.AllPanel,tf)
        end
    end

    methods(Access = ?matlab.unittest.TestCase, Hidden = true)
        function qeSetDirty(this,value)
            setDirty(this,value)
        end
        function qeDoubleClickTable(this,hSrc,hData)
            cbDoubleClickTable(this,hSrc,hData);
        end
    end
end

function ind = findBoundaryIndex(nameFactor1, nameFactor2, spec)
if isempty(spec.Factors)
    ind = 1;
else
    nBoundaries = numel(spec.Factors);
    for iBoundary = 1:nBoundaries
        eFactors = spec.Factors{iBoundary};
        eFactor1 = eFactors(1);
        eFactor2 = eFactors(2);
        if (strcmp(eFactor1,nameFactor1) && strcmp(eFactor2,nameFactor2)) || ...
                (strcmp(eFactor1,nameFactor2) && strcmp(eFactor2,nameFactor1))
            ind = iBoundary;
            return
        end
    end
    ind = nBoundaries+1;
end
end

% LocalWords:  btn lbl edt piecewiselinear twolines tbl tblBdry
