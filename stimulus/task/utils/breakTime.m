% create breaks every two minutes. shows a message and the break time and
% waits for key press.

block_length_sec = 2*60;

% look for an existing timer variable, create if not found. 
if ~exist('break_time', 'var') || i == 1
    break_time = GetSecs;  % time zero
end

if GetSecs >= (break_time + block_length_sec) % time > than 2 min since timer start
    Beeper('med'); Beeper('low');
    t0_p = datetime;  % record time in break
    
    WaitSecs(.2);
    [~, ~, keyCode] = KbCheck;
    
    % send some event markers
    if eye
        Eyelink('message', 'TRIG_32');
    end

    if eeg
        io64(ioObj, port_addr, 32);  % mark the start of the break 
        WaitSecs(.005); 
        io64(ioObj, port_addr, 0);
    end
    
    break_prompt = 0; % keep track of whether a break prompt has been given
    break_inspo_text = {'Take a deep breath.','Smile :)','Think nice things.',...
        'Rockin'' it!','Are neurons even real?','Excellent performance.', ...
        'Rest your eyes.','Keep calm and carry on','Live, laugh, long term potentiation ... '};
    break_inspo_text = break_inspo_text{randi(numel(break_inspo_text))};
    
    while 1
        [~, ~, keyCode] = KbCheck;
        if (datetime-t0_p > duration(0,0,15))
            text = ['Break time.\n\nPress "SPACE" when ready to resume.\n\n', char(datetime-t0_p)];
            
            % sound a gentle tone to alert 30 seconds is up
            if break_prompt ~= 1
                Beeper('low', .1); 
                break_prompt = 1; 
            end
        else
            text = ['Break.\n\n', break_inspo_text, '\n\n', char(datetime-t0_p)];
        end
        
        DrawFormattedText(wh, text, 'center', 'center', 0);
        Screen('Flip', wh);
        check_exit_key(wh);

        if keyCode(KbName('space')) && (datetime-t0_p > duration(0,0,5))
            Screen('Flip', wh);
            break
        end
    end
    
    % send events saying the break is over
    if eye
        Beeper('high',.1,.05); Beeper('high',.2,.05); 
        calibrate(ET); 
        startRecording(ET);
        Eyelink('message', 'TRIG_31'); % mark the beginning of more data
    end
    
    if eeg
        io64(ioObj, port_addr, 31);  
        WaitSecs(.005); 
        io64(ioObj, port_addr, 0); 
    end
    
    break_time = GetSecs;  % restart timer
    t.breaks(i) = 1; % record when a break happened
    WaitSecs(5);  % extra time before next stim
end

