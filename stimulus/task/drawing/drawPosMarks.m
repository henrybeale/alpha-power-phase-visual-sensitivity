function drawPosMarks(wh, mark_ln, s)
% draw the lines

Screen('DrawLines', wh, mark_ln, s.mark.thick, s.mark.col, [], 1, 1);