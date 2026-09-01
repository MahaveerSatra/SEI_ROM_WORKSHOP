classdef PiecewiselinearBoundarySpec < handle
    %

    % PiecewiselinearBoundarySpec
    % 
    % Panel to display/set piecewise linear boundaries

    % Copyright 2025 The MathWorks, Inc.

    properties(SetAccess=private)
        EditBoundariesFigure
        EditBoundariesWidgets

        Widgets
        
        Mode (1,1) string {mustBeMember(Mode, ["add", "remove", "select", "selected", "zoom"])} = "select"
        Data
        Points
        Vertices       
        isValid

        AxesLims
        isAxisAdjustable
    end

    methods
        function this = PiecewiselinearBoundarySpec(EditBoundariesWidgets, boundaryspec, parent, row, col, ind, lims, isAxisAdjustable)
            % PiecewiselinearBoundarySpec
            this.EditBoundariesFigure = parent.Parent;
            this.EditBoundariesWidgets = EditBoundariesWidgets;
            this.Widgets = struct();
            this.Data = struct();       
            this.AxesLims = lims;
            this.isAxisAdjustable = isAxisAdjustable;

            %Build the panel
            buildPanel(this,parent,row,col)
    
            %Get existing boundary 
            if ~isempty(ind)
                this.Widgets.ddIneq.Value = boundaryspec.Spec.Inequality{ind};
                this.Widgets.chkConnect.Value = boundaryspec.Spec.Connect{ind};                            
                data = boundaryspec.Spec.Data{ind};
                points = data.Points;
                vertices = data.Vertices;
                eFactors = boundaryspec.Spec.Factors{ind};
                eFactor1 = eFactors(1);
                if strcmp(eFactor1, EditBoundariesWidgets.ddFactor1.Value)
                    this.Points = points;
                    this.Vertices = vertices;
                else
                    this.Points = [points(:,2), points(:,1)];
                    this.Vertices = [vertices(:,2), vertices(:,1)];                    
                end 
            else
                getDefaultData(this);
            end

            %Update the data and the panel
            updatePanel(this)

            %Connect the panel to the data source
            connectPanel(this)
        end

        function getDefaultData(this) 
            xlims = this.AxesLims(1,:);
            ylims = this.AxesLims(2,:);
            x1 = 2/3*xlims(1)+1/3*xlims(2);
            x2 = 1/3*xlims(1)+2/3*xlims(2);
            y1 = 2/3*ylims(1)+1/3*ylims(2);
            y2 = 1/3*ylims(1)+2/3*ylims(2);
            this.Points = [x1 y1; x2 y2];
            this.Vertices = [];
        end

        function buildPanel(this,parent,row,col)            
            layout = uigridlayout(parent,[5,4]);
            layout.Layout.Row = row;
            layout.Layout.Column = col;
            layout.RowHeight = {10,'fit','fit','1x','fit'};
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

            chkConnect = uicheckbox(layout);
            chkConnect.Layout.Row = 3;
            chkConnect.Layout.Column = [1 2];
            chkConnect.Value = false;
            chkConnect.Text = romapp.internal.resources.getString('lblBoundary_Connect');

            tbVertices = uitable(layout);
            tbVertices.Layout.Row = [4 5];
            tbVertices.Layout.Column = [1 2];
            tbVertices.ColumnName = {romapp.internal.resources.getString('lblBoundary_Factor1_twolines'), romapp.internal.resources.getString('lblBoundary_Factor2_twolines')};
            tbVertices.ColumnEditable = [true true];
           
            layoutBtn = uigridlayout(layout,[4,1]);
            layoutBtn.Layout.Row = [2 4];
            layoutBtn.Layout.Column = 3;
            layoutBtn.RowHeight = {'fit','fit','fit','fit'};

            addBtn = uibutton(layoutBtn,"push");
            addBtn.Layout.Row = 1;
            addBtn.Layout.Column = 1;
            addBtn.Text = '';
            matlab.ui.control.internal.specifyIconID(addBtn, 'new', 16, 16);
            addBtn.Tooltip = romapp.internal.resources.getString('ttipBoundary_AddPts');
            
            rmBtn = uibutton(layoutBtn,"push");
            rmBtn.Layout.Row = 2;
            rmBtn.Layout.Column = 1;
            rmBtn.Text = '';  
            matlab.ui.control.internal.specifyIconID(rmBtn, 'eraser', 16, 16);
            rmBtn.Tooltip = romapp.internal.resources.getString('ttipBoundary_RmPts');
            
            zoomBtn = uibutton(layoutBtn,"push");
            zoomBtn.Layout.Row = 3;
            zoomBtn.Layout.Column = 1;
            zoomBtn.Text = '';
            matlab.ui.control.internal.specifyIconID(zoomBtn, 'zoomReset', 16, 16);
            zoomBtn.Tooltip = romapp.internal.resources.getString('ttipBoundary_Zoom');

            homeBtn = uibutton(layoutBtn,"push");
            homeBtn.Layout.Row = 4;
            homeBtn.Layout.Column = 1;
            homeBtn.Text = "";
            matlab.ui.control.internal.specifyIconID(homeBtn, 'homeUI', 16, 16);
            homeBtn.Tooltip = romapp.internal.resources.getString('ttipBoundary_Fit');

            ax = uiaxes(layout);
            ax.Layout.Row = [2 4];
            ax.Layout.Column = 4;
            ax.Box = 'on';
            ax.Toolbar.Visible = 'off';
            hold(ax,'on');
            xlabel(ax,this.EditBoundariesWidgets.ddFactor1.Value)
            ylabel(ax,this.EditBoundariesWidgets.ddFactor2.Value)   
            xlims = this.AxesLims(1,:);
            ylims = this.AxesLims(2,:);
            axis(ax, [xlims ylims]);        

            lblIntersect = uilabel(layout);
            lblIntersect.Layout.Row = 5;
            lblIntersect.Layout.Column = 4;
            lblIntersect.Text = '';
            lblIntersect.HorizontalAlignment = 'center';
            matlab.graphics.internal.themes.specifyThemePropertyMappings(lblIntersect,'FontColor','--mw-color-error')

            this.Widgets = struct( ...
                'layout',layout, ...
                'lblIneq',lblIneq, ...
                'ddIneq',ddIneq, ...
                'chkConnect',chkConnect, ...
                'tbVertices',tbVertices, ...
                'ax',ax, ...
                'layoutBtnAdd',addBtn, ...
                'layoutBtnRm',rmBtn, ...           
                'layoutBtnZoom',zoomBtn, ...
                'layoutBtnHome',homeBtn, ...
                'lblIntersect',lblIntersect);
        end
        
        function updateData(this)
            this.Data.Points = this.Points;
            this.Data.Vertices = this.Vertices;
        end
        
        function updatePanel(this)
            updateTable(this);      
            updatePoints(this);        
            updatePatches(this);
            updateBtn(this);
            updateAxesLims(this);
        end

        function connectPanel(this)
            weak = romapp.internal.resources.WeakReference(this);
            set(this.EditBoundariesFigure,'WindowButtonMotionFcn',@(src,event)changeCursor(weak.Handle,event));            
            this.Widgets.layoutBtnAdd.ButtonPushedFcn = @(src,event) cbAddPt(weak.Handle);  
            this.Widgets.layoutBtnRm.ButtonPushedFcn = @(src,event) cbRmPt(weak.Handle);
            this.Widgets.layoutBtnZoom.ButtonPushedFcn = @(src,event) cbZoom(weak.Handle);
            this.Widgets.layoutBtnHome.ButtonPushedFcn = @(src,event) cbHome(weak.Handle); 
            this.Widgets.ax.ButtonDownFcn = @(src,event)addPt(weak.Handle,event);
            addlistener(this.Widgets.ddIneq,'ValueChanged', @(~,~) updatePatchesBtn(weak.Handle));
            addlistener(this.Widgets.chkConnect,'ValueChanged', @(src,event) updatePatchesBtn(weak.Handle));
            addlistener(this.Widgets.tbVertices,'CellEdit',@(src,event)cbTableEdited(weak.Handle,event));
        end

        function cbTableEdited(this,event)
            row = event.Indices(1);
            col = event.Indices(2);
            if (isnumeric(event.NewData) && isreal(event.NewData) && isfinite(event.NewData))
                this.Points(row,col) = event.NewData;
                updatePoints(this)
                updatePatches(this)
                updateBtn(this)
            else
                this.Widgets.tbVertices.Data(row,col) = this.Points(row,col);    
            end  
        end

        function changeCursor(this,event)
            if isa(event.HitObject,'matlab.graphics.chart.primitive.Line')
                if strcmpi(this.Mode,'remove')
                    pointerShape = NaN(16, 16); % Initialize with NaN for transparency
                    pointerShape(7:9,1:16) = 1;
                    set(this.EditBoundariesFigure,'Pointer','custom', 'PointerSHapeCData',pointerShape, 'PointerShapeHotSpot', [8, 8]);
                else
                    set(this.EditBoundariesFigure,'Pointer','hand');
                end
            elseif isa(event.HitObject,'matlab.ui.control.UIAxes')
                if strcmpi(this.Mode,'add')
                    set(this.EditBoundariesFigure,'Pointer','crosshair')
                else 
                    set(this.EditBoundariesFigure,'Pointer','arrow')
                end
            else
                set(this.EditBoundariesFigure,'Pointer','arrow')
            end
        end
                
        function updateTable(this)
            this.Widgets.tbVertices.Data = this.Points;
        end
 
        function isIntersect = chkIntersect(this, pts, extended)
            % initialize to no intersection and no error message 
            isIntersect = false;
            this.Widgets.lblIntersect.Text = '';
            % quit if there are not enough points 
            nPts = size(pts,1);
            if nPts<=0
                return
            end
            % list all connecting lines. each row is the indices of the end points.
            lines = zeros(nPts,2);
            c = 0;
            for i = 1:nPts-1
                c = c+1;
                lines(c,:) = [i,i+1];
            end
            lines(end,:) = [nPts,1];
            % for each pair of lines, check for intersection. 
            nLines = size(lines,1);
            for i = 1:nLines
                for j = i+1:nLines
                    l1 = lines(i,:);
                    l2 = lines(j,:);
                    % only check for pairs of non-neighbouring lines (i.e. do not share a vertex).
                    if isempty(intersect(l1,l2))
                        p1 = l1(1); p2 = l1(2); p3 = l2(1); p4 = l2(2);
                        x1 = pts(p1,1); x2 = pts(p2,1); x3 = pts(p3,1); x4 = pts(p4,1);
                        y1 = pts(p1,2); y2 = pts(p2,2); y3 = pts(p3,2); y4 = pts(p4,2);        
                        % Calculate the direction vectors and the determinant
                        dx1 = x2-x1;
                        dy1 = y2-y1;
                        dx2 = x4-x3;
                        dy2 = y4-y3;
                        det = -dx1*dy2+dy1*dx2;
                        if ~det == 0 % if not parallel
                            t = (-(x3-x1)*(y4-y3)+(x4-x3)*(y3-y1)) / det;
                            u = ((x2-x1)*(y3-y1)-(x3-x1)*(y2-y1)) / det;
                            % Check if the intersection point is on either segments
                            isIntersect = (t >= 0 && t <= 1) && (u >= 0 && u <= 1);   
                            if extended
                                if i==1 && j==nLines-1
                                    isIntersect = t >= 0 && t <= 1;
                                end
                            end
                            if isIntersect
                                return;
                            end
                        end  
                    end
                end
            end
        end
        
        function cbAddPt(this)
            % turn off zoom. unhighlight all other buttons. 
            zoom(this.Widgets.ax,'off');
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnRm,"BackgroundColor","--mw-backgroundColor-primary")
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnZoom,"BackgroundColor","--mw-backgroundColor-primary")
            %if alraedy in add mode. toggle "add" off to "select". un-highlight add button. 
            if strcmpi(this.Mode,"add") 
                this.Mode = "select";           
                controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnAdd,"BackgroundColor","--mw-backgroundColor-primary")
                %if not in add mode. toggle mode to "add". highlight add button.
            else
                this.Mode = "add";
                controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnAdd,"BackgroundColor","--mw-graphics-colorNeutral-line-primary")                
            end 
        end

        function cbRmPt(this)
            zoom(this.Widgets.ax,'off');
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnAdd,"BackgroundColor","--mw-backgroundColor-primary")
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnZoom,"BackgroundColor","--mw-backgroundColor-primary")
            if strcmpi(this.Mode,"remove")
                this.Mode = "select";
                controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnRm,"BackgroundColor","--mw-backgroundColor-primary")
            else
                this.Mode = "remove";
                controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnRm,"BackgroundColor","--mw-graphics-colorNeutral-line-primary")   
            end
        end

        function cbZoom(this)
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnAdd,"BackgroundColor","--mw-backgroundColor-primary")
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnRm,"BackgroundColor","--mw-backgroundColor-primary")
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
            zoom(this.Widgets.ax,'off');
            %unhighlight all other buttons. change mode to "select".
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnAdd,"BackgroundColor","--mw-backgroundColor-primary")
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnRm,"BackgroundColor","--mw-backgroundColor-primary")
            controllib.plot.internal.utils.setColorProperty(this.Widgets.layoutBtnZoom,"BackgroundColor","--mw-backgroundColor-primary")
            this.Mode = "select";
            %fit axes to view
            updateAxesLims(this)
        end

        function addPt(this,event)
            if strcmpi(this.Mode, "add")
                x = event.IntersectionPoint(1);
                y = event.IntersectionPoint(2);
                this.Points = [this.Points; x, y];
                p = plot(this.Widgets.ax, x, y, '.', 'MarkerSize', 16, 'ButtonDownFcn', @(src, event) clickPt(this,src,event));  
                controllib.plot.internal.utils.setColorProperty(p,"MarkerEdgeColor","--mw-graphics-colorOrder-1-primary");
                uistack(p,'bottom')
                updateTable(this);                
                updatePatchesBtn(this)
            end
        end

        function clickPt(this,src,event)
            % find which row is in the tabale
            r = findRow(this.Points, event.IntersectionPoint);
            % remove the point if in remove mode
            % start dragging otherwise
            if strcmpi(this.Mode, "remove")
                delete(src);
                this.Points(r,:) = [];
                updateTable(this);                
                updatePatchesBtn(this)
            elseif strcmpi(this.Mode, "select")
                selectedPoint = src;
                cacheMotionFcn = this.EditBoundariesFigure.WindowButtonMotionFcn;
                this.EditBoundariesFigure.WindowButtonMotionFcn = @(src,event) drag(this,event,selectedPoint,r);
                this.EditBoundariesFigure.WindowButtonUpFcn = @(src,event) endDrag(this,cacheMotionFcn);
            end          
        end

        function drag(this,event,selectedPoint,r)     
            xLim = this.Widgets.ax.XLim;
            yLim = this.Widgets.ax.YLim;
            cp = event.IntersectionPoint(1:2);
            if any(isnan(cp)) 
                return
            end
            cp = [min(max(cp(1,1),xLim(1)), xLim(2)), min(max(cp(1,2),yLim(1)), yLim(2))];
            selectedPoint.XData = cp(1,1);
            selectedPoint.YData = cp(1,2);                
            this.Points(r,:) = cp(1,1:2);
            updateTable(this);
            updatePatchesBtn(this)
        end   

        function endDrag(this, cacheMotionFcn)
            this.EditBoundariesFigure.WindowButtonMotionFcn = cacheMotionFcn;
            this.EditBoundariesFigure.WindowButtonUpFcn = [];               
        end

        function updateAxesLims(this)       
            for iFactor = 1:2
                if this.isAxisAdjustable(iFactor)
                    lims = [ min(this.Points(:,iFactor)), max(this.Points(:,iFactor)) ]; %min and max for specific factor from all points                    
                    lims = [lims(1)-diff(lims), lims(2)+diff(lims)];
                    this.AxesLims(iFactor,:) = lims;
                end    
            end
            axis(this.Widgets.ax, [this.AxesLims(1,:), this.AxesLims(2,:)]); %update axes limits  
        end

        function updateBtn(this)
            this.EditBoundariesWidgets.pnlOCH.ApplyButton.Enable = this.isValid;
            this.EditBoundariesWidgets.pnlOCH.OKButton.Enable = this.isValid;   
        end

        function updatePoints(this)
            delete(findobj(this.Widgets.ax, 'Type', 'line')) 
            nPts = size(this.Points,1);
            if nPts>0
                for iPt = 1:nPts
                    x = this.Points(iPt,1);
                    y = this.Points(iPt,2);
                    p = plot(this.Widgets.ax, x, y, '.', 'MarkerSize', 16, 'ButtonDownFcn', @(src, event) clickPt(this,src,event));  
                    controllib.plot.internal.utils.setColorProperty(p,"MarkerEdgeColor","--mw-graphics-colorOrder-1-primary");
                    uistack(p,'bottom')
                end
            end    
        end

        function updatePatchesBtn(this)
            updatePatches(this)
            updateBtn(this)
        end

        function updatePatches(this)
            % clear patches 
            delete(findobj(this.Widgets.ax, 'Type', 'patch')) 
            % if no enough points
            if isempty(this.Points)
                this.isValid = false;
                this.Widgets.lblIntersect.Text = romapp.internal.resources.getString('errBoundary_Piecewiselinear_NeedPts');
                return
            elseif size(this.Points,1)<2
                this.isValid = false;
                this.Widgets.lblIntersect.Text = romapp.internal.resources.getString('errBoundary_Piecewiselinear_NeedPts');
                return
            end
            % initialize isValid
            this.isValid = true;
            % if given points intersect 
            isIntersect = chkIntersect(this, this.Points, false);
            if isIntersect
                this.Widgets.lblIntersect.Text = romapp.internal.resources.getString('errBoundary_Intersect');  
                this.isValid = false;
            end
            % get limits
            pts = this.Points;
            nPts = size(pts,1);
            xLim = this.Widgets.ax.XLim;
            yLim = this.Widgets.ax.YLim;
            % if more than 3 points (including) 
            if nPts>=3                                 
                if ~this.Widgets.chkConnect.Value
                    % find intersection of line P1P2 and Pn-1Pn
                    x1 = pts(1,1); x2 = pts(2,1); x3 = pts(nPts-1,1); x4 = pts(nPts,1);
                    y1 = pts(1,2); y2 = pts(2,2); y3 = pts(nPts-1,2); y4 = pts(nPts,2);
                    dx1 = x2-x1; dy1 = y2-y1; dx2 = x4-x3; dy2 = y4-y3;
                    det = -dx1*dy2+dy1*dx2;
                    % extend to intersect axes in three conditions
                    % (1) parallel
                    if det == 0
                        intersectAxes =true;
                    else
                        t = (-(x3-x1)*(y4-y3)+(x4-x3)*(y3-y1)) / det;
                        u = ((x2-x1)*(y3-y1)-(x3-x1)*(y2-y1)) / det;
                        xIntersect = (x2-x1)*t+x1;
                        yIntersect = (y2-y1)*t+y1;
                        % (2) intersect in the wrong direction
                        if t>=1 || u<=0
                            intersectAxes = true;
                            % (3) intersection is outside of ranges
                        elseif xIntersect<xLim(1) || xIntersect>xLim(2) || yIntersect<yLim(1) || yIntersect>yLim(2)
                            intersectAxes = true;
                        else
                            % intersect within ranges
                            intersectAxes = false;
                            pi = [xIntersect, yIntersect];
                        end
                    end

                    if ~isIntersect %if lines intersect, draw as if first and last are connected      
                        if intersectAxes %add points for drawing a patch
                            %find intersection with axis for line p1p2 and pn-1pn
                            t = -100;
                            pf = [(x2-x1)*t+x1, (y2-y1)*t+y1];
                            pl = [(x3-x4)*t+x4, (y3-y4)*t+y4];
                            pts = [pf; pts; pl];
                        else      
                            pts = [pts;pi];
                            isIntersectExtended = chkIntersect(this,pts,true);
                            if isIntersectExtended
                                this.isValid = false;     
                                this.Widgets.lblIntersect.Text = romapp.internal.resources.getString('errBoundary_Intersect_Extended');
                            end
                        end  
                    end
                end
            elseif nPts == 2
                if ~this.Widgets.chkConnect.Value
                    x1 = pts(1,1); x2 = pts(2,1); 
                    y1 = pts(1,2); y2 = pts(2,2);
                    t = -100*(xLim(2)-xLim(1))/abs(x2-x1);                   
                    if x1 == x2
                        t = 10;
                        x3 = t*(xLim(2)-xLim(1))*sign(y2-y1)+x1; % step 10 times the range from one point
                        pts = [x1 yLim(1); x3 yLim(1); x3 yLim(2); x1 yLim(2)]; % points define a box
                    elseif y1 == y2
                        t = 10;
                        y3 = t*(yLim(2)-yLim(1))*sign(x2-x1)+y1;
                        pts = [xLim(1) y1; xLim(1) y3; xLim(2) y3; xLim(2) y1];
                    else
                        x3 = mean(xLim);
                        y3 = t*sign(x2-x1)*(yLim(2)-yLim(1))+y1;
                        pm = [x3,y3]; % add a point very high or low in the middle 
                        pf = [(x2-x1)*t+x1, (y2-y1)*t+y1]; % extends to the point 1 direction
                        pl = [(x2-x1)*(-t)+x1, (y2-y1)*(-t)+y1]; % extends to the point 2 direction 
                        pts = [pf; pm; pl];
                    end
                else
                    this.isValid = false;
                    this.Widgets.lblIntersect.Text = romapp.internal.resources.getString('errBoundary_Piecewiselinear_NeedPts');
                    return 
                end
            end

            if strcmp(this.Widgets.ddIneq.Value,'<=')
                bgColor = "--mw-backgroundColor-tertiary";
                pColor = "--mw-graphics-colorOrder-1-tertiary"; 
            else
                bgColor = "--mw-graphics-colorOrder-1-tertiary"; 
                pColor = "--mw-backgroundColor-tertiary";
            end
            p = patch(this.Widgets.ax, 'XData', pts(:,1), 'YData', pts(:,2));
            p.EdgeColor = 'none';
            controllib.plot.internal.utils.setColorProperty(p,"FaceColor",bgColor);
            bgColorNum = p.FaceColor;
            this.Widgets.ax.Color = bgColorNum;
            controllib.plot.internal.utils.setColorProperty(p,"FaceColor",pColor);
            set(p,'HitTest','off');
            uistack(p,'bottom');
            this.Vertices = p.Vertices;
            updateData(this)
        end

    end
end

function r = findRow(pts, pt)
    diff = pts-pt(1:2);
    diff = sqrt(sum(diff.^2,2));
    [~,r] = min(diff);
end