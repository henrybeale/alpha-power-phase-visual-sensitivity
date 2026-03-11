% stimulus presentation 

trialBad = 0;  % keep track of whether the stimulus was responded to
resp = nan; RT = nan; 
Priority(w.max_priority);

% initial flip 
drawFix(wh, fix_lines, s)
drawPosMarks(wh, mark_ln, s)
vbl = Screen('Flip', wh);

% fixation
fix_time = s.time.fix(1) + rand*s.time.fix(2);
for f = 1: round(fix_time / w.ifi)
    drawFix(wh, fix_lines, s)
    drawPosMarks(wh, mark_ln, s)
    vbl = Screen('Flip', wh, vbl + .5 * w.ifi);
    
    if f == 1  % send events
        if eye
            Eyelink('message', 'TRIG_1')
        end
        if eeg
            io64(ioObj, port_addr, 1);
            WaitSecs(.001);
            io64(ioObj, port_addr, 0);
        end
    end
    check_exit_key(wh);
end

% display target 
for f = 1: round(s.time.fix_blink/w.ifi) + 1
    drawGabor(wh,g)

    % blink the fixation if required
    if fix_change_trials(i) && f <= round(s.time.fix_blink/w.ifi)
        s.fix.col = 1; % set to lighter shade
    else
        s.fix.col = 0;  % set to black
    end

    drawFix(wh, fix_lines, s)

    drawPosMarks(wh, mark_ln, s)
    vbl = Screen('Flip', wh, vbl + .5 * w.ifi);

    % record stimulus onset time
    if f == 1
        time_0 = vbl; 
        if eye
            Eyelink('message', 'TRIG_2')
        end
        if eeg
            io64(ioObj, port_addr, 2);
            WaitSecs(.001);
            io64(ioObj, port_addr, 0);
        end
    end
end

% keyboard response
[keyIsDown, keyTime, keyCode] = KbCheck; 

% wait for response up to max resp time
while (GetSecs <= s.time.respmax + time_0) && ~any(keyCode(s.resp_opts))
    [keyIsDown, keyTime, keyCode] = KbCheck; 

    % offset the gabor 
    if (GetSecs - time_0) >= s.time.stim
        drawPosMarks(wh, mark_ln, s)
        drawFix(wh, fix_lines, s)
        vbl = Screen('Flip', wh, vbl + .5*w.ifi);
    end
end

if ~any(keyCode(s.resp_opts))  % space bar not pressed
    resp = 0;  % no response
else  % space bar pressed
    RT = keyTime - time_0;
    resp = 1;  % 1 if correct resp
    
    if eye
        Eyelink('message', 'TRIG_3')
    end
    if eeg
        io64(ioObj, port_addr, 3);
        WaitSecs(.001);
        io64(ioObj, port_addr, 0);
    end
end


% response getting
% drawFix(wh, fix_lines, s)
% drawPosMarks(wh, mark_ln, s)
% vbl = Screen('Flip', wh, vbl + .5*w.ifi);
measured_stim_time = vbl - time_0;  % double check this is the right place
% get_resp

% % deal with unseen stimulus (show red fixation and prompt response)
% if trialBad
%     drawFixRed(wh, fix_lines, s)
%     drawPosMarks(wh, mark_ln, s)
%     time_0 = Screen('Flip', wh);
%     
%     Beeper('med');
%     get_resp  % run again to gain response and code it
% end

% trial end
drawPosMarks(wh, mark_ln, s)
drawFix(wh, fix_lines, s)
Screen('Flip', wh);
Priority(w.old_priority);

if eeg
    io64(ioObj, port_addr, 0);
end

% % ITI
% ITI = s.time.ITI(1) + rand*s.time.ITI(2) + GetSecs;
% while GetSecs <= ITI
%     check_exit_key(wh);
% end
