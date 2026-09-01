classdef CustomSignalSpec <  matlab.mixin.SetGet
    %

    % CustomSignalSpec

    % Copyright 2024 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        SignalTable
        Widgets
        Spec romapp.internal.data.CustomSignalSpec
    end

    events(NotifyAccess = protected)
        ValueChanged
    end

    methods
        function this = CustomSignalSpec(tool,spec,parent,row,col)
            % CustomSIGNALSPEC
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
            tbldata = cell(nInputs,2);
            for ct=1:nInputs
                tbldata{ct,1} = char(names(ct));
                tbldata{ct,2} = char(this.Spec.userInput{ct});
            end
            this.SignalTable.Data = tbldata;

            this.Widgets.errMsg.Text = '';
        end
        
        function inputsAreValid = validateInputs(this)
            % validate all inputs, display error message for the first invalid input encountered
            inputsAreValid = false;
            for ct = 1:numel(this.Spec.Signals)
                oneUserInput = this.SignalTable.Data{ct,2};
                try 
                    oneData = evalin('base',char(oneUserInput));
                catch
                    this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                        string(romapp.internal.resources.getString('errCustomSignal'));
                    return
                end
                
                if istimetable(oneData) % timetable
                    if ~(size(oneData{:,1})>1)
                        this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                            string(romapp.internal.resources.getString('errCustomSignalSize'));
                        return
                    elseif ~( isequal(size(oneData,2),1) && isnumeric(oneData{:,1}) && isreal(oneData{:,1}) && isequal(size(oneData{:,1},2),1) ) %check timetable of ONE variable, data is real matrix, data is of size Nx1
                        this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                            string(romapp.internal.resources.getString('errCustomSignalData'));
                        return
                    elseif sum(isfinite(oneData{:,1}),"all") ~= numel(oneData{:,1}) % check finite (no NaN/Inf)
                        this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                            string(romapp.internal.resources.getString('errCustomSignalData'));
                        return 
                    else %then check time starts from 0
                        try 
                            if ~(isequal(min(seconds(oneData.Time)),0)) 
                                this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                                    string(romapp.internal.resources.getString('errCustomSignalTime'));
                                return
                            end
                        catch
                            this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                                string(romapp.internal.resources.getString('errCustomSignalTime'));
                            return
                        end
                    end
                elseif isnumeric(oneData) % numeric array
                    if ~ (isequal(size(oneData,2),2) && size(oneData,1)>1) % two-column
                        this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                            string(romapp.internal.resources.getString('errCustomSignalSize'));
                        return
                    elseif ~ (isreal(oneData(:,2)) && (sum(isfinite(oneData(:,2)),"all") == numel(oneData(:,2))) ) %real, two-column, finite (no NaN/Inf)
                        this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                            string(romapp.internal.resources.getString('errCustomSignalData'));
                        return 
                    elseif ~ ( (sum(isfinite(oneData(:,1)),"all") == numel(oneData(:,1))) && ...%time is finite
                            sum(oneData(:,1)>=0,"all")==numel(oneData(:,1)) && isequal(min(oneData(:,1)),0) ) %time is nonneg starting from 0  
                        this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                            string(romapp.internal.resources.getString('errCustomSignalTime'));
                        return 
                    end
                else % not timetable or not numeric array
                    this.Widgets.errMsg.Text = string(this.SignalTable.Data{ct,1}) + ...
                        string(romapp.internal.resources.getString('errCustomSignal'));
                    return
                end
            end
            inputsAreValid = true;
        end

        function updateSpec(this,varargin)
            % populate table
            nSig = size(this.SignalTable.Data,1);
            userData = cell(nSig,1);
            for ct = 1:nSig
                userData{ct} = evalin('base', this.SignalTable.Data{ct,2});
            end
            if nargin == 1
                setValues(this.Spec,this.SignalTable.Data(:,2),userData);
            elseif nargin>1
                setValues(varargin{1},this.SignalTable.Data(:,2),userData);
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
            layoutOptions = uigridlayout(parent, [3 2]);
            layoutOptions.Layout.Row = row;
            layoutOptions.Layout.Column = col;
            layoutOptions.RowHeight = {'fit', 'fit', 'fit'};
            layoutOptions.ColumnWidth = {'fit', '1x'};
            layoutOptions.Padding = [5 5 5 0]; %No top padding to keep horizontal-spacing with common widgets
            layoutOptions.Scrollable = 'on';
            
            labelSignalLimits = uilabel(layoutOptions);
            labelSignalLimits.Text = romapp.internal.resources.getString('lblCustomSignalSpec_TableTitle');
            labelSignalLimits.Layout.Row = 1;
            labelSignalLimits.Layout.Column = 1;

            signalTable = uitable(layoutOptions);
            signalTable.Layout.Row = 2;
            signalTable.Layout.Column = [1 2];
            vars = {...
                romapp.internal.resources.getString('lblPRSignalSpec_SignalName'),...
                romapp.internal.resources.getString('lblCustomSignalSpec_Value')};
            signalTable.ColumnName = vars;
            signalTable.ColumnWidth = {'fit', '1x'};
            signalTable.ColumnEditable = [false true];
            signalTable.ColumnFormat = {'char', 'char'};
            rightAlignStyle = uistyle('HorizontalAlignment', 'right');
            addStyle(signalTable, rightAlignStyle, "column", 2);
            this.SignalTable = signalTable;

            lblError = uilabel(layoutOptions);
            lblError.WordWrap = "on";
            lblError.Text = '';
            lblError.HorizontalAlignment = 'left';
            lblError.Layout.Row = 3;
            lblError.Layout.Column = [1 2];
            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblError,'FontColor','--mw-color-error')

            %Store the widgets
            this.Widgets = struct(...
                'textInstruction', labelSignalLimits,...
                'errMsg', lblError);  
        end

        function connectPanel(this)            
            addlistener(this.SignalTable,'CellEdit',@(hSrc,hData) notify(this,'ValueChanged'));
        end
    end
end

% LocalWords:  Custom btn lbl edt