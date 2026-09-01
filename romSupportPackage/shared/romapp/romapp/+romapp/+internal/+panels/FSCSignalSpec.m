classdef FSCSignalSpec <  matlab.mixin.SetGet
    %

    % FSCSIGNALSPEC

    % Copyright 2024 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        SignalTable
        Widgets
        Spec romapp.internal.data.FSCSignalSpec
    end

    events(NotifyAccess = protected)
        ValueChanged
    end

    methods
        function this = FSCSignalSpec(tool,spec,parent,row,col)
            % FSCSIGNALSPEC

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

        function delete(~)

        end

        function setVisibleSpec(this,spec)
            this.Spec = spec;
        end

        function updatePanel(this)

            data = getToolData(this.Tool);

            names = getShortPortName(data,this.Spec.Signals);
            nInputs = numel(names);
            tbldata = cell(nInputs,1);
            for ct=1:nInputs
                tbldata{ct,1} = char(names(ct));
            end
            this.SignalTable.Data = tbldata;

            this.Widgets.edtInitialFrequency.Value = mat2str(this.Spec.InitialFrequency,4);
            this.Widgets.edtTargetFrequency.Value = mat2str(this.Spec.TargetFrequency,4);
            this.Widgets.edtInitialPhase.Value = mat2str(this.Spec.InitialPhase,4);            
            this.Widgets.edtMin.Value = mat2str(this.Spec.Ranges(:,1)',4);
            this.Widgets.edtMax.Value = mat2str(this.Spec.Ranges(:,2)',4);
            this.Widgets.edtTargetTime.Value = this.Spec.TargetTime;
            this.Widgets.errMsg.Text = '';
        end
        
        function inputsAreValid = validateInputs(this)

            data = getToolData(this.Tool);
            names = getShortPortName(data,this.Spec.Signals);
            nInputs = numel(names);

            inputsAreValid = false; 
            if (~validateVector(this.Widgets.edtInitialFrequency.Value,nInputs)) || (~validateNonNeg(this.Widgets.edtInitialFrequency.Value))
                this.Widgets.errMsg.Text = romapp.internal.resources.getString("errFSCSignalSpec_InitialFrequency", nInputs);
                return
            end
            if (~validateVector(this.Widgets.edtTargetFrequency.Value,nInputs)) || (~validateNonNeg(this.Widgets.edtTargetFrequency.Value))
                this.Widgets.errMsg.Text = romapp.internal.resources.getString("errFSCSignalSpec_TargetFrequency", nInputs);
                return
            end
            if ~validateVector(this.Widgets.edtInitialPhase.Value,nInputs)
                this.Widgets.errMsg.Text = romapp.internal.resources.getString("errFSCSignalSpec_InitialPhase", nInputs);
                return
            end
            if ~validateVector(this.Widgets.edtMin.Value,nInputs)
                this.Widgets.errMsg.Text = romapp.internal.resources.getString("errFSCSignalSpec_SignalMin", nInputs);
                return
            end
            if ~validateVector(this.Widgets.edtMax.Value,nInputs)
                this.Widgets.errMsg.Text = romapp.internal.resources.getString("errFSCSignalSpec_SignalMax", nInputs);
                return
            end
            if sum( evalin('base',this.Widgets.edtInitialFrequency.Value) ==...
                    evalin('base',this.Widgets.edtTargetFrequency.Value) )
                this.Widgets.errMsg.Text = romapp.internal.resources.getString("errFSCSignalSpec_SameFrequency");
                return
            end
            if ~ (isfinite(this.Widgets.edtTargetTime.Value) && this.Widgets.edtTargetTime.Value>0)
                this.Widgets.errMsg.Text = romapp.internal.resources.getString("errFSCSignalSpec_TargetTime");
                return
            end
            inputsAreValid = true;
        end

        function updateSpec(this,varargin)
            data = getToolData(this.Tool);
            names = getShortPortName(data,this.Spec.Signals);
            nInputs = numel(names);

            ifreq = evalInput(this.Widgets.edtInitialFrequency.Value,nInputs);
            tfreq = evalInput(this.Widgets.edtTargetFrequency.Value,nInputs);
            iphase = evalInput(this.Widgets.edtInitialPhase.Value,nInputs);            
            ranges = [evalInput(this.Widgets.edtMin.Value,nInputs)', evalInput(this.Widgets.edtMax.Value,nInputs)'];
            ranges = sort(ranges,2);
            ttime = this.Widgets.edtTargetTime.Value;
            if nargin == 1
                setValues(this.Spec,ifreq,tfreq,iphase,ttime,ranges); % update signal spec of this panel
            elseif nargin>1
                setValues(varargin{1},ifreq,tfreq,iphase,ttime,ranges); % update a standalone signal spec
            end
        end
        
        function wdgts = getWidgets(this)
            wdgts = this.Widgets;
            wdgts.SignalTable = this.SignalTable;
        end
    end

    methods (Access=private)
        function buildPanel(this,parent,row,col)

            %Create widgets to display/edit the spec
            layoutOptions = uigridlayout(parent, [9 2]);
            layoutOptions.Layout.Row = row;
            layoutOptions.Layout.Column = col;
            layoutOptions.RowHeight = {'fit', 130, 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            layoutOptions.ColumnWidth = {'fit', '1x'};
            layoutOptions.Padding = [5 5 5 0]; %No top padding to keep horizontal-spacing with common widgets 
            layoutOptions.Scrollable = 'on';            
           
            labelSignalLimits = uilabel(layoutOptions);
            labelSignalLimits.Text = romapp.internal.resources.getString('lblFSCSignalSpec_Parameters');
            labelSignalLimits.Layout.Row = 1;
            labelSignalLimits.Layout.Column = 1;

            signalTable = uitable(layoutOptions);
            signalTable.Layout.Row = 2;
            signalTable.Layout.Column = [1 2];
            vars = {romapp.internal.resources.getString('lblPRSignalSpec_SignalName')};
            signalTable.ColumnName = vars;
            signalTable.ColumnWidth = {'1x'};
            signalTable.ColumnEditable = false;
            signalTable.ColumnFormat = {'char'};
            this.SignalTable = signalTable;

            labelInitailFrequency = uilabel(layoutOptions);
            labelInitailFrequency.Text = romapp.internal.resources.getString('lblFSCSignalSpec_InitialFrequency');
            labelInitailFrequency.Layout.Row = 3;
            labelInitailFrequency.Layout.Column = 1;
            editFieldIF = uieditfield(layoutOptions,'text');
            editFieldIF.Layout.Row = 3;
            editFieldIF.Layout.Column = 2;
            editFieldIF.Value = '0.1';

            labelTargetFrequency = uilabel(layoutOptions);
            labelTargetFrequency.Text = romapp.internal.resources.getString('lblFSCSignalSpec_TargetFrequency');
            labelTargetFrequency.Layout.Row = 4;
            labelTargetFrequency.Layout.Column = 1;
            editFieldTF = uieditfield(layoutOptions,'text');
            editFieldTF.Layout.Row = 4;
            editFieldTF.Layout.Column = 2;
            editFieldTF.Value = '1';

            labelInitialPhase = uilabel(layoutOptions);
            labelInitialPhase.Text = romapp.internal.resources.getString('lblFSCSignalSpec_InitialPhase');
            labelInitialPhase.Layout.Row = 5;
            labelInitialPhase.Layout.Column = 1;
            editFieldIP = uieditfield(layoutOptions,'text');
            editFieldIP.Layout.Row = 5;
            editFieldIP.Layout.Column = 2;
            editFieldIP.Value = '0';

            labelMin = uilabel(layoutOptions);
            labelMin.Text = romapp.internal.resources.getString('lblFSCSignalSpec_SignalMin');
            labelMin.Layout.Row = 6;
            labelMin.Layout.Column = 1;
            editFieldMin = uieditfield(layoutOptions,'text');
            editFieldMin.Layout.Row = 6;
            editFieldMin.Layout.Column = 2;
            editFieldMin.Value = '-1';

            labelMax = uilabel(layoutOptions);
            labelMax.Text = romapp.internal.resources.getString('lblFSCSignalSpec_SignalMax');
            labelMax.Layout.Row = 7;
            labelMax.Layout.Column = 1;
            editFieldMax = uieditfield(layoutOptions,'text');
            editFieldMax.Layout.Row = 7;
            editFieldMax.Layout.Column = 2;
            editFieldMax.Value = '1';

            labelTargetTime = uilabel(layoutOptions);
            labelTargetTime.Text = romapp.internal.resources.getString('lblFSCSignalSpec_TargetTime');
            labelTargetTime.Layout.Row = 8;
            labelTargetTime.Layout.Column = 1;
            editFieldTT = uieditfield(layoutOptions,'numeric');
            editFieldTT.Layout.Row = 8;
            editFieldTT.Layout.Column = 2;
            editFieldTT.Value = 20;

            lblError = uilabel(layoutOptions);
            lblError.WordWrap = "on";
            lblError.Text = '';
            lblError.HorizontalAlignment = 'left';
            lblError.Layout.Row = 9;
            lblError.Layout.Column = [1 2];
            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')

            %Store the widgets
            this.Widgets = struct(...
                'textInstruction', labelSignalLimits,...
                'edtInitialFrequency', editFieldIF,...
                'edtTargetFrequency', editFieldTF,...
                'edtInitialPhase', editFieldIP, ...
                'edtTargetTime', editFieldTT, ...
                'edtMin', editFieldMin, ...
                'edtMax', editFieldMax, ...
                'errMsg', lblError); 
        end

        function connectPanel(this)
            addlistener(this.Widgets.edtInitialFrequency,'ValueChanged', @(hSrc,hData) notify(this,'ValueChanged'));
            addlistener(this.Widgets.edtTargetFrequency,'ValueChanged', @(hSrc,hData) notify(this,'ValueChanged'));
            addlistener(this.Widgets.edtInitialPhase,'ValueChanged', @(hSrc,hData) notify(this,'ValueChanged'));            
            addlistener(this.Widgets.edtMin,'ValueChanged', @(hSrc,hData) notify(this,'ValueChanged'));
            addlistener(this.Widgets.edtMax,'ValueChanged', @(hSrc,hData) notify(this,'ValueChanged'));
            addlistener(this.Widgets.edtTargetTime,'ValueChanged', @(hSrc,hData) notify(this,'ValueChanged'));
        end
        
    end
end


function inputIsValid = validateVector(vectorInput,nSig)
    % checks for real vector and size
    inputIsValid = false;
    try
        evalVectorInput = evalin('base',vectorInput);
    catch 
        return
    end
    if ~ (isnumeric(evalVectorInput) && isreal(evalVectorInput) && isvector(evalVectorInput))
        return
    elseif sum(~isfinite(evalVectorInput),"all")
        return 
    end
    sizeValid1 = isscalar(evalVectorInput);
    sizeValid2 = isequal(size(evalVectorInput),[1,nSig]);
    sizeValid3 = isequal(size(evalVectorInput),[nSig,1]);
    if ~(sizeValid1 || sizeValid2 || sizeValid3)
        return
    end
    inputIsValid = true;
end

function inputIsNonNegReal = validateNonNeg(vectorInput)
    % checks for non-negative real vector
    inputIsNonNegReal = false;
    try
        evalVectorInput = evalin('base',vectorInput);
        if sum(evalVectorInput>=0,"all") ~= numel(evalVectorInput)
            return
        end
    catch 
        return
    end
    inputIsNonNegReal = true;
end

function evaledInput = evalInput(vectorInput, nSig)
    evaledInput = evalin('base', vectorInput);
    if isscalar(evaledInput)
        evaledInput = evaledInput*ones(1,nSig);
    elseif isequal(size(evaledInput),[nSig,1])
        evaledInput = evaledInput';
    end
end
