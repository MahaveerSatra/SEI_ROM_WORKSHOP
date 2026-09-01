classdef ModelPorts < romapp.internal.databrowser.TreeDataBrowser
    %ModelPorts Tree data browser for model ports
    %
    
    % Copyright 2022-2025 The MathWorks, Inc.

    % Properties
    properties (SetAccess = private)
        AppData
        nodeInputs
        nodeOutputs
        nodeParameters
        nodeExperiments
        nodeLoggedOutputs
        nodeTransformFcn
    end

    methods
        function this = ModelPorts(app)
            %ModelPorts
            %

            title = romapp.internal.resources.getString('lblInputsOutputs');
            name = 'PortBrowser';
            this = this@romapp.internal.databrowser.TreeDataBrowser(name,title);
            this.AppData = getAppData(app);

            %Add default, tree-wide, callbacks
            addCallbacks(this,app)

            % Create tree nodes
            buildTree(this)
            
            % Initialize the tree
            refreshTree(this)

            %Add listener to App ModelPorts property so that can refresh the
            %tree
            weak = romapp.internal.resources.WeakReference(this);
            addlistener(this.AppData.ModelPorts,'DataChanged', @(hSrc,hData) refreshTree(weak.Handle));
        end

        function delete(this) %#ok<INUSD>
            % Release data browser resources.

        end
    end

    methods(Access = private)

        function buildTree(this)
            %buildTree
            %

            %Add default nodes for the tree
            this.nodeInputs = uitreenode(this.Tree,'Tag', 'ndInputs', 'Text', string(romapp.internal.data.PortType.ROMInput));
            this.nodeOutputs = uitreenode(this.Tree,'Tag', 'ndOutputs', 'Text', string(romapp.internal.data.PortType.ROMOutput));
            this.nodeParameters = uitreenode(this.Tree,'Tag','ndParameters', 'Text', string(romapp.internal.data.PortType.ROMParameter));
            this.nodeExperiments = uitreenode(this.Tree,'Tag','ndExperiment', 'Text', string(romapp.internal.data.PortType.SimulationInput));
            this.nodeLoggedOutputs = uitreenode(this.Tree,'Tag','ndLoggedOutputs', 'Text', string(romapp.internal.data.PortType.LoggedOutput));
            this.nodeTransformFcn = uitreenode(this.Tree,'Tag','ndTransformFcn', 'Text', ...
                romapp.internal.resources.getString('lblTransformOutputSignal_Function'));
        end

        function refreshTree(this)
            %refreshTree
            %

            data = this.AppData.ModelPorts;
            opts = this.AppData.SimulationOptions;

            %Clear sub-nodes and recreate
            lbls = romapp.internal.data.ModelPorts.getFullName(data.InputSignals);
            lAddNodes(this.Tree, this.nodeInputs,lbls);
            lbls = romapp.internal.data.ModelPorts.getFullName(data.InputParameters);
            lAddNodes(this.Tree, this.nodeParameters,lbls)
            if opts.UsePostSimFcn
                fstr = string(func2str(opts.PostSimFcn));
                builtin_FinalValue = isequal(fstr,"romapp.internal.data.PostSimFcn.FinalValue_Internal");
                lbls = romapp.internal.data.ModelPorts.getDisplayName(data.OutputSignals);
                if builtin_FinalValue
                    lbls = lbls + " (" + romapp.internal.resources.getString('lblTransformOutputSignal_FinalValue') + ")";
                end
            else
                lbls = romapp.internal.data.ModelPorts.getFullName(data.OutputSignals);
            end
            lAddNodes(this.Tree, this.nodeOutputs,lbls);
            lbls = vertcat(...
                romapp.internal.data.ModelPorts.getFullName(data.ExperimentInputSignals), ...
                romapp.internal.data.ModelPorts.getFullName(data.ExperimentInputParameters));
            lAddNodes(this.Tree, this.nodeExperiments,lbls)
            if opts.UsePostSimFcn
                lbls = romapp.internal.data.ModelPorts.getFullName(data.LoggedOutputs);
                lAddNodes(this.Tree, this.nodeLoggedOutputs,lbls);
                if builtin_FinalValue
                    lbls = string(romapp.internal.resources.getString('lblTransformOutputSignal_FinalValue'));
                else
                    lbls = fstr;
                end
                lAddNodes(this.Tree, this.nodeTransformFcn,lbls);
            else
                lAddNodes(this.Tree, this.nodeLoggedOutputs,[])
                lAddNodes(this.Tree, this.nodeTransformFcn,[])
            end
                        
            %Expand all the nodes
            expand(this.Tree)
        end

        function addCallbacks(this,app)
            %addCallbacks
            %

            %Add callback for double click
            addlistener(this.Tree,'DoubleClicked',@(hSrc,hData) cbOpenIOSelector(this,hData,app));

            %Add context menu for the tree
            contextMenu = uicontextmenu('Parent', this.Figure);
            this.Tree.ContextMenu = contextMenu;

            % Add edit menu item
            editMenuItem = uimenu(contextMenu, ...
                'Text',romapp.internal.resources.getString('lblEditWithEllipses'), ...
                'Tag','EditItem', ...
                'Visible','on');
            editMenuItem.MenuSelectedFcn = @(hSrc,hData) showSelectIOs(app,'initialize');
        end

        function cbOpenIOSelector(~,hData,app)
            %cbOpenIOSelector
            %

            %Open the I/O Selector if the white space is clicked (i.e., not on a node)
            %there is no node selected or the selected node is a leaf node.
            %Double clicking a parent node collapses/expands the node and
            %don't want to open the selector in that case
            hSrc = hData.Source;
            if isempty(hData.InteractionInformation.Node) ...
                    || isempty(hSrc.SelectedNodes) ...
                    || isempty(hSrc.SelectedNodes.Children)
                data = getAppData(app);
                if data.HaveSimulinkModel
                    showSelectIOs(app,'initialize')
                else
                    showImportDataDialog(app,Mode='new')
                end
            end
        end
    end
end

function  lAddNodes(rNode,pNode,lbls)

if isempty(lbls)
    %No node children, remove the node
    pNode.Parent = [];
else
    %Refresh the node children and make sure node is parented to the tree
    nC = numel(pNode.Children);
    if nC > 0
        for ct=nC:-1:1
            delete(pNode.Children(ct))
        end
    end
    for ct=1:numel(lbls)
        uitreenode(pNode,'Text', lbls(ct));
    end

    %Parent the node
    pNode.Parent = rNode;
end
end

% LocalWords:  TREEDATABROWSER BUILDTREE lbl IOs cbOpenIOSelector
