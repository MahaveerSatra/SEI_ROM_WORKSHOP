function muxOutH = configureSLInputBlocks(subsystemPath, inVarNames)
% Configure the inport and mux blocks for the ROM_Block sub-system

% Copyright 2026 The MathWorks, Inc.

y0 = 50; dy = 40; xInL = 30; xInR = 60;
nIn = numel(inVarNames);
inOutPH = zeros(1, nIn);   % cache Outport handles to wire into Mux

for k = 1:nIn
    inPath = [subsystemPath '/' inVarNames{k}];
    pos    = [xInL, y0+(k-1)*dy, xInR, y0+(k-1)*dy+20];

    add_block('simulink/Sources/In1', inPath, ...
        'Position', pos, ...
        'IconDisplay','Signal name', ...
        'ShowName','off');

    ph = get_param(inPath, 'PortHandles');
    inOutPH(k) = ph.Outport(1);
end

% If only one input, no Mux needed.
if nIn == 1
    muxOutH = inOutPH(1);
    return;
end

% Mux inputs (lines labeled with raw input names)
muxPath   = [subsystemPath '/InputsMux'];
muxTop    = 70;
muxBottom = 70 + nIn*dy;

add_block('simulink/Signal Routing/Mux', muxPath, ...
    'Position', [90 muxTop 100 muxBottom], ...
    'Inputs', num2str(nIn));

phMux   = get_param(muxPath, 'PortHandles');
muxInPH = phMux.Inport;
muxOutH = phMux.Outport(1);

for k = 1:nIn
    lh = add_line(subsystemPath, inOutPH(k), muxInPH(k), 'autorouting','on');
    if ~isempty(inVarNames{k})
        set_param(lh, 'Name', inVarNames{k});
    end
end
end