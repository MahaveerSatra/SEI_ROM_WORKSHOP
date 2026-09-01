classdef DistributionParameters < handle
    %

    % DistributionParameters
    %
    % Panel to display/set the distribution information for random
    % parameters

    % Copyright 2023-2025 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool

        HaveStats

        Layout
        Places
        Widgets

        DistributionNameMap

        CorrelationPanel
        ParentTab
        
        Spec romapp.internal.data.RandomParameterSpec
    end

    properties (Hidden,  GetAccess = public,  SetAccess = protected)
        QEMeanPreserved   % indicates whether mean preserved when changing distribution type
        QEStdPreserved    % indicates whether std preserved when changing distribution type
    end

    methods
        function this = DistributionParameters(spec,havestats,corrPanel,parent,row,col)
            %DistributionParameters

            this.Widgets = struct();

            %Set the data for the class
            this.Spec = spec;
            this.HaveStats = havestats;
            setDistributionNameMap(this);
            this.ParentTab = parent;
            

            %Store handle to correlation panel
            this.CorrelationPanel = corrPanel;
           
            %Build the panel and update the panel
            if nargin < 5
                %No row/col information
                row = nan;
                col = nan;
            end
            buildPanel(this,parent,row,col)
            updatePanel(this)

            %Connect the panel to the data source
            connectPanel(this)
        end

        function delete(~)

        end

        function updatePanel(this)

            if isempty(this.Spec.Parameters)
                %Show message saying there are no parameters in sample set
                this.Widgets.ParameterTable.Data = [];
                this.Layout.Visible              = false;
            else
                % this.LayoutNoParams.Visible = false; 
                % this.Layout.Visible         = true;
                updateParameterTable(this);
                updateDistributionalParameters(this);
            end

        end

        function updateSpec(this)
           
        end
    end

    methods (Access=private)
        function buildPanel(this,parent,row,col)
            
            buildLayout(this,parent,row,col)
            
            %Create widgets
            buildDistributionTable(this);
            buildDistributionSpecifiers(this);
            
            %Place widgets in the layout, now that they've been created
            applyPlacement(this);
        end

        function buildLayout(this,container,row,col)
            %Build layout.  The layout is organized in 3 main groups:
            %    Left: table, highlighted row shows which parameter's
            %        distributions are being edited
            %    Middle: widgets for the distributional parameters
            
            layout = uigridlayout(container, [11 9]);
            if ~isnan(row) && ~isnan(col)
                layout.Layout.Row = row;
                layout.Layout.Column = col;
            end
            rh = 23;    % row height for fixed rows
            cwL = 30;   % column width to left of distributional parameters
            cwR = 40;   % column width to right distributional parameters

            %Rows:                  1     2   3  4  5    6   7    8    9    10    11
            layout.RowHeight   = {'fit','fit',rh,rh,rh,'fit',rh,'fit','1x','fit','fit'};

            %Columns:               1   2    3     4   5   6     7    8    9
            layout.ColumnWidth = {'fit',cwL,'fit','fit',cwR,'1x','fit','fit','1x'};

            %Store the layout
            this.Layout = layout;

            %Placement for parameter table
            setPlaces(this, 'ParameterTable',                 [2 11],  1);

            %Placement for distributional parameters
            setPlaces(this, 'DistributionLabel',               2,      3);
            setPlaces(this, 'DistributionValue',               2,      4);
            setPlaces(this, 'DistributionalParameterLabel1',   3,      3);
            setPlaces(this, 'DistributionalParameterValue1',   3,      4);
            setPlaces(this, 'DistributionalParameterLabel2',   4,      3);
            setPlaces(this, 'DistributionalParameterValue2',   4,      4);
            setPlaces(this, 'DistributionalParameterLabel3',   5,      3);
            setPlaces(this, 'DistributionalParameterValue3',   5,      4);
            setPlaces(this, 'CrossCorrelated',                 8,     [3 4]);
        end

        function buildWidgets(this)
            %Create widgets
            buildDistributionTable(this);
            buildDistributionSpecifiers(this);
            
            %Place widgets in the layout, now that they've been created
            applyPlacement(this);
        end

        function buildDistributionTable(this)
            %Create widgets for table to show distributional parameters

            %Common items
            container = this.Layout;

            %Create table to display distributional parameters
            colNames = {...
                romapp.internal.resources.getString('lblEditDistributions_DistributionsTable_Parameter'), ...
                romapp.internal.resources.getString('lblEditDistributions_DistributionsTable_Distribution'), ...
                romapp.internal.resources.getString('lblEditDistributions_DistributionsTable_CrossCorrelatedLF') };
            data = table([], [], [], ...
                'VariableNames', {'Parameter','DistributionType','CrossCorrelated'});
            tag = 'ParameterTable';
            this.Widgets.(tag) = uitable(container, ...
                'Tag',                    tag, ...
                'Data',                   data, ...
                'ColumnName',             colNames, ...
                'ColumnEditable',         false, ...
                'ColumnSortable',         false, ...
                'ColumnWidth',            'auto', ...
                'RowName',                [], ...
                'SelectionType',          'row', ...
                'Multiselect',            'off', ...
                'RowStriping',            'off');
        end

        function buildDistributionSpecifiers(this)
            %Create widgets to specify distributional parameters

            %Common items
            container = this.Layout;

            %TODO: Width for distributional parameter labels:
            %Either set to a constant based on longest name,
            %or set based on extent of longest name (for G10N)
            
            %Label for probability distribution
            tag = 'DistributionLabel';
            this.Widgets.(tag) = uilabel(container, ...
                'Tag',                 tag, ...
                'Text',                romapp.internal.resources.getString('lblEditDistributions_DistributionDetail_Type'), ...
                'HorizontalAlignment', 'Left');

            %Value for probability distribution
            tag = 'DistributionValue';
            this.Widgets.(tag) = uidropdown(container, ...
                'Tag',       tag, ...
                'Items',     getDistributionName(this,'AllViewForm'), ...
                'ItemsData', getDistributionName(this,'AllDataForm'));

            %Label for distributional parameter 1
            tag = 'DistributionalParameterLabel1';
            this.Widgets.(tag) = uilabel(container, ...
                'Tag',                 tag, ...
                'Text',                '', ...
                'HorizontalAlignment', 'Left');

            %Value for distributional parameter 1
            tag = 'DistributionalParameterValue1';
            this.Widgets.(tag) = uieditfield(container, 'text', ...
                'Tag',   tag, ...
                'Value', '0');

            %Label for distributional parameter 2
            tag = 'DistributionalParameterLabel2';
            this.Widgets.(tag) = uilabel(container, ...
                'Tag',                 tag, ...
                'Text',                '', ...
                'HorizontalAlignment', 'Left');

            %Value for distributional parameter 2
            tag = 'DistributionalParameterValue2';
            this.Widgets.(tag) = uieditfield(container, 'text', ...
                'Tag',   tag, ...
                'Value', '0');

            %Label for distributional parameter 3
            tag = 'DistributionalParameterLabel3';
            this.Widgets.(tag) = uilabel(container, ...
                'Tag',                 tag, ...
                'Text',                '', ...
                'HorizontalAlignment', 'Left');

            %Value for distributional parameter 3
            tag = 'DistributionalParameterValue3';
            this.Widgets.(tag) = uieditfield(container, 'text', ...
                'Tag',   tag, ...
                'Value', '0');

            %Checkbox for cross-correlated
            tag = 'CrossCorrelated';
            this.Widgets.(tag) = uicheckbox(container, ...
                'Tag',  tag, ...
                'Text', romapp.internal.resources.getString('lblEditDistributions_DistributionsTable_CrossCorrelated') );
        end

        function setPlaces(this, widgetTag, row, column)
            %SETPLACES Set placement of widgets in layout
            %

            %Store places as a cell.
            %    Column 1: widget tag
            %    Column 2: row placement
            %    Column 3: column placement
            this.Places = vertcat(this.Places, ...
                {widgetTag row column} );
        end
        function widget = findWidget(this, identifier)
            %FINDWIDGET Find widget
            %
            %    widget = findWidget(this, Identifier)
            %    Finds widget whose Tag matches Identifier
            %

            widget = this.Widgets.(identifier);
        end

        function applyPlacement(this)
            %APPLYPLACEMENT Apply placement to widgets
            %    applyPlacement(this) applies placement for all widgets
            %    specified in Places
            %

            for ct =  1 : size(this.Places, 1)
                tag = this.Places{ct,1};
                wdgt = findWidget(this, tag);
                wdgt.Layout.Row    = this.Places{ct,2};
                wdgt.Layout.Column = this.Places{ct,3};
            end
        end

        function connectPanel(this)
           

            %Table
            uit = this.Widgets.('ParameterTable');
            uit.SelectionChangedFcn = @(source,evData) cbTableSelectionChanged(this,source,evData);

            %Drop down for probability distribution
            cmb = this.Widgets.('DistributionValue');
            cmb.ValueChangedFcn = @(source,evData) cbDistribution(this,source);

            %Edit-fields for distributional parameters
            tagsAll = {'DistributionalParameterValue1','DistributionalParameterValue2', ...
                'DistributionalParameterValue3'};
            for ct = 1:numel(tagsAll)
                tag = tagsAll{ct};
                edt = this.Widgets.(tag);
                edt.ValueChangedFcn = @(source,evData) cbDistributionalParameter(this,source,evData);
            end

            %Checkbox for cross-correlated
            chk = this.Widgets.('CrossCorrelated');
            chk.ValueChangedFcn = @(source,evData) cbCorrelated(this,source);
        end

        function updateParameterTable(this)
            %UPDATEPARAMETERTABLE Update parameter table

            %Common items
            spec = this.Spec;
            names = romapp.internal.data.ModelPorts.getDisplayName(spec.Parameters);
            dist = spec.Distributions;
            nParam = numel(names);

            tbldata = cell(nParam,3);
            iCorr = getCorrelatedParameterIndices(this.CorrelationPanel);
            for ct=1:nParam
                tbldata{ct,1} = char(names(ct));
                tbldata{ct,2} = char(dist(ct).DistributionName);
                tbldata{ct,3} = any(ct==iCorr);
            end

            %Populate parameter table
            uit = this.Widgets.ParameterTable;
            uit.Data = tbldata;
            if isempty(uit.Selection)
                uit.Selection = 1;
            end            
        end

        function updateDistributionalParameters(this)
            %UPDATEDISTRIBUTIONALPARAMETERS Update distribution parameters

            %Get distribution and settings
            [~,idx] = getSelectedParameter(this);
            if isempty(idx)
                %Quick return, nothing to do
                return
            end
            pd = this.Spec.Distributions(idx);
            [dParamNames, dParamValues] = romapp.internal.panels.DistributionParameters.getDistributionalParameters(pd);

            %Update drop-down with probability distribution
            distributionName_DataForm = getDistributionName(this, 'DataForm', pd.DistributionName);
            this.Widgets.DistributionValue.Value = distributionName_DataForm;

            %For piecewise linear distribution, insert the # of points as
            %the first distributional parameter
            if matches('PiecewiseLinear', distributionName_DataForm)
                dParamNames = {romapp.internal.resources.getString('lblEditDistributions_PiecewiseLinear_NumPoints'), ...
                    dParamNames{1:2} };
                dParamValues = {numel(pd.x)  dParamValues{1:2} };
            end

            %Update distributional parameters
            for ct = 1:numel(dParamNames)
                nameField  = ['DistributionalParameterLabel'  num2str(ct)];
                valueField = ['DistributionalParameterValue'  num2str(ct)];
                updateDistributionalParamValuePair(this, ...
                    dParamNames{ct}, dParamValues{ct}, ...
                    nameField, valueField);
            end

            %Set cross-correlation checkbox
            if isempty(this.CorrelationPanel.CorrelatedParams)
                this.Widgets.CrossCorrelated.Value = false;
            else
                this.Widgets.CrossCorrelated.Value = any(this.CorrelationPanel.CorrelatedParams==idx);
            end
        end

        function updateDistributionalParamValuePair(this, paramName, paramValue, nameOfLabel, nameOfEditfield)
            %UPDATEDISTRIBUTIONALPARAMVALUEPAIR Update distribution
            %    Update widgets for a distributional parameter name/value
            %    pair

            %Get widgets
            wdgtName  = this.Widgets.(nameOfLabel);
            wdgtValue = this.Widgets.(nameOfEditfield);

            %Update widget content
            if isempty(paramName)
                vis = 'off';
            else
                wdgtName.Text = paramName;
                if strcmp('', paramValue)
                    val = '';   % % this branch may not be reached/needed
                else
                    val = mat2str(paramValue);
                end
                wdgtValue.Value = val;
                vis = 'on';
            end

            %Update widget visibility
            wdgtName.Visible = vis;
            wdgtValue.Visible = vis;
        end

        function [name,selectedRow] = getSelectedParameter(this)
            % GETSELECTEDPARAMETER Get parameter selected in the table
            uit = this.Widgets.ParameterTable;
            selectedRow = uit.Selection;
            if isempty(selectedRow)
                name = [];
            else
                name = uit.Data{selectedRow,1};
            end
        end

        function cbTableSelectionChanged(this,uit,eventData)

            %If user clicks in blank area, don't change selection
            if isempty(eventData.Selection) && ~isempty(uit.Data)
                uit.Selection = eventData.PreviousSelection;
                return
            end

            updateDistributionalParameters(this);
        end

        function cbDistribution(this,source)
            %CBDISTRUBTION Manage changes to probability distribution

            [~,idx] = getSelectedParameter(this);
            if isempty(idx)
                %Quick return, nothing to do
                return
            end

            %Make a probability distribution of the type specified in the
            %widget.  Provide the old distribution, to try to match the
            %mean and std.
            pdOld = this.Spec.Distributions(idx);
            pd = createDistribution(this, pdOld, source.Value);

            %Set the probability distribution
            this.Spec.Distributions(idx) = pd;
                        
            updateDistributionalParameters(this)
            updateParameterTable(this)
        end

        function cbDistributionalParameter(this,widget,eventData)

            %Common items
            previous = eventData.PreviousValue;   % in case have to revert
            txt = widget.Value;

            % Value cannot be empty
            if isempty(txt)
                revert(this,widget,previous);
                return
            end

            %Evaluate widget text
            [val,reverted] = evaluateDistributionalParameter(this,widget,previous);
            if reverted
                return
            end

            %If a vector, ensure it's a row for widget display. Vectors
            %occur for e.g. piecewise linear distributions.
            val = reshape(val, 1, []);

            %Get probability distribution
            [~,idx] = getSelectedParameter(this);
            pd = this.Spec.Distributions(idx);

            %Handle case of piecewise linear distribution
            distributionName_DataForm = getDistributionName(this, 'DataForm', pd.DistributionName);
            if matches('PiecewiseLinear', distributionName_DataForm)
                cbDistributionalParameter_PiecewiseLinear(this,widget,previous,pd,val);
                return
            end

            switch widget.Tag
                case 'DistributionalParameterValue1'
                    idxP = 1;
                case 'DistributionalParameterValue2'
                    idxP = 2;
                case 'DistributionalParameterValue3'
                    idxP = 3;
            end
            dParamName = pd.ParameterNames{idxP};

            %For uniform distributions, swap the lower/upper bounds if
            %needed
            pdUniform = makedist('Uniform');
            if strcmp(pdUniform.DistributionName, pd.DistributionName)
                pd = createUniformDistribution(this,pd,previous,val);
            else
                %Try to make a distribution with this specification.
                try
                    pd.(dParamName) = val;
                catch E
                    revert(this,widget,previous, E.message);
                    return
                end
            end

            % Set the modified distribution in the data
            this.Spec.Distributions(idx) = pd;
        end

        function cbCorrelated(this,source)
            %CBCORRELATED Manage changes to correlation
            [~,idx] = getSelectedParameter(this);

            if source.Value
                addCorrelatedParameter(this.CorrelationPanel,idx)
            else
                removeCorrelatedParameter(this.CorrelationPanel,idx)
            end
            updateParameterTable(this);
            setDirty(this.CorrelationPanel,true);
        end

        function setDistributionNameMap(this)
            % GETDISTRIBUTIONNAMEMAP Get distribution name map
            %    Make distribution name mapping between data and view forms
            createNames = romapp.internal.panels.DistributionParameters.availableDistributions(this.HaveStats);
            createNames = reshape(createNames, [], 1);   % ensure column for table
            distributions = cellfun(@(e) makedist(e),  createNames,  'UniformOutput', false);
            displayNames = cellfun(@(e) e.DistributionName,  distributions,  'UniformOutput', false);
            nameMap = table(createNames, displayNames, ...
                'VariableNames', {'DataForm', 'ViewForm'});
            this.DistributionNameMap = nameMap;
        end

        function name = getDistributionName(this,form,value)
            % GETDISTRIBUTIONNAME Get distribution name
            %     getDistributionName(this, 'DataForm', valueInViewForm)
            %     getDistributionName(this, 'AllViewForm')
            %     getDistributionName(this, 'AllDataForm')
            form = validatestring(form, {'DataForm' 'AllViewForm' 'AllDataForm'});
            switch form
                case 'DataForm'
                    tf = matches(this.DistributionNameMap.ViewForm, value);
                    name = this.DistributionNameMap.DataForm{tf};                    
                case 'AllViewForm'
                    name = this.DistributionNameMap.ViewForm;
                case 'AllDataForm'
                    name = this.DistributionNameMap.DataForm;
            end
        end

        function [val,reverted] = evaluateDistributionalParameter(this,widget,previous)
            %Evaluate widget value
            reverted = false;
            try
                val = evalin('base',widget.Value);
                if isnumeric(val)  &&  isvector(val)  &&  ~any(isnan(val))  &&  isreal(val)
                    %No operation, just easier to state logic positively
                else
                    error('shared_romapp:dialogs:errUnexpected','Value must be numeric')
                end
            catch
                revert(this,widget,previous, ...
                    romapp.internal.resources.getString('errEditDistributions_InvalidDistributionParameterValue') );
                reverted = true;
                val = nan;
            end
        end

        function revert(this,widget,previous,varargin)
            %Revert widget to previous value
            %    revert(object, widget, eventData, [message])

            %Parse inputs
            if isempty(varargin)
                msg = [];
            else
                msg = varargin{1};
            end

            %Display message
            if isempty(msg)
                revertWidget(this,widget,previous);
            else
                wholeMessage = [msg  '  '  romapp.internal.resources.getString('errEditDistributions_RevertDistributionParameterValue') ];
                uialert(romapp.internal.dialogs.EditDistributionsDialog.getFigure(this.ParentTab), ...
                    wholeMessage, ...
                    romapp.internal.resources.getString('errEditDistributions_InvalidEntry'), ...
                    'CloseFcn', @(~,~) revertWidget(this,widget,previous) );
            end
        end

        function revertWidget(~,widget,previous)
            %Revert widget
            widget.Value = previous;
        end
    end

    methods(Access = private, Static = true)
        function distributions = availableDistributions(haveStats)
            % AVAILABLEDISTRIBUTIONS Available distributions
            %
            distributions = {'Uniform' ; 'Normal' ; ...
                'Multinomial' ; 'PiecewiseLinear' ; 'Triangular'};
            if haveStats
                distributions = vertcat(distributions, ...
                    {...
                    'Beta' ; ...
                    'Binomial' ; ...
                    'BirnbaumSaunders' ; ...
                    'Burr' ; ...
                    'Exponential' ; ...
                    'ExtremeValue' ; ...
                    'Gamma' ; ...
                    'GeneralizedExtremeValue' ; ...
                    'GeneralizedPareto' ; ...
                    'InverseGaussian' ; ...
                    'Logistic' ; ...
                    'Loglogistic' ; ...
                    'Lognormal' ; ...
                    'Nakagami' ; ...
                    'NegativeBinomial' ; ...
                    'Poisson' ; ...
                    'Rayleigh' ; ...
                    'Rician' ; ...
                    'tLocationScale' ; ...
                    'Weibull'  }  );
                % Leave Uniform and Normal on top, sort the rest
                dOther = distributions(3:end);
                [~,idx] = sort(lower(dOther));
                dOther = dOther(idx);
                distributions = vertcat(...
                    distributions(1:2), ...
                    dOther);                
            end
        end
        function [dParamNames, dParamValues] = getDistributionalParameters(pd)
            % GETDISTRIBUTIONALPARAMETERS Get distributional parameters
            %    Get the distributional parameters for the probability
            %    distribution.  For example, for the Uniform distribution,
            %    the distributional parameter names are Lower and Upper,
            %    and the values are the corresponding numeric values.
            %
            
            % Get distributional parameter Names
            emptyName = '';
            dParamNames = repmat({emptyName}, 1, 3);
            namesUsed = pd.ParameterNames;
            dParamNames(1:numel(namesUsed)) = namesUsed;
            
            % Get distributional parameter Values
            emptyVal = [];   % value for empty entry
            dParamValues = repmat({emptyVal}, 1, 3);   % pre-allocate
            for ct = 1:3
                dpName = dParamNames{ct};
                if ~isempty(dpName)
                    dParamValues{ct} = pd.(dpName);
                end
            end
        end
        function value = roundZero(value, scale)
            % ROUNDZERO Round to zero
            %    Round value to zero, if the value is near zero compared to
            %    machine precision, and the scale of the distribution is
            %    much larger than machine precision
            %
            if (abs(value) < 3*eps)  && ...
                    ( (scale > 1e6*eps)  ||  ~isfinite(scale) )
                value = 0;
            end
        end
        function pd = setUniformLimits(pd, lwr, upr)
            % SETUNIFORMLIMITS Set limits on uniform distribution
            %    Ensures that the distribution's Lower parameter is always
            %    less than its Upper parameter
            lower = min(lwr,upr);
            upper = max(lwr,upr);
            if lower==upper
                if lower==0
                    lower = -1;
                    upper = 1;
                else
                    lower = lower*(1-0.1*sign(lower));
                    upper = upper*(1+0.1*sign(upper));
                end
            end
            if lower < pd.Upper
                pd.Lower = lower;
                pd.Upper = upper;
            else
                pd.Upper = upper;
                pd.Lower = lower;
            end
        end
    end

    methods(Access = private)
        function pdOut = createUniformDistribution(~,pd,previous,val)
            %Create uniform distribution, modified from existing one (pd).
            %Ensure that the lower limit is below the upper limit.

            cVals = [pd.Lower, pd.Upper];
            iChanged = abs(cVals - eval(previous)) <= eps(cVals);

            vals = [cVals(~iChanged),val];

            pdOut = makedist('Uniform');
            pdOut = romapp.internal.panels.DistributionParameters.setUniformLimits(pdOut,vals(1),vals(2));
        end
    end
end

% LocalWords:  lbl CrossCorrelatedLF Multiselect SETPLACES APPLYPLACEMENT UPDATEPARAMETERTABLE sldo
% LocalWords:  UPDATEDISTRIBUTIONALPARAMETERS UPDATEDISTRIBUTIONALPARAMVALUEPAIR
% LocalWords:  GETSELECTEDPARAMETER CBDISTRUBTION CBCORRELATED GETDISTRIBUTIONNAMEMAP
% LocalWords:  GETDISTRIBUTIONNAME InavlidDistributionParameterValue AVAILABLEDISTRIBUTIONS Birnbaum
% LocalWords:  Loglogistic Nakagami GETDISTRIBUTIONALPARAMETERS ROUNDZERO SETUNIFORMLIMITS
