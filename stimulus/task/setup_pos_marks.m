% function [mark_lns] = setup_pos_marks(w, s, g)
% calculate the line positions of the vernier-style marks.

% start with centre points 
mid_pnts = [w.x.mid, w.x.mid, w.x.mid, w.x.mid; ... 
            w.y.mid, w.y.mid, w.y.mid, w.y.mid];

% the offset from the screen center (takes x-y to corner)
mid_offset = [-g.x_offset, -g.x_offset, -g.x_offset, -g.x_offset; ... 
              -g.y_offset, -g.y_offset, -g.y_offset, -g.y_offset];

% extend a line oriented at 0 rad at the edge of the gabor
ln_ext = [s.mark.ext, s.mark.size + s.mark.ext, -s.mark.ext, -s.mark.size - s.mark.ext;...
          0, 0, 0, 0];

% rotate each x-y column using rotation matrix R
R = [-cos(s.mark.ori), sin(s.mark.ori); sin(s.mark.ori), cos(s.mark.ori)];

for i = 1:size(ln_ext,2)
    ln_ext(:, i) = R * ln_ext(:,i);
end

% add the positions to get final line coords (for both sides of display)
mark_lns{1} = mid_pnts + mid_offset + ln_ext;
mark_lns{2} = mid_pnts + (mid_offset + ln_ext) .* [-ones(1,4); ones(1,4)];  % flip horiz.

if 0  % test
    % draw textures first for some reason?
    side = 1; 
    g.side = g.sides{side};
    drawGabor
    mark_ln = mark_lns{side};
    
    % draw the lines
    drawPosMarks
    
    drawFix
    w.flip();
end