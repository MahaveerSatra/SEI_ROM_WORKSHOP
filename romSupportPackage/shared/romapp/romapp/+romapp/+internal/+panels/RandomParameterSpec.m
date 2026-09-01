classdef RandomParameterSpec <  handle
    %

    % RandomParameterSpec
    %
    % Panel to display/set random parameter data

    % Copyright 2023-2026 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        ParameterTable
        Widgets

        Spec romapp.internal.data.RandomParameterSpec

        EditDistributionsDialog
    end

    events(NotifyAccess = protected)
        ValueChanged
    end

    methods
        function this = RandomParameterSpec(tool,spec,parent,row,col)
            % GriddedParameterSpec

            this.Widgets = struct();

            %Set the tool and spec
            this.Tool = tool;
            this.Spec = spec;

            %Build the panel and update the panel
            buildPanel(this,parent,row,col)
            updatePanel(this)

            %Connect the panel to the data source
            connectPanel(this)
        end

        function updatePanel(this)

            %data = getToolData(this.Tool);

            %Parameter value settings
            spec = this.Spec;
            %names = getShortPortName(data,spec.Parameters);
            names = romapp.internal.data.ModelPorts.getDisplayName(spec.Parameters);
            dist = spec.Distributions;
            nParam = numel(names);
            tbldata = cell(nParam,2);
            for ct=1:nParam
                tbldata{ct,1} = char(names(ct));
                tbldata{ct,2} = char(lDist2String(dist(ct)));
            end
            this.ParameterTable.Data = tbldata;

            %Num samples settings
            this.Widgets.edtNumSamples.Value = spec.getNumSim;
        end

        function updateSpec(this,spec)


            if nargin < 2
                %Only widgets on this panel have changed.
                nSample = this.Widgets.edtNumSamples.Value;
                this.Spec.setNumSim(nSample)
            else
                %Have a new spec from distribution dialog
                updateSpec(this.Spec,spec)
            end
        end

        function updateDirtySpec(this,spec)
            % get a copy of the current dirty panel to pass to
            % SimulationSetConfigureAll to pass to BoundarySpecPanel
            if isempty(this.EditDistributionsDialog)
                newSpec = copy(this.Spec);
            else
                newSpec = getSpec(this.EditDistributionsDialog);
            end
            nSample = this.Widgets.edtNumSamples.Value;
            newSpec.setNumSim(nSample)
            updateSpec(spec,newSpec)
        end

        function setVisibleSpec(this,spec)

            this.Spec = spec;
        end

        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
            wdgts.ParameterTable = this.ParameterTable;
            wdgts.dlgEditDistributions = this.EditDistributionsDialog;
        end

    end

    methods (Access=private)
        function buildPanel(this,parent,row,col)


            layout = uigridlayout(parent,[3 3]);
            layout.RowHeight = {'fit','1x','fit'};
            layout.ColumnWidth = {'fit','fit','1x'};
            layout.Padding = [1 1 1 1];
            layout.Layout.Row = row;
            layout.Layout.Column = col;

            %Edit field for number of samples
            lblNumSamples = uilabel(layout);
            lblNumSamples.Layout.Row = 1;
            lblNumSamples.Layout.Column = 1;
            lblNumSamples.Text = romapp.internal.resources.getString('lblParameterSpec_NumSamples');
            edtNumSamples = uispinner(layout);
            edtNumSamples.Layout.Row = 1;
            edtNumSamples.Layout.Column = 2;
            edtNumSamples.Limits = [1 inf];
            edtNumSamples.RoundFractionalValues = 'on';
            edtNumSamples.UpperLimitInclusive = 'off';

            %Table for distributions
            parameterTable = uitable(layout);
            parameterTable.Layout.Row = 2;
            parameterTable.Layout.Column = [1 3];
            vars = {...
                romapp.internal.resources.getString('lblParameterSpec_Parameter'), ...
                romapp.internal.resources.getString('lblParameterSpec_Distribution')};
            parameterTable.ColumnName = vars;
            parameterTable.ColumnWidth = {'1x', '1x'};
            parameterTable.ColumnEditable = [false false];
            parameterTable.ColumnFormat = {'char','char'};
            this.ParameterTable = parameterTable;
            this.ParameterTable.ContextMenu = createParameterTableContextMenu(this,parent);
            this.ParameterTable.DoubleClickedFcn = @(hSrc,hData) cbEditDistributions(this);

            %Button to edit distributions
            btnEdit = uibutton(layout);
            btnEdit.Layout.Row = 3;
            btnEdit.Layout.Column = 1;
            btnEdit.Text = romapp.internal.resources.getString('lblParameterSpec_EditDistributions');

            %Store the widgets
            this.Widgets = struct(...
                'tbl', parameterTable, ...
                'edtNumSamples', edtNumSamples, ...
                'btnEdit', btnEdit);
        end

        function connectPanel(this)

            addlistener(this.Widgets.edtNumSamples,'ValueChanged', @(hSrc,hData) cbNumSamples(this));
            addlistener(this.Widgets.btnEdit,'ButtonPushed', @(hSrc,hData) cbEditDistributions(this));
        end

        function contextMenu = createParameterTableContextMenu(this,parent)

            contextMenu = uicontextmenu('Parent', romapp.internal.dialogs.findParentFigure(parent));

            %Edit
            editMenuItem = uimenu(contextMenu, ...
                'Text', romapp.internal.resources.getString('lblEditWithEllipses'), ...
                'Tag','EditParameterDistributions');
            editMenuItem.MenuSelectedFcn = @(src,evt)cbEditDistributions(this);
        end

        function cbNumSamples(this)

            value = max(1,floor(this.Widgets.edtNumSamples.Value));
            if ~isequal(value,this.Widgets.edtNumSamples.Value)
                updatePanel(this)
            end

            notify(this,'ValueChanged')
        end

        function cbEditDistributions(this)

            if isempty(this.EditDistributionsDialog) || ~isvalid(this.EditDistributionsDialog)
                dlg = romapp.internal.dialogs.EditDistributionsDialog(this.Spec);
                weak = romapp.internal.resources.WeakReference(this);
                addlistener(dlg,'SpecChanged', @(hSrc,hData) cbDistributionsEdited(weak.Handle,hSrc));
                this.EditDistributionsDialog = dlg;
            else
                dlg = this.EditDistributionsDialog;
            end
            appContainer = get(getApp(this.Tool), 'Container');
            show(dlg, appContainer, 'CENTER')
            wd = dlg.getWidget;
            alreadyRegistered = hasDialog(getApp(this.Tool), wd.Tag);
            if ~alreadyRegistered
                registerDialog(getApp(this.Tool),wd)
            end
        end

        function cbDistributionsEdited(this,hSrc)
            %cbDistributionsEdited
            %
            % Manage spec updated events from the distributions dialog. The
            % dialog has copy of the spec, so we need to ensure that the
            % tool data uses the updated copy.

            %Push the new spec to the tool data. Does not change "Apply"
            %button of spec panel but does apply all randomspec changes.
            newSpec = getSpec(hSrc);
            nSample = this.Widgets.edtNumSamples.Value;
            newSpec.setNumSim(nSample)
            if ~isequal(this.Spec,newSpec)
                updateSpec(this,newSpec)
            
                %Update the panel with the edited data.
                updatePanel(this)

                %Notify view that data changed, needed to trigger dirty state
                %and modify "Apply" button.
                notify(this,'ValueChanged')
            end
        end
    end
end

function str = lDist2String(dist)

if strcmp(dist.DistributionName,'Piecewise Linear') || ...
        strcmp(dist.DistributionName,'Multinomial')
    str = string(dist.DistributionName) + "( #points = " + numel(dist.ParameterValues{1})+")";
else
    str = string(dist.DistributionName) + "(";
    for ct=1:numel(dist.ParameterNames)
        str = str+dist.ParameterNames{ct}+"="+dist.ParameterValues(ct);
        if ct < numel(dist.ParameterNames)
            str = str+", ";
        end
    end
    str = str+")";
end
end

% LocalWords:  btn lbl edt tbl cb randomspec