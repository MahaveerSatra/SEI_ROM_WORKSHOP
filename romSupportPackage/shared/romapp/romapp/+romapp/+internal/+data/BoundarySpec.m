classdef BoundarySpec < handle
    %

    % BoundarySpec
    %

    % Copyright 2025 The MathWorks, Inc.

    properties(GetAccess = public, SetAccess = protected)
        % Properties are cell arrays. Each element in the cell array is
        % associated with one boundary. 
        % Factors: each element is the name of the two factors
        % Type: each element is "piecewiselinear" or "elliptical"
        % Inequality: boundary inequality, each element is "<=" or ">="
        % Data: each element is a struct of data
        % Connect: each element is true or false for a piecewise linear
        % boundary, and empty for an elliptical boundary. It indicates
        % whether the first and last points are connected. 
        Method
        Factors     
        Type
        Inequality
        Data
        Connect       
    end

    events
        DataChanged
    end

    methods
        function this = BoundarySpec()        
            this.Method = "resample";
            this.Factors = {};
            this.Type = {};
            this.Inequality = {};
            this.Connect = {};
            this.Data = {};
        end   

        function obj = copy(this)
            obj = romapp.internal.data.BoundarySpec();
            obj.Method = this.Method;
            obj.Factors = this.Factors;
            obj.Type = this.Type;
            obj.Inequality = this.Inequality;
            obj.Data = this.Data;
            obj.Connect = this.Connect;
        end

        function setProps(this, ind, varargin)
            % ind is the index of the boundary to set properties
            if nargin>2
                this.Factors{ind} = varargin{1};
                this.Type{ind} = varargin{2};
                this.Inequality{ind} = varargin{3};
                this.Data{ind} = varargin{4};
                this.Connect{ind} = varargin{5};             
            else
                this.Factors(ind) = [];
                this.Type(ind) = [];
                this.Inequality(ind) = [];
                this.Data(ind) = [];
                this.Connect(ind) = [];
            end
        end

        function typeString = getTypeString(this,i)
            if strcmpi(this.Type{i},"piecewiselinear")
                typeString = romapp.internal.resources.getString('lblBoundary_Piecewiselinear');
            else
                typeString = romapp.internal.resources.getString('lblBoundary_Elliptical');
            end
        end

        function [nonConflicting,conflictingFactor] = validateIntervals(this,nameFactor,SimulationSpec)
            % Loop through all boundaries and extract intervals on the ones
            % that contain the factor in question.
            % Returns logical for whether nameFactor has conflicting
            % boundaries. 
            nonConflicting = true;
            conflictingFactor = [];
            nBoundaries = numel(this.Factors);
            intervals = {[-Inf,Inf]};
            for iBoundary = 1:nBoundaries
                if ismember(nameFactor,this.Factors{iBoundary})
                    interval_new = extractInterval(this,iBoundary,nameFactor,SimulationSpec);
                    intervals = findIntersection(this,intervals,interval_new);
                    if isempty(intervals)
                        nonConflicting = false;
                        conflictingFactor = nameFactor;
                        break
                    end
                end
            end
        end
        
        function updated_intervals = findIntersection(this,intervals,interval_new)
            % For a factor and its existing valid intervals, return the
            % intersection with the interval_new, to update the valid
            % intervals. 
            % Valid intervals is a cell array containing all valid
            % intervals. 
            if isempty(interval_new)
                updated_intervals = {};
                return
            end
            updated_intervals = {};
            for i = 1:numel(intervals)
                old = intervals{i};
                for j = 1:numel(interval_new)
                    single_interval_new = interval_new{j};
                    % Compute intersection
                    if ~isempty(single_interval_new)               
                        left = max(old(1), single_interval_new(1));
                        right = min(old(2), single_interval_new(2));
                        if left <= right
                            updated_intervals{end+1} = [left, right]; 
                        end
                    end
                end
            end
        end

        function interval = extractInterval(this,iBoundary,Factor1,SimulationSpec)
            % Extract the valid intervals of a factor from one boundary
            nType = this.Type{iBoundary};
            nInequality = this.Inequality{iBoundary};
            nData = this.Data{iBoundary};
            nConnect = this.Connect{iBoundary};

            lims1 = getFactorLimits(SimulationSpec,Factor1);
            lb1 = lims1(1);
            ub1 = lims1(2);

            [~,ind] = ismember(Factor1,this.Factors{iBoundary});
            if ind == 1
                Factor2 = this.Factors{iBoundary}(2);
            else
                Factor2 = this.Factors{iBoundary}(1);
            end
            lims2 = getFactorLimits(SimulationSpec,Factor2);
            lb2 = lims2(1);
            ub2 = lims2(2);
            
            switch nType
                case 'piecewiselinear'
                    interval = getPiecewiselinearInterval(this,nInequality,nData,nConnect,...
                        ind,lb1,ub1,lb2,ub2);
                case 'elliptical'
                    switch nInequality
                        case '>='
                            interval = getEllipticalOutsideIntervals(this, ...
                                nData, ind, lb1, ub1, lb2, ub2);
                        case '<='
                            interval = getEllipticalInsideInterval(this, ...
                                nData,ind,lb1,ub1,lb2,ub2);
                    end
                case 'none'
                    interval = [lb1,ub1];
            end
            if ~iscell(interval)
                interval = {interval};
            end         
        end

        function addBoundary(this,factors,type,inequality,data,connect)
            this.Factors = [this.Factors,{factors}];
            this.Type = [this.Type,{type}];
            this.Inequality = [this.Inequality,{inequality}];
            this.Data = [this.Data,{data}];
            this.Connect = [this.Connect,{connect}];
            notify(this,'DataChanged')
        end

        function removeBoundary(this,ind)
            
            nBoundaries = numel(this.Factors);
            removeAction = ~isempty(ind) && ismember(ind,1:nBoundaries);

            if removeAction
                this.Factors(ind) = [];
                this.Type(ind) = [];
                this.Inequality(ind) = [];
                this.Data(ind) = [];
                this.Connect(ind) = [];
                notify(this,'DataChanged')
            end
        end

        function [factors,type,inequality,data,connect] = getProps(this,ind)
            factors = this.Factors{ind};
            type = this.Type{ind};
            inequality = this.Inequality{ind};
            data = this.Data{ind};
            connect = this.Connect{ind};
        end

        function replaceBoundaries(this,boundaries)
            this.Method = boundaries.Method;
            this.Factors = boundaries.Factors;
            this.Type = boundaries.Type;
            this.Inequality = boundaries.Inequality;
            this.Data = boundaries.Data;
            this.Connect = boundaries.Connect;
            notify(this,'DataChanged')
        end

        function tf = hasBoundaries(this)
            tf = ~isempty(this.Factors);
        end

        function [SignalBoundaries, ParameterBoundaries, MixedBoundaries] = ...
            separateBoundaries(this, SignalNames, ParameterNames)
            %This function seperates BoundarySpec into boundary specs that 
            %involve only signals, only parameters, and a mix of signals 
            % and parameters. 
            
            nBoudaries = numel(this.Factors);
            SignalBoundaries = romapp.internal.data.BoundarySpec();
            ParameterBoundaries = romapp.internal.data.BoundarySpec();
            MixedBoundaries = romapp.internal.data.BoundarySpec();

            for i = 1:nBoudaries
                [factors,type,inequality,data,connect] = getProps(this,i);
                sigInd1 = find(strcmp(SignalNames,factors(1)));
                sigInd2 = find(strcmp(SignalNames,factors(2)));
                paramInd1 = find(strcmp(ParameterNames,factors(1)));
                paramInd2 = find(strcmp(ParameterNames,factors(2)));

                if numel([sigInd1, sigInd2]) == 2
                    addBoundary(SignalBoundaries,factors,type,inequality,data,connect)
                elseif numel([paramInd1 paramInd2]) == 2
                    addBoundary(ParameterBoundaries,factors,type,inequality,data,connect)
                else
                    addBoundary(MixedBoundaries,factors,type,inequality,data,connect)
                end
            end
            setMethod(SignalBoundaries, getMethod(this));
            setMethod(ParameterBoundaries, getMethod(this));
            setMethod(MixedBoundaries, getMethod(this));
        end

        function method = getMethod(this)
            method = this.Method;
        end

        function setMethod(this,method)
            if strcmpi(method,'resample') || strcmpi(method,'project')
                this.Method = method;
            elseif isempty(method)
                this.Method = "resample";
            else
                error('Invalid sampling method')
            end
        end
    end

    methods
        function interval = getPiecewiselinearInterval(this,nInequality,nData,nConnect,...
                ind,lb1,ub1,lb2,ub2)
            % For One piecewise linear boundary, get the feasible interval
            % where the factor in question can take on at least one value. 
            % 
            % nInequality, nData, nConnect comes from the boundary. 
            % 
            % lb1, ub1, lb2, ub2 are the bounds of the first and second
            % factor. 
            % 
            % ind indicates whether the factor in question is the first or
            % the second factor. 
            if nConnect && strcmpi(nInequality,'<=')
                factorLims = nData.Points(:,ind);
                interval = [min(factorLims), max(factorLims)];
            elseif nConnect && strcmpi(nInequality,'>=')
                lbs = [lb1,lb2];
                ubs = [ub1,ub2];
                interval = [lbs(ind),ubs(ind)];
            else
                if ind == 1
                    x_lower = lb1;
                    x_upper = ub1;
                    y_lower = lb2;
                    y_upper = ub2;
                else
                    x_lower = lb2;
                    x_upper = ub2;
                    y_lower = lb1;
                    y_upper = ub1;
                end

                % find intersection points p2 -> p1
                x1 = nData.Points(1,1);
                x2 = nData.Points(2,1);
                y1 = nData.Points(1,2);
                y2 = nData.Points(2,2);
                % intersection with x lower bound
                t1 = (x_lower - x1)/(x2-x1);
                % intersection with x upper bound
                t2 = (x_upper - x1)/(x2-x1);
                % intersection with y lower bound
                t3 = (y_lower-y1)/(y2-y1);
                % intersection with y upper bound
                t4 = (y_upper-y1)/(y2-y1);
                % first intersection is largest t<0
                tm = [t1 t2 t3 t4];
                tm = tm(tm<=0);
                if isempty(tm)
                    t = 0;
                else
                    t = max(tm);
                end
                xi1 = (x2-x1)*t+x1;
                yi1 = (y2-y1)*t+y1;

                % find intersection points plast-1 -> plast
                x3 = nData.Points(end-1,1);
                x4 = nData.Points(end,1);
                y3 = nData.Points(end-1,2);
                y4 = nData.Points(end,2);
                % intersection with x lower bound, x upper bound, y
                % lower bound, y upper bound
                t1 = (x_lower - x3)/(x4-x3);
                t2 = (x_upper - x3)/(x4-x3);
                t3 = (y_lower - y3)/(y4-y3);
                t4 = (y_upper - y3)/(y4-y3);
                % first intersection is smallest t>1
                tm = [t1 t2 t3 t4];
                tm = tm(tm>=1);
                if isempty(tm)
                    t = 1;
                else
                    t = min(tm);
                end
                xi2 = (x4-x3)*t+x3;
                yi2 = (y4-y3)*t+y3;

                % find intervals from all visible vertices
                pts = [nData.Points;
                    xi1, yi1;
                    xi2, yi2];
                px = pts(:,1);
                py = pts(:,2);
                if ind == 1                    
                    interval = [min(px),max(px)];
                else
                    interval = [min(py),max(py)];
                end
                % For cases where an axis is in boundary with no intersection, 
                % add an extra step to check whether an axis is in-boundary. 
                % If looking for intervals on the x-axis, if left axis is
                % within the boundary (bottom-left and top-left), expand
                % interval lower limit. Similarly for the upper limit. 
                p_bottom_left  = [x_lower, y_lower];
                p_upper_left   = [x_lower, y_upper];
                p_bottom_right = [x_upper, y_lower];
                p_upper_right  = [x_upper, y_upper];
                inBoundary_bottom_left  = inpolygon(p_bottom_left(1), p_bottom_right(2), nData.Vertices(:,1), nData.Vertices(:,2));
                inBoundary_upper_left   = inpolygon(p_upper_left(1), p_upper_left(2), nData.Vertices(:,1), nData.Vertices(:,2));
                inBoundary_bottom_right = inpolygon(p_bottom_right(1), p_bottom_right(2), nData.Vertices(:,1), nData.Vertices(:,2));
                inBoundary_upper_right  = inpolygon(p_upper_right(1), p_upper_right(2), nData.Vertices(:,1), nData.Vertices(:,2));
                if strcmpi(nInequality,'>=')
                    inBoundary_bottom_left = ~inBoundary_bottom_left;
                    inBoundary_upper_left   = ~inBoundary_upper_left;
                    inBoundary_bottom_right = ~inBoundary_bottom_right;
                    inBoundary_upper_right  = ~inBoundary_upper_right;
                end
                if ind == 1
                    if inBoundary_bottom_left && inBoundary_upper_left
                        interval(1) =  x_lower;
                    end
                    if inBoundary_bottom_right && inBoundary_upper_right
                        interval(2) = x_upper;
                    end
                else
                    if inBoundary_bottom_left && inBoundary_bottom_right
                        interval(1) =  y_lower;
                    end
                    if inBoundary_upper_left && inBoundary_upper_right
                        interval(2) = y_upper;
                    end
                end
            end           
        end

        function interval = getEllipticalInsideInterval(this,nData,...
                ind,lb1,ub1,lb2,ub2)
            % Find feasible intervals for an elliptical boundary that is
            % valid <= than the elliptical region
            % 
            % For One elliptical boundary, get the feasible interval
            % where the factor in question can take on at least one value. 
            % 
            % nInequality, nData, comes from the boundary. 
            % 
            % lb1, ub1, lb2, ub2 are the bounds of the first and second
            % factor. 
            % 
            % ind indictes whether the factor in question (Factor1) is the 
            % first or the second factor in the boundary. 
            [x0,y0,a,b,theta] = getElliptcialParameters(nData);
            candidates = [];

            % ind is for the factor in question. 
            % ind=1 means it is the first factor, and plotted on x-axis
            % ind=2 means it is the second factor, and plotted on y-axis
            %
            % x0, y0, a, b, and theta are defined based on axes.
            %
            % To use the symmetry to reuse code, if ind=2, swap the two factors, so
            % x-axis is always the factor in question. 
            [lbx,ubx,lby,uby,x0,y0,a,b,theta] = swapAxes(ind,lb1,ub1,lb2,ub2,x0,y0,a,b,theta);

            % intersections with vertical edges/factor limits
            for x_edge = [lbx,ubx]
                y_roots = ellipse_y_given_x(x_edge, x0, y0, a, b, theta);
                for i = 1:length(y_roots)
                    y = y_roots(i);
                    if y>=lby && y<=uby
                        candidates(end+1) = x_edge;
                    end
                end
            end

            % intersections with horizontal edges/factor limits
            for y_edge = [lby,uby]
                x_roots = ellipse_x_given_y(y_edge, x0, y0, a, b, theta);
                for i = 1:length(x_roots)
                    x = x_roots(i);
                    if x>=lbx && x<=ubx
                        candidates(end+1) = x;
                    end
                end
            end

            % ellipse x-extrema
            for sign = [-1, 1]
                t_ext = atan2(-b*sin(theta), a*cos(theta)) + (sign==1)*pi;
                x_ext = x0 + a*cos(t_ext)*cos(theta) - b*sin(t_ext)*sin(theta);
                y_ext = y0 + a*cos(t_ext)*sin(theta) + b*sin(t_ext)*cos(theta);
                if y_ext>=lby && y_ext<=uby && x_ext>=lbx && x_ext<=ubx
                    candidates(end+1) = x_ext;
                end
            end

            % box corners
            corners = [lbx,lby;
                lbx,uby;
                ubx,lby; 
                ubx,uby];
            for k = 1:4
                x_c = corners(k,1); y_c = corners(k,2);
                if point_in_ellipse(x_c, y_c, x0, y0, a, b, theta)
                    candidates(end+1) = x_c;
                end
            end

            if isempty(candidates)
                interval = [];
            else
                interval = [min(candidates),max(candidates)];
            end
        end  

        function intervals = getEllipticalOutsideIntervals(this, nData, ...
                ind, lb1, ub1, lb2, ub2)
            % Find feasible intervals for an elliptical boundary that is
            % valid >= than the elliptical region 
            %
            % returns a cell array of feasible intervals
            % each element is an interval (two-element vector)
            % borrowed method from a classical projection method of segmenting into
            % smaller intervals. for each x interval, if the corresponding ymin and
            % ymax are not both inside the ellipse, then this is a feasible
            % interval. similarly for y intervals.
            % 
            % x0, y0, a, b, theta are the ellipse' center, axes lengths,
            % and rotation angle
            % 
            % lb1, ub1, lb2, ub2 are the bounds of the first and second factor. 
            % 
            % ind indictes whether the factor in question is the first or
            % the second factor. 

            [x0,y0,a,b,theta] = getElliptcialParameters(nData);
            [lbx,ubx,lby,uby,x0,y0,a,b,theta] = swapAxes(ind,lb1,ub1,lb2,ub2,x0,y0,a,b,theta);
   
            N = 1001;
            [xminE, xmaxE, yminE, ymaxE] = ellipse_extrema(x0, y0, a, b, theta);

            if isinf(lby) || isinf(uby)
                intervals = [-Inf, Inf];
                return
            end

            % Determine x sampling range
            if isinf(lbx) && isinf(ubx)
                xlow = xminE - 1e-8; % slightly expand to catch edges
                xhigh = xmaxE + 1e-8;
            elseif isinf(lbx)
                xlow = xminE - 1e-8;
                xhigh = ubx;
            elseif isinf(ubx)
                xlow = lbx;
                xhigh = xmaxE + 1e-8;
            else
                xlow = lbx;
                xhigh = ubx;
            end

            xs = linspace(xlow, xhigh, N);
            is_covered = false(1, N);

            for i = 1:N
                x = xs(i);
                y1 = lby;
                y2 = uby;
                [xe1, ye1] = rotate_point(x, y1, x0, y0, -theta);
                [xe2, ye2] = rotate_point(x, y2, x0, y0, -theta);
                in1 = (xe1/a)^2 + (ye1/b)^2 <= 1;
                in2 = (xe2/a)^2 + (ye2/b)^2 <= 1;
                is_covered(i) = in1 && in2;
            end

            % Find covered intervals
            intervals = combineEllipticalOutsideIntervals(xs, ~is_covered, ...
                xlow, xhigh);

            if isinf(lbx)
                intervals{1}(1) = -Inf;
            end

            if isinf(ubx)
                intervals{end}(2) = Inf;
            end
        end
    end
