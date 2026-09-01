function r = min(data)
%min
%
% Post simulation function to compute the minimum value for all outputs.

% Copyright 2024-2025 The MathWorks, Inc.

outSigs = data.OutputSignals;

r = struct();
allNames = string.empty;
for ct=1:numel(outSigs)
    values = outSigs(ct).Values;
    sigName = outSigs(ct).Name;
    if isequal(strtrim(sigName),"")
        %Signal is not named in simulink.
        sigName = "Output"+ct;
    end
    sigName = matlab.lang.makeValidName(matlab.lang.makeUniqueStrings(sigName,allNames));
    allNames = vertcat(allNames,sigName); %#ok<AGROW>
    fname = sigName+"_min";
    r.(fname) = min(values{:,:});
end
end
