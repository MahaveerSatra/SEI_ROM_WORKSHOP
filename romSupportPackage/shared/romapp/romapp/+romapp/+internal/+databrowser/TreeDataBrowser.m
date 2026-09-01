classdef TreeDataBrowser < matlab.ui.internal.databrowser.AbstractDataBrowser
    %TREEDATABROWSER Tree data browser
    %
    %  
    
    % Copyright 2022 The MathWorks, Inc.

    % Properties
    properties (SetAccess = private)
        Tree
    end

    properties(Dependent)
        SingleRowSelection(1,1) logical
    end

    events (NotifyAccess = protected, ListenAccess = public)
        NodeSelectionChanged
        NodeExpanded
        NodeCollapsed
    end
    
    methods
        function this = TreeDataBrowser(name,title)
            %TREEDATABROWSER
            %

            this = this@matlab.ui.internal.databrowser.AbstractDataBrowser(name,title);
            
            % Create uitree.
            buildTree(this)
            
            % Add callbacks to uitree.
            connectTree(this);            
        end
        
        function delete(this) %#ok<INUSD> 
            % Release data browser resources.

        end        
    end

    methods
        function val = get.SingleRowSelection(this)
            val = strcmp(this.Tree.Multiselect,'off');
        end

        function set.SingleRowSelection(this, val)
            if val
                this.Tree.Multiselect = 'off';
            else
                this.Tree.Multiselect = 'on';
            end
        end

    end

    methods
        function addNode(this,node)
            node.Parent = this.Tree;
        end
    end

    methods (Access = protected)
        
        function nodeSelectionChanged(this,selectedNodes) %#ok<INUSD> 
            
        end

        function nodeExpanded(this, expandedNode) %#ok<INUSD> 
            
        end

        function nodeCollapsed(this,collapsedNode) %#ok<INUSD> 
            
        end

    end

    methods(Access = private)

        function buildTree(this)
            %BUILDTREE
            
            % Use 1x1 uigridlayout for auto-resizing.
            g = uigridlayout(this.Figure);
            g.ColumnWidth = {'1x'};
            g.RowHeight = {'1x'};
            g.Padding = 0;
            
            % Tree
            tree = uitree(g);
            tree.Tag = strcat('dbtable_',this.Name);
            tree.Multiselect = 'off';    % default to single row selection

            % Save the handle.
            this.Tree = tree;
        end

        function connectTree(this)
            %CONNECTTREE
            
            % Node selection changed
            this.Tree.SelectionChangedFcn = @(src,data) cbSelectionChanged(this,src,data);
            
            % Node expanded
            this.Tree.NodeExpandedFcn = @(src,data) cbNodeExpanded(this,src,data);
            
            % Node collapsed
            this.Tree.NodeCollapsedFcn = @(src,data) cbNodeCollapsed(this,src,data);
        end

        function cbSelectionChanged(this,src,data) %#ok<INUSL> 
            %CBSELECTIONCHANGED
            
            % Fire callback.
            nodeSelectionChanged(this,data.SelectedNodes)
            
            % Fire event.
            %customEventData = matlab.ui.internal.databrowser.GenericEventData(data);
            notify(this,'NodeSelectionChanged',data)
        end

        function cbNodeExpanded(this,src,data) %#ok<INUSL> 
            %CBNODEEXPANDED
            
            % Fire callback.
            nodeExpanded(this,data.Node)
            
            % Fire event.
            notify(this,'NodeExpanded',data)
        end
        
        function cbNodeCollapsed(this,src,data) %#ok<INUSL> 
            %CBNODECOLLAPSED
            
            % Fire callback.
            nodeCollapsed(this,data.Node)
            
            % Fire event.
            notify(this,'NodeCollapsed',data)
        end
        
    end
end