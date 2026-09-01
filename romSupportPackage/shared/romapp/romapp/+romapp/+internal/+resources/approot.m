function pth = approot()
%approot
%
%Utility to return the root directory of the romapp, used to determine
%resource location when the app is used as an add-on. 

% Copyright 2023 The MathWorks, Inc.

f = which('romapp.reducedOrderModeler','-all');
pth = regexprep(f{1},['\',filesep,'\+romapp\',filesep,'reducedOrderModeler\.m'],'');

end
