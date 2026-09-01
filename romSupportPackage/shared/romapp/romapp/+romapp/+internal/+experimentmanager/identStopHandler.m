function stop = identStopHandler(monitor,maxIter,iterOffset,modelType,varargin)
%Callback function to display and monitor training for ident solvers
%

%   Copyright 2023-2026 The MathWorks, Inc.

    if strcmpi(modelType,"NLARX")
        %Inputs are monitor,max,iterOffset,modelType,varargin
        %Update monitor object with progress
        info = varargin{1};
        stage = varargin{2};
        iter = info.Iteration;

        if isfield(info,'resnorm')
           cost = info.resnorm;
        elseif isfield(info,'fval')
           cost = info.fval;
        elseif isfield(info,'CurrentCost')
           cost = info.CurrentCost;
        elseif isfield(info,'Cost')
           cost = info.Cost;
        else
           romapp.internal.resources.error('errUnexpected','Unknown solver progress format')
        end
        
        if strcmp(stage,'iter')
            monitor.Progress = round(100*iter/maxIter);
            recordMetrics(monitor,iter+iterOffset,TrainingLoss=cost)
        end
        
        %Handle any user stop events
        stop = monitor.Stop;
    
    elseif strcmpi(modelType,"NSS")
        %Inputs are monitor,maxEpoch,0(epochOffset),varargin
        %Update monitor object with progress
        info = varargin{1};
        monitor.Progress = round(100*info.Epoch/maxIter);
        recordMetrics(monitor,info.Epoch,TrainingLoss=info.Loss)
    
        %Handle any user stop events
        stop = monitor.Stop;
    end
end
% LocalWords:  fval resnorm gn gna nss