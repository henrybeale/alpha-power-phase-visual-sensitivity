% function [g] = setup_gabor(w, g)
% create a gabor texture and calculate two screen positions, left and right
% of fixation, to present it at.


[g.tx, g.rect] = CreateProceduralGabor(w.h, g.size, g.size, [], ...
    [repmat(w.BG_color,1,3), 1], 1, [w.BG_color]);  % disable norm amp, premult: .5


g.rect = OffsetRect(g.rect, w.x.mid - g.size/2, w.y.mid - g.size/2);  % center the rect
g.centred_rect = g.rect; 
g.lh_rect = OffsetRect(g.rect, -g.x_offset, -g.y_offset);
g.rh_rect = OffsetRect(g.rect,  g.x_offset, -g.y_offset);

g.sides = {g.lh_rect, g.rh_rect};  % combine for indexing

% setup the rects to index for 2 display sides x 2 criterion sides
g.rects = {};
for i = 1:2
    for j = 1:2
        k = (j-2)*2 + 1;  % -1 or 1, for left or right
        l = -(i-1)*pi/2;  % if rhs rects, subtract 90 deg
        g.rects{i}{j} = OffsetRect(g.sides{i}, ...
                                k*g.crit_offset * cos(s.mark.ori+l), ...
                                k*g.crit_offset * sin(s.mark.ori+l));
    end
end