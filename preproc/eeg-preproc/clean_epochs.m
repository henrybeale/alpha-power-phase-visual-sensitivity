function [eeg, bads] = clean_epochs(eeg, varargin)
% clean epochs by scoring based on three metrics in FASTER: amplitude
% range, deviation from channel average, and variance.


% process multiple datasets
if length(eeg) > 1
    for i = 1:length(eeg)
        eeg(i) = clean_epochs(eeg(i), varargin);
    end
    return
end

% handle default (s)ettings
s.exclude = []; 
s.rej_thr = 3; 
s.trim_epochs = 0;  % remove bad epochs before scoring channels ('all' method only)
s.plot = false;
s.time = []; 

% update the struct with any supplied args
assert( ~mod(length(varargin), 2), '# of keys do not match args')
for n = 1:2:length(varargin)
    assert(isfield(s, lower(varargin{n})), [varargin{n}, ' not found (spelling?)'])
    s.(varargin{n}) = varargin{n+1};
end

% handle excluding channels from further processing
if iscell(s.exclude)
    chan_mask = find(~ismember({eeg.chanlocs.labels}, s.exclude));
else
    chan_mask = find(~ismember(1:eeg.nbchan, s.exclude));
end

% z score checking function
get_bads = @(x) abs(zscore(x)) > s.rej_thr;

% handle excluding channels
tmp = pop_select(eeg, 'nochannel', s.exclude);

% handle looking through subset of times
if ~isempty(s.time)
    tmp = pop_select(tmp, 'time', s.time);
end

% storage
amp_range = nan(size(tmp.data,3),1);
chan_dev = amp_range;
variance = amp_range; 

% channel average 
chan_avg = mean(tmp.data,[2,3]);

% calculate metrics per epoch
for n = 1:size(eeg.data,3)
    ep = tmp.data(:,:,n); 

    % amplitude range
    amp_range(n) = mean(range(ep,2));
    
    % deviation from channel average
    chan_dev(n) = mean(mean(ep,2) - chan_avg);

    % average variance over channels
    variance(n) = mean(var(ep,[],2));
end

% score 
bads_amp_range = get_bads(amp_range);
bads_chan_dev = get_bads(chan_dev);
bads_var = get_bads(variance);
bads = bads_amp_range | bads_chan_dev | bads_var;

bad_trials = find(bads);

% optional plot
if s.plot
    clf
    tiledlayout(ceil(numel(bad_trials)/2),2,'tilespacing','compact')
    for n = 1:numel(bad_trials)
        nexttile
        ln = plot(eeg.times, eeg.data(:,:,bad_trials(n)));
        for k = 1:numel(ln)
            ln(k).Color(4) = .4;
        end

        lab = {}; 
        if bads_amp_range(bad_trials(n))
            lab = {lab{:}, 'ampRange'};
        end
        if bads_chan_dev(bad_trials(n))
            lab = {lab{:}, 'chanDev'};
        end
        if bads_var(bad_trials(n))
            lab = {lab{:}, 'var'};
        end

        title(sprintf('Trial %d',bad_trials(n)),lab(:))
    end
end

eeg = pop_select(eeg, 'notrial', bad_trials);

