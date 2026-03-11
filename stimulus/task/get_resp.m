% function [resp, RT, trialBad] = get_resp(w, s, time_0, corr_resp_key)

% get participant response
% time_0 = GetSecs;  % start time

% keyboard response
[keyIsDown, keyTime, keyCode] = KbCheck; 

while (GetSecs <= s.time.respmax + time_0) && ~keyIsDown
    [keyIsDown, keyTime, keyCode] = KbCheck; 
end

if ~keyIsDown || ~any(keyCode(s.resp_opts))
    trialBad = 1;  % no response given in allowed time window
else
    RT = keyTime - time_0;
    resp = keyCode(corr_resp_key);  % 1 if correct resp
    
    if eye
        Eyelink('message', 'TRIG_3');
    end
    if eeg
        io64(ioObj, port_addr, 3);
        WaitSecs(.001);
        io64(ioObj, port_addr, 0);
    end
end


% % mouse
% [x, y, buttons] = GetMouse(w.h);
% 
% while (GetSecs <= s.response_win + time_0) && ~any(buttons(1,3))
%     [x, y, buttons] = GetMouse(w.h);
% end
% 
% if ~any(buttons) 
%     trialBad = 1; 
% else
%     RT = GetSecs - time_0; 
%     resp = buttons(corr_resp_key);
% end
