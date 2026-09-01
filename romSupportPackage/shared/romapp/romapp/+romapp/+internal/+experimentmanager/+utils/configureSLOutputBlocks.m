function configureSLOutputBlocks(subsystemPath, outVarNames, denOutH)
% Configure the outport and mux blocks for the ROM_Block sub-system

% Copyright 2026 The MathWorks, Inc.

nOut = numel(outVarNames);
nSrc = numel(denOutH);

if nOut == 1
    % Single output
    outPath = [subsystemPath '/' outVarNames{1}];
    add_block('simulink/Sinks/Out1', outPath, 'Position', [720 100 750 120]);
    phOut = get_param(outPath, 'PortHandles');
    add_line(subsystemPath, denOutH(1), phOut.Inport(1), 'autorouting','on');
    return;
end

% Multiple outputs:
xLout = 760; xRout = 790; y0out = 60; dyout = 40;

if nSrc == nOut
    % GriddedInterpolant case - Demux not needed
    for k = 1:nOut
        outPath = [subsystemPath '/' outVarNames{k}];
        pos = [xLout, y0out+(k-1)*dyout, xRout, y0out+(k-1)*dyout+20];
        add_block('simulink/Sinks/Out1', outPath, 'Position', pos);
        phOut = get_param(outPath, 'PortHandles');
        add_line(subsystemPath, denOutH(k), phOut.Inport(1), 'autorouting','on');
    end
else
    % For other model types - Need a Demux 
    demuxPath = [subsystemPath '/OutputsDemux'];
    add_block('simulink/Signal Routing/Demux', demuxPath, ...
        'Position', [700 70 720 70 + 30*nOut], ...
        'Outputs', num2str(nOut));

    phDemux = get_param(demuxPath, 'PortHandles');
    add_line(subsystemPath, denOutH(1), phDemux.Inport(1), 'autorouting','on');

    for k = 1:nOut
        outPath = [subsystemPath '/' outVarNames{k}];
        pos = [xLout, y0out+(k-1)*dyout, xRout, y0out+(k-1)*dyout+20];
        add_block('simulink/Sinks/Out1', outPath, 'Position', pos);
        phOut = get_param(outPath, 'PortHandles');
        add_line(subsystemPath, phDemux.Outport(k), phOut.Inport(1), 'autorouting','on');
    end
end
end