function error(key,varargin)
%error
%
%Utility throw and error using a message catalog string but also support cases for the
%Add-on where the message catalog does not exist

% Copyright 2023 The MathWorks, Inc.

if romapp.internal.resources.Shipped
    error(message("shared_romapp:dialogs:"+key,varargin{:}))
else
    msg = romapp.internal.resources.getString(key,varargin{:});
    error("shared_romapp:dialogs:"+key,msg)
end
end
