classdef GriddedInterpBlock < romapp.internal.experimentmanager.ExportToSL
    % GRIDDEDINTERPBLOCK creates an n-D Lookup Table sub-system block for a
    % griddedInterpolant-based ROM–Simulink workflow.
    
    % Copyright 2026 The MathWorks, Inc.
    
    properties
        InNames  cell = {}
        OutNames cell = {}
    end

    methods
        function obj = GriddedInterpBlock(varargin)
            obj = obj@romapp.internal.experimentmanager.ExportToSL(varargin{:});
        end

        function obj = extractIONames(obj, trainingOutput)
            inNames = trainingOutput.Parameters.Properties.VariableNames(:);
            outNames = string(trainingOutput.OutputNames);

            % Normalize newlines -> space, '/' -> '_'(path-safe)
            cleanNames = @(c) cellstr( ...
                strtrim( ...
                regexprep( ...
                replace( ...
                replace(string(c), [newline, char(13), char(10)], " "), ...
                "/", "_"), ...
                "\s+", " ")) ); %#ok<CHARTEN>

            obj.InNames  = cleanNames(inNames);
            obj.OutNames = cleanNames(outNames);
        end
    end

    methods (Access = protected)
        function createROMSLBlock(this, subsystemPath, trainingOutput)
            %CREATEROMSLBLOCK Creates the ROM_Block sub-system which is
            %unique for every model type

            % 1) Pull gridded data & methods
            GI = trainingOutput.GriddedInterpolantModel;

            gridVectors = GI.GridVectors;   
            nDims       = numel(gridVectors);
            tableVals   = GI.Values;

            % Methods
            [interpMethod, extrapMethod] = mapMethodNames(subsystemPath, GI.Method, GI.ExtrapolationMethod);

            % 2) Names
            inVarNames  = this.InNames;   % row cell array
            outVarNames = this.OutNames;  % row cell array

            % 3) Save model struct
            romapp.internal.experimentmanager.utils.saveModel(trainingOutput);

            % 4) Build subsystem
            load_system(bdroot(subsystemPath));
            load_system(subsystemPath);

            % 4a) Inports
            muxOutH = romapp.internal.experimentmanager.utils.configureSLInputBlocks(subsystemPath, inVarNames);

            numTables = size(tableVals, nDims+1);    % Number of n-D lookup table blocks needed 
            lutOutHs  = zeros(1, numTables);    % outport handles

            basePos = [310 90 430 130];
            yStep   = 70;
            
            % 4b) Add n-D lookup table block(s)
            for k = 1:numTables
                if numTables == 1
                    lutPath = [subsystemPath '/GriddedLookupND'];
                    pos = basePos;
                else
                    lutPath = sprintf('%s/GriddedLookupND_%d', subsystemPath, k);
                    pos = basePos + [0 (k-1)*yStep 0 (k-1)*yStep];
                end

                add_block('simulink/Lookup Tables/n-D Lookup Table', lutPath, ...
                          'Position', pos);

                % Algorithm panel
                set_param(lutPath, 'UseOneInputPortForAllInputData', 'on');
                set_param(lutPath, 'InterpMethod',   interpMethod);
                set_param(lutPath, 'ExtrapMethod',   extrapMethod);

                % Table/Breakpoints
                set_param(lutPath, 'NumberOfTableDimensions', num2str(nDims));

                if numTables == 1
                    % No slicing when there is only one table
                    set_param(lutPath, 'Table', mat2str(tableVals));
                else
                    set_param(lutPath, 'Table', mat2str(tableVals(:,:,k)));
                end

                for d = 1:nDims
                    pName = sprintf('BreakpointsForDimension%d', d);
                    set_param(lutPath, pName, mat2str(gridVectors{d}));
                end

                % Wire: Mux -> each n-D Lookup
                phLut   = get_param(lutPath, 'PortHandles');
                lutInH  = phLut.Inport(1);
                lutOutH = phLut.Outport(1);
                add_line(subsystemPath, muxOutH, lutInH, 'autorouting','on');
                lutOutHs(k) = lutOutH;
            end

            % 4c) Outputs
            romapp.internal.experimentmanager.utils.configureSLOutputBlocks(subsystemPath, outVarNames, lutOutHs);
        end
    end
end

% Local Helper
function [lutInterpMethod, lutExtrapMethod] = mapMethodNames(subsystemPath, interpMethod, extrapMethod)
% Map GriddedInterpolant methods to n-D Lookup Table param options.
interpMap = struct( ...
    'linear',  'Linear point-slope', ...
    'nearest', 'Nearest', ...
    'spline',  'Cubic spline', ...
    'cubic', 'Cubic spline');

extrapMap = struct( ...
    'linear',  'Linear', ...
    'nearest', 'Clip', ...
    'spline',  'Cubic spline', ...
    'cubic', 'Cubic spline');

% Validate supported methods
% LUT supports only: linear / nearest / spline / cubic (as encoded in maps above).
supported = {'linear','nearest','spline', 'cubic'};

if ~ismember(interpMethod, supported) || ~ismember(extrapMethod, supported)
    romapp.internal.resources.error('errUnsupportedGriddedMethods');
    return
end

% Interp & Extrap mapping + add annotation for extrapMethod to be Clip
% when the interp is nearest and interp to be spline when extrap is spline
if strcmp(interpMethod, 'nearest')
    lutInterpMethod  = interpMap.nearest;
    lutExtrapMethod = extrapMap.nearest;

    if ~strcmp(extrapMethod, 'nearest')
        model = bdroot(subsystemPath);
        msg = romapp.internal.resources.getString('warnGriddedInterpROMBlockExtrap');
        ann = Simulink.Annotation(model, msg);
        
        ann.ForegroundColor = 'black'; 
        ann.BackgroundColor = 'yellow';
    end
elseif strcmp(extrapMethod, 'spline')
    lutInterpMethod  = interpMap.spline;
    lutExtrapMethod = extrapMap.spline;

    if ~strcmp(interpMethod, 'spline')
        model = bdroot(subsystemPath);
        msg = romapp.internal.resources.getString('warnGriddedInterpROMBlockInterp');
        ann = Simulink.Annotation(model, msg);

        ann.ForegroundColor = 'black';
        ann.BackgroundColor = 'yellow';
    end
else
    lutInterpMethod = interpMap.(interpMethod);
    lutExtrapMethod = extrapMap.(extrapMethod);
end
end
