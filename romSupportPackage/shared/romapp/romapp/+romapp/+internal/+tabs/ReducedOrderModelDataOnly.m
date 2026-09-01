classdef (Hidden) ReducedOrderModelDataOnly < handle
    % Reduce order model tab for ROM Designer
    %
    % Is used when app is launched without a Simulink model and directly
    % works with data

    %
    % Copyright 2022-2025 The MathWorks, Inc.

    properties(Access = public)
        App
        Tab
        Widgets
    end

    methods
        function this = ReducedOrderModelDataOnly(app)
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

            % Import/view data Section
            DataSection = Section(sprintf(romapp.internal.resources.getString('lblData')));
            add(this.Tab, DataSection);
            column1 = Column();
            column2 = Column();
            
            ImportDataStr = sprintf(romapp.internal.resources.getString('lblImportDataWithLF'));
            ImportDataButton = Button(ImportDataStr,'import');
            ImportDataButton.Description = romapp.internal.resources.getString('lblImportData_Description');
            ImportDataButton.Tag = 'btnImportData';
            add(DataSection,column1)
            add(column1,ImportDataButton)
            
            lbl = sprintf(romapp.internal.resources.getString('lblOpenResults'));
            ttip = romapp.internal.resources.getString('ttipOpenResults');
            PlotResultButton = Button(lbl,'plotMultiple');
            PlotResultButton.Description = ttip;
            PlotResultButton.Tag = 'btnPlotResult';
            add(DataSection,column2)
            add(column2,PlotResultButton)

            this.Widgets.DataSection =  struct(...
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
                    'MaxColumnCount', 4, ...
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
            ExportButton = Button(romapp.internal.resources.getString('lblExport'), 'export_data');
            ExportButton.Description = romapp.internal.resources.getString('ttipExportToWorkspace');
            ExportButton.Tag = 'btnExport';
            add(ExportSection, column1);
            add(column1, ExportButton);

            this.Widgets.ExportSection =  struct(...
                'ExportButton', ExportButton);
        end

        function addListeners(this)
            %addListeners Create listeners for widgets

            % File Section Callbacks
            weak = romapp.internal.resources.WeakReference(this);
            addlistener(this.Widgets.FileSection.NewSessionButton, ...
                'ButtonPushed', @(src, data)cbNewSession(weak.Handle));
            addlistener(this.Widgets.FileSection.SaveSessionButton, ...
                'ButtonPushed', @(src, data)cbSaveSession(weak.Handle));
            addlistener(this.Widgets.FileSection.OpenSessionButton, ...
                'ButtonPushed', @(src, data)cbLoadSession(weak.Handle));
            
            % Import/view data Callbacks
            addlistener(this.Widgets.DataSection.ImportData, ...
                'ButtonPushed', @(src, data)cbImportData(weak.Handle));
            addlistener(this.Widgets.DataSection.PlotResults, ...
                'ButtonPushed', @(src, data)cbPlotResults(weak.Handle));

            %Model section
            data = getAppData(this.App);
            addlistener(data,'DataChanged', @(hSrc,hData) updateGallery(this));

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
            showImportDataDialog(this.App,Mode='new')
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

        function cbImportData(this)
            %cbImportData Handle import data button callbacks
            %

            showImportDataDialog(this.App);
        end

        function cbPlotResults(this)
            %cbPlotResults Handle plot results button events

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
            %cbExport Handle export button events
            %

            showExportDialog(this.App,'workspace')
        end


        function comp = createGalleryComponent(this,type,isROMStatic,numParam)
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
            comp.Enabled = true;
            comp.Icon = icon;
            comp.Tag = tag;
            weak = romapp.internal.resources.WeakReference(this);
            comp.ItemPushedFcn = @(hSrc,hData) cbLaunchModel(weak.Handle,type);
            this.Widgets.ModelSection.GalleryCategory.add(comp);

            if strcmp(type,"romapp.internal.experimentmanager.InterpStatic.scatteredInterpExperiment")
                data = getAppData(this.App);
                nSim = 0;                
                for ct = 1:numel(data.SimulationSets)
                    if ~isempty(data.SimulationSets(ct).Results)
                        nSim = nSim + data.SimulationSets(ct).NumResults;
                    end
                end
                resultsMatchSimSpec = all([data.SimulationSets.ResultsMatchSimSpec]);
                if ~resultsMatchSimSpec
                    comp.Enabled = false;
                end
                % disable icon if Scattered Interpolant and more than 3
                % parameters, or not enough points 
                if (numParam>3 || numParam<1) || nSim<3
                    comp.Enabled = false;
                end 
            end

            if strcmp(type,"romapp.internal.experimentmanager.InterpStatic.griddedInterpExperiment")
                % disable icon if Gridded Interpolant 
                % and not any SimulationSets have a GriddedParameterSpec
                % or not enough points in any dimensions
                hasValidGriddedParameterExperiment = 0;
                data = getAppData(this.App);
                if (getNumPorts(data.ModelPorts)>0) && ~isempty(data.SimulationSets) % check for at least one experiment      
                    for ct=1:numel(data.SimulationSets) % go through all experiments
                        if isa(data.SimulationSets(ct).SimulationSpec.ParameterSpec,'romapp.internal.data.GriddedParameterSpec') ...
                            && ~isempty(data.SimulationSets(ct).Results) % check if this experiment has GriddedParameterSpec
                            ldims = cellfun(@numel, data.SimulationSets(ct).SimulationSpec.ParameterSpec.Values);
                            hasValidGriddedParameterExperiment = all(ldims>1); % last check if all dimensions have at least 2 points 
                            if hasValidGriddedParameterExperiment
                                break; end
                        end
                    end
                end
                if ~hasValidGriddedParameterExperiment
                    comp.Enabled = false;
                end
                resultsMatchSimSpec = all([data.SimulationSets.ResultsMatchSimSpec]);
                if ~resultsMatchSimSpec
                    comp.Enabled = false;
                end
            end
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
            %enableWidgets

            data = getAppData(this.App);
            haveIOs = getNumPorts(data.ModelPorts) > 0;
            haveImportedData = haveIOs && any(arrayfun(@(x) isempty(x.SimulationSpec),data.SimulationSets));
            
            %Data widgets
            this.Widgets.DataSection.ImportData.Enabled = haveIOs;
            this.Widgets.DataSection.PlotResults.Enabled = haveImportedData;

            %Model widgets
            this.Widgets.ModelSection.Gallery.Enabled = haveImportedData;

            %Export widgets
            this.Widgets.ExportSection.ExportButton.Enabled = haveImportedData;
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
                createGalleryComponent(this, cls(ct), hasScalarOutput(data.ModelPorts), numel(data.ModelPorts.InputParameters));
            end
        end
    end

    methods(Hidden = true)
        function dlgs = qeGetDialogs(this)

            appDlgs = qeGetDialogs(this.App);
            dlgs = struct(...
                'SelectIO', appDlgs.SelectIO, ...
                'RunOptions', [], ...
                'Export', appDlgs.Export, ...
                'Progress', []);
        end
        function qeUpdateGallery(this)
            updateGallery(this)
        end
    end
end

function simout = lProgressDisplay(simout,dlgProgress)

increment(dlgProgress,1)
end

% LocalWords:  LSTM NN cb mdlNSS mdlLPV lbl ttip lblSaveSessionWithLF NSS LPV WithLF btn mnu glry
% LocalWords:  glryROMMOdels ios ExistingIOs IOs experimentmanager REQUIREDPRODUCTS
% LocalWords:  lblImportDataWithLF Interpolant
