classdef ImportDataWithFixedIODialog < romapp.internal.dialogs.ImportDataDialog
    % Import Data from MATLAB workspace
    %
    %  Subclass of ImportDataDialog, used for workflow where IOs are
    %  predetermined and cannot be changed.

    % Copyright 2024-2026 The MathWorks, Inc.

    properties (SetAccess = private, GetAccess=?matlab.unittest.TestCase)
        DataSpec romapp.internal.data.ImportDataSpec
    end

    methods
        function this = ImportDataWithFixedIODialog(dataspec)
            this = this@romapp.internal.dialogs.ImportDataDialog();

            %Modify workspace filter function to allow cell arrays of
            %tables/matrices.
            this.FilterWorkspaceVariableFcn = @(x) romapp.internal.dialogs.ImportDataWithFixedIODialog.isValidImportData(x);
            
            setIOs(this,dataspec)
        end

        function updateUI(this)
            %updateUI
            %

            %Call parent method
            updateUI@romapp.internal.dialogs.ImportDataDialog(this)

            %Disable add time button if table has time or time is implicit.
            haveTime = any(strcmp(this.Widgets.tblIOs.Data(:,2),string(romapp.internal.data.ImportType.Time)));
            this.Widgets.btnAddTime.Enable = ~haveTime && ~this.Widgets.chkTimeImplicit.Value;
        end

        function setIOs(this,dataspec)
            %setIOs

            if ~any(arrayfun(@(x) isequal(x,romapp.internal.data.ImportType.Time)',[dataspec.Type]))
                %No time spec (i.e., was implicit). Add an explicit time
                %spec
                tspec = romapp.internal.data.ImportDataSpec(...
                    string(romapp.internal.data.ImportType.Time),...
                    "", ...
                    romapp.internal.data.ImportType.Time);
                dataspec = vertcat(dataspec(:),tspec);
            end
            this.DataSpec = dataspec;

            if ~isempty(this.Widgets)
                %Dialog has been built, refresh

                %Clear out any data entries
                this.Widgets.ddDataToImport.ValueIndex = 1;
                initializeIOTable(this)
                this.Widgets.edtSampleTime.Value = 1;
                this.Widgets.chkTimeImplicit.Value = false;

                %Update the widget states
                updateUI(this)
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
            tblIOs.ColumnEditable = [false, false, false]; %Changes to [false false true] when data is added
            tblIOs.SelectionType = 'row';
            dataValues = {' ', '  '}; %Drop-down will be populated with specific values later
            tblIOs.ColumnFormat = {'char', 'char', dataValues};
            tblIOs.RowName = [];
            cmIOs = uicontextmenu(f);
            cm1 = uimenu(cmIOs,"Text",romapp.internal.resources.getString('lblImportData_Delete'));
            tblIOs.ContextMenu = cmIOs;
           
            %Delete row & add time widgets
            pnlDeleteRow = uigridlayout(mainGridLayout,[1 3]);
            pnlDeleteRow.Padding(4) = 1; %Small top padding
            pnlDeleteRow.Padding(3) = 0; %No right padding
            pnlDeleteRow.RowHeight = {'fit'};
            pnlDeleteRow.ColumnWidth = {'1x','fit','fit'};
            pnlDeleteRow.Layout.Row = 3;
            pnlDeleteRow.Layout.Column = 1;
            btnDeleteRow = uibutton(pnlDeleteRow);
            btnDeleteRow.Layout.Row = 1;
            btnDeleteRow.Layout.Column = 3;
            btnDeleteRow.Text = romapp.internal.resources.getString('lblImportData_Delete');
            btnAddTime = uibutton(pnlDeleteRow);
            btnAddTime.Layout.Row = 1;
            btnAddTime.Layout.Column = 2;
            btnAddTime.Text = romapp.internal.resources.getString('lblImportData_AddTime');
                        
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
                'tblIOs', tblIOs, ...
                'btnDeleteRow', btnDeleteRow, ...
                'btnAddTime', btnAddTime, ...
                'chkTimeImplicit', chkTimeImplicit, ...
                'lblSampleTime', lblSampleTime, ...
                'edtSampleTime', edtSampleTime, ...
                'lblError', lblError, ...
                'pnlOCH', pnlOCH);

            %InitializeIOTable
            initializeIOTable(this)
        end

        function connectUI(this)

            weak = romapp.internal.resources.WeakReference(this);

            %Data to import drop-down and add 
            addlistener(this.Widgets.ddDataToImport,'ValueChanged', @(hSrc,hData)updateUI(weak.Handle));
            addlistener(this.Widgets.btnAdd,'ButtonPushed',@(hSrc,hData)cbAddData(weak.Handle));

            %IO table
            this.Widgets.tblIOs.CellEditCallback = @(hSrc,hData) cbCellEdited(weak.Handle,hData);
            this.Widgets.tblIOs.CellSelectionCallback = @(hSrc,hData) updateUI(weak.Handle);
            %IO Table context menus
            this.Widgets.cmDeleteRow.MenuSelectedFcn = @(hSrc,hData) cbDeleteRow(weak.Handle);
           
            %Delete row(s) button
            addlistener(this.Widgets.btnDeleteRow,'ButtonPushed', @(hSrc,hData) cbDeleteRow(weak.Handle));
            addlistener(this.Widgets.btnAddTime,'ButtonPushed', @(hSrc,hData) cbAddTime(weak.Handle));

            %Time is implicit checkbox
            addlistener(this.Widgets.chkTimeImplicit,'ValueChanged', @(hSrc,hData) updateUI(weak.Handle));

            %Ok, cancel, help buttons
            this.Widgets.pnlOCH.ImportButton.ButtonPushedFcn = @(hSrc,hData) cbOK(weak.Handle);
            this.Widgets.pnlOCH.CancelButton.ButtonPushedFcn = @(hSrc,hData) cbCancel(weak.Handle);
            this.Widgets.pnlOCH.HelpButton.ButtonPushedFcn = @(hSrc,hData) cbHelp(weak.Handle);
        end

        function initializeIOTable(this)
            %initializeIOTable
            %

            nSpec = numel(this.DataSpec);
            data = cell(nSpec,3);
            for ct=1:nSpec
                data{ct,1} = char(this.DataSpec(ct).Name);
                if ~strcmp(this.DataSpec(ct).Type,romapp.internal.data.ImportType.Time)
                    data{ct,2} = string(this.DataSpec(ct).Type);
                end
            end
            this.Widgets.tblIOs.Data = data;
        end

        function addIOData(this,dataToAdd)
            %addIOData
            %
            % Add data to the table note that this does not change the IOs
            %

            %Find variables to add that are not already in the table
            pData = this.Widgets.tblIOs.ColumnFormat{3};
            if isequal(pData,{' ', '  '})
                %1st time adding variables, remove the placeholder options
                pData = {};
            end
            [~,ia] = setdiff(dataToAdd(:,3),pData);
            if ~isempty(ia)
                %Have unseen data to add
                pData = horzcat(pData,dataToAdd(:,3)');
                this.Widgets.tblIOs.ColumnFormat{3} = pData;
                this.Widgets.tblIOs.ColumnEditable = [false false true];
                %this.Widgets.tblIOs.CellEditCallback = @(hSrc,hData) cbCellEdited(this,hData);
            end

            %Get current data, modify copy then replace so don't trigger
            %continual edits
            cData = this.Widgets.tblIOs.Data;

            %If there is time in the data to add, add it to the row with
            %time. 
            tCurrent = find(cellfun(@(x) strcmp(x,string(romapp.internal.data.ImportType.Time)), cData(:,2)),1);
            tAdd = find(cellfun(@(x) strcmp(x,string(romapp.internal.data.ImportType.Time)), dataToAdd(:,2)),1);
            if ~isempty(tAdd)
                if isempty(tCurrent)
                    %There was no explicit time add it now
                    cData = vertcat(cData,dataToAdd(tAdd,:));
                else
                    cData(tCurrent,3) = dataToAdd(tAdd,3);
                end
                dataToAdd(tAdd,:) = []; %Remove time from the data to add
            end

            %Check whether the data to add is already displayed on the
            %table, if so remove it from adding. 
            idxE = cellfun('isempty',cData(:,3));
            cData(idxE,3) = {''};
            [~,ia] = intersect(dataToAdd(:,3),cData(:,3));
            dataToAdd(ia,:) = [];
            if isempty(dataToAdd)
                %Nothing to do
                return
            end

            %Find the 1st empty row of the table and add the new variables
            %from there on. If no empty row add at the top of the table.
            emptyOffset = find(cellfun('isempty',cData(:,3)),1);
            if isempty(emptyOffset)
                emptyOffset = 1;
            end
            for ct=0:size(dataToAdd,1)-1
                %If the row being replaced has time, skip it
                row = mod(ct+emptyOffset-1,size(cData,1))+1;
                if ~isempty(tCurrent) && row == tCurrent
                    emptyOffset = emptyOffset+1;
                    row = mod(ct+emptyOffset-1,size(cData,1))+1;
                end
                cData{row,3} = dataToAdd{ct+1,3};
            end

            %Update the table with the modified data
            this.Widgets.tblIOs.Data = cData;
        end

        function cbCellEdited(this,hData)
            %cbCellEdited Manage table cell edit events
            %

            row = hData.Indices(1);
            col = hData.Indices(2);
            if col ~=3
                %Quick return, nothing to do
                %Should never happen as only 3rd column is editable
                return
            end

            %Check whether the new value was previously used in the table.
            tblIOs = this.Widgets.tblIOs;
            idx = find(strcmp(tblIOs.Data(:,3),hData.NewData));
            idx(idx==row) = [];
            if ~isempty(idx) 
                if isempty(hData.PreviousData)
                    tblIOs.Data{idx,3} = '';
                else
                    tblIOs.Data{idx,3} = hData.PreviousData;
                end
            end

            %Update the dialog settings/state
            updateUI(this)
        end

        function cbDeleteRow(this)
            %cbDeleteRow Manage delete row button and context menu events
            %

            sel = this.Widgets.tblIOs.Selection;
            if all(strcmp(this.Widgets.tblIOs.Data(sel,2),string(romapp.internal.data.ImportType.Time)))
                this.Widgets.tblIOs.Data(sel,:) = [];
                updateUI(this)
            else
                uialert(this.UIFigure,...
                    romapp.internal.resources.getString('errImportData_DeleteIOs'),...
                    romapp.internal.resources.getString('lblError'))
            end
        end

        function cbAddTime(this)
            %cbAddTime Manage add time button events
            %

            %Make sure there is not already a time entry
            tblData = this.Widgets.tblIOs.Data;
            if ~any(strcmp(tblData(:,2),string(romapp.internal.data.ImportType.Time)))
                tblData(end+1,:) = {...
                    string(romapp.internal.data.ImportType.Time), ...
                    string(romapp.internal.data.ImportType.Time), ...
                    ''};
                this.Widgets.tblIOs.Data = tblData;
                updateUI(this)
            end
        end

        function resetIOsForDatastoreImport(this, isDatastore)
            if isDatastore || this.ImportType == "datastore"
                % Either the new data to add is a datastore, or the
                % existing data in the table is a datastore. Datastores
                % cannot be combined with other data sets, so clear all
                % possible data variables from the table's Column3
                % ColumnFormat.
                this.Widgets.tblIOs.ColumnFormat{3} = {' ', '  '}; % default
                this.Widgets.tblIOs.Data(:,3) = {[]}; % Clear existing selections
            end
        end
    end

    methods(Access = ?qe.romapp.Tester)
        function qeAddTime(this)
            cbAddTime(this)
        end

        function qeEditDataCell(this, row, newValue)
            prevValue = this.Widgets.tblIOs.Data{row, 3};
            this.Widgets.tblIOs.Data{row, 3} = newValue;
            hData = struct('Indices', [row 3], 'NewData', newValue, 'PreviousData', prevValue);
            cbCellEdited(this, hData);
        end
    end
end


% LocalWords:  tblExport pnlOCH lbl experimentmanager IOs mw btn tbl chk edt cb
