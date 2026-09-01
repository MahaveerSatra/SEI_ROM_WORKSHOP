classdef DataBrowserManager
    %

    % Copyright 2022-2023 The MathWorks, Inc.

    properties
        App
        SystemBrowser
        SimBrowser
    end

    methods
        function this = DataBrowserManager(app)
            this.App = app;
            this.SystemBrowser = romapp.internal.databrowser.TreeDataBrowser('Inputs/Outputs', ...
                romapp.internal.resources.getString('lblIOs'));
            this.SimBrowser = romapp.internal.databrowser.ModelPanel(app);
        end
    end
end

% LocalWords:  lblIOs
