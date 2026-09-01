classdef NoneBoundarySpec < handle
    %

    % NoneBoundarySpec
    % 
    % Empty panel

    % Copyright 2025 The MathWorks, Inc.

    properties(SetAccess=private)
        EditBoundariesFigure
        EditBoundariesWidgets
    end

    methods
        function this = NoneBoundarySpec(EditBoundariesWidgets, parent, row, col)
            %NoneBoundarySpec
            this.EditBoundariesFigure = parent.Parent; %dialog window
            this.EditBoundariesWidgets = EditBoundariesWidgets; %widget on top of dialog

            %Build the panel and update the panel
            buildPanel(this,parent,row,col)

            %Connect the panel to the data source
            connectPanel(this)
        end

        function buildPanel(this,parent,row,col)
            layout = uigridlayout(parent,[1,1]);
            layout.Layout.Row = row; 
            layout.Layout.Column = col;
            updateBtn(this)
        end

        function connectPanel(this)
            set(this.EditBoundariesFigure,'WindowButtonDownFcn',[]);
            set(this.EditBoundariesFigure,'WindowButtonMotionFcn',[]);   
        end 
        
        function updateBtn(this)
            this.EditBoundariesWidgets.pnlOCH.ApplyButton.Enable = 'on';
            this.EditBoundariesWidgets.pnlOCH.OKButton.Enable = 'on';
        end
    
    end
end