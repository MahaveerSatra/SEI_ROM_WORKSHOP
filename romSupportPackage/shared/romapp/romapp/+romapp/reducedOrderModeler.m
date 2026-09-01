function varargout = reducedOrderModeler(data,varname)
% reducedOrderModeler  Model Reducer App.
%
%   reducedOrderModeler(data,varnames)
%
%   data is cell array with following possible formats
%      data = {modelname}, modelname is a string
%      data = {x} or {y,u}, x,y,u are matrices or timetables
%      data = {sessiondata}, sessiondata is a romapp session object
%
%   varname is a cell array with the variable names of the elements in
%   data.
%
%   data and varnames can be simultaneously empty
%

%   Copyright 2022-2025 The MathWorks, Inc.

haveMinProducts = ~isempty(ver('ident')) && license('test','Identification_Toolbox') && ...
    ~isempty(ver('stats')) && license('test','Statistics_Toolbox');
if ~haveMinProducts
    romapp.internal.resources.error('errOpenApp_License');
end

haveModel = true;
if isempty(data)
    %No modelname, sessiondata, or data, open dialog to ask for
    %modelname or data
    dlg = romapp.internal.dialogs.ChooseAppModeDialog;
    show(dlg)
    addlistener(dlg,'OKPushed', @(hSrc,hData) uiresume(getFigure(hSrc)));
    addlistener(dlg,'CancelPushed', @(hSrc,hDara) delete(hSrc));
    addlistener(dlg,'CloseEvent', @(hSrc,hDara) delete(hSrc));
    uiwait(getFigure(dlg));

    if isvalid(dlg)
        %Ok pressed
        if strcmp(dlg.SelectedMode,'SimulinkModel')
            arg = dlg.ModelName;
            delete(dlg)
        elseif strcmp(dlg.SelectedMode,'WorkspaceVariable')
            varname = dlg.VariableName;
            delete(dlg)
            tool = evalin('base',"reducedOrderModeler("+varname+")");
            varargout = {tool};
            return
        end
    else
        %Cancel pressed, nothing to to.
        varargout = {[]};
        return
    end

    sessionData = [];
    varname = {};
else
    if haveControls()
        if all(mrtool.internal.util.isValidSystem(data))
            %Passed a linear model, launch model reducer and return
            varargout{1} = modelReducer(data{:});
            return
        end
    end
        
    if isscalar(data) && isa(data{1},'romapp.internal.data.AppData')
        %Passed a session data object
        sessionData = data{1};
        arg = sessionData.Model;
        haveModel = ~isempty(arg);
        varname = [];
    elseif isstring(data{1}) || ischar(data{1})
        %Passed a modelname
        arg = data{1};
        sessionData = [];
        varname = [];
    else
        %Passed one or two data arguments.
        haveModel = false;
        sessionData = [];
        if isnumeric(data{1}) || istimetable(data{1})
            % Determine expected data size from first data
            expSize = size(data{1},1);
        end
        for ct=1:numel(data)
            if ~lIsValidInput(data{ct})
                if isnumeric(data{ct}) || istimetable(data{ct})
                    romapp.internal.resources.error('errOpenApp_InvalidData')
                elseif isa(data{ct},'DynamicSystem')
                    romapp.internal.resources.error('errOpenApp_NoCST')
                else
                    romapp.internal.resources.error('errOpenApp_BadArgument1')
                end
            end
            if (isnumeric(data{ct}) || istimetable(data{ct})) && ~isequal(size(data{ct},1),expSize)
                romapp.internal.resources.error('errOpenApp_InconsistentSize')
            end
        end
        arg = data;
    end
end

%Make sure the model is loaded and showing
if haveModel
    if ~any(strcmp(find_system('type','block_diagram','Shown','on'),arg))
        try
            open_system(arg);
        catch
            romapp.internal.resources.error('errOpenApp_BadModelName')
        end
    end
end

%Launch and open the tool
if isempty(sessionData)
    Tool = romapp.internal.ReducedOrderModeler(arg,varname);
else
    Tool = romapp.internal.ReducedOrderModeler(arg,[],true);
    loadSession(Tool,sessionData);
end
if nargout
    varargout{1} = Tool;
end
end

function tf = haveControls()
%haveControls
%
tf = ~isempty(ver('control')) && license('test','Control_Toolbox');
end

function tf = lIsValidInput(data)

tf = romapp.internal.dialogs.ImportDataDialog.isValidImportData(data);
%While a scalar double is a valid data to import for parameters, we do not
%support launching the app with a single scalar value, see g3822218.
tf = tf && ~(isnumeric(data) && isscalar(data));
end

% LocalWords:  modelname sessiondata lbl varname
