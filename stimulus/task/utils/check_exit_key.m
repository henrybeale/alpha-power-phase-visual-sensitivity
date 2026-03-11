function eyestatus = check_exit_key(wh)
% check for exit, pause if pause key is pressed.

eyestatus = 0; % request eye calibration
[~, ~, keyCode] = KbCheck;

if keyCode(KbName('q'))
    sca
    evalin('base', 'save([info.beh_file])')  % save data in base workspace
    error('Exit: manual.')  % a cryptic message to avoid suspicion
    
elseif keyCode(KbName('e'))
    eyestatus = 1; 
    
elseif keyCode(KbName('p'))
    % pause. if you press 'p' it will pause here until you press it again.
    Beeper('low')
    t0_p = datetime;
    WaitSecs(.5);
    [~, ~, keyCode] = KbCheck;

    while ~keyCode(KbName('p'))
        [~, ~, keyCode] = KbCheck;
        text = ['Paused. Press "p" to resume. ', char(datetime-t0_p)];
        DrawFormattedText(wh, text, 'center', 'center', 0);
        Screen('Flip', wh);
    end
    
    WaitSecs(.2);
end
