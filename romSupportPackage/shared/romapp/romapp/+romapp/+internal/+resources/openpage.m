function openpage(pagepath)
%openpage
%
%Utility to open a html page that is relative to the app add on root
%folder. Used in the doc to link to pages

% Copyright 2023-2024 The MathWorks, Inc.

[~,~,ext] = fileparts(pagepath);
if strcmp(ext,'.mlx')
    open(romapp.internal.resources.approot+pagepath)
else
    if matlab.htmlviewer.internal.isHTMLViewer
        htmlviewer("file:///"+romapp.internal.resources.approot+pagepath)
    else
        web("file:///"+romapp.internal.resources.approot+pagepath)
    end
end
end

% LocalWords:  mlx
