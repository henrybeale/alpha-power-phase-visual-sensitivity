% Contrast localising experiment using Bayesian adaptive method to estimate
% psychometric function parameters online and sample contrast values around
% the threshold. Stimuli are only presented on one side in this version. 

% get things going
clear
eye = 1;
eeg = 1; 
% task = 'contrLocalBadptBurnin';
task = 'contrLocalBadpt';

addpath(genpath('./task'))  % sub-functions

% create participant and session information
[info, eye, eeg] = setup_participant(task, eye, eeg);  

% use a bayesian adaptive staircase
try
    B = Badpt('parms', './data/precomp4_quick.mat');
catch
    % create parameter space
    thr = linspace(.1, .7, 21);  
    slo = linspace(log(1/100), log(1/1.5), 21);
    lam = linspace(.01, .1, 11);
    gam = linspace(.2, .8, 21);
    
    % create a stimulus space
    stim = linspace(1e-3, 1, 100);

    % psychometric function form 
    PF = @(th, x) th(4) + (1 - abs(th(3)) - th(4)) * normcdf(log10(x), log10(th(1)), exp(th(2)));
    fun = @(r, th, x) binopdf(r, 1, PF(th, x));

    B = Badpt('parms', {'thr', thr, 'slo', slo, 'lam', lam, 'gam', gam}, ...
                'stim', stim, 'fun', fun);
    save(B, './data/precomp4_quick.mat')
end

% set up the (t)rial structure
t.max_trials = 360; 
if info.ses_num == 1 && info.run_num == 1
    t.n_stair_trials = 150;  % number of staircasing trials
    usePost = 0;  % use the posterior from the previous saved session
else
    t.n_stair_trials = 10; 
    usePost = 1; 
end
t.pct_stair = 10;  % proportion of trials thrown selected by look-ahead algorithm

% confirm settings with a dialog box
[t.max_trials, t.n_stair_trials, disp_side, usePost, t.pct_stair] = confirm_variables('Max trials', t.max_trials, ...
    'Adaptive trials', t.n_stair_trials, 'Test side', 'left', 'Use posterior', usePost, 'Percent adaptive', t.pct_stair);
disp_side = find(contains({'left','right'}, disp_side));

% override previously loaded prior and use the rectangular default
if ~usePost
    resetPrior(B);
else
    fprintf('Loading posterior ... \n')
    assert( isfield(info, 'last_file'), 'no previous session found')
    load([info.last_file.folder, './', info.last_file.name], 'posterior');
    B.p = posterior;
end

% setup pseudorandom balanced response options and orientations
[ropts, oris] = BalanceTrials(t.max_trials, 1, 1:2, [-45,45]);

% setup control of sampling strategy on each trial
trial_control = repmat({'lookahead'}, 1, round(t.pct_stair/100 * (t.max_trials-t.n_stair_trials)));
trial_control = cat(2, trial_control, repmat({'normal'}, 1, (t.max_trials-t.n_stair_trials) - length(trial_control)));
trial_control = cat(2, repmat({'adaptive'}, 1, t.n_stair_trials), Shuffle(trial_control));

% open a window
stim0_setup  % some variables created here

% setup peripherals
if eye
    ET = EyeTracker(w,info);
    calibrate(ET);
    startRecording(ET);
end

if eeg
    setup_eeg
end

% mark the beginning of data for this task 
if eye
    Eyelink('message', 'TRIG_37'); % task specific code
end

if eeg
    io64(ioObj, port_addr, 37);  
    WaitSecs(.005); 
    io64(ioObj, port_addr, 0);
end

% preallocate trial data
t.contr = nan(1, t.max_trials);
t.bads = nan(1, t.max_trials);
t.resp = nan(1, t.max_trials);
t.RT = nan(1, t.max_trials);
t.corr_resp = nan(1, t.max_trials);
t.meas_disp_time = nan(1, t.max_trials);
t.breaks = nan(1, t.max_trials);

% storage
parm_log = nan(length(B.parms_ID), t.max_trials);  % to store the parameter estimates
compute_time = nan(t.max_trials,1);

% get things started
info.start_time = GetSecs; 
WaitSecs(10);

