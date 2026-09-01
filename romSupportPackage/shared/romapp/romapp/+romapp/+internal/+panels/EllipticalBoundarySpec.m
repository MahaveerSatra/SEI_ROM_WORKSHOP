classdef EllipticalBoundarySpec < handle % romapp.internal.panels.BoundarySpec
    %

    % EllipticalBoundarySpec
    % 
    % Panel to display/set elliptical boundaries

    % Copyright 2025 The MathWorks, Inc.
    
    properties(SetAccess=private)
        EditBoundariesFigure
        EditBoundariesWidgets
        Widgets 

        Mode (1,1) string {mustBeMember(Mode, ["select","zoom"])} = "select"
        Data 

        AxesLims
        isAxisAdjustable
    end

    methods
        function this = EllipticalBoundarySpec(EditBoundariesWidgets, boundaryspec, parent, row, col, ind, lims, isAxisAdjustable)
            %EllipticalBoundarySpec
            this.EditBoundariesFigure = parent.Parent;
            this.EditBoundariesWidgets = EditBoundariesWidgets;
            this.Widgets = struct();
            this.Data = struct();          
            this.AxesLims = lims;
            this.isAxisAdjustable = isAxisAdjustable;

            %Build the panel
            buildPanel(this,parent,row,col)

            %Populate if a matching boundary exists
            if ~isempty(ind)
                eFactors = boundaryspec.Spec.Factors{ind};
                eFactor1 = eFactors(1); 
                this.Widgets.ddIneq.Value = boundaryspec.Spec.Inequality{ind};     
                data = boundaryspec.Spec.Data{ind};
                this.Widgets.efRotation.Value = data.Rotation;                
                if strcmp(eFactor1, EditBoundariesWidgets.ddFactor1.Value) % if factor order matches    
                    this.Data = data; 
                else
                    swappedData = struct();
                    swappedData.CenterPoint = [data.CenterPoint(2), data.CenterPoint(1)];
                    swappedData.AxesLengths = [data.AxesLengths(2), data.AxesLengths(1)];
                    swappedData.Rotation = data.Rotation;
                    this.Data = swappedData;
                end
            else
                getDefaultData(this)
            end

            %UpdatePanel
            updatePanel(this)

            %Connect the panel to the data source
            connectPanel(this)
        end

        function getDefaultData(this)
            xlims = this.AxesLims(1,:);
            ylims = this.AxesLims(2,:);
            x_center = mean(xlims);
            y_center = mean(ylims);
            x_length = (xlims(2)-xlims(1))/2;
            y_length = (ylims(2)-ylims(1))/2;
            data.CenterPoint = [x_center, y_center];
            data.AxesLengths = [x_length, y_length];
            data.Rotation = 0;
            this.Data = data;
        end

        function buildPanel(this,parent,row,col)
            layout = uigridlayout(parent,[6,4]);
            layout.Layout.Row = row;
            layout.Layout.Column = col;
            layout.RowHeight = {10,'fit',5,'fit','fit','1x'};
            layout.ColumnWidth = {'fit','fit','fit','1x'};
            
            lblIneq = uilabel(layout);
            lblIneq.Layout.Row = 2;
            lblIneq.Layout.Column = 1;
            lblIneq.Text = romapp.internal.resources.getString('lblBoundary_Ineq');

            ddIneq = uidropdown(layout);
            ddIneq.Layout.Row = 2;
            ddIneq.Layout.Column = 2;
            ddIneq.Items = {'<=','>='};
            ddIneq.Value = ddIneq.Items{1};

            tbVertices = uitable(layout);
            tbVertices.Layout.Row = 4;
            tbVertices.Layout.Column = [1 2];
            tbVertices.RowName = {romapp.internal.resources.getString('lblBoundary_Center'), romapp.internal.resources.getString('lblBoundary_Axes')};
            tbVertices.ColumnName = {romapp.internal.resources.getString('lblBoundary_Factor1_twolines'), romapp.internal.resources.getString('lblBoundary_Factor2_twolines')};
            tbVertices.ColumnWidth = {'1x','1x'};
            tbVertices.ColumnFormat = {'char','char'};
            rightAlignStyle = uistyle('HorizontalAlignment', 'right');
            addStyle(tbVertices, rightAlignStyle, "column", [1 2]);
            tbVertices.ColumnEditable = [true true];
            tbVertices.Data = cell(2,2);

            lblRotation = uilabel(layout);
            lblRotation.Layout.Row = 5;
            lblRotation.Layout.Column = 1;
            lblRotation.Text = romapp.internal.resources.getString('lblBoundary_Rotation');

            efRotation = uieditfield(layout,'numeric');
            efRotation.Layout.Row = 5;
            efRotation.Layout.Column = 2;
            efRotation.Value = 0;
            
            layoutBtn = uigridlayout(layout,[2,1]);
            layoutBtn.Layout.Row = [2 6];
            layoutBtn.Layout.Column = 3;
            layoutBtn.RowHeight = {'fit','fit'};

            zoomBtn = uibutton(layoutBtn,"push");
            zoomBtn.Layout.Row = 1;
            zoomBtn.Layout.Column = 1;
            zoomBtn.Text = '';
            matlab.ui.control.internal.specifyIconID(zoomBtn, 'zoomReset', 16, 16);
            zoomBtn.Tooltip = romapp.internal.resources.getString('ttipBoundary_Zoom');

            homeBtn = uibutton(layoutBtn,"push");
            homeBtn.Layout.Row = 2;
            homeBtn.Layout.Column = 1;
            homeBtn.Text = "";
            matlab.ui.control.internal.specifyIconID(homeBtn, 'homeUI', 16, 16);
            homeBtn.Tooltip = romapp.internal.resources.getString('ttipBoundary_Fit');

            ax = uiaxes(layout);
            ax.Layout.Row = [2 6];
            ax.Layout.Column = 4;
            ax.Box = 'on';  
            ax.Toolbar.Visible = 'off';
            xlabel(ax,this.EditBoundariesWidgets.ddFactor1.Value)
            ylabel(ax,this.EditBoundariesWidgets.ddFactor2.Value)    
            xlims = this.AxesLims(1,:);
            ylims = this.AxesLims(2,:);
            axis(ax, [xlims ylims]);           
            ax.Interactions = [];
            
            lblInvalid = uilabel(layout);
            lblInvalid.Layout.Row = 6;
            lblInvalid.Layout.Column = [1 2];
            lblInvalid.Text = '';
            lblInvalid.HorizontalAlignment = 'center';
            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblInvalid,'FontColor','--mw-color-error')
            lblInvalid.Text = '';
            lblInvalid.WordWrap = 'on';

            this.Widgets = struct(...
                'layout', layout, ...
                'lblIneq',lblIneq, ...
                'ddIneq',ddIneq, ...
                'tbVertices',tbVertices, ...
                'lblRotation',lblRotation, ...
                'efRotation',efRotation, ...
                'ax',ax, ...
                'layoutBtnZoom',zoomBtn, ...
                'layoutBtnHome',homeBtn, ...
                'lblInvalid',lblInvalid);
        end

        function connectPanel(this)
            weak = romapp.internal.resources.WeakReference(this);
            this.EditBoundariesFigure.WindowButtonDownFcn = [];
            this.EditBoundariesFigure.WindowButtonMotionFcn = [];
            addlistener(this.Widgets.ddIneq,'ValueChanged',@(hSrc,hData) cbIneqChanged(weak.Handle));
            addlistener(this.Widgets.tbVertices,'CellEdit',@(hSrc,event) cbTableEdited(weak.Handle,event));            
            addlistener(this.Widgets.efRotation,'ValueChanged',@(hSrc,hData) cbRotationEdited(weak.Handle));
            this.Widgets.layoutBtnZoom.ButtonPushedFcn = @(src,event) cbZoom(weak.Handle);
            this.Widgets.layoutBtnHome.ButtonPushedFcn = @(src,event) cbHome(weak.Handle); 
        end
        
        function updatePanel(this)
            updatePanelData(this)
            drawEllipse(this)
            updateAxesLims(this)
        end

        function updatePanelData(this)
            this.Widgets.tbVertices.Data{1,1} = this.Data.CenterPoint(1);
            this.Widgets.tbVertices.Data{1,2} = this.Data.CenterPoint(2);
            this.Widgets.tbVertices.Data{2,1} = this.Data.AxesLengths(1);
            this.Widgets.tbVertices.Data{2,2} = this.Data.AxesLengths(2);
            this.Widgets.efRotation.Value = this.Data.Rotation;
        end

        function updateAxesLims(this)
            % find the projection on axes after rotation 
            x_center = this.Data.CenterPoint(1);
            y_center = this.Data.CenterPoint(2);
            a = this.Data.AxesLengths(1);
            b = this.Data.AxesLengths(2);          
            theta = deg2rad(this.Data.Rotation);

            pts = [x_center-a, y_center;
                x_center+a, y_center;
                x_center, y_center-b;
                x_center, y_center+b];
            R = [cos(theta), -sin(theta); sin(theta), cos(theta)];

            pts = (R * pts')';

            for iFactor = 1:2
                if this.isAxisAdjustable(iFactor)
                    lims = [min(pts(:,iFactor)), max(pts(:,iFactor))];
                    this.AxesLims(iFactor,:) = lims;
                end    
            end
            axis(this.Widgets.ax, [this.AxesLims(1,:), this.AxesLims(2,:)]); %update axes limits 
        end

        function drawEllipse(this)
            allPatches = findobj(this.Widgets.ax, 'Type', 'patch');
            delete(allPatches)
            allLines = findobj(this.Widgets.ax, 'Type', 'line');
            delete(allLines)
   
            tbData = this.Widgets.tbVertices.Data;
            x_center = tbData{1,1};
            y_center = tbData{1,2};            
            a = tbData{2,1};
            b = tbData{2,2};
            theta = deg2rad(this.Widgets.efRotation.Value);

            t = linspace(0, 2*pi, 100); % Parameter t for generating points
            x = a * cos(t); % X coordinates before rotation
            y = b * sin(t); % Y coordinates before rotation

            % Rotation matrix
            R = [cos(theta), -sin(theta); sin(theta), cos(theta)];

            % Rotate and translate points
            ellipse_points = R * [x; y];
            x_rotated = ellipse_points(1, :) + x_center;
            y_rotated = ellipse_points(2, :) + y_center;
            
            if strcmp(this.Widgets.ddIneq.Value,'<=')
                bgColor = "--mw-backgroundColor-tertiary";
                pColor = "--mw-graphics-colorOrder-1-tertiary"; 
            else
                bgColor = "--mw-graphics-colorOrder-1-tertiary"; 
                pColor = "--mw-backgroundColor-tertiary";
            end
            p = patch(this.Widgets.ax, 'XData', x_rotated, 'YData', y_rotated); 
            p.EdgeColor = 'none';
            controllib.plot.internal.utils.setColorProperty(p,"FaceColor",bgColor); %set patch to background color to get background color number
            bgColorNum = p.FaceColor;
            this.Widgets.ax.Color = bgColorNum; %properly set background color
            controllib.plot.internal.utils.setColorProperty(p,"FaceColor",pColor); %properly set patch color  
            
            hold(this.Widgets.ax, 'on');
            h = line(this.Widgets.ax,x_rotated,y_rotated);
            controllib.plot.internal.utils.setColorProperty(h,'Color',pColor);
            hold(this.Widgets.ax, 'off');

            updateData(this)           
        end
        
        function updateData(this)
            % data stores center point, axes lengths, rotation
            tbData = this.Widgets.tbVertices.Data;
            this.Data.CenterPoint = [tbData{1,:}]; 
            this.Data.AxesLengths = [tbData{2,:}];
            this.Data.Rotation = this.Widgets.efRotation.Value;
        end

        % check table and edit fields are valid
        function validateTable(this,row,col)           
            % When an imaginary number is entered, then a real number is entered, 
            % the table recognizes it as an imaginary number 
            tbData = this.Widgets.tbVertices.Data;
            for irow = 1:2
                for icol = 1:2
                    if isnumeric(tbData{irow,icol})
                        if imag(tbData{irow,icol}) == 0
                            tbData{irow,icol} = real(tbData{irow,icol});
                        end
                    end
                end
            end
            this.Widgets.tbVertices.Data = tbData;
        
            % Table starts with default values, and revert if an invalid value is
            % entered, and therefore will not be empty/partially empty
            if row==1
                % The edited cell is Signal/Parameter Center point
                center = tbData{1,col};
                centerValid = isnumeric(center) && isreal(center) && isfinite(center);
                if ~centerValid
                    % Revert if an invalid value has been entered
                    this.Widgets.tbVertices.Data{row,col} = this.Data.CenterPoint(col);
                end
            else
                axesLength = tbData{2,col};
                axesLengthValid = isnumeric(axesLength) && isreal(axesLength) && isfinite(axesLength) && (axesLength>0);
                if ~axesLengthValid
                    this.Widgets.tbVertices.Data{row,col} = this.Data.AxesLengths(col);
                end
            end 
        end
        
        function validateRotation(this)    
            % If rotation is not finite/real
            rot = this.Widgets.efRotation.Value;
            rotValid = isnumeric(rot) && isreal(rot) && isfinite(rot);
            if ~rotValid
                this.Widgets.efRotation.Value = this.Data.Rotation;
            end            
        end

        function cbZoom(this)
            if strcmp(this.Mode,"zoom")
                this.Mode = "select";
                zoom(this.Widgets.ax,'off');
                controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnZoom,"BackgroundColor","--mw-backgroundColor-primary")
            else
                this.Mode = "zoom";
                zoom(this.Widgets.ax,'on');
                controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnZoom,"BackgroundColor","--mw-graphics-colorNeutral-line-primary")  
            end
        end

        function cbHome(this)
            %unhighlight zoom button. change mode to "select".
            zoom(this.Widgets.ax,'off');
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnZoom,"BackgroundColor","--mw-backgroundColor-primary")
            this.Mode = "select";
            %fit axes to view
            updateAxesLims(this)
        end

        function cbIneqChanged(this)
            drawEllipse(this)
        end

        function cbTableEdited(this,event)
            row = event.Indices(1);
            col = event.Indices(2);
            validateTable(this,row,col)
            drawEllipse(this)
        end       

        function cbRotationEdited(this)
            validateRotation(this)
            drawEllipse(this)
            updateAxesLims(this)
        end

    end
end