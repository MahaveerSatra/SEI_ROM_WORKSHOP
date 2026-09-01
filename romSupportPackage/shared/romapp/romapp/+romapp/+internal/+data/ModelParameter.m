classdef ModelParameter < handle
    %MODELPARAMETER
    %

    %   Copyright 2022-2023 The MathWorks, Inc.

    properties
        BlockPath Simulink.SimulationData.BlockPath = Simulink.SimulationData.BlockPath.empty
        Name string = string.empty;
        Workspace string = string.empty;
    end

    methods
        function obj = ModelParameter(name,blockpath,wksp)
            %MODELPARAMETER
            %

            if nargin > 0
                obj.Name = name;
            end
            if nargin > 1
                obj.BlockPath = blockpath;
            end
            if nargin > 2
                obj.Workspace = wksp;
            end
        end

        function value = getCurrentValue(this)

            try
                blockPath = convertToCell(this.BlockPath);
                if isempty(this.Workspace)
                    %Block dialog parameter
                    str = get_param(blockPath,this.Name);
                    mdl = bdroot(blockPath);
                    %value = slcontrollib.internal.utils.slResolve(str{1},mdl{1},'expression');
                    % Use slResolve directly as 1) ROM app binding does not
                    % support model references, 2) slcontrollib is not part
                    % of ROM app dependencies
                    value = slResolve(str{1},mdl{1},'expression');
                else
                    %Workspace variable
                    mdl = bdroot(blockPath);
                    %value = slcontrollib.internal.utils.slResolve(char(this.Name),mdl{1},'expression');
                    % Use slResolve directly as 1) ROM app binding does not
                    % support model references, 2) slcontrollib is not part
                    % of ROM app dependencies
                    value = slResolve(char(this.Name),mdl{1},'expression');
                end
                if ~isscalar(value) || ~isreal(value)
                    romapp.internal.resources.error('errUnexpected','Parameter values must be scalar real numeric values')
                end
                if isinf(value)
                    value = sign(value)*ones(1,1);
                elseif isnan(value)
                    value = zeros(1,1);
                end
            catch E %#ok<NASGU>
                value = zeros(1,1); %needs a valid scalar value
            end
        end
        function simin = updateSimulationInput(this,simin,value)
            %updateSimulationInput
            %
            % Update a Simulink.SimulationInput object with the block
            % parameter/variable defined by this object

            if isempty(this.Workspace)
                %Block dialog parameter
                bp = convertToCell(this.BlockPath);
                bp = bp{1}; %How handle model reference
                simin = setBlockParameter(simin,bp, char(this.Name), mat2str(value));
            else
                %Model variable
                if strcmpi(this.Workspace,'base')
                    simin = setVariable(simin,char(this.Name),value);
                else
                    bp = convertToCell(this.BlockPath);
                    bp = bp{1}; %How handle model reference
                    mdl = bdroot(bp);
                    simin = setVariable(simin,char(this.Name),value, 'Workspace', mdl);
                end
            end
        end
    end
end
