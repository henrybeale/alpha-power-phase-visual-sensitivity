clear
addpath('./utils/fooof_mat/')
% import packages for FOOOF
py.importlib.import_module('os');
py.importlib.import_module('numpy');
py.importlib.import_module('fooof');

%% file setup
% data info
SUBS = 1:8;
SES_NUMS = 1:4;
TASK = 'contrDetectBadpt';

% file locations
DATA_FOLDER = fullfile('/Users/henry/Documents/local-data',TASK);

OUT_FOLDER = fullfile(DATA_FOLDER,'derivatives','eeg','ic');

if ~exist(OUT_FOLDER,'dir')
    mkdir(OUT_FOLDER);
end

%% reload data for interactive
ic = getfield(load(fullfile(OUT_FOLDER,'all_ic.mat')),'ic');
beh = getfield(load(fullfile(OUT_FOLDER,'all_beh.mat')),'all_beh');

%% inspect topographies and recode for consistent sign
maps = ic.maps;
data = ic.data;

% store what got flipped for sign
flips = nan(8,4);

clf;
tiledlayout(8,4,'tilespacing','compact','tileindexing','rowmajor')
for n = 1:size(maps,2)
    % find the sign of the maximum activated electrode
    [~, maxind] = max(abs(maps(:,n)));  % get the max elec index
    S = sign(maps(maxind,n));
    maps(:,n) = maps(:,n) * S;
    
    % store who got flipped
    flips(n) = S;
    
    % recode data sign
    [ses,sub] = ind2sub([4,8],n);
    ii = beh.sub == SUBS(sub) & beh.ses == SES_NUMS(ses);
    if sub == 4 && strcmp(TASK,'contrDetectBadpt') % outlier
        S = S*-1;
    end

    if strcmp(TASK,'contrDetectBadpt') && sub==3 && any(ses == [2,3])
        S = S*-1;
    end
    
    data(:,ii) = data(:,ii) * S;

    ax = nexttile;
    topoplot(zscore(maps(:,n)),ic.chanlocs);
    if sub == 1
        title(sprintf('ses-%02d',SES_NUMS(ses)))
    end
    if ses == 1
        ylabel(sprintf('sub-%02d',SUBS(sub)));
        ax.YLabel.FontWeight = 'bold';
        ax.YLabel.Visible = 'on';
    end
end
colormap(viridis)
sgtitle('Selected IC components')

save(fullfile(DATA_FOLDER, 'plot-data', 'ic-topos.mat'), 'maps')

%% investigate flips
flips

%% plot the group average
figure
topoplot(mean(zscore(maps,[],1),2), ic.chanlocs);
colormap(viridis)
title('Group average component (zscore)')

%% save topo data for replotting
group_avg_topo = mean(zscore(maps, [], 1)); 
labels = {ic.chanlocs.labels};
save(fullfile(DATA_FOLDER,'plot-data','IC-topo-data'), 'group_avg_topo', 'labels')

%% plot spectra
ti = ic.times >= -500 & ic.times < 0;
npad = 512*5;
[pow,f] = pwelch(data(ti,:),hamming(length(ic.times(ti))),[],npad,ic.fs,'power');
% [pow,f] = pwelch(data(ti,:),ones(length(ic.times(ti)),1),[],npad,ic.fs,'power');  % no frequency smoothing

clf; hold on 
colororder(tab10)

sub_pow = []; 

for n = 1:8
    ii = beh.sub == SUBS(n); 
    sub_pow(:,n) = log(mean(pow(:,ii),2));
    ln = plot(f, sub_pow(:,n),'linewidth',2);
    ln.Color(4) = .7;
end

avg_pow = log(mean(pow,2));
ln = plot(f, avg_pow,'linewidth',3,'color','k');
xlim([1,30])
xlabel('Hz')
ylabel('ln Power')
legend(ln, 'Group Average')

%% save for replotting
save(fullfile(DATA_FOLDER,'plot-data','IC-freq-data'), 'avg_pow','pow','f')

%% FOOOF (power, freq, aperiodic offset, 1/f slope)
% set FOOOF parameters
fooof_cfg = [];
fooof_cfg.peak_width_limits = [.5,6];
fooof_cfg.max_n_peaks = 4;
f_range = [1,40];

alpha_band = [8,14];  % extended for trial-level variability

npad = 2048;

% select times
ti = ic.times >= -500 & ic.times < 0; 
time = ic.times(ti);

% pull out the data and demean
tmp = data(ti,:);
tmp = tmp - mean(tmp,1); 

% get the power spectrum
[pow,f] = pwelch(tmp,ones(size(time)),[],npad,ic.fs,'power');

