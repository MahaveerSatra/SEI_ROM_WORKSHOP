function createNormalizationSubsystem(parentSystem, blockName, muVec, sigmaVec, position)
% Creates a Normalize subsystem inside ROM_Block sub-system

% Copyright 2026 The MathWorks, Inc.

% Note: Mu and Sigma must be column vectors as NSS and based block required 
% the input to be in column vector while the other blocks doesn't care.
muS    = muVec(:);            % column vector
sigmaS = sigmaVec(:);         % column vector
gainS  = 1 ./ sigmaS;           % element-wise

normalizePath = [parentSystem '/' blockName];
add_block('built-in/Subsystem', normalizePath, 'Position', position);

% Cosmetic label
set_param(normalizePath, 'MaskDisplay', 'disp(''Normalize'')')

% Inside Normalize subsystem
load_system(normalizePath);

% Positions for blocks (horizontal alignment)
posInport     = [30 100 60 120];
posConst      = [30 160 100 190];
posSum        = [150 90 180 130];
posGain       = [280 90 340 130];
posOutport    = [420 100 450 120];

% Add Inport and Outport
add_block('simulink/Sources/In1', [normalizePath '/Denormalized'], 'Position', posInport);
add_block('simulink/Sinks/Out1',  [normalizePath '/Normalized'],    'Position', posOutport);

% Mean constant (vector)
constBlock = [normalizePath '/MeanConst'];
constValue = char(mat2str(muS));
add_block('simulink/Sources/Constant', constBlock, ...
    'Value', constValue, 'Position', posConst);

% Subtract mean (vector-friendly)
sumBlock = [normalizePath '/SubtractMean'];
add_block('simulink/Math Operations/Sum', sumBlock, 'Inputs', '|+-', 'Position', posSum);

% Scale by std (element-wise gain with vector value)
gainBlock = [normalizePath '/ScaleByStd'];
gainValue = char(mat2str(gainS));
add_block('simulink/Math Operations/Gain', gainBlock, 'Gain', gainValue, 'Position', posGain);

% Connect blocks
add_line(normalizePath, 'Denormalized/1', 'SubtractMean/1');
add_line(normalizePath, 'MeanConst/1',    'SubtractMean/2');
add_line(normalizePath, 'SubtractMean/1', 'ScaleByStd/1');
add_line(normalizePath, 'ScaleByStd/1',   'Normalized/1');

Simulink.BlockDiagram.arrangeSystem(normalizePath);
end