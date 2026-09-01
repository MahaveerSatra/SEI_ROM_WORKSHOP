classdef ReducedOrderModeler < controllib.ui.internal.dialog.DialogManager & ...
        matlab.mixin.SetGet
    % REDUCED ORDER MODELER APP
    %

    % Copyright 2022-2026 The MathWorks, Inc.

    properties (SetAccess = private, GetAccess = public, SetObservable)
        % UUID for the App
        ID

        % Widgets
        Widgets

        % AppContainer
        Container

        %Export results dialog
        ExportResultDialog

        %Import data dialog
        ImportDataWithFixedIODialog
        ImportDataDialog
        IndexedVariableImportDialog

        %Select IO dialog
        SelectIODialog

        % Data
        AppData

        % Managers
        DataBrowserManager
        ToolManager
        EventManager
        DialogManagerModel

        % Tabs
        TabGroup
        ReduceSystemTab


        DocumentGroup

        % Browsers
        SimulationSetBrowser
        ModelPortBrowser

        % Bars
        StatusBar
    end

    properties(Constant)
        PROPERTYEDITORWIDTH = 400;
    end

    properties(Access = public)
        SimulationSetTab
        PropertyPanel
    end

    events
        ModelsUpdated
        ModelNameChanged
    end

    properties (SetAccess = private)
        IsDirty
        WaitBar
        ExportCompletedListener
        ImportListener
        ImportCanceledListener
        ImportListenerFixedIO
        IndexedVariableImportListener
    end

    properties (Access = private, Transient = true)
        % Listeners
        ContainerListener
        DataChangedListener
        ModelListener
    end

    methods
        function app = ReducedOrderModeler(data,varname,haveSession)

            arguments
                data = {};
                varname = {};
                haveSession = false;
            end

            app.ID = matlab.lang.internal.uuid;

            %Create data object to store all app data
            app.AppData = romapp.internal.data.AppData(data);

            % create container to house Browser, Tabs, DocArea
            createAppContainer(app);
            attachDialogManagerToAppContainer(app, app.Container)

            %Add listener for model close events
            if app.AppData.HaveSimulinkModel
                createModelListener(app)
            end

            % create Main tab
            createPermanentTabs(app);

            % create Data Browser components
            createDataBrowserManager(app);

            % create Tool Manager
            app.ToolManager = romapp.internal.managers.ToolManager(app);

            % create Eventmanager and install listeners
            app.EventManager = controllib.app.managers.eventmanager.internal.AppEventManager(app.Container);
            %Remove the installed undo/redo buttons
            app.Container.removeQabControl('QABUndoButton')
            app.Container.removeQabControl('QABRedoButton')
            installListeners(app);

            % create app context help button
            createContextualHelpButton(app)

            %Open the overview document
            openPlot(app.ToolManager,romapp.internal.plots.OverviewPlot.TYPE,app.AppData.HaveSimulinkModel)

            % Show App
            show(app);
            if ~app.AppData.HaveSimulinkModel && ~haveSession
                %Launched with data. If the variable name is empty the data
                %is not a workspace variable but comes from an indexed variable,
                %e.g. var.field, var(:,1), etc. 
                idxEmpty = cellfun('isempty',varname);
                if any(idxEmpty)
                    if numel(varname) > 1
                        %Multiple data used when launching the app, set the
                        %1st to output the rest to inputs.
                        vartype = repmat(romapp.internal.data.ImportType.Input,size(varname));
                        vartype(1) = romapp.internal.data.ImportType.Output;
                    else
                        vartype = romapp.internal.data.ImportType.Input;
                    end
                    varname(idxEmpty) = cellstr("Data"+find(idxEmpty));
                    showIndexedVariableImportDialog(app,data,...
                        VariableName=varname,...
                        VariableType=vartype)
                else
                    if numel(varname) > 1
                        %Multiple data used when launching the app, set the
                        %1st to output the rest to inputs.
                        vartype = repmat(romapp.internal.data.ImportType.Input,size(varname));
                        vartype(1) = romapp.internal.data.ImportType.Output;
                    else
                        vartype = romapp.internal.data.ImportType.Input;
                    end
                    showImportDataDialog(app,Mode='new',...
                        VariableName=varname, ...
                        VariableType=vartype)
                end
            end
            setAppDirty(app, false);
        end

        function show(app)
            app.Container.Visible = true;
        end

        function close(app)
            delete(app);
        end

        function data = getAppData(app)
            data = app.AppData;
        end

        function resetAppData(app,newdata)

            %Close existing plots and tools
            closeTool(app.ToolManager);
            closePlot(app.ToolManager);

            %Load the session data
            data = getAppData(app);
            loadSavedData(data,newdata)
        end

        function installListeners(app)
            % Installs listeners.
            app.ContainerListener = addlistener(app.Container, ...
                'StateChanged',@(es,ed) cbAppContainerStateChanged(app,es));
            app.Container.CanCloseFcn = @(es,ed) cbAppContainerCanClose(app);
        end

        function cbAppContainerStateChanged(app, es)
            % Callback function app container's state changed event.

            if es.State == matlab.ui.container.internal.appcontainer.AppState.TERMINATED
                delete(app);
            end
        end

        function canAppClose = cbAppContainerCanClose(app)
            % Callback function to systematically close the app.

            canAppClose = true;
            if isAppDirty(app)
                canAppClose = askForSaveSession(app);
            end
        end

        function setWaiting(app, flag, msg)
            % Shows progress bar in front of the app.
            if flag
                if nargin <3
                    msg = romapp.internal.resouces.getString('msgProcessing');
                end
                app.WaitBar = uiprogressdlg(app.Container,...
                    'Message', msg, ...
                    'Title', app.Container.Title, ...
                    'Indeterminate', 'on');
            else
                if ~isempty(app.WaitBar) && isvalid(app.WaitBar)
                    close(app.WaitBar);
                    app.WaitBar = [];
                end
            end
        end

        % GET/SET PROPERTIES
        function EventManager = get.EventManager(app)
            EventManager = app.EventManager;
        end

        function ToolManager = get.ToolManager(app)
            ToolManager = app.ToolManager;
        end


        function Container = get.Container(app)
            Container = app.Container;
        end

        function set.SimulationSetTab(app, tab)
            app.SimulationSetTab = tab;
        end

        function set.PropertyPanel(app, panel)
            app.PropertyPanel = panel;
        end

        function Widgets = get.Widgets(app)
            Widgets.Container = get(app, 'Container');
            Widgets.EventManager = get(app, 'EventManager');
            %Widgets.StatusBar = Widgets.EventManager.getStatusBar;
            Widgets.ModelPanel = app.ModelPanel;

            Widgets.ToolMap = app.ToolManager.ToolMap;

            Widgets.Tool.ReduceSystem = app.ReduceSystemTab;
            Widgets.Tool.Plot = app.PlotTab;

            Widgets.Tabs.ReduceSystemTab = app.ReduceSystemTab.getTab;
            Widgets.Tabs.PlotTab = app.PlotTab.getTab;
        end

        function delete(app)
            % Delete all existing components of the App

            delete(app.Container)
        end

        % LOAD/SAVE SESSION
        function promptForLoadSession(app)
            [filename, pathname] = uigetfile( ...
                {'*.mat';'*.*'}, ...
                romapp.internal.resources.getString('msgSelectSession'));
            if ~isequal(filename,0) && ~isequal(pathname,0)
                % load the session file
                SessionFile = fullfile(pathname,filename);
                try
                    ROMSessionData = validateSessionFile(app,SessionFile);
                catch ME
                    uialert(app.Container, ME.message, app.Container.Title);
                    return;
                end

                % preload the session
                preLoadSession(app, ROMSessionData, filename);
            end
        end

        function SessionData = validateSessionFile(~,filename)
            data = load(filename);
            if isfield(data,'ROMSessionData') && isa(data.ROMSessionData,'romapp.internal.data.AppData')
                SessionData = data.ROMSessionData;
            else
                romapp.internal.resources.error('errSessionFileFormat')
            end
        end

        function preLoadSession(app, SessionData, filename)
            %preLoadSession
            %
            % If SessionData is for the same model the app is currently
            % targeting update the app, if not open a new app.
            %
            % If Session data is not for a model and the app is currently not
            % for a model then refresh the app.
           
           if ~app.AppData.HaveSimulinkModel && ~SessionData.HaveSimulinkModel
                %Currently open session and session to be loaded both do
                %not have simulink models

                loadSession(app, SessionData, filename);
            else
                %One or the other of the current session and the loaded
                %session have a model
                if strcmp(app.AppData.Model,SessionData.Model)
                    %The sessions are for the same model
                    loadSession(app, SessionData, filename);
                else
                    %Sessions are either for different models, or one is not
                    %for a model.
                    romapp.reducedOrderModeler({SessionData})
                end
            end
        end

        function loadSession(app, SavedData, filename)
            % load models

            setAppDirty(app,false);

            if nargin < 3
                % load session data
                resetAppData(app, SavedData);
            else
                openingMsg = romapp.internal.resources.getString('msgOpeningSession', filename);
                % set App to bet busy
                setWaiting(app, true, openingMsg);
                % relay to Event Manager
                postActionStatus(app.EventManager, 'on', openingMsg);
                % load session data
                resetAppData(app, SavedData);
                % set waiting bar and message
                setWaiting(app, false);
                openedMsg = romapp.internal.resources.getString('msgOpenedSession',filename);
                postActionStatus(app.EventManager, 'off', openedMsg);
            end

            setAppDirty(app,false);
        end

        % save
        function canAppClose = askForSaveSession(app)
            qstn = romapp.internal.resources.getString('msgSaveSession');
            name = romapp.internal.resources.getString('lblSaveSession');
            yes = romapp.internal.resources.getString('lblYes');
            no = romapp.internal.resources.getString('lblNo');
            cancel = romapp.internal.resources.getString('lblCancel');

            selection = uiconfirm(app.Container, ...
                qstn, name,'Options', {yes,no,cancel},'DefaultOption',yes);

            switch selection
                case romapp.internal.resources.getString('lblYes')
                    canAppClose = promptForSaveSession(app);
                case romapp.internal.resources.getString('lblNo')
                    canAppClose = true;
                case romapp.internal.resources.getString('lblCancel')
                    canAppClose = false;
                otherwise
                    canAppClose = true;
            end

        end

        function hasSaved = promptForSaveSession(app, ~)

            data  = getAppData(app);
            SaveName = "ROMSession";
            if ~isempty(data.Model)
                SaveName = data.Model + "_" + SaveName;
            end

            [filename, pathname] = uiputfile( ...
                {'*.mat';'*.*'}, ...
                romapp.internal.resources.getString('lblSaveSession'), ...
                SaveName);
            if ~isequal(filename,0) && ~isequal(pathname,0)
                ROMSessionData = saveSession(app);
                save(fullfile(pathname, filename), 'ROMSessionData', '-v7.3');
                [~,name] = fileparts(filename);
                postActionStatus(app.EventManager, 'off', ...
                    romapp.internal.resources.getString('msgSavedSession', name));
                output = true;
            else
                output = false;
            end
            if nargout > 0
                hasSaved = output;
            end
        end

        function SessionData = saveSession(app)

            data  = getAppData(app);
            SessionData = getSaveData(data);
        end

        %Export
        function showExportDialog(app,mode,varargin)

            if isempty(app.ExportResultDialog) || ~isvalid(app.ExportResultDialog)
                data = getAppData(app);
                dlg = romapp.internal.dialogs.ExportResultsDialog(data,app.EventManager,app);
                app.ExportResultDialog = dlg;
            else
                dlg = app.ExportResultDialog;
            end
            setMode(dlg,mode,varargin{:})
            show(dlg, app);

            wd = getWidget(dlg);
            alreadyRegistered = hasDialog(app, wd.Tag);
            if isvalid(dlg) && ~alreadyRegistered
                registerDialog(app,wd)
            end

        end

        %Import
        function showImportDataDialog(app,options)
            %showImportDataDialog
            %

            arguments
                app romapp.internal.ReducedOrderModeler
                options.Mode {mustBeMember(options.Mode,{'fixed','new'})} = 'fixed';
                options.VariableName string = string.empty;
                options.VariableType romapp.internal.data.ImportType = romapp.internal.data.ImportType.Input;
            end

            switch options.Mode
                case "fixed"
                    %Convert ports to dataspec for import
                    data = getAppData(app);
                    dataspec = convertToImportSpec(data.ModelPorts);

                    if isempty(app.ImportDataWithFixedIODialog) || ~isvalid(app.ImportDataWithFixedIODialog)
                        dlgImportData = romapp.internal.dialogs.ImportDataWithFixedIODialog(dataspec);
                        fig = getWidget(dlgImportData);
                        fig.Tag = [fig.Tag,'-fixed-io']; %Make sure is unique figure for registration
                        if ~isempty(app.ImportListenerFixedIO)
                            delete(app.ImportListenerFixedIO)
                        end
                        app.ImportListenerFixedIO = addlistener(dlgImportData,'ImportPushed', @(hSrc,hData) cbImportData(app,hData,'add'));
                        app.ImportDataWithFixedIODialog = dlgImportData;
                    else
                        %Refresh dialog IOs as they could have changed.
                        setIOs(app.ImportDataWithFixedIODialog,dataspec)
                    end
                    show(app.ImportDataWithFixedIODialog,app.Container,'CENTER')

                    wd = getWidget(app.ImportDataWithFixedIODialog);
                    alreadyRegistered = hasDialog(app,wd.Tag);
                    if isvalid(app.ImportDataWithFixedIODialog) && ~alreadyRegistered
                        registerDialog(app,wd)
                    end
                case "new"
                    if isempty(app.ImportDataDialog) || ~isvalid(app.ImportDataDialog)
                        dlgImportData = romapp.internal.dialogs.ImportDataDialog();
                        if ~isempty(app.ImportListener)
                            delete(app.ImportListener)
                        end
                        app.ImportListener = addlistener(dlgImportData,'ImportPushed', @(hSrc,hData) cbImportData(app,hData,'reset'));
                        if ~isempty(app.ImportCanceledListener)
                            delete(app.ImportCanceledListener)
                        end
                        app.ImportCanceledListener = addlistener(dlgImportData, 'ImportCanceled', @(~,~)cbImportCanceled(app));
                        app.ImportDataDialog = dlgImportData;
                    end
                    show(app.ImportDataDialog,app.Container,'CENTER')
                    resetIOs(app.ImportDataDialog,... %works on visual components do needs to be after show which builds the components
                        VariableName=options.VariableName, ...
                        VariableType=options.VariableType) 

                    wd = getWidget(app.ImportDataDialog);
                    alreadyRegistered = hasDialog(app,wd.Tag);
                    if isvalid(app.ImportDataDialog) && ~alreadyRegistered
                        registerDialog(app,wd)
                    end
                otherwise
                    romapp.internal.resources.error('errUnexpected','Unsupported mode for Import Dialog')
            end
        end
        function showIndexedVariableImportDialog(app,data,options)
            %showIndexedVariableImportDialog
            %

            arguments
                app romapp.internal.ReducedOrderModeler
                data
                options.VariableName string = string.empty;
                options.VariableType romapp.internal.data.ImportType = romapp.internal.data.ImportType.Input;
            end

            if isempty(app.IndexedVariableImportDialog) || ~isvalid(app.IndexedVariableImportDialog)
                dlgImportData = romapp.internal.dialogs.ImportDataDialog();
                dlgImportData.GetDataFcn = @(x) lFakeWorkspace(data,options.VariableName,x);
                fig = getWidget(dlgImportData);
                fig.Tag = [fig.Tag,'-indexed-variable']; %Make sure is unique figure for registration
                if ~isempty(app.IndexedVariableImportListener)
                    delete(app.IndexedVariableImportListener)
                end
                app.IndexedVariableImportListener = addlistener(dlgImportData,'ImportPushed', @(hSrc,hData) cbImportData(app,hData,'indexedvariable'));
                app.IndexedVariableImportDialog = dlgImportData;
            end
            show(app.IndexedVariableImportDialog,app.Container,'CENTER')
            %Add items for indexed variables to the import dialog drop down
            dd = getDropDown(app.IndexedVariableImportDialog);
            dd.ShowNonExistentVariable = true;
            dd.NonExistentVariableName = options.VariableName{1};
            dd.Value = options.VariableName{1};
            dd.ItemsData = horzcat(dd.ItemsData,options.VariableName{:});
            dd.Items = horzcat(dd.Items,options.VariableName{:});
            dd.Enable = 'off';
            resetIOs(app.IndexedVariableImportDialog,...
                VariableName=options.VariableName, ...
                VariableType=options.VariableType) %works on visual components do needs to be after show which builds the components

            wd = getWidget(app.IndexedVariableImportDialog);
            alreadyRegistered = hasDialog(app,wd.Tag);
            if isvalid(app.IndexedVariableImportDialog) && ~alreadyRegistered
                registerDialog(app,wd)
            end
        end
        function cbImportData(this,hData,mode)
            %cbImportData Manage import data dialog events
            %

            switch mode
                case 'reset'
                    %Happens when launching the app or clicking new session
                    dlgImportData = this.ImportDataDialog;

                    E = lValidateImportData(dlgImportData.GetDataFcn,hData);
                    if ~isempty(E)
                        uialert(this.Container, E.message, this.Container.Title)
                        close(dlgImportData)
                        return
                    end
                    
                    %Change the IOs the app works with
                    changeIOsFromDataSpec(this,hData)
                case 'add'
                    %Happens when clicking import data
                    dlgImportData = this.ImportDataWithFixedIODialog;

                    %For datastores, we need to validate the import data so
                    %that the full datastore gets checked
                    if hData.ImportType == "datastore"
                        E = lValidateImportData(dlgImportData.GetDataFcn,hData);
                        if ~isempty(E)
                            uialert(this.Container, E.message, this.Container.Title)
                            close(dlgImportData)
                            return
                        end
                    end
                case 'indexedvariable'
                    %Happens when launching app with a variable with indexing
                    %(i.e., the tool doesn't know the variable name).
                    dlgImportData = this.IndexedVariableImportDialog;

                    %Change the IOs the app works with
                    changeIOsFromDataSpec(this,hData)
                otherwise
                    romapp.internal.resources.error('errUnexpected','Invalid mode for data import dialog')
            end

            % If the import data is a datastore, set up the transform
            % function. Otherwise, build an ArrayDatastore that returns
            % experiment data when read.
            if hData.ImportType == "datastore"
                expDS = this.importDatastoreData(hData,dlgImportData.GetDataFcn);
            else
                expDS = this.importInMemoryData(hData,dlgImportData.GetDataFcn);
            end

            %Create a simulation set, and set its spec empty (implies no
            %simulation). Set the results to the imported experiment datastore
            data = getAppData(this);
            SimSet = romapp.internal.data.SimulationSet(data.ModelPorts);
            SimSet.Name = matlab.lang.makeUniqueStrings(...
                romapp.internal.resources.getString('lblImportedData'),...
                [data.SimulationSets.Name]);
            SimSet.SimulationSpec = romapp.internal.data.SimulationSpec.empty;
            storeImportResult(SimSet,expDS)
            addSimulationSet(data,SimSet);
            
            %Close the import dialog
            close(dlgImportData)
        end

        %New session/select IOs
        function showSelectIOs(app,initialState)

            appContainer = app.Container;
            appData = getAppData(app);

            if isempty(app.SelectIODialog) || ~isvalid(app.SelectIODialog)
                app.SelectIODialog = romapp.internal.dialogs.SelectIODialog(appData);
            end
            %Make sure dialog is showing correct port settings
            if strcmp(initialState,'clear')
                clearWorkingData(app.SelectIODialog)
            else
                initializeWorkingData(app.SelectIODialog)
            end
            show(app.SelectIODialog, appContainer, 'CENTER');

            wd = getWidget(app.SelectIODialog);
            alreadyRegistered = hasDialog(app,wd.Tag);
            if isvalid(app.SelectIODialog) && ~alreadyRegistered
                registerDialog(app,wd)
            end
        end
    end

    methods (Access = private)
        function createAppContainer(app)
            title = romapp.internal.resources.getString('lblAppName');
            appData = getAppData(app);
            if appData.HaveSimulinkModel
                appOptions.Title = sprintf('%s-%s', title, appData.Model);
            else
                appOptions.Title = title;
            end
            appOptions.Tag = sprintf('rom-%s',app.ID);
            appOptions.ToolstripEnabled = true;
            appOptions.Product = 'System Identification Toolbox';
            appOptions.Scope = 'ROM Data Collection App';
            appOptions.EnableTheming = true;
            app.Container = matlab.ui.container.internal.AppContainer(appOptions);
        end

        function createPermanentTabs(app)
            % creates perm tabs - home (model reducer), plot, view

            data = getAppData(app);
            if data.HaveSimulinkModel
                app.ReduceSystemTab = romapp.internal.tabs.ReducedOrderModel(app);
            else
                app.ReduceSystemTab = romapp.internal.tabs.ReducedOrderModelDataOnly(app);
            end

            % create perm tab group
            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = sprintf('rom-permanent-tab-group-%s', app.ID);
            app.TabGroup = tabGroup;

            % add tabs to the group
            tabGroup.add(app.ReduceSystemTab.getTab());

            % add tab group to app container
            add(app.Container, tabGroup);
        end

        function createContextualHelpButton(app)
            helpButton = matlab.ui.internal.toolstrip.qab.QABHelpButton();
            helpButton.ButtonPushedFcn = @(varargin) helpview('simulink','reduced_order_modeler_app');
            app.Container.add(helpButton);
        end

        function createDataBrowserManager(app)
            % create tree browser for model ports
            app.ModelPortBrowser = romapp.internal.databrowser.ModelPorts(app);
            addToAppContainer(app.ModelPortBrowser, app.Container);

            % create table browser for simulation set
            app.SimulationSetBrowser = romapp.internal.databrowser.SimulationSet(app);
            addToAppContainer(app.SimulationSetBrowser, app.Container);
        end

        function createModelListener(app)
            %Create listener for model close events

            hMdl = get_param(app.AppData.Model,'Object');
            app.ModelListener = Simulink.listener(hMdl,'CloseEvent', @(hSrc,hData) close(app));
        end

        function changeIOsFromDataSpec(this,hData)
            %changeIOsFromDataSpec
            %

            data = getAppData(this);

            spec = hData.DataSpec;
            types = [spec.Type];

            %Create input ports
            idx = types == romapp.internal.data.ImportType.Input;
            s = spec(idx);
            sigIn = Simulink.SimulationData.Signal.empty;
            for ct=numel(s):-1:1
                sig = Simulink.SimulationData.Signal;
                sig.Name = s(ct).Name;
                sigIn(ct) = sig;
            end

            %Create output ports
            idx = types == romapp.internal.data.ImportType.Output;
            s = spec(idx);
            sigOut = Simulink.SimulationData.Signal.empty;
            for ct=numel(s):-1:1
                sig = Simulink.SimulationData.Signal;
                sig.Name = s(ct).Name;
                sigOut(ct) = sig;
            end

            %Create parameter
            types = [spec.Type];
            idx = types == romapp.internal.data.ImportType.Parameter;
            s = spec(idx);
            paramIn = romapp.internal.data.ModelParameter.empty;
            for ct=numel(s):-1:1
                param = romapp.internal.data.ModelParameter;
                param.Name = s(ct).Name;
                param.Workspace = 'global';
                paramIn(ct) = param;
            end

            logOut = Simulink.SimulationData.Signal.empty;
            sigExp = Simulink.SimulationData.Signal.empty;
            paramExp = romapp.internal.data.ModelParameter.empty;
            setPorts(data.ModelPorts,...
                'Inputs', sigIn(:), ...
                'Outputs', sigOut(:), ...
                'LoggedOutputs', logOut(:), ...
                'SimulationInputs', sigExp(:), ...
                'Parameters', paramIn(:), ...
                'SimulationParameters',paramExp(:));

            %Delete the existing simulation sets
            removeSimulationSet(data,[]) %remove all
        end

        function expDS = importDatastoreData(this,hData,GetDataFcn)
            % Get the app data, which contains the IO information.
            data = getAppData(this);

            % Do not pass the model ports or event data properties into
            % the anonymous transform function. Save to local variables
            % first to avoid garbage collection issues.
            sigIn = data.ModelPorts.InputSignals;
            sigOut = data.ModelPorts.OutputSignals;
            Ts = hData.SampleTime;
            spec = hData.DataSpec;
            tfcn = @(x) romapp.internal.data.SimulationSet.extractExperimentFromDatastore(...
                x, sigIn, sigOut, spec, Ts);
            dsName = extractBefore(hData.DataSpec(1).Expression,"(:)");
            DS = GetDataFcn(dsName);
            expDS = transform(DS,tfcn);
        end

        function expDS = importInMemoryData(this,hData,GetDataFcn)
            % Get the app data, which contains the IO information.
            data = getAppData(this);

            %Get the time info from the spec
            timeImplicit = ~isempty(hData.SampleTime);
            if timeImplicit
                SampleTime = hData.SampleTime;
                spec = hData.DataSpec;
                t = [];
            end

            %Create an experiment for the imported data
            expData = romapp.internal.data.ExperimentData();
            expData = repmat(expData,hData.NumDataset,1);

            for ct=1:hData.NumDataset
                if ~timeImplicit
                    spec = hData.DataSpec;
                    idx = [spec.Type] == romapp.internal.data.ImportType.Time;
                    try
                        expr = spec(idx).Expression;
                        if hData.NumDataset > 1
                            expr = regexprep(expr,'\{:\}',['{',num2str(ct),'}']);
                        end
                        t = GetDataFcn(expr);
                    catch E
                        uialert(this.Container, E.message, this.Container.Title)
                        close(dlgImportData)
                        return
                    end

                    if ~isduration(t)
                        t = seconds(t(:));
                    end
                    SampleTime = [];
                end

                %Import the different IO signals
                sig = data.ModelPorts.InputSignals;
                sig = lImportSignalData(sig,spec,GetDataFcn,...
                    timeImplicit,SampleTime,t,hData.NumDataset,ct);
                expData(ct).InputSignals = sig;
                sig = data.ModelPorts.OutputSignals;
                sig = lImportSignalData(sig,spec,GetDataFcn,...
                    timeImplicit,SampleTime,t,hData.NumDataset,ct);
                expData(ct).OutputSignals = sig;

                %Import any parameter values
                params = data.ModelPorts.InputParameters;
                params = lImportParameterData(params,spec,GetDataFcn, ...
                    hData.NumDataset,ct);
                expData(ct).InputParameters = params;
            end

            %Convert the experiment array into a datastore
            expDS = arrayDatastore(expData,'OutputType','same');
        end

        function cbImportCanceled(app)
            data = getAppData(app);
            haveIOs = getNumPorts(data.ModelPorts) > 0;
            if ~haveIOs
                delete(app)
            end
        end
    end

    methods
        function flag = isAppDirty(app)
            % Dirty actions:

            flagApp = get(app, 'IsDirty'); % import/create/remove models
            flagTool = false;

            flag = any([flagApp, flagTool]);
        end

        function set.IsDirty(app, flag)
            app.IsDirty = flag;
        end

        function Flag = get.IsDirty(app)
            Flag = app.IsDirty;
        end

        function setAppDirty(app, flag)
            if islogical(flag)
                set(app, 'IsDirty', flag);
            end
        end
    end

    methods(Hidden = true)
        function dlgs = qeGetDialogs(this)

            dlgs = struct(...
                'Export', this.ExportResultDialog, ...
                'SelectIO', this.SelectIODialog);
        end
    end
end

function sig = lImportSignalData(sig,spec,importFcn,timeImplicit,SampleTime,t,NumDataset,idxDataset)
%lImportSignalData
%

for ct=1:numel(sig)
    idx = [spec.Name] == romapp.internal.data.ModelPorts.getDisplayName(sig(ct));
    if any(idx)
        if NumDataset > 1
            expr = spec(idx).Expression;
            expr = regexprep(expr,'\{:\}',['{',num2str(idxDataset),'}']);
            vals = importFcn(expr);
        else
            vals = importFcn(spec(idx).Expression);
        end
        if isduration(vals)
            %Can happen if import time from timetable as an input or output
            vals = seconds(vals);
        end
        if timeImplicit
            t = (0:numel(vals)-1)*SampleTime;
            t = seconds(t(:));
        end
        sig(ct).Values = timetable(t(:),vals(:),'VariableNames',{'Data'});
    end
end
end

function pdata = lImportParameterData(param,spec,importFcn,NumDataset,idxDataset)
%lImportParameterData
%

if isempty(param)
    %Quick return, nothing to do.
    pdata = romapp.internal.data.ParameterData.empty;
    return
end

for ct=numel(param):-1:1
    idx = [spec.Name] == romapp.internal.data.ModelPorts.getDisplayName(param(ct));
    if any(idx)
        p = romapp.internal.data.ParameterData;
        p.BlockPath = param(ct).BlockPath;
        p.Name = param(ct).Name;
        if NumDataset > 1
            expr = spec(idx).Expression;
            expr = regexprep(expr,'\{:\}',['{',num2str(idxDataset),'}']);
            p.Value = importFcn(expr);
        else
            p.Value = importFcn(spec(idx).Expression);
        end
        pdata(ct) = p;
    end
end
end

function result = lFakeWorkspace(dataLocal,varnameLocal, exprLocal) %#ok<INUSD>

for ctLocal=1:numel(varnameLocal)
    if isempty(varnameLocal{ctLocal})
        eval("Data = dataLocal{"+ctLocal+"};");
    else
        eval(varnameLocal{ctLocal}+" = dataLocal{"+ctLocal+"};");
    end
end

result = eval(exprLocal);
end

function E = lValidateImportData(getFcn,hData)

E = [];
DataSpec = hData.DataSpec;
nDataset = hData.NumDataset;

if hData.ImportType == "datastore"
    % Check the full datastore while importing
    try
        expr = DataSpec(1).Expression;
        dsName = extractBefore(expr,"(:)");
        DS = getFcn(dsName);
        lCheckFullDatastore(DS);
    catch E
        % There was an error either getting the datastore object or read
        % operations were inconsistent
        return
    end
else
    for ctDS=1:nDataset
        for ct=1:numel(DataSpec)
            try
                expr = DataSpec(ct).Expression;
                if nDataset > 1
                    %Expression has {:} from import of multiple datasets, replaced with dataset index,
                    expr = regexprep(expr, '\{:\}', "{"+ctDS+"}",'once');
                end
                getFcn(expr+";");
            catch E
                return
            end
        end
    end
end
end

function tf = lCheckFullDatastore(var)
% Read the datastore as long as data exists and verify that each read
% returns the same format
reset(var);
firstRead = read(var);
expectTT = istimetable(firstRead);
nIO = size(firstRead,2);
while hasdata(var)
    currRead = read(var);
    tf = romapp.internal.dialogs.ImportDataDialog.isValidImportData(currRead);
    % Check that each read is consistent
    tf = tf && (expectTT == istimetable(currRead)) && (nIO == size(currRead,2));

    if ~tf
        romapp.internal.resources.error('errInvalidDatastore')
    end
end
end

% LocalWords:  controllib lbl IOs QABUndoButton QABRedoButton dataspec cb indexedvariable
