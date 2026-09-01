classdef SimulationSet < matlab.ui.internal.databrowser.TableDataBrowser
    %
    
    
    % Copyright 2021-2025 The MathWorks, Inc.
    
    properties (SetAccess = private, GetAccess = public)
        App
        Data
        Dialog
        SelectionListener
        Tag
    end
    
    methods
        function this = SimulationSet(app)
            
            % instantiate table browser
            panelTitle = romapp.internal.resources.getString('lblSimulationSets');
            tagPrefix = 'rom-model-panel';
            this = this@matlab.ui.internal.databrowser.TableDataBrowser(...
                tagPrefix, panelTitle);
            this.Tag = sprintf('%s-%s', tagPrefix, app.ID);
            this.App = app;
            
            buildUI(this);
            connectUI(this);
            updateUI(this);
        end
    
        function updateUI(this)
            %UPDATEUI
            %
            data = getAppData(this.App);
            nSimSet = numel(data.SimulationSets);
            tbldata = cell(nSimSet,4);
            haveInconsistentResults = false;
            for ct=1:nSimSet
                tbldata{ct,1} = data.SimulationSets(ct).Enable;
                tbldata{ct,2} = char(data.SimulationSets(ct).Name);
                if isempty(data.SimulationSets(ct).SimulationSpec)
                    % There is no spec, so the experiment must be imported
                    % data. Show the number of results.
                    tbldata{ct,3} = data.SimulationSets(ct).NumResults;
                else
                    % There is a spec, so show the proposed number of
                    % simulations based on that spec.
                    tbldata{ct,3} = data.SimulationSets(ct).NumSim;
                end
                if isempty(data.SimulationSets(ct).Results)
                    tbldata{ct,4} = '';
                else
                    dLink = romapp.internal.resources.getString('lblResultData');
                    if ~data.SimulationSets(ct).ResultsMatchSimSpec
                        dLink = strcat(dLink,'*');
                        haveInconsistentResults = true;
                    end
                    tbldata{ct,4} = dLink;
                end
            end
            this.Table.Data = tbldata;
            if haveInconsistentResults
                this.Table.Tooltip = romapp.internal.resources.getString('ttipResultsDontMatchSpec');
            else
                this.Table.Tooltip = '';
            end
        end
        
        function data = getData(this,row)
            % GETDATA returns the specified data value; otherwise, it
            % returns empty value.

            data = [];
            if isempty(row) || ~any(row)
                %Quick return, nothing to do
                return
            end
            allData = this.Table.Data;
            if row <= numel(allData)                
                data = allData(row,2);
            end
        end
    end
    
    methods (Access = protected)
        
        function buildUI(this)
            %BUILDUI
            %

            vars = {'', ...
                romapp.internal.resources.getString('lblName'), ...
                romapp.internal.resources.getString('lblNumSimulations_short'), ...
                romapp.internal.resources.getString('lblResults')};
            data = cell(0,4);
            this.Table.Data = data;
            this.Table.ColumnName = vars;
            this.Table.ColumnEditable = [true, true, false, false];
            this.Table.CellEditCallback = @(hSrc,hData) cbCellEdited(this,hData);
                        
            % activate multi select
            this.SingleRowSelection = false;

            % accepting any invalid string names from the user
            this.GenerateValidVarName = false;
            
            % adding context menu
            this.Table.ContextMenu = createContextMenu(this);
            
            % configure such that we allow only one callback for execution
            this.Table.Interruptible = false;
        end
        
        function connectUI(this)

            weak = romapp.internal.resources.WeakReference(this);
            % Context Menu
            registerDataListeners(this, ...
                addlistener(this.Table.ContextMenu, ...
                'ContextMenuOpening', @(src, event)updateContextMenu(weak.Handle, event)), ...
                'ContextMenuOpening');

            %Listen for data changes 
            appData = getAppData(this.App);
            registerDataListeners(this, addlistener(appData, ...
                'DataChanged', @(src, event)updateUI(weak.Handle)));
        end
        
        function DoubleClickCallback(this, row)

            selectedSet = getData(this, row);
            data = getAppData(this.App);
            idx = strcmp([data.SimulationSets.Name],selectedSet{1});

            simset = data.SimulationSets(idx);
            if isempty(simset.SimulationSpec) && ~isempty(simset.Results)
                %Imported data
                cbPlotResults(this)
            else
                %Simulation result
                cbOpenSelection(this, row);
            end
        end
    end
    
    methods (Access = private)
        function contextMenu = createContextMenu(this)
            % Create a nested context menu.            
            
            contextMenu = uicontextmenu('Parent', this.Figure);

            %Open Simulation Set
            openSelectionMenuItem = uimenu(contextMenu, ...
                'Text',romapp.internal.resources.getString('mnuOpenSelection'), ...
                'Tag','OpenSelectionItem');
            openSelectionMenuItem.MenuSelectedFcn = @(src,evt)cbOpenSelection(this);

            %Plot results
            plotResultsMenuItem = uimenu(contextMenu, ...
                'Text', romapp.internal.resources.getString('mnuPlotResults'), ...
                'Tag','OpenResultItem');
            plotResultsMenuItem.MenuSelectedFcn = @(src,evt)cbPlotResults(this);
            
            % Add Export menu
            exportMenuItem = uimenu(contextMenu, ...
                'Text',romapp.internal.resources.getString('lblExportWithEllipses'), ...
                'Tag','ExportItem');
            exportMenuItem.MenuSelectedFcn = @(src,evt)cbExport(this);
            
            % Add Delete menu
            deleteMenuItem = uimenu(contextMenu, ...
                'Text', romapp.internal.resources.getString('lblDelete'), ...
                'Tag','DeleteItem');
            deleteMenuItem.MenuSelectedFcn = @(src,evt)cbDelete(this);

            % Add Copy menu
            copyMenuItem = uimenu(contextMenu, ...
                'Text',romapp.internal.resources.getString('lblCopy'), ...
                'Tag','CopyItem');
            copyMenuItem.MenuSelectedFcn = @(src,evt)cbCopy(this);

            % Add new menu
            newMenuItem = uimenu(contextMenu, ...
                'Text', romapp.internal.resources.getString('lblNewWithEllipses'), ...
                'Tag','NewItem');
            newMenuItem.MenuSelectedFcn = @(src,evt)cbNew(this);
            
            this.Table.ContextMenu = contextMenu;
            this.Table.ContextMenu.Tag = strcat('mr-tool-context-menu-model-', ...
                this.App.ID);

            %By default disable all the context menus
            disableContextMenu(this)
        end 
        
        function disableContextMenu(this)
            %DISABLECONTEXTMENU
            %
            
            children = this.Table.ContextMenu.Children;
            for i = 1:numel(children)
                children(i).Visible = false;
            end
        end

        % update menu items depending on selection
        function updateContextMenu(this, event)
            % Get the selected the row.
            selection = event.InteractionInformation;
            % React when a cell or the white space is clicked.
            if isempty(selection.Row)
                % Remove current row selections.
                this.Table.Selection = [];
                disableContextMenu(this)

                %Enable new item if there is a simulink model and there are
                %IOs defined
                data = getAppData(this.App);
                this.Table.ContextMenu.Children(1).Visible = data.HaveSimulinkModel && getNumPorts(data.ModelPorts) > 0;
            else
                % Select the right-clicked row.
                this.Table.Selection = selection.Row;

                % Enable submenus.
                children = this.Table.ContextMenu.Children;

                %Disable the new item
                children(1).Visible = false;

                %Always enable delete and copy items
                children(2).Visible = true;
                children(3).Visible = true;

                %Enable export and plot results only if there are
                %results
                data = getAppData(this.App);
                tf = ~isempty(data.SimulationSets(selection.Row).Results);
                children(4).Visible = tf;
                children(5).Visible = tf;

                %Enable open only if there is a simulation spec
                tf = ~isempty(data.SimulationSets(selection.Row).SimulationSpec);
                children(6).Visible = tf;                
            end
        end

        function cbCellEdited(this,hData)

            row = hData.Indices(1);
            col = hData.Indices(2);
            switch col
                case 1 %Enable
                    data = getAppData(this.App);
                    data.SimulationSets(row).Enable = hData.NewData;
                case 2 %Name
                    data = getAppData(this.App);
                    %Make sure the name does not conflict with an existing
                    %name
                    name = strtrim(hData.NewData);
                    if strcmp(name,data.SimulationSets(row).Name)
                        hData.Source.Data{row,col} = name; 
                        return
                    end
                    if isempty(name)
                        name = char(data.SimulationSets(row).Name);
                    else
                        name = matlab.lang.makeUniqueStrings(name,[data.SimulationSets.Name]); 
                        data.SimulationSets(row).Name = name;
                    end      
                    hData.Source.Data{row,col} = name; %Could have changed

                    % If the row that changed is currently the selected
                    % tool, then update the tool since the name may have
                    % changed.
                    tool = findTool(this.App.ToolManager, romapp.internal.tools.SimulationSetTool.TYPE);
                    if ~isempty(tool)
                        selectedSet = getData(this, row);  
                        data = getAppData(this.App);
                        idx = strcmp([data.SimulationSets.Name],selectedSet{1});
                        simset = data.SimulationSets(idx);
                        toolData = tool.getToolData;
                        if isequal(toolData, simset)
                            openTool(this.App.ToolManager,romapp.internal.tools.SimulationSetTool.TYPE,simset,false);
                            openTool(this.App.ToolManager,romapp.internal.plots.SimulationSpecPlot.TYPE,simset,false);
                        end
                    end
            end
        end
                
        function cbOpenSelection(this, ~)

            row = this.Table.Selection;
            selectedSet = getData(this, row);
            data = getAppData(this.App);
            idx = strcmp([data.SimulationSets.Name],selectedSet{1});

            if any(idx)
                simset = data.SimulationSets(idx);

                %Create a tool to view the simulation set
                openTool(this.App.ToolManager,romapp.internal.tools.SimulationSetTool.TYPE,simset,false);
                openTool(this.App.ToolManager,romapp.internal.plots.SimulationSpecPlot.TYPE,simset,false);
            end
        end

        function cbPlotResults(this) 
            row = this.Table.Selection;
            selectedSet = getData(this, row);

            data = getAppData(this.App);
            idx = strcmp([data.SimulationSets.Name],selectedSet{1});
            simset = data.SimulationSets(idx);

            if hasScalarOutput(data.ModelPorts)
                pType = romapp.internal.plots.ScalarResultPlot.TYPE;
            else
                pType = romapp.internal.plots.SimulationResultPlot.TYPE;
            end
            openPlot(this.App.ToolManager,pType,simset)
        end
        
        function cbExport(this)
            showExportDialog(this.App,'workspace')
        end

        function cbDelete(this)
            % get selected data
            idx = this.Table.Selection;
            appData = getAppData(this.App);
            removeSimulationSet(appData,this.Table.Data{idx,2})
        end

        function cbCopy(this)
            idx = this.Table.Selection;
            appData = getAppData(this.App);
            copySimulationSet(appData,this.Table.Data{idx,2})
        end

        function cbNew(this)

            appData = getAppData(this.App);
            SimSet = romapp.internal.data.SimulationSet(appData.ModelPorts);
            SimSet.Name = matlab.lang.makeUniqueStrings(...
                romapp.internal.resources.getString('lblSimulation'),...
                [appData.SimulationSets.Name]);
            addSimulationSet(appData,SimSet);

            %Create a tool to view the simulation set
            openTool(this.App.ToolManager,romapp.internal.tools.SimulationSetTool.TYPE,SimSet);
            openTool(this.App.ToolManager,romapp.internal.plots.SimulationSpecPlot.TYPE,SimSet);           
        end
    end
end

% LocalWords:  lbl mnu mr DISABLECONTEXTMENU CLEARSELECTION IOs ttipResultsDontMatchSpec
