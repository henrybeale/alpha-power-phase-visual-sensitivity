% stimulus presentation 

trialBad = 0;  % keep track of whether the stimulus was responded to
resp = nan; RT = nan; 
Priority(w.max_priority);

% initial flip 
% drawPosMarks(wh, mark_ln, s)
vbl = Screen('Flip', wh);

request_eye_calib = 0; 

% fixation
fix_time = s.time.fix(1) + rand*s.time.fix(2);
for f = 1: round(fix_time / w.ifi)
    drawFix(wh, fix_lines, s)
    drawPosMarks(wh, mark_ln, s)
    vbl = Screen('Flip', wh, vbl + .5 * w.ifi);
    
    if f == 1  % send events
        if eye
            Eyelink('message', 'TRIG_1');
        end
        if eeg
            io64(ioObj, port_addr, 1);
            WaitSecs(.001);
            io64(ioObj, port_addr, 0);
        end
    end
    
    % check the exit key and optional recalibration after trial
    if check_exit_key(wh)
        request_eye_calib = 1; 
    end
end

% display target
for f = 1: round(s.time.stim / w.ifi)
    drawGabor(wh,g)
    drawFix(wh, fix_lines, s)
    drawPosMarks(wh, mark_ln, s)
    vbl = Screen('Flip', wh, vbl + .5 * w.ifi);

    % record stimulus onset time
    if f == 1
        time_0 = vbl; 
        if eye
            Eyelink('message', 'TRIG_2');
        end
        if eeg
            io64(ioObj, port_addr, 2);
            WaitSecs(.001);
            io64(ioObj, port_addr, 0);
        end
    end
end

% response getting
drawFix(wh, fix_lines, s)
drawPosMarks(wh, mark_ln, s)
vbl = Screen('Flip', wh, vbl + .5*w.ifi);
measured_stim_time = vbl - time_0;  % double check this is the right place
get_resp

% deal with unseen stimulus (show red fixation and prompt response)
if trialBad
    drawFixBlue(wh, fix_lines, s)
    drawPosMarks(wh, mark_ln, s)
    time_0 = Screen('Flip', wh);
    
%     Beeper('med');
    get_resp_infwait  % run again to gains response and code it
end

% trial end
% drawPosMarks(wh, mark_ln, s)
Screen('Flip', wh);
Priority(w.old_priority);

if eeg
    io64(ioObj, port_addr, 0);
end

if eye && request_eye_calib
    calibrate(ET); 
    startRecording(ET);
end

% % ITI
% ITI = s.time.ITI(1) + rand*s.time.ITI(2) + GetSecs;
% while GetSecs <= ITI
%     check_exit_key(wh);
% end
