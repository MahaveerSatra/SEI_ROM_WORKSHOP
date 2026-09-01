function r = L2(data)
%L2
%
% Post simulation function to compute the signal energy (L2 norm) for all
% outputs.

% Copyright 2024-2025 The MathWorks, Inc.

outSigs = data.OutputSignals;

r = struct();
allNames = string.empty;
for ct=1:numel(outSigs)
    values = outSigs(ct).Values;
    sigName = string(outSigs(ct).Name);
    if isequal(strtrim(sigName),"")
        %Signal is not named in simulink.
        sigName = "Output"+ct;
    end
    sigName = matlab.lang.makeValidName(matlab.lang.makeUniqueStrings(sigName,allNames));
    allNames = vertcat(allNames,sigName); %#ok<AGROW>
    fname = sigName+"_L2";
    r.(fname) = norm(values{:,:},2);
end
end