end

% helper functions
function y_roots = ellipse_y_given_x(x, x0, y0, a, b, theta)
    % helper: solve for y given x on the ellipse
    cosT = cos(theta); sinT = sin(theta);
    A = (sinT/a)^2 + (cosT/b)^2;
    B = 2*(x-x0)*cosT*sinT*(1/a^2 - 1/b^2);
    C = (x-x0)^2*( (cosT/a)^2 + (sinT/b)^2 )-1;
    y_roots = roots([A, B, C])+y0;
    y_roots = y_roots(imag(y_roots)==0); % Only real roots
end

function x_roots = ellipse_x_given_y(y, x0, y0, a, b, theta)
    % helper: solve for x given y on the ellipse ---
    cosT = cos(theta); sinT = sin(theta);
    A = (cosT/a)^2 + (sinT/b)^2;
    B = 2*(y-y0)*cosT*sinT*  (1/a^2 - 1/b^2);
    C = (y-y0)^2*( (sinT/a)^2 + (cosT/b)^2 )-1;
    x_roots = roots([A, B, C])+x0;
    x_roots = x_roots(imag(x_roots)==0); % Only real roots
end

function inside = point_in_ellipse(x, y, x0, y0, a, b, theta)
    % helper: whether point in ellipse
    xp = (x-x0)*cos(theta) + (y-y0)*sin(theta);
    yp = -(x-x0)*sin(theta) + (y-y0)*cos(theta);
    inside = (xp/a)^2 + (yp/b)^2 <= 1;
