function r = FinalValue_Internal(data)
%

%   Copyright 2024 The MathWorks, Inc.

outSigs = data.OutputSignals;

for ct=1:numel(outSigs)
    values = outSigs(ct).Values;
    values = values(end,:);
    outSigs(ct).Values = values;
end
r = outSigs;
end