% run FOOOF 
pow_fit = fooof_group(f,pow,f_range,fooof_cfg);

% loop trials and score 
for t = 1:height(beh)
    % get the slope and offset
    beh.ap_offset(t) = pow_fit(t).aperiodic_params(1); 
    beh.ap_slope(t) = pow_fit(t).aperiodic_params(2);
    
    % get the index of the spectral peaks within alpha range
    peaks = pow_fit(t).peak_params(:,1);
    ind = find(peaks >= min(alpha_band) & peaks <= max(alpha_band));

    % deal with more than one peak (pick the largest amplitude)
    if numel(ind) > 1
        amps = pow_fit(t).peak_params(:,2);
        [~,maxampind] = max(amps(ind));
        ind = ind(maxampind);
    end

    % don't add anything if no peak is detected
    if isempty(ind)
        beh.freq(t) = nan; 
        beh.power(t) = 0;  % must set to 0 if missing
    else
        beh.freq(t) = pow_fit(t).peak_params(ind,1);
        beh.power(t) = pow_fit(t).peak_params(ind,2);
    end

    % record R-squared of the fits
    beh.FOOOF_rSq(t) = pow_fit(t).r_squared; 
end

% z score per session 
ii2 = ~isnan(beh.freq);
beh.zfreq(:) = nan;
beh.zpower(:) = nan;
for n = 1:numel(SUBS)
    for k = 1:numel(SES_NUMS)
        ii = beh.sub == SUBS(n) & beh.ses == SES_NUMS(k);
        beh.zap_offset(ii) = zscore(beh.ap_offset(ii));
        beh.zap_slope(ii) = zscore(beh.ap_slope(ii));
        
        % must zscore only ~isnan data 
        beh.zfreq(ii & ii2) = zscore(beh.freq(ii & ii2));
        beh.zpower(ii & ii2) = zscore(beh.power(ii & ii2));
    end
end

%% plot group-level FOOOF data
figure
tiledlayout(2,2,'tilespacing','compact')
nexttile
histogram(beh.zfreq,100,'edgealpha',.1)
title('Freq.')

nexttile
histogram(beh.power,100,'edgealpha',.1)
title('Amplitude')

nexttile
histogram(beh.zap_offset,100,'edgealpha',.1)
title('Offset')

nexttile
histogram(beh.zap_slope,100,'edgealpha',.1)
title('Slope')

sgtitle('Group-level FOOOF parameters')

%% plot FOOOF r-squared
clf
histogram(beh.FOOOF_rSq,100,'edgealpha',.1)
title('R Squared')

%% calculate data loss
data_loss = table; 
for n = 1:numel(SUBS)
    ii = beh.sub == SUBS(n);
    data_loss.RTs(n) = sum(beh.badRTs(ii)) / sum(ii);
    data_loss.blink(n) = sum(beh.blinks(ii)) / sum(ii); 
    data_loss.eeg(n) = sum(beh.bad_eeg(ii)) / sum(ii); 
    data_loss.nofreq(n) = sum(isnan(beh.freq(ii))) / sum(ii);

    data_loss.total(n) = sum(isnan(beh.freq(ii)) | beh.exclude(ii)) / sum(ii);
end

writetable(data_loss,fullfile(OUT_FOLDER,'data-lost.csv'))

%% get phase estimates based on the peak frequency in the 500ms window
% select times
ti = ic.times >= -500 & ic.times < 0; 
time = ic.times(ti);

% pull out the data and demean
dat = data(ti,:);
dat = dat - mean(dat,1);

% get the FFT of the window
npad = 1024*2;
Fx = fft(dat.*hamming(sum(ti)),npad);

% calculate frequencies
hz = ic.fs;  % make the nyquist half the number of points
n = npad;
if mod(n,2)  % odd
    F = [0:(n-1)/2, -(n-1)/2:-1] ./ (1/hz*n);
else
    F = [0:n/2-1, -n/2:-1] ./ (1/hz*n);
end

% use the FOOOF peak frequency (this will exclude trials with no
% oscillation in the larger 500ms window)
beh.phi_w500(:) = nan;
fi = dsearchn(F', beh.freq);
for n = 1:numel(fi)
    beh.phi_w500(n) = angle(Fx(fi(n),n));
end
beh.phi_w500(isnan(beh.freq)) = nan;

clf;
plot(beh.phi_w500,'.')

save(fullfile(OUT_FOLDER,'compiled-data.mat'),'beh')

% save also as a structure for loading into python
df = table2struct(beh,'ToScalar',true);
save(fullfile(OUT_FOLDER,'compiled-data-struct.mat'),'df')

save(fullfile(OUT_FOLDER,'timeseries-IC-data.mat'),'data')