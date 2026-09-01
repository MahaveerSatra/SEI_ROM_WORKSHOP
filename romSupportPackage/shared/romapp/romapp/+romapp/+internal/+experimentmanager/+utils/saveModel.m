function [modelFile, modelVarName] = saveModel(output, modelType)
% Saves the model output from the custom training function in the current 
% directory with a specific naming convention -> trainingOutputX.mat. The
% same X (num) suffix is used for changing the model object name-space in 
% the MAT file for easy mapping of models coming from different files. 

% Copyright 2026 The MathWorks, Inc.
arguments
    output struct
    modelType = [];
end

% Check if current folder has write permissions
currentFolder = pwd;
perm = filePermissions(currentFolder);
if ~perm.Writable
    % Show alert dialog with the appropriate message
    romapp.internal.resources.error('errRun_NoWritePerm_ExportToSL');
    return
end

baseName  = 'trainingOutput';
ext       = '.mat';
idx       = 0;
modelFile = fullfile(pwd, [baseName ext]);

while exist(modelFile, 'file')
    idx = idx + 1;
    modelFile = fullfile(pwd, [baseName num2str(idx) ext]);
end

% Model-specific field renaming for easy mapping
modelFieldMap = struct( ...
    'NSS',   'NSSModel', ...
    'NLARX', 'NonlinearModel');

modelVarName = '';

if isfield(modelFieldMap, modelType)
    oldField = modelFieldMap.(modelType);

    if idx == 0
        suffix = '';
    else
        suffix = num2str(idx);
    end
    newField = [oldField suffix];

    % Rename field in-place
    output.(newField) = output.(oldField);
    output = rmfield(output, oldField);
    modelVarName = newField;
end

save(modelFile, '-struct', 'output');
end