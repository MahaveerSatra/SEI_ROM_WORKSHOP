%% Reduced Order Modeling
% Log data from a Simulink model and use that data to train a reduced order model (ROM).
%
% *Step 1*
%
% Select Inputs and Outputs from the Simulink Model. Then select:
%% 
% * Simulink signals that are inputs for the ROM you want to create
% * Simulink block parameters that are inputs for the ROM you want to create
% * Simulink signals you want to replace or perturb when you log data from the 
% model. These signals are simulation inputs and can be the same as or
% different to the ROM inputs
% * Simulink signals that are outputs of the ROM you want to create
%% 
% *Step 2*
%
% Specify experiments to modify the parameters and simulation inputs to use 
% when logging data from the model. You can create multiple experiments using 
% different combinations of input signal and parameter values.
%
% *Step 3*
%
% Run the Simulink model with the selected experiments and collect input,
% parameter, and output data than can be used to train a ROM.
%
% *Step 4*
%
% Select a ROM type and launch the experiment manager to train 
% a model of that type using the collected data.
