classdef (Hidden) ReducedOrderModel < handle
    % Reduce order model tab for ROM Designer

    %
    % Copyright 2022-2025 The MathWorks, Inc.

    properties(Access = public)
        App
        Tab
        Widgets
    end

    properties(Access = protected)
        RunOptionsDialog
        ProgressDialog
    end

    methods
        function this = ReducedOrderModel(app)
            this.Tab = matlab.ui.internal.toolstrip.Tab(romapp.internal.resources.getString('lblROM'));
            this.Tab.Tag = 'rom-permanent';
            this.App = app;
            createWidgets(this)
            enableWidgets(this)
            addListeners(this)
            addDataListeners(this)
        end
        function delete(~)
        end
        function Tab = getTab(this)
            Tab = this.Tab;
        end
        function Widgets = getWidgets(this)
            Widgets = this.Widgets;
        end
    end

    methods (Access = private)

        function createWidgets(this)
            import matlab.ui.internal.toolstrip.*

            % FILE SECTION WIDGETS
            NewSessionStr = sprintf(romapp.internal.resources.getString('lblNewSession'));
            NewSessionTooltip = romapp.internal.resources.getString('ttipNewSession');
            OpenSessionStr = sprintf(romapp.internal.resources.getString('lblOpenSession'));
            OpenSessionTooltip = romapp.internal.resources.getString('ttipOpenSession');
            SaveSessionStr = sprintf(romapp.internal.resources.getString('lblSaveSessionWithLF'));
            SaveSessionTooltip = romapp.internal.resources.getString('ttipSaveSession');
            FileSection = Section(romapp.internal.resources.getString('lblFile'));
            add(this.Tab, FileSection);
            column1 = Column();
            column2 = Column();
            column3 = Column();

            NewSessionButton = Button(NewSessionStr,'new');
            NewSessionButton.Description = NewSessionTooltip;
            NewSessionButton.Tag = 'btnNewSession';
            add(FileSection,column1);
            add(column1, NewSessionButton)

            OpenSessionButton = Button(OpenSessionStr,'openFolder');
            OpenSessionButton.Description = OpenSessionTooltip;
            OpenSessionButton.Tag = 'btnOpenSession';
            add(FileSection,column2);
            add(column2,OpenSessionButton)

            SaveSessionButton = Button(SaveSessionStr,'saved');
            SaveSessionButton.Description = SaveSessionTooltip;
            SaveSessionButton.Tag = 'btnSaveSession';
            add(FileSection,column3);
            add(column3,SaveSessionButton)

            this.Widgets.FileSection =  struct(...
                'NewSessionButton',NewSessionButton, ...
                'OpenSessionButton',OpenSessionButton, ...
                'SaveSessionButton',SaveSessionButton);

            % IO section
            IOSection = Section(romapp.internal.resources.getString('lblInputsOutputs'));
            add(this.Tab, IOSection);
            EditIOStr = sprintf(romapp.internal.resources.getString('lblEditIO'));
            EditIOTooltip = romapp.internal.resources.getString('ttipEditIO');
            EditIOButton = Button(EditIOStr);
            EditIOButton.Icon = romapp.internal.resources.getIcon("edit_inputOutput");
            EditIOButton.Description = EditIOTooltip;
            EditIOButton.Tag = 'btnEditIO';
            column1 = Column();
            add(IOSection,column1);
            add(column1, EditIOButton)

            this.Widgets.IOSection =  struct(...
                'EditIOButton', EditIOButton);

            % Simulate/collect/import data Section
            RunOptionsStr = sprintf(romapp.internal.resources.getString('lblRunOptions_WithLF'));
            RunOptionsTooltip = romapp.internal.resources.getString('ttipRunOptions');
            RunSimStr = sprintf(romapp.internal.resources.getString('lblRunSimulations'));
            RunSimTooltip = romapp.internal.resources.getString('ttipRunSimulations');
            SimSection = Section(romapp.internal.resources.getString('lblCollectData'));
            add(this.Tab, SimSection);
            column1 = Column();
            column2 = Column();
            column3 = Column();
            column4 = Column();
            column5 = Column();

            ImportDataStr = sprintf(romapp.internal.resources.getString('lblImportDataWithLF'));
            ImportDataButton = Button(ImportDataStr,'import');
            ImportDataButton.Description = romapp.internal.resources.getString('lblImportData_Description');
            ImportDataButton.Tag = 'btnImportData';
            add(SimSection,column1)
            add(column1,ImportDataButton)

            ExperimentString = sprintf(romapp.internal.resources.getString('lblNewSimulationSet'));
            ExperimentButton = Button(ExperimentString);
            ExperimentButton.Description = romapp.internal.resources.getString('lblNewSimulationSet_Description');
            ExperimentButton.Icon = romapp.internal.resources.getIcon("add_plotMultiple");
            ExperimentButton.Tag = 'btnNewSimulationSet';
            this.Widgets.DesignSection =  struct(...
                'ExperimentButton', ExperimentButton);
            add(SimSection,column2);
            add(column2, ExperimentButton)

            RunOptionsButton = Button(RunOptionsStr, 'settings');
            RunOptionsButton.Description = RunOptionsTooltip;
            RunOptionsButton.Tag = 'btnRunOptions';
            add(SimSection,column3);
            add(column3, RunOptionsButton)

            RunSimButton = Button(RunSimStr,'playControl');
            RunSimButton.Description = RunSimTooltip;
            RunSimButton.Tag = 'btnRunSim';
            add(SimSection,column4);
            add(column4,RunSimButton)

            lbl = sprintf(romapp.internal.resources.getString('lblOpenResults'));
            ttip = romapp.internal.resources.getString('ttipOpenResults');
            PlotResultButton = Button(lbl,'plotMultiple');
            PlotResultButton.Description = ttip;
            PlotResultButton.Tag = 'btnPlotResult';
            add(SimSection,column5)
            add(column5,PlotResultButton)

            this.Widgets.SimSection =  struct(...
                'RunOptions',RunOptionsButton, ...
                'RunSim',RunSimButton, ...
                'ImportData', ImportDataButton, ...
                'PlotResults', PlotResultButton);

            % Model Section

            % Section, Widgets
            ModelSection = Section(romapp.internal.resources.getString('lblModel'));
            add(this.Tab, ModelSection);
            columnGallery = Column();

            gallPopup = matlab.ui.internal.toolstrip.GalleryPopup(...
                'ShowSelection',false,'GalleryItemWidth',75);

            gallCat = matlab.ui.internal.toolstrip.GalleryCategory(romapp.internal.resources.getString('lblROMMethods'));
            gallCat.Tag = 'glryROMModelCategory';
            gallPopup.add(gallCat)
            
            if romapp.internal.resources.Shipped
                % Compatible with R2024a onward
                gallery = matlab.ui.internal.toolstrip.Gallery(...
                    gallPopup, 'MinColumnCount', 1, ...
                    'MaxColumnCount', 5, ...
                    'HideDisabledItems', false);
            else
                % Compatible with R2023b
                gallery = matlab.ui.internal.toolstrip.Gallery(...
                    gallPopup, 'MinColumnCount', 1, ...
                    'MaxColumnCount', 4);
            end
            gallery.Tag = 'glryROMMOdels';
            add(ModelSection, columnGallery);
            add(columnGallery, gallery);

            this.Widgets.ModelSection =  struct(...
                'Gallery', gallery, ...
                'GalleryPopup',gallPopup, ...
                'GalleryCategory',gallCat);
            updateGallery(this); %Populate gallery with default items

           
            %Export section
            ExportSection = Section(romapp.internal.resources.getString('lblExport'));
            add(this.Tab, ExportSection);
            column1 = Column();
            str = romapp.internal.resources.getString('lblExportToWorkspace');
            ExportButton = Button(str, 'export_data');
            ExportButton.Description = romapp.internal.resources.getString('ttipExportToWorkspace');
            ExportButton.Tag = 'btnExport';
            add(ExportSection, column1);
            add(column1, ExportButton);

            this.Widgets.ExportSection =  struct(...
                'ExportButton', ExportButton);
        end

        function addListeners(this)
            %addListeners Create listeners for widgets

            weak = romapp.internal.resources.WeakReference(this);
            % File Section Callbacks
            addlistener(this.Widgets.FileSection.NewSessionButton, ...
                'ButtonPushed', @(src, data)cbNewSession(weak.Handle));
            addlistener(this.Widgets.FileSection.SaveSessionButton, ...
                'ButtonPushed', @(src, data)cbSaveSession(weak.Handle));
            addlistener(this.Widgets.FileSection.OpenSessionButton, ...
                'ButtonPushed', @(src, data)cbLoadSession(weak.Handle));

            % IO Section Callbacks
            addlistener(this.Widgets.IOSection.EditIOButton, ...
                'ButtonPushed', @(src,data)cbEditIO(weak.Handle));

            % Design Section Callbacks
            addlistener(this.Widgets.DesignSection.ExperimentButton, ...
                'ButtonPushed', @(src,data) cbSimulationSet(weak.Handle));
            
            % Simulation Section Callbacks
            addlistener(this.Widgets.SimSection.RunSim, ...
                'ButtonPushed', @(src, data)cbRun(weak.Handle));
            addlistener(this.Widgets.SimSection.RunOptions, ...
                'ButtonPushed', @(src, data)cbRunOptions(weak.Handle));
            addlistener(this.Widgets.SimSection.ImportData, ...
                'ButtonPushed', @(src, data)cbImportData(weak.Handle));
            addlistener(this.Widgets.SimSection.PlotResults, ...
                'ButtonPushed', @(src, data)cbPlotResults(weak.Handle));

            %Model section
            data = getAppData(this.App);
            addlistener(data,'DataChanged', @(hSrc,hData) updateGallery(weak.Handle));

            % Export Section Callbacks
            addlistener(this.Widgets.ExportSection.ExportButton, ...
                'ButtonPushed', @(src, data)cbExport(weak.Handle));
        end

        function addDataListeners(this)

            data = getAppData(this.App);
            addlistener(data,'DataChanged', @(hSrc,hData) cbDataChanged(this));
            addlistener(data.ModelPorts,'DataChanged', @(hSrc,hData) cbDataChanged(this));
        end

        function cbNewSession(this)
            %cbNewSession Handle new session button callbacks

            openPlot(this.App.ToolManager,romapp.internal.plots.OverviewPlot.TYPE,[])
            showSelectIOs(this.App,'clear')
        end

        function cbSaveSession(this)
            %cbSaveSession Handle save session button callbacks

            promptForSaveSession(this.App);
        end

        function cbLoadSession(this)
            %cbLoadSession
            %

            promptForLoadSession(this.App)
        end

        function cbEditIO(this)
            %cbNewSession Handle edit io button callbacks

            showSelectIOs(this.App,'initialize')
        end

        function cbSimulationSet(this)
            %cbSimulationSet Handle simulation set button callbacks
            %

            %Create a new simulation set and add to the app data
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

        function cbRun(this)
            %cbRun Handle run button callbacks
            %

            % Check if current folder has write permissions
            currentFolder = pwd;
            perm = filePermissions(currentFolder);

            if ~perm.Writable
                % Show alert dialog with the appropriate message
                uialert(this.App.Container,...
                    romapp.internal.resources.getString('errRun_NoWritePerm'), ...
                    romapp.internal.resources.getString('lblError'), ...
                    'Icon', 'error');
                return
            end

            data = getAppData(this.App);

            nSim = 0;
            for ct=1:numel(data.SimulationSets)
                if data.SimulationSets(ct).Enable
                    nSim = nSim + data.SimulationSets(ct).NumSim;
                end
            end
            if nSim == 0
                uialert(this.App.Container,...
                    romapp.internal.resources.getString('errRun_NoSimulations'), ...
                    romapp.internal.resources.getString('lblError'), ...
                    'Icon', 'error');
                return
            end
            if ~isempty(this.ProgressDialog) && isvalid(this.ProgressDialog)
                pDlg = this.ProgressDialog;
                resetCount(pDlg)
            else
                pDlg = romapp.internal.dialogs.ProgressDialog();
            end
            setNumSim(pDlg,nSim);

            showDlg(pDlg,this.App.Container)
            try
                runSimulations(data,@(simout) lProgressDisplay(simout,pDlg))
                success = true;
                close(pDlg)
            catch E
                success = false;
                msg = lFindLeafErrorMsg(E);
                uialert(this.App.Container,msg,romapp.internal.resources.getString('errRun_SimulationErrorTitle'))
            end

            if success
                %Show the simulation results
                if hasScalarOutput(data.ModelPorts)
                    pType = romapp.internal.plots.ScalarResultPlot.TYPE;
                else
                    pType = romapp.internal.plots.SimulationResultPlot.TYPE;
                end
                for ct=1:numel(data.SimulationSets)
                    if data.SimulationSets(ct).NumSim>=1
                        openPlot(this.App.ToolManager,pType,data.SimulationSets(ct))
                    end
                end
            end
        end

        function cbImportData(this)
            %cbImportData Handle import data button callbacks
            %

            showImportDataDialog(this.App);
        end

        function cbRunOptions(this)
            %cbRunOptions Handle run options button callbacks
            %

            if isempty(this.RunOptionsDialog) || ~isvalid(this.RunOptionsDialog)
                appData = getAppData(this.App);
                dlg = romapp.internal.dialogs.RunOptionsDialog(appData);
                this.RunOptionsDialog = dlg;
            else
                dlg = this.RunOptionsDialog;
            end
            show(dlg,this.App)

            wd = getWidget(dlg);
            alreadyRegistered = hasDialog(this.App, wd.Tag);
            if isvalid(dlg) && ~alreadyRegistered
                registerDialog(this.App,wd)
            end
        end

        function cbPlotResults(this)

            data = getAppData(this.App);
            if hasScalarOutput(data.ModelPorts)
                pType = romapp.internal.plots.ScalarResultPlot.TYPE;
            else
                pType = romapp.internal.plots.SimulationResultPlot.TYPE;
            end

            for ct=1:numel(data.SimulationSets)
                simset = data.SimulationSets(ct);
                if simset.Enable && ~isempty(simset.Results)
                    openPlot(this.App.ToolManager,pType,simset)
                end
            end
            
        end

        function cbExport(this)
            %cbExport Handle export button callbacks
            %

            showExportDialog(this.App,'workspace')
        end


        function comp = createGalleryComponent(this,type,isROMStatic)
            %createGalleryComponent Helper to create a gallery component

            scalarOut = eval(type+".HAS_SCALAR_OUTPUT");
            signalOut = eval(type+".HAS_SIGNAL_OUTPUT");
            if isROMStatic && ~scalarOut   
                %don't add to the gallery.
                return
            end
            if ~isROMStatic && ~signalOut
                return
            end            
            
            label = eval(type+".NAME");
            icon = eval(type+".ICON");
            description = eval(type+".DESCRIPTION");
            tag = "mnu"+eval(type+".TYPE");

            comp = matlab.ui.internal.toolstrip.GalleryItem(label);
            comp.Description = description;
            
            comp.Icon = icon;
            comp.Tag = tag;
            weak = romapp.internal.resources.WeakReference(this);
            comp.ItemPushedFcn = @(hSrc,hData) cbLaunchModel(weak.Handle,type);
            this.Widgets.ModelSection.GalleryCategory.add(comp);

            %Check whether to enable icon or not
            data = getAppData(this.App); 
            data = data.SimulationSets; 
            cmd = type + ".canUseWithData";
            comp.Enabled = feval(cmd,data);
        end

        function cbLaunchModel(this,type)
            %cbLaunchModel Manage gallery item callbacks
            %

            cmd = type + ".checkProducts(" + ...
                type + ".REQUIREDPRODUCTS, " + ...
                type + ".NAME)";
            try
                eval(cmd)
            catch E
                uialert(this.App.Container, ...
                    E.message, ...
                    romapp.internal.resources.getString('lblError'), ...
                    'Icon', 'error')
                return
            end
            
            showExportDialog(this.App,'experimentmanager',type)
        end

        function cbDataChanged(this)
            % The data has changed in the app. First set the dirty state to
            % true. Then enable widgets as required.
            this.App.setAppDirty(true);

            enableWidgets(this);
        end

        function enableWidgets(this)

            data = getAppData(this.App);
            haveIOs = getNumPorts(data.ModelPorts) > 0;
            haveSimSet = haveIOs && numel([data.SimulationSets.SimulationSpec]) > 0;
            haveSamples = false;
            if haveSimSet
                for iSimSet = 1:numel(data.SimulationSets)
                    if data.SimulationSets(iSimSet).SimulationSpec.hasEnoughSamples
                        haveSamples = true;
                        break
                    end
                end
            end
            haveImportedData = haveIOs && any(arrayfun(@(x) isempty(x.SimulationSpec),data.SimulationSets));
            if haveSimSet
                haveResults = haveSimSet;
                for ct=1:numel(data.SimulationSets)
                    haveResults = ~isempty(data.SimulationSets(ct).Results);
                    if haveResults, break, end
                end
            else
                haveResults = false;
            end
            
            %IO widgets
            this.Widgets.IOSection.EditIOButton.Enabled = haveIOs;

            %Simset widgets
            this.Widgets.DesignSection.ExperimentButton.Enabled = haveIOs;

            %Run widgets
            this.Widgets.SimSection.RunSim.Enabled = haveSamples;
            this.Widgets.SimSection.RunOptions.Enabled = haveSamples;
            this.Widgets.SimSection.ImportData.Enabled = haveIOs;
            this.Widgets.SimSection.PlotResults.Enabled = haveResults || haveImportedData;

            %Model widgets
            this.Widgets.ModelSection.Gallery.Enabled = haveResults || haveImportedData;

            %Export widgets
            this.Widgets.ExportSection.ExportButton.Enabled = haveResults || haveImportedData;
        end

        function updateGallery(this)

            %Clear the gallery of any existing elements
            ch = getChildByIndex(this.Widgets.ModelSection.GalleryCategory);
            for ct=1:numel(ch)
                remove(this.Widgets.ModelSection.GalleryCategory,ch(ct));
            end
            
            %Populate the gallery, make sure the quick-start item is the
            %1st in the gallery
            data = getAppData(this.App);
            cls = romapp.internal.experimentmanager.ROMExperiment.findAllROMExperiments;
            clsQuickStart ="romapp.internal.experimentmanager.QuickStart.DynamicModelExperiment";
            idx = strcmp(cls,clsQuickStart);
            cls(idx) = [];
            cls = [clsQuickStart; cls(:)];
            for ct=1:numel(cls)
                createGalleryComponent(this, cls(ct), hasScalarOutput(data.ModelPorts));
            end
        end
    end

    methods(Hidden = true)
        function dlgs = qeGetDialogs(this)

            appDlgs = qeGetDialogs(this.App);
            dlgs = struct(...
                'SelectIO', appDlgs.SelectIO, ...
                'RunOptions', this.RunOptionsDialog, ...
                'Export', appDlgs.Export, ...
                'Progress', this.ProgressDialog);
        end
        function qeUpdateGallery(this)
            updateGallery(this)
        end
    end
end

function simout = lProgressDisplay(simout,dlgProgress)

increment(dlgProgress,1)
end

function msg = lFindLeafErrorMsg(E)

while ~isempty(E.cause)
    E = E.cause{1};
end

msg= E.message;
%Remove any HTML refs
msg = regexprep(msg,'<a[^>]*>','');
msg = regexprep(msg,'</a>','');
end

% LocalWords:  LSTM NN cb mdlNSS mdlLPV lbl ttip lblSaveSessionWithLF NSS LPV WithLF btn mnu glry
% LocalWords:  glryROMMOdels ios ExistingIOs IOs experimentmanager REQUIREDPRODUCTS
% LocalWords:  lblImportDataWithLF Interpolant
