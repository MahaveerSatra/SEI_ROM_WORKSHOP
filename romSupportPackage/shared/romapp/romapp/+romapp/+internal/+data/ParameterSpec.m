classdef ParameterSpec < handle
    %

    % ParameterSpec
    %

    % Copyright 2023-2025 The MathWorks, Inc.

    properties(GetAccess = public, SetAccess = protected)
        Parameters romapp.internal.data.ModelParameter = romapp.internal.data.ModelParameter.empty
    end

    properties(Access = protected)
        Space
    end

    events(NotifyAccess = protected)
        DataChanged
    end

    methods
        function obj = ParameterSpec(params)
            
            obj.Parameters = params;
        end

        function [dspace,pVec] = createDesignSpace(this,baseSpace,values)
            %createDesignSpace
            %
            % [dspace,param] = createDesignSpace(this,baseSpace,values)
            %
            % dspace - Design space with n, entries. Each entry
            %          contains multiple parameters
            %
            % param - array of parameter definitions

            nParam = numel(this.Parameters);
            for ct=nParam:-1:1
                [pVec(ct), slPParam{ct}, pSpec{ct}] = this.createDesignParameter(this.Parameters(ct),values(:,ct));
            end

            %Exhaustively combine the parameter space with the base space
            pSpace = multisim.design.internal.Sequential([pSpec{:}]);
            dspace = multisim.design.internal.Exhaustive([pSpace,baseSpace]);
        end
        function [msParam,pVec] = getMultisimDesignVariables(this)
            %getMultisimDesignVariables
            %
            % [msParam,pVec] = getMultisimDesignVariables(this)
            %
            % slParam - a cell array of multisim.design.internal.Variable/BlockParameter
            % pVec - a vector of romapp.internal.data.ParameterData

            nParam = numel(this.Parameters);
            msParam = cell(nParam,1);
            for ct=nParam:-1:1
                [pVec(ct), msParam{ct}] = this.createDesignParameter(this.Parameters(ct));
            end
        end
    end

    methods(Static = true, Access = protected)
        function [pData, msParam, msValueSet] = createDesignParameter(ParamSpec,values)
            %createDesignParameter
            %
            %  Use a parameter spec and set of parameter values to create a
            %  multisim parameter and a multisim value set for that
            %  parameter. Also create a romapp parameter data to later
            %  store the parameter values.
            %
            % [pData, msParam, msValueSet] = createDesignParameter(ParamSpec,values)
            %
            % Inputs
            %   ParamSpec - a romapp.internal.data.ModelParameter
            %   values - vector of parameter values
            %
            % Outputs
            %   pData - a romapp.internal.data.ParameterData
            %   msParam - a multisim.design.internal.Variable/BlockParameter
            %   mValueSet - a multisim.design.internal.ValueSetParameter
            %

            createValueSet = nargout > 2;

            pData = romapp.internal.data.ParameterData;
            pData.Name = ParamSpec.Name;
            isBlockParam = isempty(ParamSpec.Workspace);
            if isBlockParam
                %Block dialog parameter
                pData.BlockPath = ParamSpec.BlockPath;

                bp = convertToCell(pData.BlockPath);
                bp = bp{1}; %How handle model reference
                msParam = multisim.design.internal.BlockParameter(bp,pData.Name);
                if createValueSet
                    vals= arrayfun(@(x) mat2str(x),values(:),'UniformOutput',false);
                    msValueSet = multisim.design.internal.ValueSetParameter(msParam,vals);
                end
            else
                %Workspace variable
                mdl = bdroot(convertToCell(ParamSpec.BlockPath));
                pData.BlockPath = mdl{1};
                if strcmp(ParamSpec.Workspace,"base")
                    wksp = "global-workspace";
                elseif strcmp(ParamSpec.Workspace,"model")
                    wksp = mdl;
                elseif contains(ParamSpec.Workspace,".sldd")
                    wksp = "global-workspace";
                else
                    romapp.internal.resources.error('errUnexpected',"Unsupported variable source location: " + ParamSpec.Name + ...
                       " - " + ParamSpec.Workspace);
                end
                msParam = multisim.design.internal.Variable(pData.Name,wksp);
                if createValueSet
                    msValueSet = multisim.design.internal.ValueSetParameter(msParam,values(:));
                end
            end
        end
    end

    methods(Hidden = true)
        function qeFireDataChanged(this)
            notify(this,'DataChanged')
        end
        function changeModelName(this,newname,oldname)
            %changeModelName
            %
            %   Utility to change the root level model name the session
            %   data refers to. Useful when renaming a Simulink model.
            %

            for ct=1:numel(this.Parameters)
                bp = this.Parameters(ct).BlockPath;
                bp = regexprep(convertToCell(bp),"^"+oldname,newname);
                this.Parameters(ct).BlockPath = bp;
            end
        end
    end

    methods(Access = public, Abstract = true)
        nsim = getNumSim(this)
        ranges = getPlotRanges(this,values)
        israndom = isRandom(this)
        obj = copy(this)
        obj = convertToRandom(this)
        obj = convertToGridded(this)
    end
end

% LocalWords:  dspace nx getMultisimDesignVariables pVec multisim
