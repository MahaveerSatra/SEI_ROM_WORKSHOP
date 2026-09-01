function r = mean(data)
%mean
%
% Post simulation function to compute the mean value for all outputs.

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
    fname = sigName+"_mean";
    r.(fname) = mean(values{:,:});
end
end
