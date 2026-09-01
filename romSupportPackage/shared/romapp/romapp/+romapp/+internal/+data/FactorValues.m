classdef FactorValues < handle

    % FactorValues
    % Copyright 2025 The MathWorks, Inc.

    % Properties
    % SignalValues is a matrix for random and chirp signals of size 
    % NumPulse by nSignals. A cell array for a custom signal to allow
    % for signals of different lengths. 
    % 
    % ParameterValues is a matrix of size numSim by nParameters. 
    % 
    % The following properties are maximum number of iterations before
    % giving up sampling, bisecting and oversampling factors:
    % MaxIterSingleFacotr
    % MaxIterTwoFactors
    % MaxIterBisect
    % OverSampling 
    
    properties (SetAccess=private,GetAccess=public)     
        SignalValues 
        ParameterValues
        EnoughSamples 
    end
    
    properties (Access=protected)
        MaxIterSingleFactor double = 10
        MaxIterTwoFactors double = 30
        MaxIterBisect double = 50
        OverSampling double = 2
    end

    events
        DataChanged
    end

    methods (Access=public)
        % This method block has the public functions:
        % to sample factors 
        % to check if enough samples can be obtained for all factors
        % to populate factor values when converting from V1 to V2
        
        function obj = FactorValues()
            setValues(obj,[],[],false)
        end

        function obj = copy(this)
            obj = romapp.internal.data.FactorValues();
            obj.SignalValues = this.SignalValues;
            obj.ParameterValues = this.ParameterValues;
            obj.EnoughSamples = this.EnoughSamples;
        end

        function sampleFactors(this,spec)
            % Top-level sample function to sample FactorValues
            if hasBoundary(spec)    
                if ~isempty(spec.SignalSpec)
                    PRBS = strcmpi(spec.SignalSpec.TYPE,"PRBS");
                else
                    PRBS = false;
                end

                if PRBS
                    [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries(this,spec);
                elseif strcmpi(spec.BoundarySpec.Method, "resample") || isempty(spec.BoundarySpec.Method)
                    [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries(this,spec);
                elseif strcmpi(spec.BoundarySpec.Method, "project")
                    [sigValues,paramValues,enoughSamples] = projectWithinBoundaries(this,spec);
                else
                    error('Invalid sampling method')
                end
            else
                [sigValues,paramValues,enoughSamples] = sampleWithoutBoundaries(this,spec);
            end
            setValues(this,sigValues,paramValues,enoughSamples);
        end  

        function enoughSamples = hasEnoughSamples(this)
            % Outputs a logical to indicate if has enough FactorValues
            enoughSamples = this.EnoughSamples;
        end

        function this = populateFactorValues(this,spec)
            % Only called from romapp.data.SimulationSpec
            % Used for populating FactorValues when converting a V1 object
            % to V2
            this.EnoughSamples = true;
            hasSignals = ~isempty(spec.SignalSpec);
            hasParameters = ~isempty(spec.ParameterSpec);            
            if hasSignals
                signalIsRandom = isRandom(spec.SignalSpec);
                if signalIsRandom 
                    this.SignalValues = spec.SignalSpec.Values;
                else
                    this.SignalValues = sampleSpecValues(spec.SignalSpec,[]);
                end
            end
            if hasParameters
                parameterIsRandom = isRandom(spec.ParameterSpec);
                if parameterIsRandom
                    this.ParameterValues = spec.ParameterSpec.Values;
                else
                    this.ParameterValues = getValues(spec.ParameterSpec);
                end
            end
            if hasSignals && hasParameters
                if ~iscell(this.SignalValues)
                    this.SignalValues = repmat(this.SignalValues,[getNumSim(spec.ParameterSpec),1]);
                end
            end
        end
    end


    methods (Access=private)
        %This block contains top-level methods to sample/project
        
        function [sigValues,paramValues,enoughSamples] = sampleWithoutBoundaries(this,spec)
            %Get signal and parameter values when there are no boundaries
            %
            %Always able to sample enough samples when there are no
            %boundaries
            enoughSamples = true;

            %Get signal values. 
            %Get numPulse number of signals for random signals
            %Let chirp and custom decides on number of samples
            if isempty(spec.SignalSpec)
                sigValues = [];
            else          
                numPulse = getNumPulse(spec.SignalSpec);
                sigValues = sampleSpecValues(spec.SignalSpec,numPulse);
            end

            %Get parameter values
            if isempty(spec.ParameterSpec)
                paramValues = [];
            else
                numSim = getNumSim(spec.ParameterSpec);
                paramValues = sampleSpecValues(spec.ParameterSpec,numSim);
            end

            %Duplicate signal values for each combination of parameter
            %Values, each row corresponds to one simulation 
            if (~isempty(spec.SignalSpec)) && (~isempty(spec.ParameterSpec))
                nParamValues = size(paramValues,1);
                if ~iscell(sigValues)
                    sigValues = repmat(sigValues,[nParamValues,1]);
                end
            end
        end
        
        function [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries(this,spec)
            % Different sampling strategies depending on spec w/o signals
            % and parameters, having random or deterministic 
            % signals/parameters. 
            % 
            % Random signals only
            % Chirp/custom signals only
            % Random parameters only
            % Gridded parameters only
            % Chirp/custom signals + random parameters
            % Chirp/custom signals + gridded parameters
            % Random signals + random parameters
            % Random signals + gridded parameters
            
            method = 'resample';

            SignalNames = getSignalNames(spec);
            hasSignals = ~isempty(SignalNames);
            if hasSignals
                signalIsRandom = isRandom(spec.SignalSpec);
            end

            ParameterNames = getParameterNames(spec);
            hasParameters = ~isempty(ParameterNames);
            if hasParameters
                parameterIsRandom = isRandom(spec.ParameterSpec);
            end
            
            % Split boundaries into ones involving only signals, only
            % parameters, and both signals and parameters. 
            [SignalBoundaries, ParameterBoundaries, MixedBoundaries] = separateBoundaries(spec.BoundarySpec, SignalNames, ParameterNames);

            if hasSignals && ~hasParameters               
                
                if signalIsRandom
                    [sigValues,enoughSamples] = sampleSignalsWithinBoundaries(this,spec,SignalBoundaries,SignalNames,method);
                    sigValues = getRequiredSamples(this,sigValues,spec.SignalSpec.NumPulse,enoughSamples);
                    paramValues = [];        
                
                else
                    sigValues = sampleSpecValues(spec.SignalSpec);
                    paramValues = [];
                    enoughSamples = true;
                end
            
            elseif ~hasSignals && hasParameters                
                
                if parameterIsRandom
                    [paramValues,enoughSamples] = sampleParametersWithinBoundaries(this,spec,ParameterBoundaries,ParameterNames,method);
                    paramValues = getRequiredSamples(this,paramValues,getNumSim(spec.ParameterSpec),enoughSamples);
                    sigValues = [];
                
                else
                    [paramValues,~] = checkWithinSignalOrParameterBoundaries(this,ParameterBoundaries,ParameterNames, getValues(spec.ParameterSpec) );
                    enoughSamples = ~isempty(paramValues);
                    sigValues = [];
                end

            elseif hasSignals && hasParameters 
                
                if ~signalIsRandom && parameterIsRandom
                    [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries_DeterministicSignals_RandomParameters(this,spec,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method);
                
                elseif (~signalIsRandom && ~parameterIsRandom)
                    [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries_DeterministicSignals_GriddedParameters(this,spec,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method);
                
                elseif (signalIsRandom && parameterIsRandom)              
                    [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries_RandomSignals_RandomParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method);
              
                elseif (signalIsRandom && ~parameterIsRandom)
                    [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries_RandomSignals_GriddedParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method);

                end 
            end
        end
        
        function [sigValues,paramValues,enoughSamples] = projectWithinBoundaries(this,spec)
            % Different sampling strategies depending on spec w/o signals
            % and parameters, having random or deterministic signals/parameters. 
            % 
            % Random signals only
            % Chirp/custom signals only
            % Random parameters only
            % Gridded parameters only
            % Chirp/custom signals + random parameters
            % Chirp/custom signals + gridded parameters
            % Random signals + random parameters
            % Random signals + gridded parameters

            method = 'project';
            
            SignalNames = getSignalNames(spec);
            hasSignals = ~isempty(SignalNames);
            if hasSignals
                signalIsRandom = isRandom(spec.SignalSpec);
            end

            ParameterNames = getParameterNames(spec);
            hasParameters = ~isempty(ParameterNames);
            if hasParameters
                parameterIsRandom = isRandom(spec.ParameterSpec);
            end

            % Split boundaries into ones involving only signals, only
            % parameters, and both signals and parameters. 
            [SignalBoundaries, ParameterBoundaries, MixedBoundaries] = separateBoundaries(spec.BoundarySpec, SignalNames, ParameterNames);

            if hasSignals && ~hasParameters               
                if signalIsRandom 
                    % Sample at least one valid point to project towards
                    [sigValuesInBoundaries,enoughSamples] = sampleSignalsWithinBoundaries(this,spec,SignalBoundaries,SignalNames,method);
                    % If there is at least one valid point
                    if enoughSamples
                        enoughSamples = chkEnoughSamples(this,sigValuesInBoundaries,getNumPulse(spec.SignalSpec));
                        sigValues = sigValuesInBoundaries;
                        ctIter = 0;
                        while (~enoughSamples) && (ctIter<=this.MaxIterBisect)
                            % While not having samples specified by user,
                            % continue to sample and project. This is
                            % necessary in the case where projection did
                            % not come within boundary due to numerical/too
                            % many bisections. 
                            ctIter = ctIter + 1; 
                            % numPulse is the number of signal points still
                            % needed
                            numPulse = getNumPulse(spec.SignalSpec) - size(sigValues,1);
                            inputSignalValues = sampleSpecValues(spec.SignalSpec,numPulse);
                            [sigValuesOneIter,enoughSamples] = project_SignalsOrParameters(this,SignalBoundaries,SignalNames,sigValuesInBoundaries,inputSignalValues,[]);
                            sigValues = [sigValues; sigValuesOneIter];
                            enoughSamples = chkEnoughSamples(this,sigValues,getNumSim(spec.SignalSpec));
                        end
                    end
                    if ~enoughSamples
                        sigValues = [];
                    end
                else                    
                    numPulse = getNumPulse(spec.SignalSpec);
                    sigValues = sampleSpecValues(spec.SignalSpec,numPulse);                 
                    enoughSamples = true;
                end
                paramValues = [];

            elseif ~hasSignals && hasParameters                

                if parameterIsRandom
                    % Sample at least one valid point to project towards
                    [paramValuesInBoundaries,enoughSamples] = sampleParametersWithinBoundaries(this,spec,ParameterBoundaries,ParameterNames,method);
                    if enoughSamples
                        enoughSamples = chkEnoughSamples(this,paramValuesInBoundaries,getNumSim(spec));
                        paramValues = paramValuesInBoundaries;
                        ctIter = 0;
                        while ~enoughSamples && ctIter<=this.MaxIterBisect
                            % while not having samples specified by user,
                            % continue to sample and project. This is
                            % necessary in the case where projection did
                            % not come within boundary due to numerical/too
                            % many bisections. 
                            ctIter = ctIter + 1; 
                            % numSim is the number of parameter points still
                            % needed
                            numSim = getNumSim(spec.ParameterSpec) - size(paramValues,1);
                            inputParamValues = sampleSpecValues(spec.ParameterSpec,numSim);
                            [paramValues,enoughSamples] = project_SignalsOrParameters(this,ParameterBoundaries,ParameterNames,paramValuesInBoundaries,inputParamValues,paramValues);
                        end
                    end
                    paramValues = getRequiredSamples(this,paramValues,getNumSim(spec.ParameterSpec),enoughSamples);

                else
                    % Only gridded parameters
                    [paramValues,~] = checkWithinSignalOrParameterBoundaries(this,ParameterBoundaries,ParameterNames, getValues(spec.ParameterSpec) );
                    enoughSamples = ~isempty(paramValues);
                end
                sigValues = [];

            elseif hasSignals && hasParameters 

                if ~signalIsRandom && parameterIsRandom
                    [sigValues,paramValues,enoughSamples] = projectWithinBoundaries_DeterministicSignals_RandomParameters(this,spec,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries);

                elseif (~signalIsRandom && ~parameterIsRandom)
                    [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries_DeterministicSignals_GriddedParameters(this,spec,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries);

                elseif (signalIsRandom && parameterIsRandom)              
                    [sigValues,paramValues,enoughSamples] = projectWithinBoundaries_RandomSignals_RandomParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries);

                elseif (signalIsRandom && ~parameterIsRandom)
                    [sigValues,paramValues,enoughSamples] = projectWithinBoundaries_RandomSignals_GriddedParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries);
                end 
            end
        end

    end

    methods (Access=private)
        %This method block contains second-level sampling methods, to
        %sample under different scenarios

        function [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries_DeterministicSignals_RandomParameters(this,spec,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method)
            % This function acquires random parameter values, remove
            % out-of-ParameterBoundaries parameter values, and then 
            % removes the out-of-MixedBoundaries parameter values.
            % This block then repeats the above until enough parameter
            % samples are required. 
              
            [paramValues,enoughSamples] = sampleParametersWithinBoundaries(this,spec,ParameterBoundaries,ParameterNames,method);
            if ~enoughSamples
                return
            end

            sigValues = sampleSpecValues(spec.SignalSpec); 
            if iscell(sigValues)
                sigValues = getValuesArray(spec.SignalSpec,sigValues);
            end
            paramValues = checkParametersWithinMixedBoundaries(this,MixedBoundaries,SignalNames,sigValues,ParameterNames,paramValues);
            
            ctIter = 0;
            if strcmpi(method,'resample')
                numSim = getNumSim(spec.ParameterSpec);
            elseif strcmpi(method,'project')
                numSim = 1;
            end
            enoughSamples = chkEnoughSamples(this,paramValues,numSim);
            while (~enoughSamples) && (ctIter<=this.MaxIterTwoFactors)
                ctIter = ctIter+1;
                [paramValuesInBoundariesOneIter,~] = sampleParametersWithinBoundaries(this,spec,ParameterBoundaries,ParameterNames,method);
                paramValuesInBoundariesOneIter = checkParametersWithinMixedBoundaries(this,MixedBoundaries,SignalNames,sigValues,ParameterNames,paramValuesInBoundariesOneIter);
                paramValues = [paramValues; paramValuesInBoundariesOneIter];
                enoughSamples = chkEnoughSamples(this,paramValues,numSim);
            end
            
            if strcmpi(method,'resample')
                paramValues = getRequiredSamples(this,paramValues,numSim,enoughSamples); 
                if (~iscell(sampleSpecValues(spec.SignalSpec)))
                    nParamValues = size(paramValues,1);
                    sigValues = repmat(sigValues,[nParamValues,1]);
                else
                    sigValues = sampleSpecValues(spec.SignalSpec); 
                end
            end
        end

        function [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries_DeterministicSignals_GriddedParameters(this,spec,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method)
            % Chirp/custom signals + gridded parameters      
            %
            % This block acquire gridded parameter values, remove
            % out-of-ParameterBoundaries parameter values, and then 
            % removes the out-of-MixedBoundaries parameter values. 

            [paramValues,~] = checkWithinSignalOrParameterBoundaries(this,ParameterBoundaries,ParameterNames, getValues(spec.ParameterSpec) );

            sigValues = sampleSpecValues(spec.SignalSpec);
            if iscell(sigValues)
                sigValuesArray = getValuesArray(spec.SignalSpec,sigValues);
                paramValues = checkParametersWithinMixedBoundaries(this,MixedBoundaries,SignalNames,sigValuesArray,ParameterNames,paramValues);
            else
                paramValues = checkParametersWithinMixedBoundaries(this,MixedBoundaries,SignalNames,sigValues,ParameterNames,paramValues);
            end

            % Check if there is at least one parameter combination to
            % meet boundaries with unaltered chirp/custom signals
            enoughSamples = ~isempty(paramValues);
            if enoughSamples && (~iscell(sigValues))
                nParamValues = size(paramValues,1);
                sigValues = repmat(sigValues,[nParamValues,1]);
            end
            if ~enoughSamples
                sigValues = [];
                paramValues = [];
            end
        end

        function [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries_RandomSignals_RandomParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method)
              ctIter = 0;
              nParameterSets = 0;
              numSim = getNumSim(spec.ParameterSpec);
              sigValuesAll = [];
              paramValuesAll = [];
              if strcmpi('resample',method)
                  while (nParameterSets<numSim) && (ctIter<this.MaxIterTwoFactors) 
                      [paramValues,~] = sampleParametersWithinBoundaries(this,spec,ParameterBoundaries,ParameterNames,method);
                      [sigValues,paramValues] = sampleSignalsWithinSignalAndMixedBoundaries(this,spec,SignalBoundaries,SignalNames,ParameterNames,paramValues,MixedBoundaries,method);
                      sigValuesAll = [sigValuesAll; sigValues];
                      paramValuesAll = [paramValuesAll; paramValues];
                      nParameterSets = size(paramValuesAll,1);
                      ctIter = ctIter+1;
                  end
                  enoughSamples = size(paramValuesAll,1)>=numSim;
                  paramValues = getRequiredSamples(this,paramValuesAll,numSim,enoughSamples);
                  numPulse = getNumPulse(spec.SignalSpec);
                  sigValues = getRequiredSamples(this,sigValuesAll,numSim*numPulse,enoughSamples);
              elseif strcmpi('project',method)
                  [paramValues,~] = sampleParametersWithinBoundaries(this,spec,ParameterBoundaries,ParameterNames,method);
                  [sigValues,paramValues] = sampleSignalsWithinSignalAndMixedBoundaries(this,spec,SignalBoundaries,SignalNames,ParameterNames,paramValues,MixedBoundaries,method);
                  enoughSamples = ~isempty(paramValues);
              end
        end
        
        function [sigValues,paramValues,enoughSamples] = sampleWithinBoundaries_RandomSignals_GriddedParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method)
            % Random signals + gridded parameters      
            %
            % This function acquires gridded parameter within 
            % ParamterBoundaries and iteratively random samples signals 
            % until there are enough pulses for each set of parameter 
            % values. 
            %
            % For any set of parameters, if no enough pulses can be
            % acquired, that row is removed. 
            
            % Get gridded parameters within ParameterBoundaries 
            [paramValues,~] = checkWithinSignalOrParameterBoundaries(this,ParameterBoundaries,ParameterNames, getValues(spec.ParameterSpec) );
            if isempty(paramValues)
                sigValues = [];
                enoughSamples = false;
                return
            end            
            if hasBoundaries(MixedBoundaries)              
                paramValuesIn = paramValues;
                [sigValues,paramValues] = sampleSignalsWithinSignalAndMixedBoundaries(this,spec,SignalBoundaries,SignalNames,ParameterNames,paramValuesIn,MixedBoundaries,method);
                enoughSamples = ~isempty(paramValues);                
            else
                [sigValues,enoughSamples] = sampleSignalsWithinBoundaries(this,spec,SignalBoundaries,SignalNames,method);      
            end       
            if strcmpi(method,'resample')                        
                sigValues = getRequiredSamples(this,sigValues,spec.SignalSpec.NumPulse,enoughSamples);
                sigValues = repmat(sigValues,[size(paramValues,1),1]);
                enoughSamples = (~isempty(paramValues)) && (~isempty(sigValues));
            else                     
                if ~iscell(sigValues) 
                    sigValues = repmat({sigValues},[size(paramValues,1),1]);   
                end
                enoughSamples = (~isempty(paramValues)) && (any(~cellfun(@isempty,sigValues)));
            end
            if ~enoughSamples          
                sigValues = [];
                paramValues = [];
            end
        end

        function [sigValuesInBoundaries,enoughSamples] = sampleSignalsWithinBoundaries(this,spec,SignalBoundaries,SignalNames,method)
            % This function samples random signals within signal-only
            % boundaries. Returns all feasible values if got more than
            % required. 
            % 
            % Returns a matrix of sigValuesInBoundaries, and a logical 
            % enoughSamples to indicate if enough samples have been
            % acquired (equivalent to can be). 
            % 
            % Returns empty sigValuesInBoundaries if no enough samples. 
            % 
            % In resample case, iteratively sample random signals until
            % enough samples have been acquired within signal-only
            % boundaries.
            % 
            % In projection case, sample once and return all in-boundary
            % samples. Repeat until at least one in-boundary sample has
            % been acquired. 
            
            numPulse = getNumPulse(spec.SignalSpec);
            enoughSamples = false;
            ctIter = 0;
            
            if strcmpi(method,'resample')   
                sigValuesInBoundaries = [];
                while (~enoughSamples) && (ctIter<=this.MaxIterSingleFactor)
                    ctIter = ctIter+1;
                    nump = this.OverSampling^ctIter * numPulse;
                    % Sample new signal values
                    sigValuesRandom = sampleSpecValues(spec.SignalSpec,nump);
                    % Remove out-of-boundary signal values
                    [sigValuesInBoundariesOneIter,~] = checkWithinSignalOrParameterBoundaries(this,SignalBoundaries,SignalNames,sigValuesRandom); 
                    % Add to sigValuesInBoundaries
                    sigValuesInBoundaries = [sigValuesInBoundaries; sigValuesInBoundariesOneIter];
                    enoughSamples = chkEnoughSamples(this,sigValuesInBoundaries,numPulse);
                    if ~enoughSamples
                        sigValuesInBoundaries = [];
                    end
                end
            elseif strcmpi(method,'project')
                while (~enoughSamples) && (ctIter<=this.MaxIterSingleFactor)
                    ctIter = ctIter+1;
                    nump = this.OverSampling^ctIter * numPulse;
                    sigValuesRandom = sampleSpecValues(spec.SignalSpec,nump);
                    [sigValuesInBoundaries,~] = checkWithinSignalOrParameterBoundaries(this,SignalBoundaries,SignalNames,sigValuesRandom);
                    enoughSamples = ~isempty(sigValuesInBoundaries);
                end
            end          
        end

        function [paramValuesInBoundaries,enoughSamples] = sampleParametersWithinBoundaries(this,spec,ParameterBoundaries,ParameterNames,method)
            
            % This function samples random parameters within parameter-only
            % boundaries. 
            % 
            % Returns a matrix of paramValuesInBoundaries, and a logical 
            % enoughSamples to indicate if enough samples have been
            % acquired (equivalent to can be). 
            % 
            % Returns empty paramValuesInBoundaries if no enough samples. 
            % 
            % In resample case, iteratively sample random parameters until
            % enough samples have been acquired within parameter-only
            % boundaries. 
            % 
            % In projection case, sample once and return all in-boundary
            % samples. Repeat until at least one in-boundary sample has
            % been acquired. 
            
            numSim = getNumSim(spec.ParameterSpec);
            enoughSamples = false;
            ctIter = 0;
            if strcmpi(method,'resample')
                paramValuesInBoundaries = [];
                while(~enoughSamples) && (ctIter<=this.MaxIterSingleFactor)
                    ctIter = ctIter+1;
                    nump = this.OverSampling^ctIter * numSim;
                    % Sample new parameter values
                    paramValuesRandom = sampleSpecValues(spec.ParameterSpec,nump);
                    % Remove out-of-boundary parameter values
                    [paramValuesInBoundariesOneIter,~] = checkWithinSignalOrParameterBoundaries(this,ParameterBoundaries,ParameterNames,paramValuesRandom);
                    % Add to paramValuesInBoundaries
                    paramValuesInBoundaries = [paramValuesInBoundaries; paramValuesInBoundariesOneIter];
                    enoughSamples = chkEnoughSamples(this,paramValuesInBoundaries,numSim);
                end
            elseif strcmpi(method,'project')
                while (~enoughSamples) && (ctIter<=this.MaxIterSingleFactor)
                    ctIter = ctIter+1;
                    nump = this.OverSampling^ctIter * numSim;
                    paramValuesRandom = sampleSpecValues(spec.ParameterSpec,nump);
                    [paramValuesInBoundaries,~] = checkWithinSignalOrParameterBoundaries(this,ParameterBoundaries,ParameterNames,paramValuesRandom);
                    enoughSamples = ~isempty(paramValuesInBoundaries);
                end
            end
        end
        
        function [sigValues,paramValues] = sampleSignalsWithinSignalAndMixedBoundaries(this,spec,SignalBoundaries,SignalNames,ParameterNames,paramValues,MixedBoundaries,method)
            
            % Initialize sigValuesTable: a 3-dimensional matrix of signal
            % values for each set of parameters. 
            % NumPulse x nSignals x nParameterSets
            NumPulse = spec.SignalSpec.NumPulse;
            nSignals = numel(SignalNames);
            nParameterSets = size(paramValues,1);
            sigValuesTable = nan(NumPulse, nSignals, nParameterSets);
            nSigValuesTable = zeros(nParameterSets,1); % Number of feasible signal values for each set of parameters. 
            enoughSamples = false(nParameterSets,1);

            % Iteratively sample signal values.
            % Do not sample and check for parameter sets that already have enough signal samples. 
            %
            % In projection case, there needs to be at least one sample for
            % each set of parameters, because we cannot change parameter
            % values during projection. 
            ctIter = 0;
            while (~all(enoughSamples)) && (ctIter<=this.MaxIterTwoFactors)
                ctIter = ctIter+1;
                sigValues = sampleSignalsWithinBoundaries(this,spec,SignalBoundaries,SignalNames,method); 
                for iParamSet = 1:nParameterSets
                    % Returns a vector of logicals, each one indicate if
                    % the signal values are within boundaries for that
                    % parameter set. 
                    if (nSigValuesTable(iParamSet) < NumPulse) && ~isempty(sigValues) 
                        statusRows = checkSignalsWithinMixedBoundaries(this,MixedBoundaries,SignalNames,sigValues,ParameterNames,paramValues(iParamSet,:));
                        % Add sigValues (or part of it) to sigValuesTable
                        inds = nSigValuesTable(iParamSet)+1;
                        inde = min( [nSigValuesTable(iParamSet)+sum(statusRows), NumPulse] );
                        sigValuesToAdd = sigValues(statusRows,:);
                        sigValuesToAdd = sigValuesToAdd(1:inde-inds+1,:);
                        sigValuesTable(inds:inde,:,iParamSet) = sigValuesToAdd;
                        nSigValuesTable(iParamSet) = inde;
                    end
                end
                enoughSamples = nSigValuesTable>=NumPulse;
            end
            % Returns:
            % sigValues and paramValues matrices, length of sigValues is NumPulse * feasible parameter sets(resample) 
            % sigValues cell, each cell corresponds to one paramValues row(project)
            if strcmpi(method,'resample')
                % Outputs signal and parameter matrices 
                paramValues = paramValues(enoughSamples,:);
                sigValuesTable = sigValuesTable(:,:,enoughSamples);
                sigValues = [];
                for iParamSet = 1:size(paramValues,1)
                    sigValues = [sigValues;squeeze(sigValuesTable(:,:,iParamSet))];
                end
            elseif strcmpi(method,'project')
                nonEmpty = nSigValuesTable>0;
                paramValues = paramValues(nonEmpty,:);
                nParameterSets = size(paramValues,1);
                sigValuesTable = sigValuesTable(:,:,nonEmpty);
                nSigValuesTable = nSigValuesTable(nonEmpty);
                sigValues = cell(nParameterSets,1);
                for iParamSet = 1:nParameterSets
                    sigValues{iParamSet} = squeeze(sigValuesTable(1:nSigValuesTable(iParamSet),:,iParamSet));
                end
            end
        end
    end


    methods (Access = private)
        %This method block contains second-level project methods, to
        %project under different scenarios
 
        function [OutputValues,enoughSamples] = project_SignalsOrParameters(this,SignalOrParameterBoundaries,SignalOrParameterNames,ValuesInBoundaries,InputValues,OutputValues)
            % This function projects signal points to signal-only boundaries. 
            % Or parameter samples to parameter-only boundaries. 
            %
            % SignalOrParameterBoundaries must have only signals or
            % parameters. 
            %
            % ValuesInBoundaries are the points to project towards. 
            % InputValues are points to be projected. 
            % OutputValues are in-boundaries points after projection. 

            numPulse = size(InputValues,1);
            for iPulse = 1:numPulse               
                refValue = pickPoint(this,ValuesInBoundaries,OutputValues);
                % While not in boundary, bisect on one inputSignalValue
                OneInputValue = InputValues(iPulse,:);
                OneInBoundariesValue = [];
                ct = 0;
                while isempty(OneInBoundariesValue) && ct<=this.MaxIterBisect
                    % Bisect towards the reference point until stepping
                    % within boundaries
                    OneInputValue = refValue + (OneInputValue-refValue)*(1/2)^ct;
                    [OneInBoundariesValue,~] = checkWithinSignalOrParameterBoundaries(this,SignalOrParameterBoundaries,SignalOrParameterNames,OneInputValue); 
                    ct = ct + 1;
                end
                OutputValues = [OutputValues;OneInBoundariesValue];
            end
            enoughSamples = chkEnoughSamples(this,OutputValues,numPulse);
        end

        function [paramValues,enoughSamples] = project_RandomParameters(this,SignalNames,sigValues,ParameterBoundaries,ParameterNames,MixedBoundaries,paramValuesInBoundaries,inputParamValues)
            % This function takes valid parameter set values
            % validParamValues,
            % takes sampled parameter sets to be projected
            % inputParamValues,
            % takes already projected paramValues, 
            % and outputs values that are valid from projection paramValues
            if iscell(sigValues)
                sigValues = getValuesArray(spec.SignalSpec,sigValues);
            end
            numSim = size(inputParamValues,1);
            paramValues = [];
            for iSim = 1:numSim
                inputParamValue = inputParamValues(iSim,:);
                refParamValue = pickPoint(this,paramValuesInBoundaries,paramValues);
                OneParamValue = [];
                % while not in boundary, bisect on one inputSignalValue
                ctIter = 0;
                while isempty(OneParamValue) && ctIter<=this.MaxIterBisect
                    % bisect towards the reference point until stepping
                    % within boundaries
                    OneParamValue = refParamValue + (inputParamValue-refParamValue)*(1/2)^ctIter;                
                    [OneParamValue,~] = checkWithinSignalOrParameterBoundaries(this,ParameterBoundaries,ParameterNames, OneParamValue );
                    OneParamValue = checkParametersWithinMixedBoundaries(this,MixedBoundaries,SignalNames,sigValues,ParameterNames,OneParamValue);
                    ctIter = ctIter + 1;
                end
                paramValues = [paramValues;OneParamValue];
            end
            enoughSamples = chkEnoughSamples(this,paramValues,numSim);
        end
        
        function [sigValues,enoughSamples] = project_RandomSignals(this,SignalBoundaries,SignalNames,ParameterNames,MixedBoundaries,sigValuesInBoundaries,inputSigValues,paramValues)
            numPulse = size(inputSigValues,1);
            sigValues = [];
            for iPulse = 1:numPulse
                refSigValue = pickPoint(this,sigValuesInBoundaries,sigValues);
                % While not in boundary, bisect on one inputSignalValue
                inputSigValue = inputSigValues(iPulse,:);
                sigValue = [];
                ctIter = 0;
                nParameterSets = size(paramValues,1);
                while isempty(sigValue) && ctIter<=this.MaxIterBisect
                    % Bisect towards the reference point until stepped into feasible regions
                    inputSigValue = refSigValue + (inputSigValue-refSigValue)*(1/2)^ctIter;
                    % Check within signals boundaries
                    [inputSigValue, ~] = checkWithinSignalOrParameterBoundaries(this, SignalBoundaries, SignalNames, inputSigValue);
                    if ~isempty(inputSigValue)
                        statusRows_last = true;      
                        % Check within mixed boundaries for all parameter sets
                        for i = 1:nParameterSets
                            statusRows = checkSignalsWithinMixedBoundaries(this,MixedBoundaries,SignalNames,inputSigValue,ParameterNames,paramValues(i,:));
                            statusRows = statusRows && statusRows_last;
                            statusRows_last = statusRows;
                            if ~statusRows
                                break
                            end
                        end
                    else
                        statusRows = false;
                    end
                    if statusRows
                        sigValue = inputSigValue;
                    else
                        sigValue = [];
                    end
                    ctIter = ctIter + 1;
                end
                sigValues = [sigValues;sigValue];
            end
            enoughSamples = chkEnoughSamples(this,sigValues,numPulse);
        end
        
        function [sigValues,paramValues,enoughSamples] = project_RandomSignals_RandomParameters(this,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,sigValuesInBoundaries,inputSigValues,paramValuesInBoundaries,inputParamValues)           
            % Initialize outputs        
            nSignals = numel(SignalNames);
            NumSim = size(inputParamValues,1);
            NumPulse = size(inputSigValues,1);
            MaxIterReselect = max(1,floor(NumPulse/10));
            sigValues = [];
            paramValues = [];      
            
            % Start with one parameter set, the parameter reference point is one parameter set. 
            % Fix this parameter direction, and the signal candidates are sigValuesInBoundaries associated with that parameter. 
            % 
            % First project parameters to meet ParameterBoundaries, step until inside. 
            %
            % For each signal set, project to meet SignalBoundaries and MixedBoundaries. 
            % If SignalBoundaries and MixedBoundaries cannot be met, discard this parameter set. 

            for iSim = 1:NumSim
                % Get reference point for one parameter set
                sigValuesInBoundariesAll = [sigValuesInBoundaries; sigValues];
                paramValuesInBoundariesAll = [paramValuesInBoundaries; paramValues];
                ind = randi([1, size(paramValuesInBoundariesAll,1)]);
                inds = NumPulse*(ind-1)+1;
                inde = NumPulse*ind;
                refParamValue = paramValuesInBoundariesAll(ind,:);
                sigRefValues = sigValuesInBoundariesAll(inds:inde,:);
                % Initialize for one parameter set
                ctParam = 0;
                statusAllSig = false(NumPulse,1);
                inputSigValuesOneParam = nan(NumPulse,nSignals);
                % At this point, parameter direction fixed and signal candidates found 
                while (~all(statusAllSig)) && (ctParam<=this.MaxIterBisect)
                    ctParam = ctParam+1;
                    inputParamValue = inputParamValues(iSim,:); 
                    inputParamValue = refParamValue + (inputParamValue-refParamValue)*(1/2)^ctParam;
                    [inputParamValue, ~] = checkWithinSignalOrParameterBoundaries(this, ParameterBoundaries, ParameterNames, inputParamValue);
                    inParamBoundaries = ~isempty(inputParamValue);

                    if ~inParamBoundaries
                        continue 
                    end       
           
                    for iPulse = 1:NumPulse                        
                        for iReselect = 1:MaxIterReselect                            
                            statusOneSig = false;
                            refSigValue = pickPoint(this,sigRefValues,sigRefValues);
                            ctSig = 0;
                            while ~statusOneSig && (ctSig<=this.MaxIterBisect)
                                ctSig = ctSig+1;
                                inputSigValue = inputSigValues(iPulse,:);
                                inputSigValue = refSigValue + (inputSigValue-refSigValue)*(1/2)^ctSig;
                                [inputSigValue, ~] = checkWithinSignalOrParameterBoundaries(this, SignalBoundaries, SignalNames, inputSigValue);
                                statusOneSig = ~isempty(inputSigValue);
                                if statusOneSig
                                    statusOneSig = checkSignalsWithinMixedBoundaries(this,MixedBoundaries,SignalNames,inputSigValue,ParameterNames,inputParamValue);
                                end
                            end   
                            if statusOneSig
                                break %No need to reselect a signal to project to if already within all boundaries 
                            end
                        end 
                        statusAllSig(iPulse) = statusOneSig;
                        if statusOneSig
                            inputSigValuesOneParam(iPulse,:) = inputSigValue;                          
                        else
                            break %If one signal set cannot meet SignalBoundaries, discard this parameter set and take the next step
                        end    
                    end
                end
                if all(statusAllSig)
                    sigValues = [sigValues; inputSigValuesOneParam];
                    paramValues = [paramValues; inputParamValue];
                end
            end
            enoughSamples = chkEnoughSamples(this,paramValues,NumSim);
        end
        
        function [sigValues,paramValues,enoughSamples] = projectWithinBoundaries_DeterministicSignals_RandomParameters(this,spec,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries)
            method = 'project';
            % sample at least one valid parameter set
            [sigValues,paramValuesInBoundaries,enoughSamples] = sampleWithinBoundaries_DeterministicSignals_RandomParameters(this,spec,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method);
            if enoughSamples    
                enoughSamples = chkEnoughSamples(this,paramValuesInBoundaries,getNumSim(spec));              
                paramValues = paramValuesInBoundaries;
                ctIter = 0;
                while ~enoughSamples && ctIter<=this.MaxIterBisect
                    % While not having samples specified by user,
                    % continue to sample and project. This is
                    % necessary in the case where projection did
                    % not come within boundary due to numerical/too
                    % many bisections. 
                    ctIter = ctIter + 1;
                    % numSim is the number of parameter sets that are still
                    % needed 
                    numSim = getNumSim(spec.ParameterSpec) - size(paramValues,1);
                    % Sample random parameters 
                    inputParamValues = sampleSpecValues(spec.ParameterSpec,numSim);
                    % Project only parameter sets
                    [paramValuesOneIter,enoughSamples] = project_RandomParameters(this,SignalNames,sigValues,ParameterBoundaries,ParameterNames,MixedBoundaries,paramValuesInBoundaries,inputParamValues); 
                    paramValues = [paramValues; paramValuesOneIter];
                end
            end
            paramValues = getRequiredSamples(this,paramValues,getNumSim(spec.ParameterSpec),enoughSamples);
            nParamValues = size(paramValues,1);        
            if strcmpi(spec.SignalSpec.TYPE,'CustomS')
                sigValues = sampleSpecValues(spec.SignalSpec);
            else
                sigValues = repmat(sigValues,[nParamValues,1]);
            end
        end

        function [sigValues,paramValues,enoughSamples] = projectWithinBoundaries_RandomSignals_RandomParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries)
            % Sample. True enoughSamples if there is at least one valid signal for at least one parameter set       
            method = 'project';           
            [sigValuesInBoundariesCell,paramValuesInBoundaries,enoughSamples] = sampleWithinBoundaries_RandomSignals_RandomParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method);                        
            [NumPulse,nParameterSets,sigValuesTable,nSigValuesTable] =  ...
                sigValuesInBoundariesCell2Table(this, spec, SignalNames, sigValuesInBoundariesCell, paramValuesInBoundaries); 
            NumSim = getNumSim(spec.ParameterSpec);           
            if enoughSamples   
                % For already sampled parameter sets, project to get enough
                % signal samples for each parameter set
                [sigValues,paramValues] = project_fill_RandomSignals_GriddedParameters(this, ...
                    spec, SignalBoundaries,SignalNames,ParameterNames,MixedBoundaries,...
                    sigValuesInBoundariesCell, paramValuesInBoundaries);
                % Project to get enough parameter sets
                enoughSamples = chkEnoughSamples(this,paramValues,NumSim);
                ctIter = 0;
                while ~enoughSamples && ctIter<=this.MaxIterBisect
                    ctIter = ctIter + 1;
                    % Project to get enough parameter sets, each with
                    % enough signals                     
                    inputSigValues = sampleSpecValues(spec.SignalSpec,NumPulse);
                    inputParamValues = sampleSpecValues(spec.ParameterSpec,NumSim-size(paramValues,1));
                    % Project signal and parameter values               
                    [sigValuesOneIter,paramValuesOneIter,~] = project_RandomSignals_RandomParameters(this,...
                        SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,...
                        sigValues,inputSigValues,paramValues,inputParamValues);
                    sigValues = [sigValues;sigValuesOneIter];
                    paramValues = [paramValues;paramValuesOneIter];
                    enoughSamples = chkEnoughSamples(this,paramValues,getNumSim(spec.ParameterSpec));
                end
            else
                paramValues = [];
                sigValues = [];
            end
            paramValues = getRequiredSamples(this,paramValues,getNumSim(spec.ParameterSpec),enoughSamples);
            sigValues = getRequiredSamples(this,sigValues,getNumSim(spec.ParameterSpec)*getNumPulse(spec.SignalSpec),enoughSamples);
        end

        function [sigValues,paramValues,enoughSamples] = projectWithinBoundaries_RandomSignals_GriddedParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries)
            method = 'project';
            % Sample feasible signal and parameter set. Return true enoughSamples if there will be enough signal values for at least one set of parameters.  
            [sigValuesInBoundariesCell,paramValuesInBoundaries,enoughSamples] = sampleWithinBoundaries_RandomSignals_GriddedParameters(this,spec,SignalBoundaries,SignalNames,ParameterBoundaries,ParameterNames,MixedBoundaries,method);
            % For each set of parameters, project until there are enough
            % signal samples. 
            if enoughSamples
                [sigValues,paramValues] = project_fill_RandomSignals_GriddedParameters(this, ...
                    spec, SignalBoundaries,SignalNames,ParameterNames,MixedBoundaries,...
                    sigValuesInBoundariesCell, paramValuesInBoundaries);
            else
                sigValues = [];
                paramValues = [];
            end
            if isempty(paramValues)
                enoughSamples = false;
            end
        end
    end
    
    
    methods (Access=private)
        %This block contains methods remove out-of-boundary samples,
        %third-level functions to sample

        function statusRowsAllBoundaries = checkSignalsWithinMixedBoundaries(this,MixedBoundaries,SignalNames,sigValues,ParameterNames,paramValues)
            % This checks whether signal values are within MixedBoundaries 
            % for one set of parameters. 
            %
            % Input 'sigValues' must be matrices, 'paramValues' must be a
            % vector for one parameter set. 
            % 
            % Output 'statusRowsAllBoundaries' is a vector of logical to
            % indicated whether in boundaries or not.

            numBoundaries = numel(MixedBoundaries.Factors);
            NumPulse = size(sigValues,1);
            statusRowsAllBoundaries = true(NumPulse,1);

            for iBoundary = 1:numBoundaries
                [factors,type,inequality,Data,~] = getProps(MixedBoundaries,iBoundary);
                values = getPoints(this,factors,SignalNames,sigValues,ParameterNames,paramValues,NumPulse);
                statusRows = checkOneBoundary(this,type,Data,values,inequality);
                statusRowsAllBoundaries = all([statusRowsAllBoundaries, statusRows],2);
            end
        end

        function paramValuesOut = checkParametersWithinMixedBoundaries(this,MixedBoundaries,SignalNames,sigValues,ParameterNames,paramValuesIn)
            % This function removes parameter values that are not within
            % MixedBoundaries. Signal values are not changed nor output.
            %
            % Input sigValues and paramValues must be matrices.
            
            numBoundaries = numel(MixedBoundaries.Factors);
            NumPulse = size(sigValues,1);
            paramValuesOut = paramValuesIn;

            for iBoundary = 1:numBoundaries
                paramStatusRows = true(size(paramValuesOut,1),1);
                [factors,type,inequality,Data,~] = getProps(MixedBoundaries,iBoundary);
                for i = 1:size(paramValuesOut,1)    
                    values = getPoints(this,factors,SignalNames,sigValues,ParameterNames,paramValuesOut(i,:),NumPulse);
                    statusRows = checkOneBoundary(this,type,Data,values,inequality);
                    paramStatusRows(i) = all(statusRows);
                end
                paramValuesOut = paramValuesOut(paramStatusRows,:);
                if isempty(paramValuesOut)
                    break
                end
            end
        end

        function [valuesOut, statusRows] = checkWithinSignalOrParameterBoundaries(this, boundaries, names, values)
            % This function removes signal values that are not within signal 
            % boundaries. 
            % 
            % Inputs are signal boundaries, SignalNames, sigValues that have 
            % not been checked against boundaries. 
            % 
            % Output, sigValuesOut, contains signal values that are within all 
            % boundaries that involve only signals. 
            % 
            % This function does the same for parameters. 
            % 
            % In one function call, inputs (boundaries, names, and values) must 
            % involve only signals, or only parameters.  
            numBoundaries = numel(boundaries.Factors);
            statusRows = true(size(values,1),1);
            for iBoundary = 1:numBoundaries
                [factors,type,inequality,Data,~] = getProps(boundaries,iBoundary);
                ind1 = find(strcmp(names,factors(1)));
                ind2 = find(strcmp(names,factors(2)));
                
                % Remove rows that are not in this boundary
                twoFactorValues = values(:,[ind1,ind2]);
                statusRows = checkOneBoundary(this,type,Data,twoFactorValues,inequality);
                values = values(statusRows,:);
            end
            valuesOut = values;
        end

        function statusRows = checkOneBoundary(this,type,Data,values,inequality)
            % This function checks whether points are within one specific 
            % elliptical or piecewise linear boundary.
            % 
            % Input 'values' is a n-by-2 matrix, representing n points. Each 
            % row is a point.  
            % 
            % Output 'statusRows' is a vector of logical, and is of length n. 
            % Each logical indicates whether the point is within the boundary.  
            if strcmpi(type,"elliptical")
                c = Data.CenterPoint;
                l = Data.AxesLengths;
                theta = Data.Rotation;            
                statusRows = false(size(values,1),1);
                for iRow = 1:size(values,1)
                    x_shifted = values(iRow,1)-c(1);
                    y_shifted = values(iRow,2)-c(2);
                    x_rotated =  x_shifted*cosd(theta) - y_shifted*sind(theta);
                    y_rotated =  x_shifted*sind(theta) + y_shifted*cosd(theta);
                    if strcmpi(inequality,"<=")
                        statusRows(iRow) = (x_rotated/l(1))^2 + (y_rotated /l(2))^2 <= 1;
                    elseif strcmpi(inequality,">=")
                        statusRows(iRow) = (x_rotated/l(1))^2 + (y_rotated /l(2))^2 >= 1;
                    end 
                end
            elseif strcmp(type,"piecewiselinear")
                v = Data.Vertices;              
                statusRows = false(size(values,1),1);
                for iRow = 1:size(values,1)
                    [in,on] = inpolygon(values(iRow,1),values(iRow,2),v(:,1),v(:,2));
                    if strcmpi(inequality,"<=")
                        statusRows(iRow) = in||on;
                    elseif strcmpi(inequality,">=")
                        statusRows(iRow) = (~in)||on;
                    end
                end
            else
                %for debug and extra protection. A boundary should not have
                %any types other than elliptical and piecewiselienar. 
                error('Invalid boundary type')
            end
        end
        
    end

    methods (Access=private)
        % This method block contains private supporting functions 

        function values = getPoints(this,factors,SignalNames,sigValues,ParameterNames,paramValues,NumPulse)
            %This function gets points to be checked for a mixed boundary.
            indSig = [find(strcmp(SignalNames,factors(1))), find(strcmp(SignalNames,factors(2)))];
            indParam = [find(strcmp(ParameterNames,factors(1))), find(strcmp(ParameterNames,factors(2)))];
            oneSigValues = sigValues(:,indSig);
            swap = isempty(find(strcmp(SignalNames,factors(1)))); %A value of true indicates the first factor is a parameter     
            values = [oneSigValues, repmat(paramValues(:,indParam),[NumPulse,1])]; %Assumes first factor is a signal
            if swap
                values = values(:, [2 1]);
            end
        end

        function setValues(this,sigValues,paramValues,enoughSamples)
            this.SignalValues = sigValues;
            this.ParameterValues = paramValues;
            this.EnoughSamples = enoughSamples;
            notify(this,'DataChanged');
        end

        function enoughSamples = chkEnoughSamples(this,values,num)
            %decide if there are enough signals/parameters samples
            enoughSamples = size(values,1) >= num;
        end
        
        function values = getRequiredSamples(this,values,nump,enoughSamples)
            %need to the signal and parameter values matrices due to 
            %oversampling
            if enoughSamples
                values = values(1:nump,:);
            else
                values = [];
            end
        end

        function refValue = pickPoint(this,validValues,values)
            % randomly select a valid point from valid points and
            % existing projected points
            % point could be only signals or parameters, or both factors
            nValid = size(validValues,1);
            nValues = size(values,1);
            n = nValid + nValues;
            if n>1
                ind = randi([1 n]);
                if ind<=nValid
                    refValue = validValues(ind,:);
                else
                    refValue = values(ind-nValid,:);
                end
            else
                refValue = validValues;
            end
        end

        function [NumPulse,nParameterSets,sigValuesTable,nSigValuesTable] =  ...
                sigValuesInBoundariesCell2Table(this, spec, SignalNames, sigValuesInBoundariesCell, paramValuesInBoundaries) 
            NumPulse = spec.SignalSpec.NumPulse;
            nSignals = numel(SignalNames);
            nParameterSets = size(paramValuesInBoundaries,1);
            nSigValuesTable = zeros(nParameterSets,1);
            sigValuesTable = nan(NumPulse,nSignals,nParameterSets);
            for iParameterSet = 1:nParameterSets
                nSignalsInBoundaries = size(sigValuesInBoundariesCell{iParameterSet},1);
                nSigValuesTable(iParameterSet) = nSignalsInBoundaries; % Number of feasible signal values for each set of parameters. 
                sigValuesTable(1:nSignalsInBoundaries,:,iParameterSet) = sigValuesInBoundariesCell{iParameterSet};                   
            end
        end
        
        function [sigValues,paramValues] = project_fill_RandomSignals_GriddedParameters(this, spec, SignalBoundaries,SignalNames,ParameterNames,MixedBoundaries,sigValuesInBoundariesCell, paramValuesInBoundaries)
            [NumPulse,nParameterSets,sigValuesTable,nSigValuesTable] =  ...
                sigValuesInBoundariesCell2Table(this, spec, SignalNames, sigValuesInBoundariesCell, paramValuesInBoundaries); 
            enoughSamples = nSigValuesTable>=NumPulse;
            ctIter = 0;
            while (~all(enoughSamples)) && (ctIter<=this.MaxIterTwoFactors)
                ctIter = ctIter+1;
                inputSigValues = sampleSpecValues(spec.SignalSpec,(NumPulse-min(nSigValuesTable))*this.OverSampling);                  
                for iParamSet = 1:nParameterSets
                    sigValuesInBoundaries = sigValuesInBoundariesCell{iParamSet};
                    inputNumPulse = NumPulse - nSigValuesTable(iParamSet);
                    inputSigValuesOneParamSet = inputSigValues(1:inputNumPulse,:);
                    % project only signals                       
                    paramValue = paramValuesInBoundaries(1,:);
                    [sigValues,~] = project_RandomSignals(this,SignalBoundaries,SignalNames,ParameterNames,MixedBoundaries,sigValuesInBoundaries,inputSigValuesOneParamSet,paramValue);                                            
                    inds = nSigValuesTable(iParamSet)+1;
                    inde = min( [nSigValuesTable(iParamSet)+size(sigValues,1), NumPulse] );
                    sigValuesToAdd = sigValues(1:inde-inds+1,:);
                    sigValuesTable(inds:inde,:,iParamSet) = sigValuesToAdd;
                    nSigValuesTable(iParamSet) = inde;
                end
                enoughSamples = nSigValuesTable>=NumPulse;
            end                
            paramValues = paramValuesInBoundaries(enoughSamples,:);
            sigValuesTable = sigValuesTable(:,:,enoughSamples);
            sigValues = [];
            for iParamSet = 1:size(paramValues,1)
                sigValues = [sigValues;squeeze(sigValuesTable((1:NumPulse),:,iParamSet))];
            end
        end
    end

end