end

function intervals = combineEllipticalOutsideIntervals(xs, feasible, xlow, xhigh)
    % helper function: compute uncovered intervals from is_covered array
    intervals = {};
    
    if all(~feasible)  
        return
    end
    
    if all(feasible)
        intervals{end+1} = [xlow,xhigh];
        return
    end
    
    N = length(xs);
    i_interval = 1;
    while i_interval<=N
        if feasible(i_interval)
            for j_interval = (i_interval+1):N
                if ~feasible(j_interval)
                    break                    
                end                
            end
            intervals{end+1} = [xs(i_interval),xs(j_interval)];
            i_interval = j_interval+1;
        else
            i_interval = i_interval+1;
        end
    end
    intervals(cellfun(@isempty, intervals)) = [];
end

function [xr, yr] = rotate_point(x, y, x0, y0, theta)
    % helper function: rotate a point (x,y) about (x0,y0) by angle theta
    dx = x - x0;
    dy = y - y0;
    xr = dx * cos(theta) - dy * sin(theta);
    yr = dx * sin(theta) + dy * cos(theta);
end

function [xmin_ellipse, xmax_ellipse, ymin_ellipse, ymax_ellipse] = ellipse_extrema(x0, y0, a, b, theta)
    % helper function: find extrema
    % find x extrema, where dx/dt = 0
    t1 = atan2(-b*sin(theta), a*cos(theta));
    t2 = t1 + pi;
    x1 = x0 + a*cos(t1)*cos(theta) - b*sin(t1)*sin(theta);
    x2 = x0 + a*cos(t2)*cos(theta) - b*sin(t2)*sin(theta);
    xmin_ellipse = min(x1, x2);
    xmax_ellipse = max(x1, x2);
    % find y extrema, where dy/dt = 0
    t1 = atan2(b*cos(theta), a*sin(theta));
    t2 = t1 + pi;
    y1 = y0 + a*cos(t1)*sin(theta) + b*sin(t1)*cos(theta);
    y2 = y0 + a*cos(t2)*sin(theta) + b*sin(t2)*cos(theta);
    ymin_ellipse = min(y1, y2);
    ymax_ellipse = max(y1, y2);
end

function [x0,y0,a,b,theta] = getElliptcialParameters(nData)
    x0 = nData.CenterPoint(1);
    y0 = nData.CenterPoint(2);
    a = nData.AxesLengths(1);
    b = nData.AxesLengths(2);
    theta = deg2rad(nData.Rotation);
end

function [lbx,ubx,lby,uby,x0,y0,a,b,theta] = swapAxes(ind,lb1,ub1,lb2,ub2,x0,y0,a,b,theta)
    lbx = lb1;
    ubx = ub1;
    lby = lb2;
    uby = ub2;
    if ind==2
        [a,b] = deal(b,a);
        [x0,y0] = deal(y0,x0);
        theta = -theta;
    end
end