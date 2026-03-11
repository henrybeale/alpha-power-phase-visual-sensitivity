test = 0; % use this to just draw the stimulus (press any key to escape)

% setup a windows
gLUT = './task/utils/LUT.mat';
[wh, w] = setupWindow('pos', [], 'col', .5, 'select_mon', 0, 'skip_sync', 0, ...
    'scr_width', 53.2, 'scr_dist', 58, 'bitsteal', 0, 'load_gamma', gLUT, 'hz', 120, 'vpixx', 1);

% create a (g)abor texture
g.size = round(w.ppd * 10);
g.ori = 0;  % in ptb deg from vertical
g.phase = 0; 
g.freq = 4 / w.ppd;
g.contr = .5; % smallest visible is 0.4% with bitstealing
g.sd = round(w.ppd * .5);
g.x_offset = round(w.ppd * 5);  % 5 dva along x axis
g.y_offset = -g.x_offset;
g.crit_offset = round(w.ppd * 1);  % spatial offset from criterion

% (fix)ation cross settings
s.fix.size = 8;         % pix units
s.fix.thick = 2;
s.fix.col = 0;          % 0 = black, 1 = white

% vernier-like criterion (mark)ers
s.mark.size = s.fix.size*2; 
s.mark.thick = s.fix.thick*2;
s.mark.col = 0;  % black
s.mark.ori = 45 / 180 * pi;  % rad 
s.mark.ext = g.sd * 4;  % distance from gabor centre

% make things
setup_gabor
setup_fix
setup_pos_marks

% experiment display (s)ettings
s.time.stim = w.ifi * 1;
s.time.fix = [1.5, .5];
s.time.respmax = 1.5;
s.time.ITI = [.5, 0];

s.resp_opts = [KbName('j'), KbName('k')];

% fID = fopen(['./output/logfile' '_henry' '.tsv'], 'a');
% log_format = '%d\t';
% fprintf(fID, '%s', '');

% test stimulus
if test  % tests
    % set offset from criterion
    corr_resp = 1;  % index: 1 = left, 2 = right, w.r.t. criterion
    
    % select side to disp.
    side = 1; 
    g.pos = g.rects{side}{corr_resp}; 
    mark_ln = mark_lns{side};
    
    g.phase = rand*180;  % set random gabor phase
    g.ori = -45; 
    
    drawGabor(wh,g)  % draw textures first for some reason?
    drawPosMarks(wh, mark_ln, s) 
    drawFix(wh, fix_lines, s)
    w.flip();
    

%     im = Screen('GetImage', wh, [], 'frontBuffer', 0,3);
%     LUT = Screen('ReadNormalizedGammaTable', wh)
    
    KbWait;
    sca; return
end
