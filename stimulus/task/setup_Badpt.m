% Define here the paramater space for the bayesian adaptive method. Run
% this to precompute model likelihoods that can be loaded during the
% experimental sessions. 

% create two parameter spaces
thr = linspace(.05, .7, 50); 
slo = linspace(.008, .15, 50);
lam = linspace(.01, .06, 12);

% create a stimulus space
stim = logspace(log10(.05), log10(.8), 100);

% load the adaptive staircase object. it will use the default flat prior
% and cumulative gaussian psychometric function.
B = Badpt('parms', {'thr', thr, 'slo', slo, 'lam', lam}, 'stim', stim);
save(B, './output/precompBadpt0.mat')

% clear thr slo lam stim