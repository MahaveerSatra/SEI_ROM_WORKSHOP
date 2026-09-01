classdef CorrelationData <  handle
    %

    % CorrelationData
    %
    % Panel to display/set the correlation information for random
    % parameters

    % Copyright 2023-2024 The MathWorks, Inc.

    properties(SetAccess=private)
        Tool
        Widgets

        CorrelatedParams
        ParentTab         %Store parent so that can mark dirty/clean
        
        Spec romapp.internal.data.RandomParameterSpec
    end

    methods
        function this = CorrelationData(spec,parent,row,col)
            %CorrelationData

            this.Widgets = struct();

            %Set the spec and local data
            this.Spec = spec;
            this.CorrelatedParams = findCorrelatedParamsFromCorrelation(this);
            this.ParentTab = parent; 
           
            %Build the panel and update the panel
            if nargin < 3
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

            idx = this.CorrelatedParams;
            if isempty(idx)
                this.Widgets.tblCorrelation.Visible = false;
                this.Widgets.msgCorrelation.Visible = true;
            else
                corr = this.Spec.Correlation;
                if isempty(corr)
                    corr = eye(numel(this.Spec.Parameters));
                end
                names = romapp.internal.data.ModelPorts.getDisplayName(this.Spec.Parameters(idx));

                tblCorrelation = this.Widgets.tblCorrelation;
                tblCorrelation.Data = corr(idx,idx);
                tblCorrelation.ColumnName = names;
                tblCorrelation.RowName = names;

                this.Widgets.msgCorrelation.Visible = false;
                this.Widgets.tblCorrelation.Visible = true;
            end
        end

        function updateSpec(this)

        end

        function addCorrelatedParameter(this,idx)

            currIdx = this.CorrelatedParams;
            if isempty(currIdx)
                currIdx = idx;
            else
                for ct=1:numel(idx)
                    if ~any(idx(ct)==currIdx)
                        currIdx = [currIdx, idx]; %#ok<AGROW>
                    end
                end
            end

            this.CorrelatedParams = sort(currIdx);
            updatePanel(this)
        end

        function removeCorrelatedParameter(this,idx)

            currIdx = this.CorrelatedParams;
            if isempty(currIdx)
                return
            else
                rIdx = []; %indices into this.CorrelatedParams to remove
                for ct=1:numel(idx)
                    rIdx = [rIdx, find(idx(ct)==currIdx)]; %#ok<AGROW>
                end
                if ~isempty(rIdx)
                    this.CorrelatedParams(rIdx) = [];
                    if isempty(this.CorrelatedParams)
                        this.Spec.Correlation = [];
                    else
                        corr = this.Spec.Correlation;
                        %Zero the correlation values for the removed
                        %parameter
                        for ct = idx
                            corr(ct,:) = 0;
                            corr(:,ct) = 0;
                            corr(ct,ct) = 1;
                        end
                        this.Spec.Correlation = corr;
                    end
                    updatePanel(this)
                end
            end
        end

        function idx = getCorrelatedParameterIndices(this)
            idx = this.CorrelatedParams;
        end

        function setDirty(this,value)

            if value
                this.ParentTab.Title = romapp.internal.resources.getString('lblEditDistributions_Correlation')+"*";
            else
                this.ParentTab.Title = romapp.internal.resources.getString('lblEditDistributions_Correlation');
            end
        end
    end

    methods (Access=private)
        function buildPanel(this,parent,row,col)
            
            layout = uigridlayout(parent, [1 1]);
            if ~isnan(row) && ~isnan(col)
                layout.Layout.Row = row;
                layout.Layout.Column = col;
            end

            % Correlation matrix
            correlations = {};
            tblCorrelation = uitable(layout, ...
                'Data',                    correlations, ...
                'ColumnName',              {}, ...
                'ColumnFormat',            {}, ...
                'ColumnEditable',          true, ...
                'RowName',                 {}, ...
                'RowStriping',             'off', ...
                'Visible',                 'off');
            tblCorrelation.Layout.Row    = 1;
            tblCorrelation.Layout.Column = 1;
            
            % Widget for message text when there are no correlations
            msgCorrelation = uilabel(layout, ...
                'Tag',                     'CorrelationMatrixMessage', ...
                'Text',                    romapp.internal.resources.getString('lblEditDistributions_CorrelationMatrixMsgNoParameters'), ...
                'HorizontalAlignment',     'Center', ...
                'VerticalAlignment',       'center', ...
                'Visible',                 'on' );
            msgCorrelation.Layout.Row    = 1;
            msgCorrelation.Layout.Column = 1;
            
            %Store the widgets
            this.Widgets = struct(...
                'tblCorrelation', tblCorrelation, ...
                'msgCorrelation', msgCorrelation);
        end

        function connectPanel(this)
            
            tbl = this.Widgets.tblCorrelation;
            addlistener(tbl,'CellEdit', @(hTable, eventData) cbTableDataChanged(this, hTable, eventData));
        end

        function idx = findCorrelatedParamsFromCorrelation(this)
            
            corr = this.Spec.Correlation;
            if isempty(corr) || isequal(corr,eye(size(corr,1)))
                %No correlation 
                idx = [];
                return;
            end
            %Check for off diagonal non-zero entries
            n = size(corr,1);
            idx = [];
            for row=1:n-1
                cRow = corr(row,(row+1):end);
                nz = find(abs(cRow)>0);
                if any(nz)
                    idx = [idx,[row, row+nz]]; %#ok<AGROW>
                end
            end
            idx = unique(idx); %remove duplicates
        end

        function cbTableDataChanged(this, hTable, eventData)
            row = eventData.Indices(1);
            col = eventData.Indices(2);
            if row == col   % Entries on the diagonal remain as 1
                hTable.Data(row, row) = 1;
            else   % Off-diagonal entry changed
                cc = eventData.EditData;
                
                % Value cannot be empty
                if isempty(cc)
                    revertValue(this)
                    return
                end
                
                % Convert to numeric data, handling expressions like 'pi/4'
                % and defined variables
                try
                    cc = evalin('base', cc);
                catch
                    revertValue(this);
                    return
                end
                
                % Filter out invalid values
                if isempty(cc)  ||  ~isscalar(cc)  ||  ~isnumeric(cc)  || ...
                        isnan(cc)  ||  ~isreal(cc)  || ...
                        (cc < -1)  ||  (cc > 1)
                    revertValue(this);
                    return
                end
                
                % Update data
                corr = this.Spec.Correlation;
                if isempty(corr)
                    corr = eye(numel(this.Spec.Parameters));
                end
                %Convert row/col index from view to row/col index in
                %correlation matrix.
                hTable.Data(col,row) = cc; %Keep table symmetric
                dRow = this.CorrelatedParams(row);
                dCol = this.CorrelatedParams(col);
                corr(dRow,dCol) = cc;
                corr(dCol,dRow) = cc;  %To keep data symmetric
                this.Spec.Correlation = corr;
            end
        end

        function revertValue(this)
            % REVERTVALUE Revert value in correlation matrix view
            %
            
            % Display error message
            uialert(romapp.internal.dialogs.EditDistributionsDialog.getFigure(this.ParentTab), ...
                romapp.internal.resources.getString('lblEditDistributions_CorrelationMatrixRevert'), ...
                '');
            
            % Revert correlation matrix view
            updatePanel(this);
        end

    end
end

% LocalWords:  lbl tbl REVERTVALUE
