% This script will load the source data which was not anonymised and save a
% downsampled anonymised version of the continuous EEG in /rawdata (for
% later BIDSification). Further basic preprocessing is done: hi-pass
% filtering, average referencing, channel cleaning/interpolation, and
% marking blink trials for exclusion.

% add custom functions
addpath('./eeg-preproc')
addpath('./eeglab2023.1')

% setup EEGLAB functions
eeglab; close; clear; 

% list of participants to use
SUBS = {};
TASK = 'contrDetectBadpt';

% where is the data? 
DATA_FOLDER = getenv('DATA_FOLDER');
if isempty(DATA_FOLDER)
    DATA_FOLDER = where_is_my_data(); 
end
SOURCEDATA_FOLDER = [DATA_FOLDER, '/sourcedata'];
RAWDATA_FOLDER = [DATA_FOLDER, '/rawdata'];
DERIV_FOLDER = [DATA_FOLDER, '/derivatives'];

% specify some EEG loading variables 
EVENT_CHAN = 73; 
SAMPLE_RATE = 512; 
LO_CUTOFF = .1; % high pass filter cutoff
EPOCH_WIN = [-1.5, .5];
BLINK_CHANS = {'EXG5', 'EXG6'};
BLINK_WIN = [-500, 100]; 
BLINK_THRES = 100;  % uV

% check the output folders exist 
if ~exist(RAWDATA_FOLDER, 'dir')
    mkdir(RAWDATA_FOLDER)
end

if ~exist(DERIV_FOLDER, 'dir')
    mkdir(DERIV_FOLDER)
end

if ~exist(fullfile(DERIV_FOLDER, 'eeg', 'raw'), 'dir')
    mkdir(fullfile(DERIV_FOLDER, 'eeg', 'raw'))
end

if ~exist(fullfile(DERIV_FOLDER, 'eeg', 'preproc'), 'dir')
    mkdir(fullfile(DERIV_FOLDER, 'eeg', 'preproc'))
end

if ~exist(fullfile(DERIV_FOLDER, 'eeg', 'clean'), 'dir')
    mkdir(fullfile(DERIV_FOLDER, 'eeg', 'clean'))
end

% start timer
t0 = tic;

% convert array job to subject and session indices (code is structured to
% load multiple files for the same split session)
array_var = str2double(getenv('SLURM_ARRAY_TASK_ID'))+1;
fprintf('This is job array %d\n', array_var)
[i,n] = ind2sub([numel(SUBS), 4], array_var);
fprintf('This is subject %d and ses %d\n',i,n)

