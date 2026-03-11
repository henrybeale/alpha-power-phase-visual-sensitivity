function [eeg, bads] = clean_chans(eeg, varargin)
% adaptive metrics to remove bad channels within epochs, and remove
% entirely if overly corrupted.

% process multiple datasets
if length(eeg) > 1
    for i = 1:length(eeg)
        eeg(i) = clean_chans(eeg(i), varargin);
    end
    return
end

% handle default (s)ettings
s.method = 'all';
s.exclude = []; 
s.rej_thr = 3; 
s.trim_epochs = 0;  % remove bad epochs before scoring channels ('all' method only)

% update the struct with any supplied args
assert( ~mod(length(varargin), 2), '# of keys do not match args')
for n = 1:2:length(varargin)
    assert(isfield(s, lower(varargin{n})), [varargin{n}, ' not found (spelling?)'])
    s.(varargin{n}) = varargin{n+1};
end

% handle excluding channels from further processing
if iscell(s.exclude)
    chan_mask = ~ismember({eeg.chanlocs.labels}, s.exclude);
else
    chan_mask = ~ismember(1:eeg.nbchan, s.exclude);
end

% z score checking function
get_bads = @(x) abs(zscore(x)) > s.rej_thr; 

% reject channels within each epoch/trial
if strcmpi(s.method, 'epochs') || strcmpi(s.method, 'trials')
    % this has not been checked and may not work with the exclude channels
    % method

    % setup
    data = eeg.data(chan_mask,:,:);
    tmp = eeg; 
    scores = nan(size(data,1), eeg.trials, 4);
    channel_means = mean(data,[2,3]);
    
    for i = 1:eeg.trials
        dat = data(:,:,i);
    
        % variance
        variances = var(dat,[], 2);
        scores(:,i,1) = get_bads(variances);
    
        % median slope 
        dt = 1/eeg.srate; 
        med_slope = median(diff(dat,1,2)./dt,2);
        scores(:,i,2) = get_bads(med_slope);
    
        % peak to peak amplitude
        ptp = range(dat,2);
        scores(:,i,3) = get_bads(ptp); 
        
        % drift from whole data mean 
        drift = mean(dat,2) - channel_means;
        scores(:,i,4) = get_bads(drift); 

        fprintf('Epoch: %d\n', i); 
        fprintf('Rejected: %s\n', eeg.chanlocs(bads).labels)
        
        % interpolate
        bads = find(sum(scores(:,i,:), 3)>0);       
        tmp.data(chan_mask,:,i) = dat; 
        tmp = eeg_interp(tmp, bads, 'spherical');
        data(:,:,i) = tmp.data(chan_mask,:,i);
    end
    
    % combine rejected channels across metrics
    bads = sum(scores,3) > 0;
    
    % find channels rejected on >= 50% of trials
    rej_all = sum(bads,2) ./ size(bads,2) >= .5;
    eeg.data(chan_mask,:,:) = data;
    eeg = eeg_interp(eeg, find(rej_all), 'spherical');
    
    % keep track of what was removed
    eeg.info.removed.epochscores = scores;
    eeg.info.removed.rej_all = rej_all;

% reject channels from the entire data range
elseif strcmpi(s.method, 'all')
    tmp = pop_select(eeg, 'nochannel', s.exclude);
    
    % remove any bad epochs first
    if s.trim_epochs
        [~, i_bad] = pop_autorej(eeg, 'nogui', 'on', 'electrodes', (1:eeg.nbchan), ...
            'startprob', 6, 'maxrej', 5);
        tmp = pop_rejepoch(eeg, i_bad, false);
    end
        
    % concatenate
    data = reshape(tmp.data, tmp.nbchan, tmp.pnts*tmp.trials);
    
    % average correlation with other channels
    avg_rho = mean(corr(data'))';
    bads_rho = get_bads(avg_rho);
    
    % variance
    variance = var(data,[],2);
    bads_var = get_bads(variance);
    
    % hurst exponent (long range correlation)
    hurst = nan(size(data,1),3);
    for i = 1:size(data,1)
        hurst(i,:) = wfbmesti(data(i,:));
    end
    hurst = hurst(:,1);  % use second order derivative estimate
    bads_hurst = get_bads(hurst);
    
    % combine across metrics
    bads = bads_rho | bads_var | bads_hurst;
    bads_labels = {tmp.chanlocs(bads).labels};
    fprintf('Rejected: %s\n', bads_labels{:})

    % find the indices of bads in the original data (may differ if some
    % channels were excluded)
    bads_inds = find(ismember({eeg.chanlocs.labels}, bads_labels));
    eeg.info.interpolated.chans_indices = bads_inds;
    eeg.info.interpolated.chans_labels = bads_labels;
  
    % interpolate
    eeg = eeg_interp(eeg, bads_inds, 'spherical');
end

