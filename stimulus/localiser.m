% P
clear;
eye = 1; 
eeg = 1; 
task = 'contrLocalSource';
disp_side = 1;

% pop-up participant id and options
[info, eye, eeg] = setup_participant(task, eye, eeg);

% build stimulus locations, gabor, open window as per specs
stim0_setup

% override experiment display (s)ettings
s.time.stim = .25; 
s.time.fix = [1,.5]; % no fixation delay
s.time.respmax = 1; 
s.time.ITI = []; 
s.time.fix_blink = .05;

s.resp_opts = KbName('space');

% set the contrast of the gabor
g.contr = .8; 

% create trial structure
t.max_trials = 120; 

% present target on 10% of trials
pc_targs = .1; 
fix_change_trials = Shuffle((1:t.max_trials) <= (pc_targs * t.max_trials));

% setup pseudorandom balanced spatial intervals and orientations
[stim_intv, oris] = BalanceTrials(t.max_trials, 1, 1:2, [-45,45]);

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
    Eyelink('message', 'TRIG_39')
end

if eeg
    io64(ioObj, port_addr, 39); 
    WaitSecs(.005); 
    io64(ioObj, port_addr, 0);
end

% instructions
DrawFormattedText(wh, 'Press SPACE when the cross flickers white.\nAny key to continue', 'center', 'center')
Screen('Flip', wh)
KbWait; Screen('Flip', wh);

info.start_time = GetSecs; 
WaitSecs(5);  % time to prepare

try 
    for i = 1: t.max_trials

        % trial setup 
        mark_ln = mark_lns{disp_side}; 
        
        % set gabor properties for this trial
        g.pos = g.rects{disp_side}{stim_intv(i)};
        g.phase = rand*360; 
        g.ori = oris(i);  % random left/right tilt

        disp_trial_localiser
    
        % record outputs
        t.contr(i) = g.contr; 
        t.resp(i) = resp; 
        t.RT(i) = RT; 
        t.corr_resp(i) = fix_change_trials(i);
        t.ori(i) = g.ori;

        breakTime
    end

    Screen('CloseAll'); RestoreCluts;
    info.ses_time = GetSecs - info.start_time; 
catch ME
    % send triggers
    if eye
        Eyelink('message', 'TRIG_32')
    end
    
    if eeg
        io64(ioObj, port_addr, 32);  % mark the beginning of data
        WaitSecs(.005); 
        io64(ioObj, port_addr, 0);
    end

    sca
    if eye
        saveData(ET)
    end
    rethrow(ME)
end

% send triggers
if eye
    Eyelink('message', 'TRIG_32')
end

if eeg
    io64(ioObj, port_addr, 32);  % mark the beginning of data
    WaitSecs(.005); 
    io64(ioObj, port_addr, 0);
end

% saving
if eye
    saveData(ET)
end

save(info.beh_file)
fprintf('Done in %.1f minutes.\n', info.ses_time/60)