% loop participants
for i = 1:numel(SUBS)
    
    % find participant root folder
    sub_folder = sprintf('%s/sub-%s', SOURCEDATA_FOLDER, SUBS{i});
    assert(exist(sub_folder, 'dir'), 'participant folder not found') % check it exists
    
    % get the data for all sessions for that participant
    eeg_files = dir([sub_folder, '/eeg/*_eeg.bdf']);
    
    % find the session number from each filename
    ses_nums = zeros(1, numel(eeg_files)); 
    for j = 1:numel(eeg_files)
        f_parts = strsplit(eeg_files(j).name, '_');
        ses_str = f_parts{contains(f_parts, 'ses')};  % select 'ses' keyname
        ses_nums(j) = sscanf(ses_str, 'ses-%02d');
    end
    
    % get the unique sessions for looping
    ses_nums_unique = unique(ses_nums); 

    % loop sessions
    for n = 1:numel(ses_nums_unique)
        % clear eeg;
    
        % deal with split files
        ses_inds = find(ses_nums == ses_nums_unique(n));
        for k = 1:numel(ses_inds)
            % load data
            ind = ses_inds(k);
            file = [eeg_files(ind).folder, filesep, eeg_files(ind).name]
            file_ok = exist(file, 'file')  % touch remote file to ensure connection
            try
                eeg(k) = pop_readbdf(file, [], EVENT_CHAN, []);
            catch
                fprintf('retrying load\n')
                file_ok = exist(file, 'file')
                eeg(k) = pop_readbdf(file, [], EVENT_CHAN, [])
            end
    
            % down sample
            eeg(k)  = pop_resample(eeg(k) , SAMPLE_RATE);  
        end
    
        % merge any split files
        eeg = pop_mergeset(eeg, 1:numel(eeg));
    
        % remove unused channels and load template electrode positions
        eeg = pop_select(eeg, 'nochannel', 65:66);
        eeg = pop_chanedit(eeg, 'lookup', [SOURCEDATA_FOLDER, '/standard_1005.elc']);
    
        % change channel 'type' (not sure why, BIDS?)
        for k = 1:length(eeg.chanlocs)
            eeg.chanlocs(k).type = 'eeg'; 
        end
        
        % rename triggers based on the two subtasks
        eeg = eeg_preproc_RECODETRIG(eeg); 
        
        % create a copy of the raw data
        eegraw = eeg; 
        
        % preprocess
        eeg = pop_eegfiltnew(eeg, 'locutoff', LO_CUTOFF); % high pass filter
        eeg = pop_reref(eeg, []);  % average reference
        
        % epoch prior to channel cleaning 
        eeg = pop_epoch(eeg, {'stim-onset'}, EPOCH_WIN);

        % find the behavioural files for this session 
        beh_file = sprintf('%s/beh/raw/sub-%02d_ses-%02d_task-%s_beh.mat', DERIV_FOLDER, i, n, TASK);
        assert(exist(beh_file, 'file'), sprintf('beh file not found: %s\n.', beh_file))
        eeg.beh = getfield(load(beh_file), 'beh');

        % deal with mismatched trials 
        if eeg.trials < height(eeg.beh)
            % remove beh trials from the start if too many (assume eeg recording
            % was started late, dropping the first block)
            eeg.beh = eeg.beh(height(eeg.beh)-eeg.trials+1:end,:); 
        end

        assert(eeg.trials == height(eeg.beh), 'trials not coregistered')

        % encode trial start times
        eeg.beh.latency(:) = [eeg.event(ismember({eeg.event.type},'stim-onset')).latency];       

        % channel cleaning and interpolation 
        ext_chans = find(contains({eeg.chanlocs.labels}, 'EX'));  
        eeg = clean_chans(eeg, 'exclude', ext_chans);  % chans with no pos info would be dropped
        eeg = pop_reref(eeg, []);  % redo average reference

        % mark bad trials using eyeblinks
        eeg = mark_blinks(eeg, BLINK_CHANS, BLINK_WIN, BLINK_THRES);

        % perform ICA decomposition
        eeg = decomp_ica(eeg);
        
        % save as anonymised data
        newfilename = sprintf('sub-%02d_ses-%02d_task-%s_eeg.set', i, n, TASK);
        eegraw.filename = fullfile(DERIV_FOLDER, 'eeg', 'raw', newfilename); 
        pop_saveset(eegraw, 'filename', eegraw.filename);

        % save processed version
        newfilename = sprintf('sub-%02d_ses-%02d_task-%s_eeg.set', i, n, TASK);
        pop_saveset(eeg, 'filename', fullfile(DERIV_FOLDER, 'eeg', 'preproc', newfilename))
    end
end

fprintf('Done in %.2f min.\n', toc(t0)/60)
exit(0)

%% select ICA components (targeting blinks and bad channels)

% loop participants
for i = 1:numel(SUBS)
    % loop sessions
    for n = 1:4
        
        %% load processed eeg
        filename = sprintf('sub-%02d_ses-%02d_task-%s_eeg.set', i, n, TASK);
        eeg = pop_loadset('filename', filename, 'filepath', fullfile(DERIV_FOLDER,'eeg','preproc'))
        
        % identify components
        SASICA(eeg)  % SASICA will return `EEG` to base workspace
        fprintf('\nYou identified %d components\n', sum(eeg.reject.gcompreject))
        
        % inspect changes
        orig_eeg = eeg; 
        eeg = pop_subcomp(EEG,[]); 
        vis_artifacts(eeg, orig_eeg)
        uiwait(gcf)

        % final preprocessing
        ext_chans = find(contains({eeg.chanlocs.labels}, 'EX'));
        eeg = pop_reref(eeg, [], 'exclude', ext_chans);
        eeg = pop_rmbase(eeg, [], 'exclude', ext_chans);
        
        % save
        newfilename = strrep(filename, '_eeg', '_epo');
        pop_saveset(eeg, 'filename', newfilename, 'filepath',fullfile(DERIV_FOLDER,'eeg','clean'))
    end
end
