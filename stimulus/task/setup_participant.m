% setup all the participant file names and handle any variables that need
% to be counterbalanced or set on a per session basis.

function [info, eye, eeg] = setup_participant(task, eye, eeg)

% general setup 
info.date = datetime(clock);
rng('Shuffle');
info.rng_state = rng; 
info.cwd = pwd; 
info.data_loc = [info.cwd, '/data'];

% check we are in the correct working directory
% if ~contains(pwd, '\CRphs\tests')
%     error('check working directory; it might need changing')
% end

% these folders should be here if we are in the right directory
assert(exist('./task', 'dir'), 'Experiment scripts not found in ./task subdir')
assert(exist('./data', 'dir'), 'Data location not found: missing ./data subdir')

% get the participant ID
prompt = {'pID'}; 
defaults = {'test'};
answer = inputdlg(prompt, 'Session info', 1, defaults);

[pID_char] = deal(answer{:});
pID_char = strrep(pID_char, ' ', '');  % remove spaces from name

% ensure leading zero
if ismember(str2num(pID_char), 0:9)
    pID_char = sprintf('%02d', str2num(pID_char));
end

% look for existing sessions for this participant
files = dir(sprintf('%s/sub-%s/beh/sub-*task-%s*', info.data_loc, pID_char, task));

if length(files) == 0
    ses_num = 1;
    run_num = 1;
else
    % get the latest session number and run 
    [file, last_ses_date] = get_latest_file(files);
    ses_num = get_from_fname(file.name, 'ses');  % empty if unused
    run_num = get_from_fname(file.name, 'run');

    info.last_file = file;  % store
    
    % advance session if older than three hours
    time_since_last_ses = (info.date - datetime(last_ses_date));
    if time_since_last_ses > duration(3,0,0)  % three hours
        fprintf('Starting a new session.\n')
        ses_num = ses_num + 1;

        % keep blank if empty (which means unused)
        if ~isempty(run_num)
            run_num = 1;
        end
    else 
        fprintf('Last session was within three hours. Keeping session label\n')

        % advance run from the last session 
        run_num = run_num + 1;  % stays empty if empty
    end
end

% set some defaults

% create a file str without .ext
run_str = make_bids_attrib('run', run_num);
ses_str = make_bids_attrib('ses', ses_num);
f_name = sprintf('/sub-%s%s_task-%s%s', pID_char, ses_str, task, run_str);

% set these
if ~exist('eye', 'var')
    eye = 0; 
end

if ~exist('eeg', 'var')
    eeg = 0;
end

% confirm some information
prompt = {'example file name', 'session number', 'run', 'eyetracking (0/1)', 'eeg'};
defaults = {f_name, num2str(ses_num), num2str(run_num), num2str(eye), num2str(eeg)}; 
answer = inputdlg(prompt, 'Confirm details', [1,50], defaults, 'on');

if isempty(answer)
    error('participant setup not accepted')
end

[f_name, ses_num, run_num, eye, eeg] = deal(answer{:});
ses_num = str2num(ses_num); 
run_num = str2num(run_num); 
eye = str2num(eye);
eeg = str2num(eeg); 

% setup the final file string
ses_str = make_bids_attrib('ses', ses_num);
run_str = make_bids_attrib('run', run_num);
f_name = sprintf('/sub-%s%s_task-%s%s', pID_char, ses_str, task, run_str);  % recreate if changed
info.f_name = f_name; 

info.output_dir = sprintf('%s/sub-%s', info.data_loc, pID_char);
info.beh_file = [info.output_dir, '/beh', f_name, '_beh.mat'];
info.ET = eye;
info.ses_num = ses_num; 
info.run_num = run_num; 

% if new participant: collect demographics & make beh folder
if length(files) == 0   % 5 no previous files
    % pop up dialog
    prompt = {'Age', 'Sex', 'Preferred hand'};
    defaults = {'0-99', 'F/M/O', 'left/right'}; 
    answer = inputdlg(prompt, 'Demographic information', [1,50], defaults, 'on');
    
    [info.age, info.sex, info.handedness] = deal(answer{:});

    mkdir([info.output_dir, '/beh'])
end

% make eeg and eye folders if using these
if eye && ~exist([info.output_dir, '/eye'])
    mkdir([info.output_dir, '/eye'])
end

if eeg && ~exist([info.output_dir, '/eeg'])
    mkdir([info.output_dir, '/eeg'])
end

% double check the PSE being used if titration has happened
if contains(task, 'contrLocalMCS')
    prompt = {'PSE'};
    defaults = {num2str(PSE)}; 
    answer = inputdlg(prompt, 'Confirm PSE', [1,50], defaults, 'on');
    [PSE] = deal(answer{:});
    PSE = str2num(PSE);
end







