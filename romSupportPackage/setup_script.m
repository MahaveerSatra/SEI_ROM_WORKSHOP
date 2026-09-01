% Run this from matlab with the location of the script being set as the current folder

matlab.internal.msgcat.setAdditionalResourceLocation(fullfile(pwd));
addpath(genpath(fullfile(pwd)))