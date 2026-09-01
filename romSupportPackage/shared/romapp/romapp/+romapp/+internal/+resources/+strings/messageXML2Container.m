%Script to convert message catalog to a container.map and save the map so
%that it can be used when the App is an Add-on and not shipped

% Copyright 2023-2024 The MathWorks, Inc.

file = fullfile(matlabroot,'resources','shared_romapp','en','dialogs.xml');
data = readstruct(file,FileType="xml");
rootMSG = data.message.entry;
map = containers.Map;

for ct=1:numel(rootMSG)
   entry = rootMSG(ct);
   key = entry.keyAttribute;
   msg = char(entry.Text); %store as char array to be consistent with message catalog get string
   map(key) = msg;
end

save(fullfile(matlabroot,'toolbox','shared','romapp','romapp','+romapp','+internal','+resources','messageMap'),'map')
