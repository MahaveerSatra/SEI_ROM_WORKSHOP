classdef SimulationOptions
    % 

    %SimulationOptions
    %
    % Class for storing & managing all options related to running simulations

    % Copyright 2023-2025 The MathWorks, Inc.

    properties(SetAccess = private, GetAccess = public)
        Version string
    end

    properties
        SignalLogging string {mustBeMember(SignalLogging,["all","romonly"])} = "romonly"
        LogStates logical
        LogToFile logical
        FileLocation string
        FastRestart logical
        UseParallel {matlab.internal.parallel.validateUseParallelOption} = "off"
        ParallelMode string {mustBeMember(ParallelMode,["blocking","nonblocking","batch"])} = "blocking"
        TransferBaseWorkspaceVariables string {mustBeMember(TransferBaseWorkspaceVariables,["on","off"])} = "on"
        GenerateCoverage logical
        UsePostSimFcn logical = false
        PostSimFcn
        ClearLogPostSim logical = true 
    end

    methods
        function obj = SimulationOptions()

            obj.Version = "2.0";
            obj.SignalLogging = 'romonly';
            obj.LogStates = false;
            obj.LogToFile = false;
            obj.FileLocation = string.empty;
            obj.FastRestart = false;
            obj.UseParallel = "off";
            obj.ParallelMode = 'blocking';
            obj.TransferBaseWorkspaceVariables = 'on';
            obj.GenerateCoverage = false;
            obj.UsePostSimFcn = false;
            obj.PostSimFcn = [];
            obj.ClearLogPostSim = true;
        end
    end

    methods(Static=true, Access=protected)
        function data = convertV1ToV2(data)

            if data.UseParallel
                data.UseParallel = "on";
            else
                data.UseParallel = "off";
            end
            data.Version = '2.0';
        end
    end

    methods(Static=true)
        function obj = loadobj(data)

            if isempty(data.Version) || strcmp(data.Version,'1.0')
                obj = romapp.internal.data.SimulationOptions.convertV1ToV2(data);
            else
                obj = data;
            end
        end
    end

end

% LocalWords:  romonly
