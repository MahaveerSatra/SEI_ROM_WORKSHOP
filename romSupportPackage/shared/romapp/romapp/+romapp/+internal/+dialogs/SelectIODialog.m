classdef SelectIODialog < controllib.ui.internal.dialog.AbstractDialog
    % Select Inputs and Outputs of ROM from Simulink
    %

    % Copyright 2022-2025 The MathWorks, Inc.

    properties (SetAccess = private,Hidden, ...
            GetAccess=?matlab.unittest.TestCase)
        Widgets struct
        Data
        NewPostSimFcnDialog
    end

    properties(GetAccess = public, SetAccess = private)
        WorkingModelSignals(:,2) cell
        WorkingParameters(:,2) cell
        WorkingTransform
    end

    properties(Access = protected, Dependent = true)
        SelectionMode %One of {'none','signal','parameter'}
    end

    properties(Access = private)
        slBinder
        binderListener
        selectionMode_
    end

    methods
        function this = SelectIODialog(data)
            this = this@controllib.ui.internal.dialog.AbstractDialog();
            this.Data = data;
            clearWorkingData(this);
            load_system(data.Model);

            this.Name = 'SelectIODialog';
            this.Title = romapp.internal.resources.getString('lblSelectIO');

            %Add listener for AbstractDialog close event. Dialog is in
            %default 'Cancel' mode.
            addlistener(this,'CloseEvent',@(hSrc,hData) cbCancel(this));
        end

        function set.SelectionMode(this,newValue)

            switch newValue
                case 'signal'
                    if ~isempty(this.slBinder)
                        clearBindMode(this)
                    end
                    this.slBinder = romapp.internal.data.BindModeROMData(this.Data.Model,'Signal',this);
                    this.binderListener = addlistener(this.slBinder,'ObjectBeingDestroyed', @(hSrc,hData) cbBinderDestroyed(this));
                    BindMode.BindMode.enableBindMode(this.slBinder)
                    this.Widgets.btnSelectSignal.Value = 1;
                    this.Widgets.lblSelectSignal.Enable = true;
                    this.Widgets.btnSelectParameter.Value = 0;
                    this.Widgets.lblSelectParameter.Enable = false;
                    %Bring model to foreground
                    open_system(this.Data.Model)
                    this.selectionMode_ = 'signal';
                case 'parameter'
                    if ~isempty(this.slBinder)
                        clearBindMode(this)
                    end
                    this.slBinder = romapp.internal.data.BindModeROMData(this.Data.Model,'Parameter',this);
                    this.binderListener = addlistener(this.slBinder,'ObjectBeingDestroyed', @(hSrc,hData) cbBinderDestroyed(this));
                    BindMode.BindMode.enableBindMode(this.slBinder)
                    this.Widgets.btnSelectSignal.Value = 0;
                    this.Widgets.lblSelectSignal.Enable = false;
                    this.Widgets.btnSelectParameter.Value = 1;
                    this.Widgets.lblSelectParameter.Enable = true;
                    %Bring model to foreground
                    open_system(this.Data.Model)
                    this.selectionMode_ = 'parameter';
                otherwise
                    this.Widgets.btnSelectSignal.Value = 0;
                    this.Widgets.lblSelectSignal.Enable = false;
                    this.Widgets.btnSelectParameter.Value = 0;
                    this.Widgets.lblSelectParameter.Enable = false;
                    clearBindMode(this)
                    this.slBinder = [];
                    delete(this.binderListener);
                    this.binderListener = [];
                    this.selectionMode_ = 'none';
            end
        end

        function value = get.SelectionMode(this)

            value = this.selectionMode_;
        end

        function updateUI(this)
            updateSignalTable(this)
            updateTransformPanel(this)
            updateParameterTable(this)
        end

        function addSignal(this,sig,type)

            switch type
                case 'Input'
                    type = string(romapp.internal.data.PortType.ROMandSimulationInput);
                case 'Output'
                    type = string(romapp.internal.data.PortType.ROMOutput);
            end

            %Check that signal is not already added
            sigs = [this.WorkingModelSignals{:,1}];
            found = false;
            for ct=1:numel(sigs)
                found = isequal(sig,sigs(ct));
                if found, break, end
            end

            if ~found
                %New signal
                data = {sig,type};
                this.WorkingModelSignals = [this.WorkingModelSignals; data];

                updateSignalTable(this)
            end
        end

        function removeSignal(this,sig)

            idx = findWorkingSignal(this,sig);
            if ~isempty(idx)
                this.WorkingModelSignals(idx,:) = [];
            end

            updateSignalTable(this)
        end

        function addParameter(this,param)

            %Check that parameter is not already added
            params = [this.WorkingParameters{:,1}];
            found = false;
            for ct=1:numel(params)
                found = isequal(param,params(ct));
                if found, break, end
            end

            if ~found
                %New parameter
                data = {param, string(romapp.internal.data.PortType.ROMandSimulationInput)};
                this.WorkingParameters = [this.WorkingParameters; data];

                updateParameterTable(this)
            end
        end

        function removeParameter(this,param)
            idx = 1;
            nParam = size(this.WorkingParameters,1);
            while idx <= nParam && ~isequal(param,this.WorkingParameters{idx,1})
                idx = idx + 1;
            end
            if idx <= nParam
                this.WorkingParameters(idx,:) = [];
            end

            updateParameterTable(this)
        end

        function initializeWorkingData(this)

            ports = this.Data.ModelPorts;

            %Get port type counts
            [romOnly,simOnly,romAndSim] = lSortSignalPorts(ports.InputSignals,ports.ExperimentInputSignals);
            nROnly = numel(romOnly);
            nSOnly = numel(simOnly);
            nBoth = numel(romAndSim);
            nOut = numel(ports.LoggedOutputs);

            %Create the signal working data
            sigdata = cell(nROnly+nSOnly+nBoth+nOut,2);
            offset = 0;
            for ct=1:nROnly
                sigdata{offset+ct,1} = romOnly(ct);
                sigdata{offset+ct,2} = string(romapp.internal.data.PortType.ROMInput);
            end
            offset = offset + nROnly;
            for ct=1:nSOnly
                sigdata{offset+ct,1} = simOnly(ct);
                sigdata{offset+ct,2} = string(romapp.internal.data.PortType.SimulationInput);
            end
            offset = offset + nSOnly;
            for ct=1:nBoth
                sigdata{offset+ct,1} = romAndSim(ct);
                sigdata{offset+ct,2} = string(romapp.internal.data.PortType.ROMandSimulationInput);
            end
            offset = offset + nBoth;
            for ct=1:nOut
                sigdata{offset+ct,1} = ports.LoggedOutputs(ct);
                sigdata{offset+ct,2} = string(romapp.internal.data.PortType.ROMOutput);
            end

            %Get parameter type counts
            [simOnly,romAndSim] = lSortParameterPorts(ports.InputParameters,ports.ExperimentInputParameters);
            nSOnly = numel(simOnly);
            nBoth = numel(romAndSim);

            %Create the parameter working data
            pdata = cell(nSOnly+nBoth,2);
            offset = 0;
            for ct=1:nSOnly
                pdata{offset+ct,1} = simOnly(ct);
                pdata{offset+ct,2} = string(romapp.internal.data.PortType.SimulationInput);
            end
            offset = offset + nSOnly;
            for ct=1:nBoth
                pdata{offset+ct,1} = romAndSim(ct);
                pdata{offset+ct,2} = string(romapp.internal.data.PortType.ROMandSimulationInput);
            end

            %Set the signal & parameter working data
            this.WorkingModelSignals = sigdata;
            this.WorkingParameters = pdata;

            %
            opts = this.Data.SimulationOptions;
            this.WorkingTransform.Enable = opts.UsePostSimFcn;
            if isequal(opts.PostSimFcn, @romapp.internal.data.PostSimFcn.FinalValue_Internal)
                this.WorkingTransform.LogFinal = true;
                this.WorkingTransform.UseFcn = false;
                this.WorkingTransform.Fcn = [];
                this.WorkingTransform.ScalarOutput = true;
                this.WorkingTransform.Outputs = this.Data.ModelPorts.OutputSignals;
            else
                this.WorkingTransform.LogFinal = false;
                this.WorkingTransform.UseFcn = true;
                this.WorkingTransform.Fcn = opts.PostSimFcn;
                this.WorkingTransform.ScalarOutput = hasScalarOutput(this.Data.ModelPorts);
                this.WorkingTransform.Outputs = this.Data.ModelPorts.OutputSignals;
            end
        end

        function clearWorkingData(this)

            this.WorkingModelSignals = cell(0,2);
            this.WorkingParameters = cell(0,2);
            this.WorkingTransform = struct(...
                'Enable', false, ...
                'LogFinal', true, ...
                'UseFcn', false, ...
                'Fcn', [], ...       %Function handle
                'Outputs', [], ...   %Simulink.SimulationData.Signal
                'ScalarOutput', []); %[] = unknown, true, false
        end
    end


    methods (Access = protected)
        function buildUI(this)
            f = this.UIFigure;
            %f.WindowStyle = 'modal';
            f.Tag = 'rom-add-signal-dialog';
            f.Position(3:4) = [600 750];
            mainGridLayout = uigridlayout(f, [5 1]);
            mainGridLayout.RowHeight = {'1x', 'fit','1x','fit'};
            mainGridLayout.ColumnWidth = {'1x'};

            %build signal panel
            signalPanel = uipanel(mainGridLayout);
            signalPanel.Title = romapp.internal.resources.getString('lblSelectIO_Signals');
            signalPanel.Layout.Row = 1;
            signalPanel.Layout.Column = 1;
            signalPanel.FontWeight = 'bold';
            signalPanel.BorderType = 'none';
            
            %build signal panel content
            signalGridLayout = uigridlayout(signalPanel, [3 2]);
            signalGridLayout.RowHeight = {'fit', '1x','fit'};
            signalGridLayout.ColumnWidth = {'fit', '1x'};
            signalGridLayout.Scrollable = 'on';
            signalGridLayout.Padding(2) = 0; %To have smaller gap with Transform widgets

            selectSignalButton = uibutton(signalGridLayout,'state');
            selectSignalButton.Text = romapp.internal.resources.getString('lblSelectIO_Signals');
            selectSignalButton.Layout.Row = 1;
            selectSignalButton.Layout.Column = 1;

            selectSignalLabel = uilabel(signalGridLayout);
            selectSignalLabel.Text = romapp.internal.resources.getString('msgSelectIO_Signals');
            selectSignalLabel.Layout.Row = 1;
            selectSignalLabel.Layout.Column = 2;
            selectSignalLabel.Enable = false;

            selectSignalTable = uitable(signalGridLayout);
            selectSignalTable.Layout.Row = 2;
            selectSignalTable.Layout.Column = [1 2];
            selectSignalTable.ColumnName = {...
                romapp.internal.resources.getString('lblSelectIO_Type'), ...
                romapp.internal.resources.getString('lblSelectIO_Signal')};
            selectSignalTable.ColumnWidth = {'fit', '1x'};
            selectSignalTable.ColumnEditable = [true, false];
            typeOptions = {...
                char(string(romapp.internal.data.PortType.ROMandSimulationInput)), ...
                char(string(romapp.internal.data.PortType.ROMOutput)), ...
                char(string(romapp.internal.data.PortType.ROMInput)), ...
                char(string(romapp.internal.data.PortType.SimulationInput))};
            selectSignalTable.ColumnFormat = {typeOptions, 'char'};
            selectSignalTable.RowName = [];
            selectSignalTable.Tooltip = [... %String array so each string is on a new line in the tooltip
                string(romapp.internal.resources.getString('ttipSelectIO_Signal_Heading')), ...
                string(romapp.internal.resources.getString('ttipSelectIO_ROMInput')), ...
                string(romapp.internal.resources.getString('ttipSelectIO_SimulationInput')), ...
                string(romapp.internal.resources.getString('ttipSelectIO_ROMOutput'))];
            selectSignalTable.ContextMenu = createContextMenu(this,'signal');
            selectSignalTable.ContextMenu.Tag = strcat('rom-tool-context-menu-select-io-signals');

            %Build Transform Output panel content
            transformPanel = uipanel(mainGridLayout,'BorderType','none');
            %transformPanel = uipanel(mainGridLayout);
            transformPanel.Layout.Row = 2;
            transformPanel.Layout.Column = 1;
            transformGridLayout = uigridlayout(transformPanel,[3,6]);
            transformGridLayout.RowHeight = {'fit','fit','fit'};
            transformGridLayout.ColumnWidth = {10,10,'1x','fit','fit','fit'};
            transformGridLayout.Padding(4) = 0;
            transformCheckBox = uicheckbox(transformGridLayout,'Text',...
                string(romapp.internal.resources.getString('lblTransformOutputSignal')));
            transformCheckBox.Layout.Row = 1;
            transformCheckBox.Layout.Column = [1 5];
            transformCheckBox.Tag = 'chkTransform';
            %Radio button group items for Log Final and Use Function
            pnl = uipanel(transformGridLayout,'BorderType','none');
            pnl.Layout.Row = 2;
            pnl.Layout.Column = [2 5];
            gl = uigridlayout(pnl);
            gl.RowHeight = {45};
            gl.ColumnWidth = {'1x'};
            gl.Padding = [0 0 0 0];
            transformRadioButtonGroup = uibuttongroup(gl);
            transformRadioButtonGroup.Layout.Row = 1;
            transformRadioButtonGroup.Layout.Column = 1;
            transformRadioButtonGroup.BorderType = 'none';
            transformRadioButton_LogFinal = uiradiobutton(transformRadioButtonGroup);
            transformRadioButton_LogFinal.Tag = 'rbtnLogFinal';
            txt = string(romapp.internal.resources.getString('lblTransformOutputSignal_LogFinal'));
            w1  = lGetDisplayWidth(txt);
            transformRadioButton_LogFinal.Text = txt;
            transformRadioButton_UseFunction = uiradiobutton(transformRadioButtonGroup);
            transformRadioButton_UseFunction.Tag = 'rbtnUseFunction';
            txt = string(romapp.internal.resources.getString('lblTransformOutputSignal_UseFunction'));
            w2 = lGetDisplayWidth(txt);
            transformRadioButton_UseFunction.Text = txt;
            transformRadioButton_LogFinal.Position(1:3) = [1 25 max(w1,w2)];
            transformRadioButton_UseFunction.Position(1:3) = [1 0 max(w1,w2)];
            transformEdit_UseFunction = uieditfield(transformGridLayout);
            transformEdit_UseFunction.Tag = 'edtTransform';
            transformEdit_UseFunction.Layout.Row = 3;
            transformEdit_UseFunction.Layout.Column = 3;
            transformButton_New = uibutton(transformGridLayout,'Text', ...
                romapp.internal.resources.getString('lblTransformOutputSignal_New'));
            transformButton_New.Tag = 'btnTransformNew';
            transformButton_New.Layout.Row = 3;
            transformButton_New.Layout.Column = 4;
            transformButton_Browse = uibutton(transformGridLayout,'Text',...
                string(romapp.internal.resources.getString('lblTransformOutputSignal_Browse')));
            transformButton_Browse.Tag = 'btnTransformBrowse';
            transformButton_Browse.Layout.Row = 3;
            transformButton_Browse.Layout.Column = 5;
            transformButton_Test = uibutton(transformGridLayout,'Text',...
                string(romapp.internal.resources.getString('lblTransformOutputSignal_Test')));
            transformButton_Test.Tag = 'btnTransformTest';
            transformButton_Test.Layout.Row = 3;
            transformButton_Test.Layout.Column = 6;

            %build parameter panel
            parameterGridPanel = uipanel(mainGridLayout);
            parameterGridPanel.Title = romapp.internal.resources.getString('lblSelectIO_Parameters');
            parameterGridPanel.Layout.Row = 3;
            parameterGridPanel.Layout.Column = 1;
            parameterGridPanel.FontWeight = 'bold';
            parameterGridPanel.BorderType = 'none';

            %build parameter panel content
            parameterGridLayout = uigridlayout(parameterGridPanel, [2 2]);
            parameterGridLayout.RowHeight = {'fit', '1x'};
            parameterGridLayout.ColumnWidth = {'fit', '1x'};
            parameterGridLayout.Scrollable = 'on';
            selectParameterButton = uibutton(parameterGridLayout,'state');
            selectParameterButton.Text = romapp.internal.resources.getString('lblSelectIO_Parameters');
            selectParameterButton.Layout.Row = 1;
            selectParameterButton.Layout.Column = 1;
            selectParameterLabel = uilabel(parameterGridLayout);
            selectParameterLabel.Text = romapp.internal.resources.getString('msgSelectIO_Parameters');
            selectParameterLabel.Layout.Row = 1;
            selectParameterLabel.Layout.Column = 2;
            selectParameterLabel.Enable = false;
            selectParameterTable = uitable(parameterGridLayout);
            selectParameterTable.Layout.Row = 2;
            selectParameterTable.Layout.Column = [1 2];
            selectParameterTable.ColumnName = {...
                romapp.internal.resources.getString('lblSelectIO_Type'), ...
                romapp.internal.resources.getString('lblSelectIO_BlockPath'),...
                romapp.internal.resources.getString('lblSelectIO_Parameter')};
            selectParameterTable.ColumnWidth = {'fit','1x','fit'};
            selectParameterTable.ColumnEditable = [true, false, false];
            typeOptions = {...
                char(string(romapp.internal.data.PortType.ROMandSimulationInput)), ...
                char(string(romapp.internal.data.PortType.SimulationInput))};
            selectParameterTable.ColumnFormat = {typeOptions, 'char', 'char'};
            selectParameterTable.RowName = [];
            selectParameterTable.Tooltip = romapp.internal.resources.getString('ttipSelectIO_Parameter_Heading');
            selectParameterTable.ContextMenu = createContextMenu(this,'parameter');
            selectParameterTable.ContextMenu.Tag = strcat('rom-tool-context-menu-select-io-parameters');

            %build lower buttons
            buttonPanel = uipanel(mainGridLayout);
            buttonPanel.Layout.Row = 4;
            buttonPanel.Layout.Column = 1;
            buttonPanel.FontWeight = 'bold';
            buttonPanel.BorderType = 'none';
            buttonGridLayout = uigridlayout(buttonPanel, [1 5]);
            buttonGridLayout.RowHeight = {'fit'};
            buttonGridLayout.ColumnWidth = {'fit','1x', 'fit', 'fit', 'fit'};
            okButton = uibutton(buttonGridLayout);
            okButton.Text = romapp.internal.resources.getString('lblOk');
            okButton.Layout.Row = 1;
            okButton.Layout.Column = 4;
            cancelButton = uibutton(buttonGridLayout);
            cancelButton.Text = romapp.internal.resources.getString('lblCancel');
            cancelButton.Layout.Row = 1;
            cancelButton.Layout.Column = 5;
            helpButton = uibutton(buttonGridLayout);
            helpButton.Text = romapp.internal.resources.getString('lblHelp');
            helpButton.Layout.Row = 1;
            helpButton.Layout.Column = 1;
            lblError = uilabel(buttonGridLayout);
            lblError.Text = romapp.internal.resources.getString('errSelectIO_NoOutput');
            lblError.HorizontalAlignment = 'right';
            lblError.Layout.Row = 1;
            lblError.Layout.Column = 3;
            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')

            % store in a struct
            this.Widgets = struct(...
                'tblSignal', selectSignalTable, ...
                'tblParameter', selectParameterTable, ...
                'btnHelp', helpButton, ...
                'btnCancel', cancelButton, ...
                'btnOk', okButton, ...
                'btnSelectSignal', selectSignalButton, ...
                'lblSelectSignal', selectSignalLabel, ...
                'btnSelectParameter', selectParameterButton, ...
                'lblSelectParameter', selectParameterLabel, ...
                'lblError', lblError, ...
                'chkTransform', transformCheckBox, ...
                'rbtngrpTransform',  transformRadioButtonGroup, ...
                'rbtnLogFinal', transformRadioButton_LogFinal, ...
                'rbtnUseFunction', transformRadioButton_UseFunction, ...
                'btnTransformNew', transformButton_New, ...
                'btnTransformBrowse', transformButton_Browse, ...
                'btnTransformTest', transformButton_Test, ...
                'edtTransform', transformEdit_UseFunction);
        end
        function connectUI(this)

            %Selection button listeners
            addlistener(this.Widgets.btnSelectSignal,'ValueChanged', @(hSrc,hData) cbSelectSignal(this));
            addlistener(this.Widgets.btnSelectParameter,'ValueChanged', @(hSrc,hData) cbSelectParameter(this));

            %Table listeners
            addlistener(this.Widgets.tblSignal,'DisplayDataChanged', @(hSrc,hData) cbSignalTableChanged(this));
            addlistener(this.Widgets.tblSignal,'KeyPress', @(hSrc,hData) cbSignalTableKeyPressed(this,hData));
            addlistener(this.Widgets.tblSignal.ContextMenu,'ContextMenuOpening', @(hSrc,hData)updateContextMenu(this, hData));
            addlistener(this.Widgets.tblParameter,'DisplayDataChanged', @(hSrc,hData) cbParameterTableChanged(this));
            addlistener(this.Widgets.tblParameter,'KeyPress', @(hSrc,hData) cbParameterTableKeyPressed(this,hData));
            addlistener(this.Widgets.tblParameter.ContextMenu,'ContextMenuOpening', @(hSrc,hData)updateContextMenu(this, hData));

            %Transform widget listeners
            addlistener(this.Widgets.chkTransform,'ValueChanged', @(hSrc,hData) cbTransformOutput(this));
            addlistener(this.Widgets.btnTransformNew,'ButtonPushed', @(hSrc,hData) cbTransformNew(this));
            addlistener(this.Widgets.btnTransformBrowse,'ButtonPushed', @(hSrc,hData) cbTransformBrowse(this));
            addlistener(this.Widgets.btnTransformTest,'ButtonPushed', @(hSrc,hData) cbTransformTest(this));
            addlistener(this.Widgets.edtTransform,'ValueChanging', @(hSrc,hData) cbTransformEditFieldChanging(this,hData));
            addlistener(this.Widgets.edtTransform,'ValueChanged', @(hSrc,hData) cbTransformEditField(this,hData));
            addlistener(this.Widgets.rbtngrpTransform,'SelectionChanged', @(hSrc,hData) cbTranformRBChanged(this));

            %Main button listeners
            addlistener(this.Widgets.btnCancel,'ButtonPushed', @(hSrc,hData) cbCancel(this));
            addlistener(this.Widgets.btnOk,'ButtonPushed', @(hSrc,hData) cbOk(this));
            addlistener(this.Widgets.btnHelp,'ButtonPushed', @(hSrc,hData) cbHelp(this));
        end

        function clearBindMode(this)
            if ~isempty(this.slBinder)
                %Disable bind mode and delete the binder
                hMdl = get_param(this.Data.Model,'Object');
                BindMode.BindMode.disableBindMode(hMdl);
                delete(this.slBinder)
            end
            this.slBinder = [];
        end

        function updateSignalTable(this)

            sig = this.WorkingModelSignals(:,1);
            type = this.WorkingModelSignals(:,2);

            nSig = numel(sig);
            tblData = cell(nSig,2);
            for ct=1:nSig
                tblData{ct,1} = char(type{ct});
                tblData{ct,2} = char(romapp.internal.data.ModelPorts.getFullName(sig{ct}));
            end

            this.Widgets.tblSignal.Data = tblData;

            updateOkButton(this)
        end

        function updateTransformPanel(this)
            %updateTransformPanel
            %
            
            % Toggle enable/disable state of transform widgets based on
            % state of enable transform output
            tf = this.WorkingTransform.Enable;
            this.Widgets.chkTransform.Value = tf;
            this.Widgets.rbtnLogFinal.Enable = tf;
            this.Widgets.rbtnUseFunction.Enable = tf;
            this.Widgets.btnTransformBrowse.Enable = tf && this.WorkingTransform.UseFcn;
            this.Widgets.btnTransformNew.Enable = tf && this.WorkingTransform.UseFcn;
            this.Widgets.edtTransform.Enable = tf && this.WorkingTransform.UseFcn;
            if isempty(strtrim(this.Widgets.edtTransform.Value))
                this.Widgets.btnTransformTest.Enable = false;
            else
                this.Widgets.btnTransformTest.Enable = tf && this.WorkingTransform.UseFcn;
            end

            %Initialize the transform widgets
            if isempty(this.WorkingTransform.Fcn)
                this.Widgets.edtTransform.Value = "";
            else
                this.Widgets.edtTransform.Value = func2str(this.WorkingTransform.Fcn);
            end
            this.Widgets.rbtnLogFinal.Value = this.WorkingTransform.LogFinal;
            this.Widgets.rbtnUseFcn.Value = this.WorkingTransform.UseFcn;

            updateOkButton(this)
        end

        function updateParameterTable(this)

            params = this.WorkingParameters(:,1);
            type = this.WorkingParameters(:,2);

            nParam = numel(params);
            tblData = cell(nParam,3);
            for ct=1:nParam
                bpath = convertToCell(params{ct}.BlockPath);
                tblData{ct,1} = char(type{ct});
                tblData{ct,2} = bpath{1};
                tblData{ct,3} = char(params{ct}.Name);
            end

            this.Widgets.tblParameter.Data = tblData;

            updateOkButton(this)
        end

        function updateOkButton(this)
            %Enable ok button if the IO selection represents a valid model
            %type/configuration. Valid configurations are:
            %   C1 - F:p->y
            %   C2 - F:p->y(t)
            %   C3 - F:u(t)->y(t)
            %   C4 - F:u(t),p -> y(t)
            %

            %Check static models, i.e., configuration C1. This can happen
            %either if the user selects to only log final values of output
            %signals or the output signal transform function returns scalar
            %values.
            staticModel = false;
            if this.WorkingTransform.Enable
                %Static models can only come about through output signal
                %transformation.
                if this.WorkingTransform.LogFinal
                    staticModel = true;
                else
                    if isempty(this.WorkingTransform.ScalarOutput)
                        if isempty(this.WorkingTransform.Fcn)
                            lblError = this.Widgets.lblError;
                            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')
                            lblError.Text = romapp.internal.resources.getString('errSelectIO_NoTransformFcn');
                            lblError.Visible = true;
                            this.Widgets.btnOk.Enable = false;
                            return
                        else
                            %Have not tested the user provided function, test
                            %it and check output.
                            E = evalPostSimFcn(this); %Throws uialert etc.
                            if ~isempty(E)
                                lblError = this.Widgets.lblError;
                                matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')
                                lblError.Text = romapp.internal.resources.getString('errSelectIO_NoTransformFcn');
                                lblError.Visible = true;
                                this.Widgets.btnOk.Enable = false;
                                return
                            end
                            staticModel = this.WorkingTransform.ScalarOutput;
                        end
                    else
                        staticModel = this.WorkingTransform.ScalarOutput;
                    end
                end

                if staticModel
                    %Static models can only have non-simulation parameter
                    %inputs
                    bad = hasSimulationInput(this) || hasSimulationOnlyParam(this) || ...
                        ~hasROMAndSimulationParam(this);
                    if ~hasOutput(this)
                        lblError = this.Widgets.lblError;
                        matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')
                        lblError.Text = romapp.internal.resources.getString('errSelectIO_NoOutput');
                        lblError.Visible = true;
                    elseif bad
                        lblError = this.Widgets.lblError;
                        matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')
                        lblError.Text = romapp.internal.resources.getString('errSelectIO_BadStaticModel');
                        lblError.Visible = true;
                        this.Widgets.btnOk.Enable = false;
                    else
                        this.Widgets.lblError.Visible = false;
                        this.Widgets.btnOk.Enable = true;
                        checkAgainstCurrentConfig(this)
                    end
                else
                    %Dynamic model with transform output, check that the
                    %evaluation function is defined. Can get to this path
                    %but have not checked that function is empty if dialog is
                    %opened editing IOs that did not use a transform output
                    %function. Otherwise these checks are done in the
                    %branch above that checks isempty(this.WorkingTransform.ScalarOutput)
                    if isempty(this.WorkingTransform.Fcn)
                        lblError = this.Widgets.lblError;
                        matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')
                        lblError.Text = romapp.internal.resources.getString('errSelectIO_NoTransformFcn');
                        lblError.Visible = true;
                        this.Widgets.btnOk.Enable = false;
                        return
                    end
                end
            end

            if staticModel
                return
            end
            
            %Check dynamic models, i.e., configurations C2, C3, c4. This
            %can happen either when there is no transform output function
            %or the transform output function returns a timeseries.
            ok = hasOutput(this) && (hasSimulationInput(this)||hasSimulationParam(this));
            this.Widgets.btnOk.Enable = ok;
            if ok
                checkAgainstCurrentConfig(this)
            elseif ~hasOutput(this)
                %No outputs selected, show error message
                lblError = this.Widgets.lblError;
                matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')
                lblError.Text = romapp.internal.resources.getString('errSelectIO_NoOutput');
                lblError.Visible = true;
            else
                %No simulation inputs selected, show error message
                lblError = this.Widgets.lblError;
                matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')
                lblError.Text = romapp.internal.resources.getString('errSelectIO_NoSimulationInput');
                lblError.Visible = true;
            end
        end

        function idx = findWorkingSignal(this,sig)
            idx = 1;
            nSig = size(this.WorkingModelSignals,1);
            while idx <= nSig && ~lSigIsEqual(sig,this.WorkingModelSignals{idx,1})
                idx = idx + 1;
            end
            if idx > nSig
                %Signal not found
                idx = [];
            end
        end

        function [sigIn,sigOut,sigExp,paramIn,paramExp] = getPortData(this)
            %getPortData
            %
            % Convert working data to signal and parameter data classes

            %Signals that are ROM inputs
            idx = strcmp(this.WorkingModelSignals(:,2),string(romapp.internal.data.PortType.ROMInput)) | ...
                strcmp(this.WorkingModelSignals(:,2), string(romapp.internal.data.PortType.ROMandSimulationInput));
            if any(idx)
                sigIn = [this.WorkingModelSignals{idx,1}];
            else
                sigIn = Simulink.SimulationData.Signal.empty;
            end

            %Signals that are ROM outputs
            idx = strcmp(this.WorkingModelSignals(:,2),string(romapp.internal.data.PortType.ROMOutput));
            if any(idx)
                sigOut = [this.WorkingModelSignals{idx,1}];
            else
                sigOut = Simulink.SimulationData.Signal.empty;
            end

            %Signals that are used to excite the model
            idx = strcmp(this.WorkingModelSignals(:,2),string(romapp.internal.data.PortType.ROMandSimulationInput)) | ...
                strcmp(this.WorkingModelSignals(:,2),string(romapp.internal.data.PortType.SimulationInput));
            if any(idx)
                sigExp = [this.WorkingModelSignals{idx,1}];
            else
                sigExp = Simulink.SimulationData.Signal.empty;
            end

            %Parameters that are ROM inputs
            idx = strcmp(this.WorkingParameters(:,2),string(romapp.internal.data.PortType.ROMandSimulationInput));
            if any(idx)
                paramIn = [this.WorkingParameters{idx,1}];
            else
                paramIn = romapp.internal.data.ModelParameter.empty;
            end

            %Parameters that are used to excite the model
            idx = strcmp(this.WorkingParameters(:,2),string(romapp.internal.data.PortType.ROMandSimulationInput)) | ...
                strcmp(this.WorkingParameters(:,2),string(romapp.internal.data.PortType.SimulationInput));
            if any(idx)
                paramExp = [this.WorkingParameters{idx,1}];
            else
                paramExp = romapp.internal.data.ModelParameter.empty;
            end
        end

        function cbSelectSignal(this)

            btnSelectSignal = this.Widgets.btnSelectSignal;

            if btnSelectSignal.Value
                this.SelectionMode = 'signal';
                this.Widgets.btnSelectParameter.Value = false;
            else
                this.SelectionMode = 'none';
            end
        end

        function cbSelectParameter(this)

            btnSelectParameter = this.Widgets.btnSelectParameter;

            if btnSelectParameter.Value
                this.SelectionMode = 'parameter';
                this.Widgets.btnSelectSignal.Value = false;
            else
                this.SelectionMode = 'none';
            end
        end

        function cbSignalTableKeyPressed(this,hData)

            if strcmp(hData.Key,'delete') & ~isempty(hData.Source.Selection)
                %Delete key pressed while a row is selected
                row = hData.Source.Selection(1);
                sig = this.WorkingModelSignals{row,1};
                removeSignal(this,sig)
            end
        end

        function cbParameterTableKeyPressed(this,hData)

            if strcmp(hData.Key,'delete') & ~isempty(hData.Source.Selection)
                %Delete key pressed while a row is selected
                row = hData.Source.Selection(1);
                param = this.WorkingParameters{row,1};
                removeParameter(this,param)
            end
        end

        function addWorkingSignals(this,sigs,type)

            nSig = numel(sigs);
            if nSig > 0
                wsig = cell(0,2);
                for ct=1:nSig
                    if isempty(findWorkingSignal(this,sigs(ct)))
                        wsig(end+1,:) = {sigs(ct), type}; %#ok<AGROW>
                    end
                end
                if ~isempty(wsig)
                    this.WorkingModelSignals = [this.WorkingModelSignals;wsig];
                    updateUI(this)
                end
            end
        end

        function cbSignalTableChanged(this)

            %Can only change signal type interactively, so only need to
            %update the WorkingModelSignal type column
            tblData = this.Widgets.tblSignal.Data;
            this.WorkingModelSignals(:,2) = tblData(:,1);

            %Enable ok button if there is at least one output
            updateOkButton(this)
        end

        function cbParameterTableChanged(this)

            %Can only change signal type interactively, so only need to
            %update the WorkingModelSignal type column
            tblData = this.Widgets.tblParameter.Data;
            this.WorkingParameters(:,2) = tblData(:,1);

            %Enable ok button if there is at least one output
            updateOkButton(this)
        end

        function cbBinderDestroyed(this)

            %Binder closed from the model side, reset the selection toggle
            %buttons
            this.SelectionMode = 'none';
            this.Widgets.btnSelectSignal.Value = false;
            this.Widgets.btnSelectParameter.Value = false;
        end

        function cbTransformOutput(this)
            %cbTransformOutput handle transform output checkbox events

            this.WorkingTransform.Enable = this.Widgets.chkTransform.Value;

            updateTransformPanel(this)
        end

        function cbTranformRBChanged(this)
            %cbTransformRBChanged handle transform radio button events

            this.WorkingTransform.LogFinal = this.Widgets.rbtnLogFinal.Value;
            this.WorkingTransform.UseFcn = this.Widgets.rbtnUseFunction.Value;
            if isempty(this.WorkingTransform.Fcn)
                %Reset info on whether the transform function returns a
                %scalar or not, set to don't know.
                this.WorkingTransform.ScalarOutput = [];
            end
            
            updateTransformPanel(this)
        end

        function cbTransformNew(this)

            if isempty(this.NewPostSimFcnDialog) || ~isvalid(this.NewPostSimFcnDialog)
                this.NewPostSimFcnDialog = romapp.internal.dialogs.NewPostSimFcnDialog();
            end
            show(this.NewPostSimFcnDialog,this.UIFigure)
        end

        function cbTransformBrowse(this)
            %cbTransformBrowse Handle Browse button events

            fname = uigetfile( ...
                '*.m', ...
                romapp.internal.resources.getString('lblTransformOutputSignal_BrowseInstructions'));
            if ~isequal(fname,0)
                if exist(fname,'file')
                    [~,fname] = fileparts(fname);
                    this.Widgets.edtTransform.Value = fname;
                    cbTransformEditField(this,struct('Value',fname))
                    this.Widgets.btnTransformTest.Enable = true;    %Enable the test button 
                else
                    uialert(this.UIFigure,...
                         romapp.internal.resources.getString('errTransformOutputSignal_BrowseFunction'), ...
                         romapp.internal.resources.getString('errTransformTest'), ...
                         'Icon', 'error')
                end
            end
        end

        function cbTransformTest(this)
            %cbTransformTest Manage test button events

            evalPostSimFcn(this); %Throws uialert etc.
            updateOkButton(this)
        end

        function cbTransformEditFieldChanging(this,hData)
            %cbTransformEditFieldChanging Manage transform edit field events
            %

            %Enable/disable test button based on whether there is a string
            %in the edit field
            this.Widgets.btnTransformTest.Enable = ~isempty(strtrim(hData.Value));
        end

        function cbTransformEditField(this,hData)
            %cbTransformEditFcn Manage transform edit field events
            %

            %Enable/disable test button based on whether there is a string
            %in the edit field
            str = strtrim(hData.Value);
            if isempty(str)
                this.WorkingTransform.Fcn = [];
            else
                if isvarname(str)
                    %The test button functionality catches the case when
                    %str is not a valid variable name and throws an error
                    %there.
                    this.WorkingTransform.Fcn = str2func(str);
                end
            end

            %As the function has changed need to reset whether it returns a
            %scalar or timetable
            this.WorkingTransform.ScalarOutput = []; %Unknown type

            %Trigger updates on OK button and any error messages
            updateOkButton(this)
        end

        function cbOk(this)

            %Get port information from the UI
            [sigIn,logOut,sigExp,paramIn,paramExp] = getPortData(this);

            %Collect postSimFcn options
            usePostSim = this.WorkingTransform.Enable;
            if usePostSim
                if this.WorkingTransform.LogFinal 
                    postSimFcn = @romapp.internal.data.PostSimFcn.FinalValue_Internal;
                    sigOut = logOut;
                    scalarOut = true;
                else
                    postSimFcn = this.WorkingTransform.Fcn;
                    sigOut = this.WorkingTransform.Outputs;
                    scalarOut = this.WorkingTransform.ScalarOutput;
                end
            else
                postSimFcn = [];
                sigOut = logOut;
                scalarOut = false;
            end

            %Check whether port or post sim options have changed
            if portsChanged(this,sigIn(:),sigOut(:), sigExp(:), paramIn(:), paramExp(:)) || ...
                    transformChanged(this)
                %Delete the existing simulation sets
                removeSimulationSet(this.Data,[]) %remove all

                %Update options
                this.Data.SimulationOptions.UsePostSimFcn = usePostSim;
                if usePostSim
                    this.Data.SimulationOptions.PostSimFcn = postSimFcn;
                end

                %Update the model ports
                hasScalarOutput(this.Data.ModelPorts,scalarOut)
                setPorts(this.Data.ModelPorts,...
                    'Inputs', sigIn(:), ...
                    'Outputs', sigOut(:), ...
                    'LoggedOutputs', logOut(:), ...
                    'SimulationInputs', sigExp(:), ...
                    'Parameters', paramIn(:), ...
                    'SimulationParameters',paramExp(:));
            end

            %Close the dialog
            cbCancel(this)
        end

        function cbCancel(this)
            clearBindMode(this)
            delete(this.UIFigure);
            close(this)
        end

        function cbHelp(~)
            helpview('simulink','rom_select_inputs_outputs')
        end

        function contextMenu = createContextMenu(this,type)
            % Create a nested context menu.

            contextMenu = uicontextmenu('Parent', this.UIFigure);

            % Add Delete menu
            deleteMenuItem = uimenu(contextMenu, ...
                'Text',romapp.internal.resources.getString('lblDelete'), ...
                'Tag','DeleteItem', ...
                'Visible','off');
            switch type
                case 'signal'
                    deleteMenuItem.MenuSelectedFcn = @(hSrc,hData) cbMenuDeleteSignal(this,hData);
                case 'parameter'
                    deleteMenuItem.MenuSelectedFcn = @(hSrc,hData) cbMenuDeleteParameter(this,hData);
            end
            deleteAllMenuItem = uimenu(contextMenu, ...
                'Text',romapp.internal.resources.getString('lblDeleteAll'), ...
                'Tag','DeleteAllItem', ...
                'Visible', 'off');
            switch type
                case 'signal'
                    deleteAllMenuItem.MenuSelectedFcn = @(hSrc,hData) cbMenuDeleteSignal(this,hData);
                case 'parameter'
                    deleteAllMenuItem.MenuSelectedFcn = @(hSrc,hData) cbMenuDeleteParameter(this,hData);
            end
        end

        function updateContextMenu(~, hData)
            %Update menu items depending on selection

            % Get the selected the row.
            selection = hData.InteractionInformation;
            tbl = hData.ContextObject;
            % React when a cell or the white space is clicked.
            if isempty(selection.Row)
                % Clicked on table white space, remove current row
                % selections. Only show delete all menu item
                tbl.Selection = [];
                tbl.ContextMenu.Children(1).Visible = true;
                tbl.ContextMenu.Children(2).Visible = false;
            else
                % Select the right-clicked row. Show delete and delete all
                % menu items
                tbl.Selection = [selection.Row selection.Column];
                tbl.ContextMenu.Children(1).Visible = true;
                tbl.ContextMenu.Children(2).Visible = true;
            end
        end

        function cbMenuDeleteSignal(this,hData)

            if isempty(this.Widgets.tblSignal.Selection) || ...
                    strcmp(hData.Source.Tag,'DeleteAllItem')
                %Delete all
                this.WorkingModelSignals = cell(0,2);
                updateSignalTable(this)
            else
                row = this.Widgets.tblSignal.Selection(1);
                sig = this.WorkingModelSignals{row,1};
                removeSignal(this,sig)
            end
        end

        function cbMenuDeleteParameter(this,hData)

            if isempty(this.Widgets.tblParameter.Selection) || ...
                    strcmp(hData.Source.Tag,'DeleteAllItem')
                %Delete all
                this.WorkingParameters = cell(0,2);
                updateParameterTable(this)
            else
                row = this.Widgets.tblParameter.Selection(1);
                param = this.WorkingParameters{row,1};
                removeParameter(this,param)
            end
        end

        function tf = hasOutput(this)

            tf = false;
            if isempty(this.WorkingModelSignals)
                return
            end
            tf = any(strcmp(this.WorkingModelSignals(:,2),string(romapp.internal.data.PortType.ROMOutput)));
        end

        function tf = hasSimulationInput(this)
            tf = false;
            if isempty(this.WorkingModelSignals)
                return
            end
            tfSimulationInput = any(strcmp(this.WorkingModelSignals(:,2),string(romapp.internal.data.PortType.SimulationInput)));
            tfROMandSimulationInput = any(strcmp(this.WorkingModelSignals(:,2),string(romapp.internal.data.PortType.ROMandSimulationInput)));
            tf = tfSimulationInput || tfROMandSimulationInput;
        end

        function tf = hasSimulationParam(this)
            tf = false;
            if isempty(this.WorkingParameters)
                return
            end
            tfROMandSimulation = any(strcmp(this.WorkingParameters(:,2),string(romapp.internal.data.PortType.ROMandSimulationInput)));
            tfSimulation = any(strcmp(this.WorkingParameters(:,2),string(romapp.internal.data.PortType.SimulationInput)));
            tf = tfROMandSimulation || tfSimulation;
        end

        function tf = hasROMAndSimulationParam(this)
            tf = false;
            if isempty(this.WorkingParameters)
                return
            end
            tf = any(strcmp(this.WorkingParameters(:,2),string(romapp.internal.data.PortType.ROMandSimulationInput)));
        end

        function tf = hasSimulationOnlyParam(this)
            tf = false;
            if isempty(this.WorkingParameters)
                return
            end
            tf = any(strcmp(this.WorkingParameters(:,2),string(romapp.internal.data.PortType.SimulationInput)));
        end
        
        function tf = portsChanged(this,sigIn,sigOut,sigExp,paramIn,paramExp)

            tf = lvecisequal(this.Data.ModelPorts.InputSignals,sigIn,@lSigIsEqual);
            tf = tf & lvecisequal(this.Data.ModelPorts.LoggedOutputs,sigOut,@lSigIsEqual);
            if this.WorkingTransform.Enable
                tf = tf & lvecisequal(this.Data.ModelPorts.OutputSignals,this.WorkingTransform.Outputs,@lSigIsEqual);
            end
            tf = tf & lvecisequal(this.Data.ModelPorts.InputParameters,paramIn,@lParamIsEqual);
            tf = tf & lvecisequal(this.Data.ModelPorts.ExperimentInputSignals,sigExp,@lSigIsEqual);
            tf = tf & lvecisequal(this.Data.ModelPorts.ExperimentInputParameters,paramExp,@lParamIsEqual);
            tf = ~tf;
        end

        function tf = transformChanged(this)

            tf = isequal(this.WorkingTransform.Enable, this.Data.SimulationOptions.UsePostSimFcn);
            if this.WorkingTransform.LogFinal
                actFcn = @romapp.internal.data.PostSimFcn.FinalValue_Internal;
            else
                actFcn = this.WorkingTransform.Fcn;
            end
            tf = tf && isequal(actFcn,this.Data.SimulationOptions.PostSimFcn);
            tf = ~tf;
        end

        function checkAgainstCurrentConfig(this)
            %checkAgainstCurrentConfig
            %
            % Compare the IO configuration defined in this dialog to the
            % configuration currently used in the App and display a warning
            % if they are different

            %Check whether the port configuration has changed and there
            %are simulation sets defined
            if havePorts(this) && ~isempty(this.Data.SimulationSets)
                [sigIn,sigOut,sigExp,paramIn,paramExp] = getPortData(this);
                if portsChanged(this,sigIn(:),sigOut(:), sigExp(:), paramIn(:), paramExp(:)) || ...
                        transformChanged(this)
                    matlab.graphics.internal.themes.specifyThemePropertyMappings(this.Widgets.lblError,'FontColor','--mw-color-warning')
                    this.Widgets.lblError.Text = romapp.internal.resources.getString('msgSelectIO_ExistingIOs');
                    this.Widgets.lblError.Visible = true;
                else
                    this.Widgets.lblError.Visible = false;
                end
            else
                %No ports defined or no simulation sets defined.
                this.Widgets.lblError.Visible = false;
            end
        end

        function tf = havePorts(this)

            tf = ~isempty(this.Data.ModelPorts.InputSignals);
            tf = tf || ~isempty(this.Data.ModelPorts.OutputSignals);
            tf = tf || ~isempty(this.Data.ModelPorts.InputParameters);
            tf = tf || ~isempty(this.Data.ModelPorts.ExperimentInputSignals);
        end

        function E = evalPostSimFcn(this)
            %evalPostSimFcn
            
            try
                out = testPostSimFcn(this);
                E = [];
            catch E
                 uialert(this.UIFigure,...
                    E.message, ...
                    romapp.internal.resources.getString('errTransformTest'), ...
                    'Icon', 'error')
                 this.WorkingTransform.Outputs = Simulink.SimulationData.Signal.empty;
                 this.WorkingTransform.ScalarOutput = [];
                 return
            end

            %Message with output from test
            fnames = fieldnames(out);
            msg = string(romapp.internal.resources.getString('lblTransform_Output_Summary',this.Widgets.edtTransform.Value));
            for ct=1:numel(fnames)
                if istimetable(out.(fnames{ct}))
                    msg = msg + newline + string(romapp.internal.resources.getString('lblTransform_OutputType_Signal',fnames{ct}));
                else
                    msg = msg + newline + string(romapp.internal.resources.getString('lblTransform_OutputType_Scalar',fnames{ct}));
                end
            end

            uialert(this.UIFigure, ...
                msg, romapp.internal.resources.getString('lblTransform_Output_Success'), ...
                'Icon', 'success')

            %Check whether output of function is scalar or timetable values
            fnames = fieldnames(out);
            if istimetable(out.(fnames{1}))
                this.WorkingTransform.ScalarOutput = false;
            else
                this.WorkingTransform.ScalarOutput = true;
            end
            this.WorkingTransform.Outputs = [];
            for ct=1:numel(fnames)
                sigOut = Simulink.SimulationData.Signal;
                sigOut.Name = fnames{ct};
                sigOut.BlockPath = this.Data.Model;
                sigOut.PortType = 'outport';
                sigOut.PortIndex = 1;
                this.WorkingTransform.Outputs = [this.WorkingTransform.Outputs; sigOut];
            end
        end

        function out = testPostSimFcn(this)

            [sigIn,logOut,sigExp,paramIn,paramExp] = getPortData(this);

            %Merge ROM and experiment input signals
            sigIn = lmergeVectors(sigIn,sigExp);
            %Set input signals to random signal
            t = seconds(0:10)';
            nPts = numel(t);
            for ct=1:numel(sigIn)
                tt = timetable(t,rand(nPts,1),...
                    'DimensionNames',{'Time', 'Variables'}, ...
                    'VariableNames',{'Data'});
                sigIn(ct).Values = tt;
            end

            %Merge ROM and experiment parameters
            paramIn = lmergeVectors(paramIn,paramExp);
            %Convert parameters to parameter data and set a random value
            for ct=numel(paramIn):-1:1
                paramData(ct).BlockPath = paramIn(ct).BlockPath;
                paramData(ct).Name = paramIn(ct).Name;
                paramData(ct).Value = rand(1);
            end

            %Set output signals to a random signal
            if isempty(logOut)
                 romapp.internal.resources.error('errTransformTest_NoLog')
            end
            for ct=1:numel(logOut)
                tt = timetable(t,rand(nPts,1),...
                    'DimensionNames',{'Time', 'Variables'}, ...
                    'VariableNames',{'Data'});
                logOut(ct).Values = tt;
            end

            %Create a fake experiment
            edata = romapp.internal.data.ExperimentData;
            edata.InputSignals = sigIn;
            if numel(paramIn) > 0
                edata.InputParameters = paramData;
            end
            edata.OutputSignals = logOut;
            
            try
                out = feval(strtrim(this.Widgets.edtTransform.Value),edata);
            catch E
               throw(E)
            end

            %Check that format of return argument from PostSimFcn is as
            %expected
            if isstruct(out)
                fnames = fieldnames(out);
                for ct=1:numel(fnames)
                    value = out.(fnames{ct});
                    ok = false;
                    if isnumeric(value) && isscalar(value)
                        ok = true;
                    elseif istimetable(value)
                        ok = strcmp(value.Properties.DimensionNames{1},'Time');
                        ok = ok && isequal(value.Time,t); %Must have same time points as logged data
                        ok = ok && any(strcmp(value.Properties.VariableNames,'Data'));
                        ok = ok && isscalar(value{1,1});
                    end
                    if ~ok
                        romapp.internal.resources.error('errTransformTest_Values',this.Widgets.edtTransform.Value)
                    end
                end
            else
                romapp.internal.resources.error('errTransformTest_Struct',this.Widgets.edtTransform.Value)
            end
        end
    end
