function str = getString(key,varargin)
%getString
%
%Utility to return a message catalog string but also support cases for the
%Add-on where the message catalog does not exist

% Copyright 2023-2025 The MathWorks, Inc.


if romapp.internal.resources.Shipped
    str = getString(message("shared_romapp:dialogs:"+key,varargin{:}));
else
    persistent map %#ok<TLEV>
    if isempty(map)
        p = mfilename('fullpath');
        p = fileparts(p);

        data = load(string(p)+filesep+"messageMap.mat",'map');
        map = data.map;
    end

    str = map(key);
    for ct=1:numel(varargin)
        hValue = varargin{ct};
        if isnumeric(hValue)
            pat = "{"+(ct-1)+", number, integer}";
            hValue = mat2str(hValue);
        else
            pat = "{"+(ct-1)+"}";
        end
        str = replace(str,pat,hValue);
    end
    %Strip duplicate white spaces from the string
    str = regexprep(str,'\s*',' ');
    str = regexprep(str,'%','%%');
    str = sprintf(str); %Account for messages with line feed etc.
end
end
