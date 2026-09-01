function createDenormalizationSubsystem(parentSystem, blockName, muVec, sigmaVec, position)
% Creates a Denormalize subsystem inside parentSystem with clean layout

% Copyright 2026 The MathWorks, Inc.

% Note: Mu and Sigma must be column vectors as NSS and based block required 
% the input to be in column vector while the other blocks doesn't care.
muS    = muVec(:);     % column vector
sigmaS = sigmaVec(:);  % column vector

denormPath = [parentSystem '/' blockName];
add_block('built-in/Subsystem', denormPath, 'Position', position);

% Cosmetic label
set_param(denormPath, 'MaskDisplay', 'disp(''Denormalize'')')

% Inside Denormalize subsystem
load_system(denormPath);

% Positions for blocks
posInport     = [30 100 60 120];
posConst      = [30 160 100 190];
posGain       = [150 90 210 130];
posSum        = [280 90 310 130];
posOutport    = [420 100 450 120];

% Add Inport and Outport
add_block('simulink/Sources/In1', [denormPath '/Normalized'],    'Position', posInport);
add_block('simulink/Sinks/Out1',  [denormPath '/Denormalized'],  'Position', posOutport);

% Mean constant
constBlock = [denormPath '/MeanConst'];
constValue = char(mat2str(muS));
add_block('simulink/Sources/Constant', constBlock, ...
    'Value', constValue, 'Position', posConst);

% Scale by std (multiply by sigma)
gainBlock = [denormPath '/ScaleByStd'];
gainValue = char(mat2str(sigmaS));
add_block('simulink/Math Operations/Gain', gainBlock, ...
    'Gain', gainValue, 'Position', posGain);

% Add mean
sumBlock = [denormPath '/AddMean'];
add_block('simulink/Math Operations/Sum', sumBlock, 'Inputs', '++', 'Position', posSum);

% Connect blocks
add_line(denormPath, 'Normalized/1', 'ScaleByStd/1');
add_line(denormPath, 'ScaleByStd/1', 'AddMean/1');
add_line(denormPath, 'MeanConst/1',  'AddMean/2');
add_line(denormPath, 'AddMean/1',    'Denormalized/1');

Simulink.BlockDiagram.arrangeSystem(denormPath);
end