end

function tf = lSigIsEqual(sig1,sig2)

%Check signal block path, port type and index.
tf = isequal(sig1.BlockPath,sig2.BlockPath) && ...
    isequal(sig1.PortType,sig2.PortType)  && ...
    isequal(sig1.PortIndex,sig2.PortIndex);
end

function tf = lParamIsEqual(p1,p2)

%Check signal block path, port type and index.
tf = isequal(p1.BlockPath,p2.BlockPath) && ...
    isequal(p1.Name,p2.Name);
end

function tf = lvecisequal(v1,v2,fcnIsEqual)

tf = isequal(size(v1),size(v2));
if ~ tf, return, end
i1 = 1;
while tf && i1 <= numel(v1)
    found = false;
    i2 = 1;
    while i2 <= numel(v2) && ~found
        if fcnIsEqual(v1(i1),v2(i2))
            found = true;
            v2(i2) = [];
        else
            i2 = i2+1;
        end
    end
    tf = tf && found;
    i1 = i1+1;
end
end

function [romIn,simIn,both] = lSortSignalPorts(romIn,simIn)
%Group signals by port type, ROMOnly, SimulationInput,
%ROMandSimulationInput

romOnly = true(size(romIn));
simOnly = true(size(simIn));
for ctR=1:numel(romIn)
    %Check whether the rom input is also a simulation input
    sig = romIn(ctR);
    for ctS=1:numel(simIn)
        if lSigIsEqual(sig,simIn(ctS))
            romOnly(ctR) = false;
            simOnly(ctS) = false;
            break
        end
    end
