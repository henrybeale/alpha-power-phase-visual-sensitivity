% % adaptive method using accelerated stochastic approximation 
% function [x_n] = ASA(x_n)
% persistent nminus1 nreversals
% 
% if isempty(nreversals)
%     nreversals = 0;
% end
% 
% C = .2;  % initial step size
% targ_prob = .75; 
% 
% % look for reversal
% if x_n ~= nminus1
%     nreversals = nreversals + 1;
% end
% nminus1 = x_n;
% 
% % update rule
% x_n = x_n - C / (nreversals+1) * (hit - targ_prob);

classdef ASA
    % This uses an adaptive algorhythm to update a stepsize change in
    % stimulus intensity depending on behavioural success/failure, such
    % that a percentage of success is targeted. 
    properties
        step_size = .3  % initial step size
        start_val = .5
        targ_prob = .75  % percent correct to target
        stop_rule = []

        nrevers = 0
        intens = []
        history = []
        steps = []
        db_steps
    end

    methods
        function obj = ASA(varargin)
            % parse input options on construction
            for n = 1: 2: length(varargin)
                assert(isprop(obj, varargin{n}), [varargin{n}, ' not found (spelling?)'])
                obj.(varargin{n}) = varargin{n+1};
            end
            
            % init history
            obj.intens = [obj.start_val];
            obj.steps = [obj.step_size];
            obj.db_steps = [];
        end
        
        function [obj, next] = update(obj, hit)
            % calculate the next stimulus level
            if length(obj.intens) <= 2
                delta = obj.step_size / length(obj.intens) * (hit - obj.targ_prob);
                
            else
                % count reversals 
                if hit ~= obj.history(end)
                    obj.nrevers = obj.nrevers + 1; 
                end

                delta = obj.step_size / (obj.nrevers+2) * (hit - obj.targ_prob);
            end

            next = obj.intens(end) - delta; 
            
            % correct for this ... 
            next = abs(next);

            % add this response to the history
            obj.history  = [obj.history, hit];
            obj.intens   = [obj.intens, next];
            obj.steps    = [obj.steps, delta];
            obj.db_steps = [obj.db_steps, 10*(log10(next) - log10(obj.intens(end-1)))];
        end

        function [stop] = check_stop(obj)
            if ~isempty(obj.stop_rule)
                if abs(obj.db_steps(end)) < obj.stop_rule
                    stop = 1;
                else
                    stop = 0; 
                end
            end
        end

        function [res] = nback_average(obj, n)
            % return the average stimulus value in the last N trials of the
            % process
            res = mean(obj.intens(end-n-1: end-1));
        end
    end
    methods(Static)
        function obj = loadobj(s)
            % Allows a saved object to be loaded back as an object. 
            obj = s; 
        end
    end
end

