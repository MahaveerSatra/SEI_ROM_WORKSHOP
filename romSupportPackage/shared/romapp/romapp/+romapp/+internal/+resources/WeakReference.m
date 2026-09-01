function whndl = WeakReference(hndl)
%WeakReference
%
% Utility used return a weak reference when shipped but not when using the
% Add-on

% Copyright 2025 The MathWorks, Inc.

if romapp.internal.resources.Shipped
    whndl = matlab.lang.WeakReference(hndl);
else
    whndl = struct('Handle',hndl);
end
end
