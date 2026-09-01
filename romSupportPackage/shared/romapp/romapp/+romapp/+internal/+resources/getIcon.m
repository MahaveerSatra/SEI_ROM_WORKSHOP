function icn = getIcon(name)
%getIcon 
%
%This is needed for the Add-on as the icons will not yet be in the MATLAB
%icon repository and need to be retrieved from file.

% Copyright 2023 The MathWorks, Inc.

ipath = romapp.internal.resources.approot;
iname = fullfile(ipath,'+romapp','+internal','+resources','+icons',string(name)+".png");

if exist(iname,'file')
    icn = matlab.ui.internal.toolstrip.Icon(iname);
else
    icn = name;
end
end
