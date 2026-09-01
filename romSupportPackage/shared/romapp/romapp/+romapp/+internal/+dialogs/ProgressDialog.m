classdef ProgressDialog < handle
    %

    %   Copyright 2023 The MathWorks, Inc.

    %ProgressDialog
    %
    %  Basic class to display progress as simulations are running. 
    
    properties(GetAccess = public, SetAccess = protected)
        NumSim
        Count
    end

    properties(Access = protected)
        Dlg
    end

    methods
        function obj = ProgressDialog()
            %ProgressDialog
            %

            obj.NumSim = 0;
            obj.Count = 0;
        end

        function showDlg(this,parent)

            if ~isempty(this.Dlg)
                delete(this.Dlg)
            end
            this.Dlg = uiprogressdlg(parent, ...
                'Title', romapp.internal.resources.getString('lblSimProgressDialog_Title'), ...
                'Message', romapp.internal.resources.getString('msgSimProgressDialog'));
        end

        function setNumSim(this,value)

            this.NumSim = value;
        end
        function increment(this,value)

            this.Count = this.Count + value;
            this.Dlg.Value = max(min(this.Count/this.NumSim,1),0);
        end
        function resetCount(this)
            this.Count = 0;
        end
        function close(this)

            if ~isempty(this.Dlg)
                close(this.Dlg)
            end
            delete(this)
        end

        function dlg = getDialog(this)
            dlg = this.Dlg;
        end
    end
end

% LocalWords:  lbl
