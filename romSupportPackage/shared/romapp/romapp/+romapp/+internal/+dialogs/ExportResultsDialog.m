classdef ExportResultsDialog < controllib.ui.internal.dialog.AbstractDialog
    % Select results to export to MATLAB workspace
    %

    % Copyright 2023-2025 The MathWorks, Inc.

    properties (SetAccess = private,Hidden, ...
            GetAccess=?matlab.unittest.TestCase)
        Widgets struct
        Data
        EventManager
        App

        ExperimentManager
    end

    properties(Access = protected)
        Mode %One of {'workspace', 'experimentmanager'}
        EMData %Data for EM project to create
    end

    methods
        function this = ExportResultsDialog(data,eventmanager,app)
            this = this@controllib.ui.internal.dialog.AbstractDialog();
            this.Data = data;
            this.Mode = 'workspace';
            this.EventManager = eventmanager;
            if nargin > 2
                this.App = app;
            end
            this.ExperimentManager = [];
                        
            this.Name = 'ExportResultsDialog';
            this.Title = romapp.internal.resources.getString('lblExportResults');
        end

        function updateUI(this)
            %updateUI
            %

            switch this.Mode
                case 'workspace'
                    this.Widgets.lblExport.Text = romapp.internal.resources.getString('lblExportResults_Workspace_Description');
                    includeProperty = 'IncludeForExportToWorkspace';
                    experimentType = 'romapp.internal.experimentmanager.ROMExperiment';
                case 'experimentmanager'
                    name = this.EMData.Name;
                    this.Widgets.lblExport.Text = romapp.internal.resources.getString('lblExportResults_EM_Description',name);
                    includeProperty = 'IncludeForTraining';
                    experimentType = char(this.EMData.Type);
            end

            %Get data to display
            data = this.Data.SimulationSets;
            nData = numel(data);
            tblData = cell(nData,3);
            for ct=1:nData
                tblData{ct,2} = char(data(ct).Name);
                tblData{ct,1} = true;
                if isempty(data(ct).Results)
                    isError = logical.empty;
                else
                    isError = data(ct).IsError;
                end
                isExclude = ~data(ct).(includeProperty);
                if isempty(isExclude)
                    nExclude = nnz(isError);
                elseif isempty(isError)
                    nExclude = 0;
                else
                    nExclude = nnz(isExclude | isError);
                end
                nTot = data(ct).NumResults;
                fcn = str2func([experimentType '.getResultsToExportString']);
                tblData{ct,3} = char(fcn(nTot, nExclude));
                if nExclude > 0 && ~contains(experimentType,'InterpStatic')
                    if strcmp(this.Mode, 'experimentmanager') && any(isError)
                        % Results are only excluded due to errors
                        % (automatically) if exporting to experiment
                        % manager and not gridded case
                        nError = nnz(isError);
                        errorStr = string(romapp.internal.resources.getString('msgExportResults_ExcludedByError', nError));
                    else
                        nError = 0;
                        errorStr = string.empty;
                    end
                    nManual = nExclude - nError;
                    if nManual > 0
                        manualStr = string(romapp.internal.resources.getString('msgExportResults_ExcludedBySelection', nManual));
                    else
                        manualStr = string.empty;
                    end
                    explanationStr = sprintf(" (%s)", strjoin([errorStr manualStr], ", "));
                    tblData{ct,3} = [tblData{ct,3} char(explanationStr)];
                end
            end
            % add a column for gridded interpolation case where can choose
            % a specific set for test data
            if strcmp(this.Mode, 'experimentmanager')
                if contains(this.EMData.Type,'InterpStatic.griddedInterpExperiment')
                    newC = repmat({false},nData,1);
                    tblData = [tblData,newC];
                end
            end
        
            %Update the table
            this.Widgets.tblExport.Data = tblData;

            %If exporting to EM, update the I/O selection table
            this.updateSelectIOTable(strcmp(this.Mode, 'experimentmanager'));

            %Enable the OK button based on the dialog state
            enableOKButton(this);
        end

        function updateSelectIOTable(this, show)
            % Update data for the I/O selection table to show all ROM input
            % signals and output signals. If show is false, then hide the
            % gridlayout rows containing the table and the text above it.
            grid = this.Widgets.tblSelectIO.Parent;
            tblRow = this.Widgets.tblSelectIO.Layout.Row;
            msgRow = tblRow - 1;
            if show
                % Show the widgets
                grid.RowHeight{msgRow} = 'fit';
                grid.RowHeight{tblRow} = '1x';

                % Update the table data
                inputSignalNames = romapp.internal.data.ModelPorts.getFullName(this.Data.ModelPorts.InputSignals);
                outputSignalNames = romapp.internal.data.ModelPorts.getFullName(this.Data.ModelPorts.OutputSignals);
                nI = numel(inputSignalNames);
                nO = numel(outputSignalNames);
                col1 = repmat({true},nI+nO,1);
                col2 = [repmat({romapp.internal.resources.getString('lblImportData_Input')},nI,1); ...
                    repmat({romapp.internal.resources.getString('lblImportData_Output')},nO,1)];
                col3 = cellstr([inputSignalNames; outputSignalNames]);
                oldData = this.Widgets.tblSelectIO.Data;

                % Preserve I/O selection where possible
                if ~isempty(oldData)
                    oldIOSignals = oldData(:,3);
                    for iR = 1:numel(col3)
                        [~,I] = ismember(col3{iR}, oldIOSignals);
                        if I ~= 0
                            % The signal existed in the previous I/O data.
                            % Preserve the selection
                            col1{iR} = oldData{I,1};
                        end
                    end
                end

                % Set the data
                this.Widgets.tblSelectIO.Data = [col1 col2 col3];
            else
                % Hide the widgets
                grid.RowHeight{msgRow} = 0;
                grid.RowHeight{tblRow} = 0;
            end
        end

        function setMode(this,mode,varargin)

            this.Mode = mode;
            if strcmp(this.Mode,'experimentmanager') 
                emtype = varargin{1};
                name = eval(emtype+".NAME");
                this.EMData = struct('Type',emtype,'Name',name);
            end
        end
    end

    methods (Access = protected)
        function buildUI(this)
            f = this.UIFigure;
            f.Tag = 'rom-export-data-dialog';
            mainGridLayout = uigridlayout(f, [8 4]);
            mainGridLayout.RowHeight = {'fit','1x','fit','1x','fit','fit'};
            mainGridLayout.ColumnWidth = {'1x','fit'};

            %Export label
            lblExport = uilabel(mainGridLayout);
            lblExport.Layout.Row = 1;
            lblExport.Layout.Column = [1 2];
            lblExport.Text = romapp.internal.resources.getString('lblExportResults_Workspace_Description');

            %Export table
            tblExport = uitable(mainGridLayout);
            tblExport.Layout.Row = 2;
            tblExport.Layout.Column = [1 2];
            tblExport.ColumnWidth = {'fit','1x','1x','fit'};
            tblExport.ColumnFormat = {'logical', 'char','char','logical'};
            tblExport.ColumnEditable = [true false false true];
            tblExport.ColumnName = {...
                romapp.internal.resources.getString('lblExportResults_Export'), ...
                romapp.internal.resources.getString('lblSimulation'), ...
                romapp.internal.resources.getString('lblSimulationResults'), ...
                romapp.internal.resources.getString('lblExportResults_Training')}; 
            tblExport.RowName = [];

            %Select I/O label
            lblSelectIO = uilabel(mainGridLayout);
            lblSelectIO.Layout.Row = 3;
            lblSelectIO.Layout.Column = [1 2];
            lblSelectIO.Text = romapp.internal.resources.getString('lblExportResults_EM_SelectIODescription');

            %Select I/O table
            tblSelectIO = uitable(mainGridLayout);
            tblSelectIO.Layout.Row = 4;
            tblSelectIO.Layout.Column = [1 2];
            tblSelectIO.ColumnWidth = {50,'fit','1x'};
            tblSelectIO.ColumnFormat = {'logical', 'char','char'};
            tblSelectIO.ColumnEditable = [true false false];
            tblSelectIO.ColumnName = {'', ...
                romapp.internal.resources.getString('lblExportResults_EM_IOType'), ...
                romapp.internal.resources.getString('lblExportResults_EM_Signal')}; 
            tblSelectIO.RowName = [];

            %Error label
            lblError = uilabel(mainGridLayout);
            lblError.Layout.Row = 5;
            lblError.Layout.Column = [1 2];
            lblError.WordWrap = "on";
            lblExport.Text = '';
            lblError.HorizontalAlignment = 'right';
            
            %Ok, cancel, help buttons
            pnl = uipanel(mainGridLayout,'BorderType','none');
            pnl.Layout.Row = 6;
            pnl.Layout.Column = [1 2];
            pnlOCH = controllib.widget.internal.buttonpanel.ButtonPanel(pnl, ["Help" "OK" "Cancel"]);

            % store in a struct
            this.Widgets = struct(...
                'tblExport', tblExport, ...
                'tblSelectIO', tblSelectIO, ...
                'lblError', lblError, ...
                'pnlOCH', pnlOCH, ...
                'lblExport', lblExport);

        end
        function connectUI(this)

            %Ok, cancel, help buttons
            this.Widgets.pnlOCH.OKButton.ButtonPushedFcn = @(hSrc,hData) cbOK(this);
            this.Widgets.pnlOCH.CancelButton.ButtonPushedFcn = @(hSrc,hData) cbCancel(this);
            this.Widgets.pnlOCH.HelpButton.ButtonPushedFcn = @(hSrc,hData) cbHelp(this);
            addlistener(this.Widgets.tblExport,'CellEdit',@(~,hData) cbCellEdited_Experiments(this,hData));
            addlistener(this.Widgets.tblSelectIO,'CellEdit',@(~,~) enableOKButton(this));
        end

        function cbCellEdited_Experiments(this,hData)
            % for gridded interpolant, select a maximum of one gridded parameter experiment
            if strcmp(this.Mode, 'experimentmanager')
                if contains(this.EMData.Type,'griddedInterpExperiment')
                    col = hData.Indices(2);
                    if col == 4
                        row = hData.Indices(1);
                        data = this.Data.SimulationSets;                                 
                        if isa(data(row).SimulationSpec.ParameterSpec,'romapp.internal.data.GriddedParameterSpec') ...
                                && all(cellfun(@numel, data(row).SimulationSpec.ParameterSpec.Values)>1)
                            % if new selection is valid, set all other rows to false
                            for ct = 1:numel(data)
                                if ct ~= row
                                    this.Widgets.tblExport.Data{ct,4} = false;
                                end
                            end
                            enableOKButton(this);
                        else                      
                            % all "Select for training" have default of false.
                            % if new selection does not have enough points in any dimensions, 
                            % or is parameter distribution experiment, revert
                            this.Widgets.tblExport.Data{row,4} = false;
                            enableOKButton(this); % Do before overwriting the error text
                            this.Widgets.lblError.Text = romapp.internal.resources.getString('errExportResults_GriddedSelection');
                            matlab.graphics.internal.themes.specifyThemePropertyMappings(this.Widgets.lblError,'FontColor','--mw-color-error')
                        end
                    end
                end
            else
                enableOKButton(this);
            end
        end

        function enableOKButton(this)
            % Enable or disable the OK button based on the selections in
            % the experiments table and the inputs/outputs table. If
            % disabled, show an error explaining why.

            % Check if experiment selection is valid
            idx = [this.Widgets.tblExport.Data{:,1}];
            if strcmp(this.Mode, 'experimentmanager') && isfield(this.EMData,'Type') && ...
                    contains(this.EMData.Type,'InterpStatic.griddedInterpExperiment')
                idxTraining = [this.Widgets.tblExport.Data{:,4}];
                idx = idx & idxTraining;
            end
            hasExperimentSelection = any(idx);

            % Check if I/O selection is valid
            if strcmp(this.Mode, 'experimentmanager')
                nI = numel(this.Data.ModelPorts.InputSignals);
                nO = numel(this.Data.ModelPorts.OutputSignals);
                idxInput = this.Widgets.tblSelectIO.Data(1:nI,1);
                idxInput = vertcat(idxInput{:});
                hasValidInputSelection = nI == 0 || any(idxInput);
                hasUnselectedInputs = hasValidInputSelection && ~all(idxInput);
                idxOutput = this.Widgets.tblSelectIO.Data(nI+1:nI+nO,1);
                idxOutput = vertcat(idxOutput{:});
                hasValidOutputSelection = any(idxOutput);
            else
                hasValidInputSelection = true;
                hasValidOutputSelection = true;
                hasUnselectedInputs = false;
            end

            % Display an error message if needed
            if ~hasExperimentSelection
                this.Widgets.lblError.Text = romapp.internal.resources.getString('errExportResults_NoSelection');
                matlab.graphics.internal.themes.specifyThemePropertyMappings(this.Widgets.lblError,'FontColor','--mw-color-error')
            elseif ~hasValidInputSelection
                this.Widgets.lblError.Text = romapp.internal.resources.getString('errExportResults_InvalidInputSelection');
                matlab.graphics.internal.themes.specifyThemePropertyMappings(this.Widgets.lblError,'FontColor','--mw-color-error')
            elseif ~hasValidOutputSelection
                this.Widgets.lblError.Text = romapp.internal.resources.getString('errExportResults_InvalidOutputSelection');
                matlab.graphics.internal.themes.specifyThemePropertyMappings(this.Widgets.lblError,'FontColor','--mw-color-error')
            elseif hasUnselectedInputs
                this.Widgets.lblError.Text = romapp.internal.resources.getString('warnExportResults_UnselectedInputs');
                matlab.graphics.internal.themes.specifyThemePropertyMappings(this.Widgets.lblError,'FontColor','--mw-color-warning')
            else
                this.Widgets.lblError.Text = '';
            end

            % Enable the OK button if everything is valid
            this.Widgets.pnlOCH.OKButton.Enable = hasExperimentSelection && hasValidInputSelection && hasValidOutputSelection;
        end
        
        function cbOK(this)
            switch this.Mode
                case 'workspace'
                    exportToWorkspaceData(this)
                case 'experimentmanager'
                    exportToEM(this)
            end
            %Close the dialog
            cbCancel(this)
        end

        function cbCancel(this)
            close(this)
        end

        function cbHelp(~)
            helpview('simulink','rom_export_results')
        end
        
        function exportToWorkspaceData(this)

            data = this.Data.SimulationSets;
            idx = this.Widgets.tblExport.Data(:,1);
            data = data([idx{:}]);
            badExperiments = string.empty;
            for ct=1:numel(data)
                result = data(ct).Results;
                isExcluded = ~data(ct).IncludeForExportToWorkspace;
                if all(isExcluded)
                    badExperiments = [badExperiments, data(ct).Name]; %#ok<AGROW>
                    continue
                elseif any(isExcluded)
                    result = subset(result,~isExcluded);
                end
                name = matlab.lang.makeValidName(data(ct).Name);
                name = matlab.lang.makeUniqueStrings(name,evalin('base','who'));
                assignin('base',name,result)
            end

            % Show an error if any of the selected experiments had no
            % selected results
            if ~isempty(badExperiments)
                if isempty(this.App)
                    fig = this.UIFigure;
                else
                    fig = this.App.Container;
                end
                uialert(fig,...
                    romapp.internal.resources.getString('errExportResults_AllUnselected'), ...
                    romapp.internal.resources.getString('lblError'), ...
                    'Icon', 'error');
                return
            end

            if ~isempty(this.EventManager)
                postActionStatus(this.EventManager, 'off', romapp.internal.resources.getString('msgExportResults_Workspace_Exported'));
            end
        end

        function exportToEM(this)
            data = this.Data.SimulationSets;
            canSelectTestData = size(this.Widgets.tblExport.Data,2) > 3;
            if canSelectTestData
                idxTraining = [this.Widgets.tblExport.Data{:,4}];
                idxTest = [this.Widgets.tblExport.Data{:,1}] & ~idxTraining;
            else
                idxTraining = [this.Widgets.tblExport.Data{:,1}];
                idxTest = [];
            end

            try 
                cmd = this.EMData.Type+".prepareResults";
                [trainDS,testDS] = feval(cmd,data,idxTraining,idxTest); %#ok<ASGLU>
            catch E
                if isempty(this.App)
                    fig = this.UIFigure;
                else
                    fig = this.App.Container;
                end
                
                uialert(fig,...
                    E.message, ...
                    romapp.internal.resources.getString('lblError'), ...
                    'Icon','error');
                return
            end
            
            % warning window for empty training results
            if ~hasdata(trainDS)
                if isempty(this.App)
                    fig = this.UIFigure;
                else
                    fig = this.App.Container;
                end
                uialert(fig,...
                    romapp.internal.resources.getString('errExportResults_NoResults'), ...
                    romapp.internal.resources.getString('lblError'), ...
                    'Icon', 'error');
                return
            end

            % Add a DS transformation to remove any inputs/outputs that the user unselected
            IOSelectionData = this.Widgets.tblSelectIO.Data;
            nI = numel(this.Data.ModelPorts.InputSignals);
            nO = numel(this.Data.ModelPorts.OutputSignals);
            idxInput = IOSelectionData(1:nI,1);
            idxInput = vertcat(idxInput{:});
            idxOutput = IOSelectionData(nI+1:nI+nO,1);
            idxOutput = vertcat(idxOutput{:});
            if any(~idxInput) || any(~idxOutput)
                % If there is anything to exclude, go through each set of
                % results and remove the proper I/O
                trainDS = transform(trainDS, @(x) x.removeIOSignals(idxInput,idxOutput));
                if ~isempty(testDS)
                    testDS = transform(testDS, @(x) x.removeIOSignals(idxInput,idxOutput));
                end
            end

            try
                cmd = this.EMData.Type;
                if size(this.Widgets.tblExport.Data,2) > 3
                    emClass = eval(cmd+"(trainDS,testDS)");
                else
                    emClass = eval(cmd+"(trainDS)");                    
                end
                em = experiments.internal.exportToExperimentManager(emClass,struct());
                this.ExperimentManager = em;
            catch E
                romapp.internal.resources.error('errUnexpected',['Invalid model type: ',E.message])
            end


            if ~isempty(this.EventManager)
                postActionStatus(this.EventManager, 'off', romapp.internal.resources.getString('msgExportResults_EM_Exported'));
            end

        end
    end
end

% LocalWords:  tblExport pnlOCH lbl experimentmanager tbl interpolant mw
