classdef ImportDataDialog < controllib.ui.internal.dialog.AbstractDialog
    % Import Data from MATLAB workspace
    %

    % Copyright 2024-2026 The MathWorks, Inc.

    properties (SetAccess = protected, GetAccess={?romapp.internal.dialogs.ImportDataDialog,?matlab.unittest.TestCase})
        Widgets struct
    end

    properties(Access = protected)
        DefaultTimeAlongRows logical = true
        TableHasTime logical = false;
        AllowParameters logical = true;
        NumDatasetToImport = 1;
        ImportType string = "workspace";
    end

    properties(GetAccess = public)
        GetDataFcn function_handle = @(expr) evalin('base',expr);
        FilterWorkspaceVariableFcn function_handle = @(x) romapp.internal.dialogs.ImportDataDialog.isValidImportData(x);
        DefaultPortType = romapp.internal.data.ImportType.Input;
        HelpFcn function_handle = @() romapp.internal.dialogs.ImportDataDialog.defaultHelp();
    end

    events(NotifyAccess = protected, ListenAccess = public)
        ImportPushed
        ImportCanceled
    end

    methods
        function this = ImportDataDialog()
            this = this@controllib.ui.internal.dialog.AbstractDialog();

            this.Name = 'ImportDataDialog';
            this.Title = romapp.internal.resources.getString('lblImportData');
        end

        function updateUI(this)
            %updateUI
            %

            %Disable add button if there is no selection in data to import
            %drop-down
            itemToAdd = this.Widgets.ddDataToImport.Value;
            nothingToAdd = strcmp(itemToAdd,this.Widgets.ddDataToImport.ItemsData{1});
            this.Widgets.btnAdd.Enable = ~nothingToAdd;
            if nothingToAdd
                this.Widgets.lblDataDescription.Text = "";
            else
                [data,E] = evalExpression(this,itemToAdd);
                if isempty(E)
                    str = lGetSummaryString(itemToAdd,data);
                else
                    str = E.message;
                end
                
                this.Widgets.lblDataDescription.Text = str;
            end

            %Disable delete button if no table rows are selected.
            this.Widgets.btnDeleteRow.Enable = ~isempty(this.Widgets.tblIOs.Selection);

            %Disable sample time widgets
            if isempty(this.Widgets.tblIOs.Data)
                this.TableHasTime = false;
            else
                this.TableHasTime = any(strcmp(this.Widgets.tblIOs.Data(:,2),string(romapp.internal.data.ImportType.Time)));
            end
            this.Widgets.chkTimeImplicit.Enable = ~this.TableHasTime;
            this.Widgets.lblSampleTime.Enable = this.Widgets.chkTimeImplicit.Value && ~this.TableHasTime;
            this.Widgets.edtSampleTime.Enable = this.Widgets.chkTimeImplicit.Value && ~this.TableHasTime;

            %Perform checks to enable/disable import button and display
            %status messages
            updateImportButton(this)
        end

        function resetIOs(this,options)
            %setIOs

            arguments
                this romapp.internal.dialogs.ImportDataDialog
                options.VariableName string = string.empty
                options.VariableType romapp.internal.data.ImportType = romapp.internal.data.ImportType.Input
            end

            if ~isempty(this.Widgets)
                %Dialog has been built, refresh

                %Clear out any data entries
                this.Widgets.ddDataToImport.ValueIndex = 1;
                this.Widgets.tblIOs.Data = cell(0,3);
                this.Widgets.edtSampleTime.Value = 1;
                this.Widgets.chkTimeImplicit.Value = false;

                if ~isempty(options.VariableName)
                    for ct=1:numel(options.VariableName)
                        idx = strcmp(this.Widgets.ddDataToImport.ItemsData,options.VariableName(ct));
                        if any(idx)
                            this.Widgets.ddDataToImport.ValueIndex = find(idx,1);
                            if isscalar(options.VariableType)
                                cbAddData(this,options.VariableType);
                            else
                                cbAddData(this,options.VariableType(ct));
                            end
                        end
                    end
                end

                %Update the widget states
                updateUI(this)
            end
        end

        function dd = getDropDown(this)
            %getDropDown

            if isempty(this.Widgets)
                dd = [];
            else
                dd = this.Widgets.ddDataToImport;
            end
        end

        function [r,e] = evalExpression(this,expr)

            e = MException.empty;
            try
                r = this.GetDataFcn(expr);
            catch e
                r = [];
            end
        end
    end

    methods (Access = protected)
        function buildUI(this)
            f = this.UIFigure;
            f.Tag = 'rom-import-data-dialog';
            mainGridLayout = uigridlayout(f, [6 1]);
            mainGridLayout.RowHeight = {'fit','1x','fit','fit','fit','fit'};
            mainGridLayout.ColumnWidth = {'1x'};
            mainGridLayout.RowSpacing = 0;

            %Data to Import widgets
            pnlDataToImport = uigridlayout(mainGridLayout,[2 3]);
            pnlDataToImport.Padding([1 3]) = 0; %No left/right padding
            pnlDataToImport.RowHeight = {'fit'};
            pnlDataToImport.ColumnWidth = {'fit','1x','fit'};
            pnlDataToImport.Layout.Row = 1;
            pnlDataToImport.Layout.Column = 1;
            lblDataToImport = uilabel(pnlDataToImport);
            lblDataToImport.Layout.Row = 1;
            lblDataToImport.Layout.Column = 1;
            lblDataToImport.Text = romapp.internal.resources.getString('lblImportData_DataToImport') + ":";
            ddDataToImport = matlab.ui.control.internal.model.WorkspaceDropDown('Parent',pnlDataToImport);
            ddDataToImport.FilterVariablesFcn = this.FilterWorkspaceVariableFcn;
            ddDataToImport.Layout.Row = 1;
            ddDataToImport.Layout.Column = 2;
            ddDataToImport.Editable = false; %Don't allow random entries
            btnAdd = uibutton(pnlDataToImport);
            btnAdd.Layout.Row = 1;
            btnAdd.Layout.Column = 3;
            btnAdd.Text = romapp.internal.resources.getString('lblImportData_Add');
            lblDataDescription = uilabel(pnlDataToImport);
            lblDataDescription.Layout.Row = 2;
            lblDataDescription.Layout.Column = [2 3];

            %IOTable
            tblIOs = uitable(mainGridLayout);
            tblIOs.Layout.Row = 2;
            tblIOs.Layout.Column = 1;
            tblIOs.ColumnName = {...
                romapp.internal.resources.getString('lblImportData_Name'), ...
                romapp.internal.resources.getString('lblImportData_Type'), ...
                romapp.internal.resources.getString('lblImportData_Data')};
            tblIOs.ColumnWidth = {'1x','fit','fit'};
            tblIOs.ColumnEditable = [true, true, false];
            tblIOs.SelectionType = 'row';
            typeValues = {...
                string(romapp.internal.data.ImportType.Input), ...
                string(romapp.internal.data.ImportType.Output), ...
                string(romapp.internal.data.ImportType.Time), ...
                string(romapp.internal.data.ImportType.Parameter)};
            if ~this.AllowParameters
                typeValues(4) = [];
            end
            tblIOs.ColumnFormat = {'char', typeValues, 'char'};
            tblIOs.RowName = [];
            cmIOs = uicontextmenu(f);
            cm1 = uimenu(cmIOs,"Text",romapp.internal.resources.getString('lblImportData_Delete'));
            cm2 = uimenu(cmIOs,"Text",romapp.internal.resources.getString('lblImportData_SetInput'));
            cm3 = uimenu(cmIOs,"Text",romapp.internal.resources.getString('lblImportData_SetOutput'));
            if this.AllowParameters
                cm4 = uimenu(cmIOs,"Text",romapp.internal.resources.getString('lblImportData_SetParameter'));
            else
                cm4 = [];
            end
            tblIOs.ContextMenu = cmIOs;

            %Delete row widgets
            pnlDeleteRow = uigridlayout(mainGridLayout,[1 2]);
            pnlDeleteRow.Padding(4) = 1; %Small top padding
            pnlDeleteRow.Padding(3) = 0; %No right padding
            pnlDeleteRow.RowHeight = {'fit'};
            pnlDeleteRow.ColumnWidth = {'1x','fit'};
            pnlDeleteRow.Layout.Row = 3;
            pnlDeleteRow.Layout.Column = 1;
            btnDeleteRow = uibutton(pnlDeleteRow);
            btnDeleteRow.Layout.Row = 1;
            btnDeleteRow.Layout.Column = 2;
            btnDeleteRow.Text = romapp.internal.resources.getString('lblImportData_Delete');

            %Sample time widgets
            pnlTimeImplicit = uigridlayout(mainGridLayout, [1 4]);
            pnlTimeImplicit.Padding([1 3 4]) = 0; %No left/right/top padding
            pnlTimeImplicit.RowHeight = {'fit'};
            pnlTimeImplicit.ColumnWidth = {'fit','fit','fit','1x'};
            pnlTimeImplicit.Layout.Row = 4;
            pnlTimeImplicit.Layout.Column = 1;
            chkTimeImplicit = uicheckbox(pnlTimeImplicit);
            chkTimeImplicit.Layout.Row = 1;
            chkTimeImplicit.Layout.Column = 1;
            chkTimeImplicit.Text = romapp.internal.resources.getString('lblImportData_TimeImplicit');
            lblSampleTime = uilabel(pnlTimeImplicit);
            lblSampleTime.Layout.Row = 1;
            lblSampleTime.Layout.Column =2;
            lblSampleTime.Text = romapp.internal.resources.getString('lblImportData_SampleTime')+":";
            edtSampleTime = uieditfield(pnlTimeImplicit,"numeric");
            edtSampleTime.Layout.Row = 1;
            edtSampleTime.Layout.Column = 3;
            edtSampleTime.Limits = [0 inf];
            edtSampleTime.LowerLimitInclusive = false;
            edtSampleTime.UpperLimitInclusive = false;
            edtSampleTime.Value = 1;

            %Error label
            pnlError = uigridlayout(mainGridLayout,[1 1]);
            pnlError.Padding([1 3 4]) = 0; %No left/right/top padding
            pnlError.Layout.Row = 5;
            pnlError.Layout.Column = 1;
            lblError = uilabel(pnlError);
            lblError.Layout.Row = 1;
            lblError.Layout.Column = 1;
            lblError.WordWrap = "on";
            lblError.Text = '';
            lblError.HorizontalAlignment = 'left';
            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')

            %Ok, cancel, help buttons
            pnl = uipanel(mainGridLayout,'BorderType','none');
            pnl.Layout.Row = 6;
            pnl.Layout.Column = 1;
            pnlOCH = controllib.widget.internal.buttonpanel.ButtonPanel(pnl, ...
                ["Help", "Import", "Cancel"]);

            % store in a struct
            this.Widgets = struct(...
                'btnAdd', btnAdd, ...
                'ddDataToImport', ddDataToImport, ...
                'lblDataDescription', lblDataDescription, ...
                'cmDeleteRow', cm1, ...
                'cmSetInput', cm2, ...
                'cmSetOutput', cm3, ...
                'cmSetParameter', cm4, ...
                'tblIOs', tblIOs, ...
                'btnDeleteRow', btnDeleteRow, ...
                'chkTimeImplicit', chkTimeImplicit, ...
                'lblSampleTime', lblSampleTime, ...
                'edtSampleTime', edtSampleTime, ...
                'lblError', lblError, ...
                'pnlOCH', pnlOCH);
        end

        function connectUI(this)

            weak = romapp.internal.resources.WeakReference(this);

            %Data to import drop-down and add
            addlistener(this.Widgets.ddDataToImport,'ValueChanged', @(hSrc,hData)cbDDData(weak.Handle));
            addlistener(this.Widgets.btnAdd,'ButtonPushed',@(hSrc,hData)cbAddData(weak.Handle));

            %IO table
            this.Widgets.tblIOs.CellEditCallback = @(hSrc,hData) updateUI(weak.Handle);
            this.Widgets.tblIOs.CellSelectionCallback = @(hSrc,hData) updateDeleteButton(weak.Handle);
            %IO Table context menus
            this.Widgets.cmDeleteRow.MenuSelectedFcn = @(hSrc,hData) cbDeleteRow(weak.Handle);
            this.Widgets.cmSetInput.MenuSelectedFcn = @(hSrc,hData) cbSetIOType(weak.Handle,romapp.internal.data.ImportType.Input);
            this.Widgets.cmSetOutput.MenuSelectedFcn = @(hSrc,hData) cbSetIOType(weak.Handle,romapp.internal.data.ImportType.Output);
            if ~isempty(this.Widgets.cmSetParameter)
                this.Widgets.cmSetParameter.MenuSelectedFcn = @(hSrc,hData) cbSetIOType(weak.Handle,romapp.internal.data.ImportType.Parameter);
            end

            %Delete row(s) button
            addlistener(this.Widgets.btnDeleteRow,'ButtonPushed', @(hSrc,hData) cbDeleteRow(weak.Handle));

            %Time is implicit checkbox
            addlistener(this.Widgets.chkTimeImplicit,'ValueChanged', @(hSrc,hData) updateUI(weak.Handle));

            %Ok, cancel, help buttons
            this.Widgets.pnlOCH.ImportButton.ButtonPushedFcn = @(hSrc,hData) cbOK(weak.Handle);
            this.Widgets.pnlOCH.CancelButton.ButtonPushedFcn = @(hSrc,hData) cbCancel(weak.Handle);
            this.Widgets.pnlOCH.HelpButton.ButtonPushedFcn = @(hSrc,hData) cbHelp(weak.Handle);
        end

        function cbDDData(this)
            %cbDDData Manage Data drop-down events
            %

            % Check whether we are importing a datastore, cell array, or
            % single in-memory dataset. Will use this info to configure
            % error messages etc.
            var = this.Widgets.ddDataToImport.Value;
            [isDatastore,E1] = evalExpression(this,"romapp.internal.dialogs.ImportDataDialog.isDatastore("+var+")");
            [isCell,E2] = evalExpression(this,"iscell("+var+")");
            if isempty(E1) && isDatastore
                this.NumDatasetToImport = 1; % Use 1 since we don't know how many datasets are in the datastore yet. Datastores will be verified upon import, so the dialog does not need the exact number of datasets at this point.
            elseif isempty(E2) && isCell
                nDS = evalExpression(this,"numel("+var+")");
                this.NumDatasetToImport = nDS;
            else
                this.NumDatasetToImport = 1;
            end
            updateUI(this)
        end

        function cbAddData(this,itype)
            %cbAddData Manage Add button events
            %

            if nargin < 2
                itype = this.DefaultPortType;
            end

            % Check if the variable being added is a datastore. If so,
            % reset the IO table since datastores cannot be combined with
            % other datasets.
            var = this.Widgets.ddDataToImport.Value;
            [isDatastore,E] = evalExpression(this,"romapp.internal.dialogs.ImportDataDialog.isDatastore("+var+")");
            if ~isempty(E)
                uialert(this.UIFigure,E.message,this.Title);
                return
            end
            this.resetIOsForDatastoreImport(isDatastore);

            % Construct the IO data for the uitable
            if isDatastore
                this.ImportType = "datastore";
                this.NumDatasetToImport = 1; % Use 1 since we don't know how many datasets are in the datastore yet. Datastores will be verified upon import, so the dialog does not need the exact number of datasets at this point.
                dataToAdd = addDatastore(this,var,itype);
            else
                % The data is not a datastore. It is either a cell array,
                % matrix, or timetable. Find the type and size of the
                % variable being added.
                this.ImportType = "workspace";
                [isCell,E] = evalExpression(this,"iscell("+var+")");
                if ~isempty(E)
                    uialert(this.UIFigure,E.message,this.Title);
                    return
                end
                if isCell
                    nDS = evalExpression(this,"numel("+var+")");
                    this.NumDatasetToImport = nDS;
                else
                    this.NumDatasetToImport = 1;
                end
                if isCell
                    isTT = evalExpression(this,"istimetable("+var+"{1})");
                else
                    isTT = evalExpression(this,"istimetable("+var+")");
                end

                if isTT
                    dataToAdd = addTT(this,var,itype);
                else
                    dataToAdd = addMatrix(this,var,itype);
                end
            end

            %Add IO data to the table
            if ~isempty(dataToAdd)
                addIOData(this,dataToAdd)
            end

            updateUI(this)
        end

        function dataToAdd = addDatastore(this,var,itype)
            sampleData = evalExpression(this,"preview("+var+")");

            % Using a sample reading from the datastore, build the values
            % that will be shown in the uitable.
            isTT = istimetable(sampleData);
            if isTT
                dNames = sampleData.Properties.DimensionNames;
                vNames = sampleData.Properties.VariableNames;
                idx = lCheckTimetable(sampleData);
                vNames = vNames(idx);
                aNames = vNames;
                for ct=1:numel(aNames)
                    if ~isvarname(aNames{ct})
                        % Timetable variable names are not required to be
                        % valid variable names, so need to add () in these
                        % cases.
                        aNames{ct} = ['(''', aNames{ct}, ''')'];
                    end
                end

                nChannels = numel(vNames);
                dataToAdd = cell(nChannels+1,3);
                for ct=1:nChannels
                    dataToAdd{ct,1} = char(vNames{ct});
                    dataToAdd{ct,2} = string(itype);
                    dataToAdd{ct,3} = char(var+"(:)."+aNames{ct});
                end
                %Add row for time data
                dataToAdd{end,1} = char(dNames{1});
                dataToAdd{end,2} = string(romapp.internal.data.ImportType.Time);
                dataToAdd{end,3} = char(var+"(:)."+dNames{1});
            else
                sz = size(sampleData);

                if sz(2) > sz(1)
                    %Looks like time could be along columns rather than rows,
                    %transpose?
                    sel = uiconfirm(this.UIFigure,...
                        romapp.internal.resources.getString('lblImportData_IsTimeAlongColumns'), ...
                        romapp.internal.resources.getString('lblImportData_AddData'),...
                        "Options", ...
                        {romapp.internal.resources.getString('lblImportData_TimeAlongColumns'), ...
                        romapp.internal.resources.getString('lblImportData_TimeAlongRows'), ...
                        romapp.internal.resources.getString('lblCancel')}, ...
                        "DefaultOption",3, "CancelOption", 3);
                    switch sel
                        case romapp.internal.resources.getString('lblImportData_TimeAlongColumns')
                            exprFcn = @(x,ct) x+"(:)("+ct+",:)";
                            nChannels = sz(1);
                        case romapp.internal.resources.getString('lblImportData_TimeAlongRows')
                            exprFcn = @(x,ct) x+"(:)(:,"+ct+")";
                            nChannels = sz(2);
                        otherwise
                            %Cancel, do nothing and return
                            dataToAdd = [];
                            return
                    end
                else
                    exprFcn = @(x,ct) x+"(:)(:,"+ct+")";
                    nChannels = sz(2);
                end

                dataToAdd = cell(nChannels,3);
                for ct=1:nChannels
                    dataToAdd{ct,1} = char(var+"_"+ct);
                    dataToAdd{ct,2} = string(itype);
                    if prod(sz) == 1
                        dataToAdd{ct,3} = char(var);
                    else
                        dataToAdd{ct,3} = char(exprFcn(var,ct));
                    end
                end
            end
        end

        function dataToAdd = addTT(this,var,itype)
            %addTT Add timetable data to the IO table
            %

            if this.NumDatasetToImport > 1
                varDisplay = var+"{:}";
                var = var+"{1}";
            else 
                varDisplay = var;
            end

            vNames = this.GetDataFcn(var+".Properties.VariableNames");
            aNames = vNames;
            for ct=1:numel(aNames)
                if ~isvarname(aNames{ct})
                    aNames{ct} = ['(''', aNames{ct}, ''')'];
                end
            end
            dNames  = this.GetDataFcn(var+".Properties.DimensionNames");
            idx = lCheckTimetable(this.GetDataFcn(var));
            vNames = vNames(idx);
           
            nChannels = numel(vNames);
            dataToAdd = cell(nChannels+1,3);
            for ct=1:nChannels
                dataToAdd{ct,1} = char(vNames{ct});
                dataToAdd{ct,2} = string(itype);
                dataToAdd{ct,3} = char(varDisplay+"."+aNames{ct});
            end
            %Add row for time data
            dataToAdd{end,1} = char(dNames{1});
            dataToAdd{end,2} = string(romapp.internal.data.ImportType.Time);
            dataToAdd{end,3} = char(varDisplay+"."+dNames{1});
        end

        function dataToAdd = addMatrix(this,var,itype)
            %addMatrix Add numeric matrix data to the IO table
            %

            varForName = var;
            if this.NumDatasetToImport > 1
                varDisplay = var+"{:}";
                var = var+"{1}";
            else
                varDisplay = var;
            end

            sz = this.GetDataFcn("size("+var+")");

            if sz(2) > sz(1)
                %Looks like time could be along columns rather than rows,
                %transpose?
                sel = uiconfirm(this.UIFigure,...
                    romapp.internal.resources.getString('lblImportData_IsTimeAlongColumns'), ...
                    romapp.internal.resources.getString('lblImportData_AddData'),...
                    "Options", ...
                    {romapp.internal.resources.getString('lblImportData_TimeAlongColumns'), ...
                    romapp.internal.resources.getString('lblImportData_TimeAlongRows'), ...
                    romapp.internal.resources.getString('lblCancel')}, ...
                    "DefaultOption",3, "CancelOption", 3);
                switch sel
                    case romapp.internal.resources.getString('lblImportData_TimeAlongColumns')
                        exprFcn = @(x,ct) x+"("+ct+",:)";
                        nChannels = sz(1);
                    case romapp.internal.resources.getString('lblImportData_TimeAlongRows')
                        exprFcn = @(x,ct) x+"(:,"+ct+")";
                        nChannels = sz(2);
                    otherwise
                        %Cancel, do nothing and return
                        dataToAdd = [];
                        return
                end
            else
                exprFcn = @(x,ct) x+"(:,"+ct+")";
                nChannels = sz(2);
            end

            dataToAdd = cell(nChannels,3);
            for ct=1:nChannels
                dataToAdd{ct,1} = char(varForName+"_"+ct);
                dataToAdd{ct,2} = string(itype);
                if prod(sz) == 1
                    dataToAdd{ct,3} = char(varDisplay);
                else
                    dataToAdd{ct,3} = char(exprFcn(varDisplay,ct));
                end
            end
        end

        function addIOData(this,dataToAdd)
            %addIOData
            %
            % Add IOs to table but only add expressions that are not already in the table
            %

            if isempty(this.Widgets.tblIOs.Data)
                this.Widgets.tblIOs.Data = vertcat(this.Widgets.tblIOs.Data,dataToAdd);
            else
                [~,ia] = setdiff(dataToAdd(:,3),this.Widgets.tblIOs.Data(:,3));
                if ~isempty(ia)
                    dataToAdd = dataToAdd(ia,:);
                    this.Widgets.tblIOs.Data = vertcat(this.Widgets.tblIOs.Data,dataToAdd);
                end
            end
        end

        function updateImportButton(this)
            %updateImportButton
            %
            %  Check dialog settings and enable/disable import button based
            %  on whether the dialog is in a valid state to import data.
            %  Also display a status/error message (lblError) indicating
            %  dialog state w.r.t. readiness to import data.
            %

            tblIOs = this.Widgets.tblIOs;
            lblError = this.Widgets.lblError;
            if isempty(tblIOs.Data)
                %Quick return no data to import
                lblError.Text = romapp.internal.resources.getString('errImportData_NoOutput');
                matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')
                this.Widgets.pnlOCH.ImportButton.Enable = false;
                this.TableHasTime = false;
                return
            end

            %Need at least one output and one input or parameter for data
            %to be in valid state. If time is not implicit then also need
            %exactly one row of the table to specify time.
            nOutput = sum(strcmp(tblIOs.Data(:,2),string(romapp.internal.data.ImportType.Output)));
            nInput = sum(strcmp(tblIOs.Data(:,2),string(romapp.internal.data.ImportType.Input)));
            nParam = sum(strcmp(tblIOs.Data(:,2),string(romapp.internal.data.ImportType.Parameter)));
            if nOutput == 0
                setImportStatus(this,...
                    romapp.internal.resources.getString('errImportData_NoOutput'), ...
                    '--mw-color-error', ...
                    false)
                return
            end
            this.TableHasTime = any(strcmp(tblIOs.Data(:,2),string(romapp.internal.data.ImportType.Time)));
            %Have valid time when time is implicit or a single time variable is imported
            tImported = sum(strcmp(tblIOs.Data(:,2),string(romapp.internal.data.ImportType.Time))) == 1;
            tImplicit = this.Widgets.chkTimeImplicit.Value;
            haveTime = or(tImported,tImplicit);
            if ~haveTime
                setImportStatus(this, ...
                    romapp.internal.resources.getString('errImportData_NoTime'), ...
                    '--mw-color-error', ...
                    false);
                return
            end
            
            if this.ImportType == "workspace" % Datastores don't need the same check, only workspace data
                %Check that the input/output/time data have the same number of
                %points. Check that parameters are scalars. Only need to do
                %this check for non-multi dataset case as multi-dataset case
                %has the time/input/output data in one timetable or matrix per
                %dataset.
                if this.NumDatasetToImport == 1
                    %Check that none of the entries indicate they are from multiple
                    %dataset
                    idx = cellfun('isempty',regexp(tblIOs.Data(:,3),'\{:\}'));
                    if ~all(idx)
                        idx = find(~idx,1);
                        setImportStatus(this, ...
                            romapp.internal.resources.getString('errImportData_MixSingleAndMultiDatasets',tblIOs.Data{idx,3}), ...
                            '--mw-color-error', ...
                            false)
                        return
                    end
    
                    nTime = [];
                    for ct=1:size(tblIOs.Data,1)
                        if isempty(tblIOs.Data{ct,3})
                            setImportStatus(this, ...
                                romapp.internal.resources.getString('errImportData_NoData',tblIOs.Data{ct,1}), ...
                                '--mw-color-error', ...
                                false)
                            return
                        end
    
                        if strcmp(tblIOs.Data{ct,2},string(romapp.internal.data.ImportType.Input)) || ...
                                strcmp(tblIOs.Data{ct,2},string(romapp.internal.data.ImportType.Output)) || ...
                                strcmp(tblIOs.Data{ct,2},string(romapp.internal.data.ImportType.Time))
                            [n,E] = evalExpression(this,"numel("+tblIOs.Data{ct,3}+")");
                            if isempty(E)
                                if isempty(nTime)
                                    nTime = n;
                                else
                                    if n ~= nTime
                                        msg = romapp.internal.resources.getString('errImportData_NumPoints', ...
                                            tblIOs.Data{ct,3}, num2str(n), num2str(nTime));
                                        setImportStatus(this, ...
                                            msg, ...
                                            '--mw-color-error', ...
                                            false)
                                        return
                                    end
                                end
                            else
                                setImportStatus(this, ...
                                    E.message, ...
                                    '--mw-color-error', ...
                                    false)
                                return
                            end
                        elseif strcmp(tblIOs.Data{ct,2},string(romapp.internal.data.ImportType.Parameter))
                            %Parameters must be scalars
                            [n,E] = evalExpression(this,"numel("+tblIOs.Data{ct,3}+")");
                            if isempty(E)
                                if n~=1
                                    msg = romapp.internal.resources.getString('errImportData_ScalarParameter', ...
                                        tblIOs.Data{ct,3}, num2str(n));
                                    setImportStatus(this,...
                                        msg, ...
                                        '--mw-color-error', ...
                                        false);
                                    return
                                end
                            else
                                setImportStatus(this,...
                                    E.message, ...
                                    '--mw-color-error', ...
                                    false)
                                return
                            end
                        end
                    end
                else
                    %Importing multiple datasets, each variable must be a cell
                    %array with the same number of elements
                    vars = unique(strtok(tblIOs.Data(:,3),'{'));
                    nElem = evalExpression(this,"numel("+vars{1}+")");
                    for ct=2:numel(vars)
                        nE = evalExpression(this,"numel("+vars{ct}+")");
                        if ~isequal(nElem,nE)
                            msg = romapp.internal.resources.getString('errImportData_Cell_DifferentNumElements', ...
                                vars{1}, vars{ct});
                            setImportStatus(this,...
                                msg, ...
                                '--mw-color-error', ...
                                false);
                            return
                        end
                    end
                end
            else
                for ct=1:size(tblIOs.Data,1)
                    if isempty(tblIOs.Data{ct,3})
                        setImportStatus(this, ...
                            romapp.internal.resources.getString('errImportData_NoData',tblIOs.Data{ct,1}), ...
                            '--mw-color-error', ...
                            false)
                        return
                    end
                end
            end
            
            %Check that IO Names are unique
            ioNames = tblIOs.Data(:,1);
            if numel(ioNames) ~= numel(unique(ioNames))
                setImportStatus(this, ...
                    romapp.internal.resources.getString('errImportData_UniqueNames'), ...
                    '--mw-color-error', ...
                    false)
                return
            end
            
            %Got through the error checks, show status message and enable
            %import button
            if this.NumDatasetToImport > 1
                str = romapp.internal.resources.getString('msgImportData_DataSummaryNoParameter_Multiple', ...
                    num2str(this.NumDatasetToImport),num2str(nInput),num2str(nOutput));
            else
                if this.ImportType == "datastore"
                    str = romapp.internal.resources.getString('msgImportData_DataSummary_Datastore', ...
                        num2str(nInput),num2str(nOutput));
                elseif this.AllowParameters
                    str = romapp.internal.resources.getString('msgImportData_DataSummaryWithParameter_Single', ...
                        num2str(nInput),num2str(nOutput),num2str(nParam),num2str(nTime));
                else
                    str = romapp.internal.resources.getString('msgImportData_DataSummaryNoParameter_Single', ...
                        num2str(nInput),num2str(nOutput),num2str(nParam),num2str(nTime));
                end
            end
            setImportStatus(this, ...
                str, ...
                '--mw-color-warning', ...
                true)
        end

        function setImportStatus(this,msg,FontColor,enable)

            lblError = this.Widgets.lblError;
            lblError.Text = msg;
            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor',FontColor)

            %Set import button status
            this.Widgets.pnlOCH.ImportButton.Enable = enable;
        end


        function updateDeleteButton(this)

            %Disable delete button if no table rows are selected.
            this.Widgets.btnDeleteRow.Enable = ~isempty(this.Widgets.tblIOs.Selection);
        end

        function cbDeleteRow(this)
            %cbDeleteRow Manage delete row button and context menu events
            %

            sel = this.Widgets.tblIOs.Selection;
            this.Widgets.tblIOs.Data(sel,:) = [];
            updateUI(this)
        end

        function cbSetIOType(this,type)
            %cbSetIOType Manage set type context menu events
            %

            sel = this.Widgets.tblIOs.Selection;
            this.Widgets.tblIOs.Data(sel,2) = {char(type)};
            updateUI(this)
        end

        function cbOK(this)
            %cbOK Manage OK (Import) button events

            %Check whether time is implicit or not
            if this.Widgets.chkTimeImplicit.Value
                sampleTime = this.Widgets.edtSampleTime.Value;
            else
                sampleTime = [];
            end

            %Collect data from table and convert into ImportDataSpecs
            tblData = this.Widgets.tblIOs.Data;
            for ct=size(tblData,1):-1:1
                if this.ImportType == "datastore"
                    % For datastores, just verify that the datastore object
                    % can be retrieved
                    expr = extractBefore(tblData{ct,3}, "(:)");
                    [~,E] = evalExpression(this,expr);
                elseif this.NumDatasetToImport == 1
                    [~,E] = evalExpression(this,tblData{ct,3});
                else
                    expr = regexprep(tblData{ct,3},'\{:\}','{1}');
                    [~,E] = evalExpression(this,expr);
                end
                if isempty(E)
                    dataSpec(ct) = romapp.internal.data.ImportDataSpec(...
                        tblData{ct,1}, tblData{ct,3}, lConvertToEnum(tblData{ct,2}));
                else
                    uialert(this.UIFigure,E.message,this.Title);
                    return
                end
                
            end

            %Fire event with what data to import
            eData = romapp.internal.data.ImportEventData(dataSpec,sampleTime,this.NumDatasetToImport,this.ImportType);
            notify(this,'ImportPushed',eData)
        end

        function cbCancel(this)

            close(this)
            notify(this,'ImportCanceled')
        end

        function cbHelp(this)
            this.HelpFcn()
        end

        function resetIOsForDatastoreImport(this, isDatastore)
            if isDatastore || this.ImportType == "datastore"
                % Either the new data to add is a datastore, or the
                % existing data in the table is a datastore. Datastores
                % cannot be combined with other data sets, so clear the
                % existing IOs.
                var = this.Widgets.ddDataToImport.Value;
                resetIOs(this);
                idx = strcmp(this.Widgets.ddDataToImport.ItemsData,var);
                this.Widgets.ddDataToImport.ValueIndex = find(idx,1);
            end
        end
    end

    methods(Access = protected, Static = true)
        function defaultHelp()
            helpview('simulink','rom_import_data')
        end
    end

    methods(Static = true)
        function tf = isValidImportData(var)

            %Check if is directly a valid import type
            tf = romapp.internal.dialogs.ImportDataDialog.isValidImportData_Element(var);
            if tf
                return
            end

            % Check if input is a valid datastore or cell array
            if  romapp.internal.dialogs.ImportDataDialog.isDatastore(var)
                tf = lCheckDatastore(var);
            elseif iscell(var) && romapp.internal.dialogs.ImportDataDialog.isValidImportData(var{1})
                expectTT = istimetable(var{1});
                nIO = size(var{1},2);

                for ct=2:numel(var)
                    tf = romapp.internal.dialogs.ImportDataDialog.isValidImportData(var{ct});
                    %Check that elements in cell array are consistent
                    tf = tf && expectTT == istimetable(var{ct});
                    if tf 
                        %Check consistent number of IOs
                        tf = nIO == size(var{ct},2);
                    end

                    if ~tf, break, end
                end
            end
        end

        function tf = isDatastore(var)
            tf = isa(var, 'matlab.io.Datastore') || isa(var, 'matlab.io.datastore.Datastore'); % Some datastores like fileDatastore use the older matlab.io.datastore.Datastore
        end
    end

    methods(Static=true, Access=protected)
        function tf = isValidImportData_Element(var)
            isValidTT = istimetable(var) && any(lCheckTimetable(var)); 
            isValidMat = isnumeric(var) && isreal(var) && (isvector(var) || ismatrix(var)) && all(isfinite(var(:)));

            tf = isValidTT || isValidMat;
        end

    end

    methods(Access = ?qe.romapp.Tester)
        function qeAddData(this, options)
            arguments
                this;
                options.iType = this.DefaultPortType;
            end

            cbAddData(this,options.iType)
        end

        function qeSetIOType(this, type)
            arguments
                this;
                type;
            end

            cbSetIOType(this,type)
        end

        function qeDeleteRow(this)
            cbDeleteRow(this)
        end
    end
end

function e = lConvertToEnum(str)
%lConvertToEnum
%
% Helper function to convert a string to romapp.internal.data.InputType
% enumeration.

switch str
    case string(romapp.internal.data.ImportType.Input)
        e = romapp.internal.data.ImportType.Input;
    case string(romapp.internal.data.ImportType.Output)
        e = romapp.internal.data.ImportType.Output;
    case string(romapp.internal.data.ImportType.Time)
        e = romapp.internal.data.ImportType.Time;
    case string(romapp.internal.data.ImportType.Parameter)
        e = romapp.internal.data.ImportType.Parameter;
end
end

function tf = lCheckTimetable(var)
%lCheckTimetable
%
% Helper function to check that there is at least one variable in the table
% that is scalar numeric, real, and finite.

tf = false(1,size(var,2));
for ct=1:size(var,2)
    dataColi = table2array(var(:,ct));
    tf(ct) = isnumeric(dataColi) && isvector(dataColi) && isreal(dataColi) && all(isfinite(dataColi));
end

end

function tf = lCheckDatastore(var)
% Perform a quick check on the datastore by reading a sample (the first
% read) and validating that data.
sample = preview(var);
tf = romapp.internal.dialogs.ImportDataDialog.isValidImportData(sample);
end

function str = lGetSummaryString(itemToAdd,data)
%lGetSummaryString
%
% Helper function to create summary string of data variable being imported.

if iscell(data)
    nDS = size(data);
    data = data{1};
else
    nDS = 1;
end

if prod(nDS) > 1
    if istimetable(data)
        sz = size(data);
        str = romapp.internal.resources.getString('lblImportData_Cell_TimeTableDescription', ...
            itemToAdd,num2str(nDS(1)),num2str(nDS(2)),num2str(sz(2)));
    else
        if isscalar(data)
            str = romapp.internal.resources.getString('lblImportData_Cell_ScalarDescription',...
                itemToAdd,num2str(nDS(1)),num2str(nDS(2)));
        elseif isvector(data)
            sz = size(data);
            str = romapp.internal.resources.getString('lblImportData_Cell_VectorDescription',...
                itemToAdd,num2str(nDS(1)),num2str(nDS(2)),num2str(sz(1)),num2str(sz(2)));
        else
            sz = size(data);
            str = romapp.internal.resources.getString('lblImportData_Cell_MatrixDescription',...
                itemToAdd,num2str(nDS(1)),num2str(nDS(2)),num2str(sz(1)),num2str(sz(2)));
        end
    end
else
    if istimetable(data)
        sz = size(data);
        str = romapp.internal.resources.getString('lblImportData_TimeTableDescription', ...
            itemToAdd,num2str(sz(2)),num2str(sz(1)));
    elseif romapp.internal.dialogs.ImportDataDialog.isDatastore(data)
        className = class(data);
        shortName = regexprep(className, '.*\.', ''); % Only use the class name, not the packages
        str = romapp.internal.resources.getString('lblImportData_DatastoreDescription',itemToAdd,shortName);
    else
        if isscalar(data)
            str = romapp.internal.resources.getString('lblImportData_ScalarDescription',...
                itemToAdd);
        elseif isvector(data)
            sz = size(data);
            str = romapp.internal.resources.getString('lblImportData_VectorDescription',...
                itemToAdd,num2str(sz(1)),num2str(sz(2)));
        else
            sz = size(data);
            str = romapp.internal.resources.getString('lblImportData_MatrixDescription',...
                itemToAdd,num2str(sz(1)),num2str(sz(2)));
        end
    end
end

end

% LocalWords:  tblExport pnlOCH lbl experimentmanager mw btn tbl IOs chk edt cb istimetable TT
