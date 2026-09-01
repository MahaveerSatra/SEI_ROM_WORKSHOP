function getGSGuide()
%getGSGuide
%
% Open the Getting Started Guide provided with the Add-on.

% Copyright 2023 The MathWorks, Inc.

ipath = romapp.internal.resources.approot;
iname = fullfile(ipath,'doc',"GettingStarted_ROMspkg.mlx");

edit(iname)
end