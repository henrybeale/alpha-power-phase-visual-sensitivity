function [wh, w] = setupWindow(varargin)
% Create a psychtoolbox window and return the details (and window handle)
% in a struct. The struct also includes handy functions to convert between
% pixels, degrees, frame speeds, etc.


% default settings
w.pos = [];             % fullscreen
w.col = 0.5;            % mid-gray (normed)
w.skip_sync = 0; 
w.select_mon = 0; 
w.load_gamma = '';      % set to 'gamma' or 'spline'
w.gamma = 2.2; 
w.alpha_blending = []; 
w.font = 'times';
w.fontsize = 24;
w.bitsteal = 1; 
w.hide_cursor = 1; 
w.vpixx = 1; 

w.scr_dist = 57;        % measured screen viewing distance (cm)
w.scr_width = 30;       % measured screen width (cm)
w.hz = [];              % desired screen Hz, will produce error if not used

% update any supplied args
assert( ~mod(length(varargin), 2), '# of keys do not match args')
for n = 1:2:length(varargin)
    assert(isfield(w, varargin{n}), [varargin{n}, ' not found (spelling?)'])
    w.(varargin{n}) = varargin{n+1};
end

% check screen refresh rate before starting (if desired Hz was passed)
hz = Screen('FrameRate', w.select_mon);
if ~isempty(w.hz) && (w.hz ~= hz)
    error('Frame rate is set to %d Hz instead of %d Hz', hz, w.hz)
end

% open a window with optimisations
Screen('Preference', 'SkipSyncTests', w.skip_sync);   % disable tests if requested
PsychDefaultSetup(2);  % normalise key names and color range (0-1)
Screen('Preference','TextRenderer',1);  % use high-quality text plugin

% hi-res color settings
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');

% use 10-bit color with VPIXX/3d
if w.vpixx
    PsychImaging('AddTask', 'General', 'EnableNative10BitFramebuffer'); % for vpix/3d
end

if w.bitsteal
    PsychImaging('AddTask', 'General', 'EnablePseudoGrayOutput');  % bit-stealing
end

% simple gamma exponent correction
if ~isempty(w.gamma) && isempty(w.load_gamma)
    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SimpleGamma'); 
end

% open a window
[wh, w.rect] = PsychImaging('OpenWindow', w.select_mon, w.col, w.pos);

if ~isempty(w.gamma) && isempty(w.load_gamma)
    PsychColorCorrection('SetEncodingGamma', wh, 1 / w.gamma);
end

if isempty(w.alpha_blending)
    Screen('BlendFunction', wh, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
end

% find the priority level that retains keyboard functionality
w.max_priority = MaxPriority(wh, 'KbCheck', 'GetMouse', 'WaitSecs', 'GetSecs');
w.old_priority = Priority(w.max_priority);

% screen calculations
[w.x.pix, w.y.pix] = Screen('WindowSize', wh);     % dim. in pix.
[w.x.mid, w.y.mid] = RectCenter(w.rect);
w.hz  = hz;                                         % refresh rate 
w.ifi = Screen('GetFlipInterval', wh);             % inter-frame interval

% other variables
w.white = WhiteIndex(wh);
w.grey  = w.white/2;
w.black = BlackIndex(wh);
w.slack = w.ifi / 2;  % time of half a refresh

Screen('TextFont', wh, w.font);
Screen('TextSize', wh, w.fontsize); 

% some helper functions
w.deg2pix = @(d) 2 * tand(d/2) * w.scr_dist * w.x.pix / w.scr_width;
w.pix2deg = @(x) 2 * atand(x * w.scr_width / w.x.pix / 2 / w.scr_dist);
w.dps2ppf = @(dps) 1 / w.hz * w.deg2pix(dps);  % deg per sec. to pix. per frame

w.ppd = w.deg2pix(1);  % calculate pixels per deg. of visual angle

% load pre-saved gamma table from file (options: 'gamma' or 'spline')
if ~isempty(w.load_gamma)

    BackupCluts();
    w.old_clut = Screen('ReadNormalizedGammaTable', wh);
    
    assert(exist(w.load_gamma, 'file'), ['missing file: ',  w.load_gamma])
    try 
        LUT = getfield(load(w.load_gamma), 'LUT');
    catch ME
        error('Gamma not loaded: tried to load %s', w.load_gamma)
    end
    
    Screen('LoadNormalizedGammaTable', wh, LUT);
end

% aliases
w.flip = @() Screen('Flip', wh);  
w.sca = @() Screen('CloseAll');
w.h = wh; 
w.BG_color = w.col; 

if w.hide_cursor
    HideCursor;
end
