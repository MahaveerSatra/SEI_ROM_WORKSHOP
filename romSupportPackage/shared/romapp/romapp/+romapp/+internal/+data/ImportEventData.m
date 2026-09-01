classdef ImportEventData < event.EventData
    %ImportEventData
    %
    % Used by ImportDataDialog class to notify clients about what data to
    % import.
    %
    
    % Copyright 2024-2025 The MathWorks, Inc.

    properties(GetAccess = public, SetAccess = protected)
        SampleTime double {mustBeScalarOrEmpty, mustBeReal, mustBeFinite, mustBePositive}
        DataSpec romapp.internal.data.ImportDataSpec
        NumDataset double {mustBeInteger, mustBeScalarOrEmpty, mustBePositive}
        ImportType string {mustBeMember(ImportType,{'datastore','workspace'})}
    end
    
    methods
        function obj = ImportEventData(dataspec,sampletime,numdataset,importtype)

            arguments
                dataspec romapp.internal.data.ImportDataSpec = romapp.internal.data.ImportDataSpec.empty
                sampletime double {mustBeScalarOrEmpty, mustBeReal, mustBeFinite, mustBePositive}  = [];
                numdataset double {mustBeInteger, mustBeScalarOrEmpty, mustBePositive} = 1;
                importtype string {mustBeMember(importtype,["datastore","workspace"])} = "workspace";
            end

            obj.DataSpec = dataspec;
            obj.SampleTime = sampletime;
            obj.NumDataset = numdataset;
            obj.ImportType = importtype;
        end
    end
    
end