try
    for i = 1: t.max_trials

        % intertrial interval at the start
        ITI = s.time.ITI(1) + rand*s.time.ITI(2) + GetSecs;
        iti_start = GetSecs; 

        % select the stimulus value via various strategies
        if strcmp(trial_control{i}, 'adaptive') || strcmp(trial_control{i}, 'lookahead')
            % use the bayesian lookahead (with marginalised nuisance parms)
            g.contr = selectStim(B, {'lam', 'gam'});
        elseif strcmp(trial_control{i}, 'normal')
            % sample from a normal distribution in log contrast, with
            % current parameter estimates for location and s.d.
            g.contr = 10^(randn*exp(parm_log(2,i-1)) + log10(parm_log(1,i-1)));
            g.contr = B.stim(dsearchn(B.stim', g.contr));  % pick from precomputed contrasts
        end
        
        % store the computation time 
        compute_time(i) = GetSecs - iti_start;

        % wait remaining time (if any)
        while GetSecs <= ITI
            check_exit_key(wh); 
        end
        
        % trial setup
        corr_resp = ropts(i);  % index: 1 = left, 2 = right, w.r.t. criterion
        corr_resp_key = s.resp_opts(corr_resp); 
        mark_ln = mark_lns{disp_side};
        
        g.pos = g.rects{disp_side}{corr_resp};
        g.phase = rand*360; 
        g.ori = oris(i);  % random left/right tilt

        % display
        disp_trial2
    
        % record some things from this trial
        t.contr(i) = g.contr; 
        t.bads(i) = trialBad; 
        t.resp(i) = resp; 
        t.RT(i) = RT; 
        t.corr_resp(i) = corr_resp; 
        t.meas_disp_time(i) = measured_stim_time;


        % update the estimator and store the current parameter estimates
        if ~isnan(resp)
            update(B, resp, g.contr); 
        end
        [~, parm_log(:,i)] = estimateParms(B);  % pse, slope, lapse
      
        % send an updated message to the control room 
        if eye
            tmp_secs = GetSecs - info.start_time;
            boothStatusMessage(ET, sprintf('%02d:%02d, t=%d, resp %d, contr %.2f, [pse: %.2f, slo: %.1f, guess %.2f, lapse: %.2f]',...
                floor(tmp_secs/60),floor(tmp_secs - floor(tmp_secs/60)*60),...
                i,resp,g.contr,parm_log(1,i),1/exp(parm_log(2,i)),parm_log(4,i),parm_log(3,i)));
        end
    
        % have a break every two minutes 
        breakTime  
    end 

catch ME 
    % close and save
    sca
    RestoreCluts
    fprintf('Exited due to an error:\n')
    if eye
        saveData(ET)
    end

    save(info.beh_file)
    
    rethrow(ME)
end

% finish up
Beeper('med',.2,.05); Beeper('low',.2,.05); 
Screen('CloseAll'); RestoreCluts;
info.ses_time = GetSecs - info.start_time;

% mark data end and save 
if eeg
    io64(ioObj, port_addr, 32);  % mark the end of data
    WaitSecs(.005); 
    io64(ioObj, port_addr, 0);
end

if eye
    Eyelink('message', 'TRIG_32')
    saveData(ET)
end

posterior = B.p;  % pull out variable
B.prob = 'removed for space';  % flush memory hungry variable
save(info.beh_file)
fprintf('Done in %.1f minutes.\n', info.ses_time/60)


%% plotting
% track selected contrasts and estimated pse 
figure; subplot 221; hold on
ind = strcmp(trial_control, 'normal');
scatter(find(ind), t.contr(ind), 'filled', 'DisplayName', 'Around threshold')

ind = ismember(trial_control, {'adaptive', 'lookahead'});
scatter(find(ind), t.contr(ind), 'filled', 'DisplayName', 'Bayes algorithm')

% scatter(1:t.n_stair_trials, t.contr(1:t.n_stair_trials), 'filled', 'DisplayName', 'Adaptive Trials')
% scatter(t.n_stair_trials+1:t.max_trials, t.contr(t.n_stair_trials+1:i), 'filled', 'DisplayName', 'Gaussian Samples')
plot(1:i, parm_log(1,1:i), '.-', 'DisplayName', 'Estimated PSE')

legend
ylabel('Contrast')
xlabel('Trial')
title('Displayed Contrasts')

% plot the pse by slope posterior
subplot 222
surf(B.parms.('slo'), B.parms.('thr'), sum(B.p,[3,4]), 'LineStyle', 'none')
view(2)
xlabel('slope')
ylabel('PSE'); title('Posterior Density')
zlabel('probability density')

% online slope estimate
subplot 223
plot(1./exp(parm_log(2,:)))
xlabel('Trial'); ylabel('Slope'); title('Estimated Slope')

% contrast sampling distribution
subplot 224 
histogram(t.contr, 30)
xline(parm_log(1,i), 'linewidth', 2)
xlabel('Contrast')
ylabel('Density'); title('Density of Selected Contrasts')
sgtitle(strrep(info.f_name, '_', ' '))

% marginal probability for each parameter
figure
for p = 1 : numel(B.parms_ID)
    subplot(2,2,p)
    margix = find(~contains(B.parms_ID, B.parms_ID{p}));
    plot(B.parms.(B.parms_ID{p}), squeeze(sum(B.P, margix)));
    xlabel(B.parms_ID{p})
end
sgtitle('Parameter probabilities')

% timing
figure  % look ahead computation time
subplot(1,2,1)
% histogram(compute_time, 50)
scatter(1:i, compute_time(1:i), 'filled')
xlabel('compute time'); title('look ahead computation'); 

subplot(1,2,2)  % stimulus presentation times
plot(t.meas_disp_time)
xlabel('trial'); ylabel('ms'); title('stimulus duration times')

%% plot response by contrast 
figure;
trls = 1:i; 
hold on 
scatter(trls(t.resp == 1), t.contr(t.resp == 1), 'filled', 'markerfacealpha', .6)
scatter(trls(t.resp == 0), t.contr(t.resp == 0), 'filled', 'markerfacealpha', .6)
yline(mean(parm_log(1,i-10:i)), 'linewidth', 2);
xlabel('trial'); ylabel('sampled contrast'); legend({'hit','miss', 'pse'}); title('Performance')