end

both = romIn(~romOnly);
romIn = romIn(romOnly);
simIn = simIn(simOnly);
end

function [simIn,both] = lSortParameterPorts(romIn,simIn)
%Group parameters by port type, SimulationInput,
%ROMandSimulationInput

simOnly = true(size(simIn));
for ctR=1:numel(romIn)
    %Check whether the rom input is also a simulation input
    param = romIn(ctR);
    for ctS=1:numel(simIn)
        if lParamIsEqual(param,simIn(ctS))
            simOnly(ctS) = false;
            break
        end
    end
end

both = romIn(~simOnly);
simIn = simIn(simOnly);
end

function width = lGetDisplayWidth(txt)
width = (matlab.internal.display.wrappedLength(txt) + 1) ...
    * get(0,'DefaultUicontrolFontSize');
end

function vec = lmergeVectors(vec1,vec2)

vec = vec1;
idx = true(numel(vec2),1);
for ct2=1:numel(vec2)
    for ct1=1:numel(vec1)
        if isequal(vec1(ct1),vec2(ct2))
            idx(ct2) = false;
            break
        end
    end
end
vec = [vec(:); vec2(idx)];
end

% LocalWords:  GL uigridlayout uiaxes YTick tbl btn lbl ttipSelectIO mw IOs ROMandSimulationInput
% LocalWords:  chk rbtn edt rbtngrp uialert cb
