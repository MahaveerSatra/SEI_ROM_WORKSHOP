classdef ROMExperiment < experiments.internal.AbstractExperiment
    %

    % Copyright 2023-2026 The MathWorks, Inc.
    
    properties(Abstract,Constant)
        TYPE string
        ICON matlab.ui.internal.toolstrip.Icon
        NAME string
        DESCRIPTION string
        REQUIREDPRODUCTS romapp.internal.experimentmanager.RequiredProducts
        HAS_SCALAR_OUTPUT logical
        HAS_SIGNAL_OUTPUT logical
        NO_SIGNAL_INPUT logical
    end

    methods(Abstract, Access = protected)
        str = getCode(obj);
        tbl = getHyperparameterSettings(obj);
        str = getExportMenuClass(obj);
    end

    properties(SetAccess = private)
        SourceTemplate = '';
        HyperTable = {};
        TrainingType = 'CustomTraining';
        ExperimentType = 'ParamSweep'
        Description = '';
    end


    methods
        function obj = ROMExperiment(results_training,varargin)
            
            arguments
                results_training matlab.io.Datastore;
            end

            arguments (Repeating)
                varargin %Empty or matlab.io.Datastore
            end
            
            createHelperFunctions(obj,results_training,varargin{:});
            obj.TrainingType = 'CustomTraining';
            obj.ExperimentType = 'ParamSweep';
            obj.Description = getLongDescription(obj);
            obj.SourceTemplate = getCode(obj);
            obj.HyperTable = getHyperparameterSettings(obj);
            obj.SuggestedHyperTable = getSuggestedHyperparameterSettings(obj);
            obj.OptimizableMetricData = {'TrainingLoss', 'Minimize'};
            obj.ExportMenuItem  = getExportMenuClass(obj);
        end
    end

    methods(Access = protected)
        function str = getLongDescription(obj)
            %
            
            %Subclasses can override this to provide a customized long
            %description. The long description populates the description
            %field in the experiment manager custom experiment template.
            str = obj.DESCRIPTION;
        end

        function fs = getEffectiveFs(this,results)
            %getEffectiveFs
            %
            % Utility method to extract the effective sample rate from the
            % training data.
            
            if nargin < 2
                data = this.HelperFunctions('trainingData.mat');
                results = data.results;
            end
            reset(results);
            datastore = transform(results,@(x) lEffectiveFS(x));
            fs = readall(datastore);
            fs = median(fs,'omitnan');
        end

        function hyperparams = getSuggestedHyperparameterSettings(this) %#ok<MANU>
            %getSuggestedHyperparameterSettings
            %
            %  Default method to return suggested hyper-parameter settings
            %  for the model. This implementation returns no
            %  hyper-parameters, subclasses should override to return their
            %  hyper-parameter list.

            hyperparams = {};
        end

        function createHelperFunctions(this,results_training,varargin)

            if nargin == 2
                data = struct('results',results_training);
                map = containers.Map({'trainingData.mat'},{data}); % trainingData.mat saves results
            else
                results_test = varargin{1};
                data.results_training = results_training;
                if isempty(results_test)
                    data.results_test = [];
                else
                    result = read(results_test);
                    reset(results_test)
                    if isempty(result(1).InputParameters)
                        data.results_test = [];
                    else
                        data.results_test = results_test;
                    end
                end
                map = containers.Map({'trainingAndTestData.mat'},{data}); % data.mat saves trainingData.results and validationData.results
            end
            this.HelperFunctions = map;
        end
    end

    methods(Static = true)
        function cls = findAllROMExperiments
            %FINDALLROMEXPERIMENTS Return a list of all known romapp.internal.experimentmanager.ROMExperiment subclasses
            %
            %    A static method that uses introspection to create a list
            %    of ROMEXPERIMENT subclasses. Subclasses must be part of
            %    the romapp.internal.experimentmanager package to be
            %    identified by this method.
            %
            %    cls = romapp.internal.experimentmanager.findAllSolvers
            %
            %    Outputs:
            %       cls - string array of experiment class names
            %

            %Use introspection to find romapp.internal.experimentmanager package
            mc = ?romapp.internal.experimentmanager.ROMExperiment;
            pk = mc.ContainingPackage;

            %Find all classes in the package (or sub packages) that are subclassed from
            %ROMExperiment.
            cls = string.empty;
            cls = [cls; lFindClassInPackage(pk,'romapp.internal.experimentmanager.ROMExperiment')];
            for ctC=1:numel(pk.PackageList)
                cls = [cls; lFindClassInPackage(pk.PackageList(ctC),'romapp.internal.experimentmanager.ROMExperiment')]; %#ok<AGROW>
            end
        end

        function checkProducts(rp,name)
            %checkProducts
            %
            % Throw an error if the required products are not installed and
            % licensed.
            %

            if ~haveProducts(rp)
                id = rp.ErrorID;
                if isempty(id)
                    p = rp.Product(1);
                    for ct=2:numel(rp.Product)
                        p = p +", " + rp.Product(ct);
                    end
                    romapp.internal.resources.error("errExportResults_EM_License", ...
                        name,p);
                else
                    error(id, getString(message(id)));
                end
            end
        end
        function tf = canUseWithData(data)
            %canUseWithData
            %
            arguments
                data romapp.internal.data.SimulationSet
            end
            tf = true;
        end
        function [rTrain,rTest] = prepareResults(data,idxTrain,idxTest)
            %prepareResults
            %
            arguments
                data romapp.internal.data.SimulationSet
                idxTrain logical
                idxTest logical = []
            end

            data = data(idxTrain);
            rTrain = [];
            for ct=1:numel(data)
                experimentDS = data(ct).Results;
                if ~isempty(experimentDS)
                    idxKeep = transform(experimentDS, @(x) lCheckSuitableData(x));
                    idxKeep = readall(idxKeep);
                    idxInclude = data(ct).IncludeForTraining;
                    experimentDS = subset(experimentDS,idxKeep & idxInclude);
                    if ct == 1
                        rTrain = experimentDS;
                    else
                        rTrain = combine(rTrain,experimentDS,ReadOrder="sequential");
                    end
                end
            end

            %By default no explicit test data is specified, the method
            %algorithm selects test data from the training data
            rTest = romapp.internal.data.ExperimentData.empty;
        end

        function str = getResultsToExportString(nTot, nExcl)
            str = romapp.internal.resources.getString('lblXofY', nTot-nExcl, nTot);
        end
    end
end

function cls = lFindClassInPackage(pk,clsToFind)
cls = string.empty;
for ctC=1:numel(pk.ClassList)
    parents = pk.ClassList(ctC).SuperclassList;
    found = false;
    ctP = 1;
    while ~found && ctP <=numel(parents)
        if strcmp(parents(ctP).Name,clsToFind)
            cls = vertcat(cls,pk.ClassList(ctC).Name); %#ok<AGROW>
            found = true;
        else
            ctP = ctP + 1;
        end
    end
end
end

function fs = lEffectiveFS(result)
sig = result.OutputSignals(1);
t = seconds(sig.Values.Time);
fs = romapp.internal.experimentmanager.getEffectiveFs(t);
end

function tf = lCheckSuitableData(result)
%Check for results that have errors or only have 1 time point

tf = isempty(result.Errors);
tf = tf && size(result.OutputSignals(1).Values.Time,1) > 1;
end

% LocalWords:  FINDALLROMEXPERIMENTS cls getEffectiveFs omitnan