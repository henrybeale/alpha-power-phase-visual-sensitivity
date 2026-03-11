% this script will load FOOOFed data and compute the endpoint corrected
% phase and amplitude for detected frequencies. 

%% load data
% task = 'contrDetectBadpt';
task = 'contrLocalBadpt';
folder = '/Volumes/CONSENPHAS-Q5078';
% folder = 'Z:/contrDetectBadpt/';

% load behavioural data table
file = fullfile(folder,task,'derivatives','eeg','ic','compiled-data-struct.mat');
load(file, 'df')
df = struct2table(df);

% load the IC data used with FOOOF 
file = fullfile(folder,task,'derivatives','eeg','ic','timeseries-IC-data.mat');
load(file, 'data')

% load the IC raw data to get the times 
file = fullfile(folder,task,'derivatives','eeg','ic','all_ic.mat');
load(file, 'ic')

times = ic.times;

%% band pass filter and get phase based on FOOOF selected frequency
df.pid = findgroups(df.sub,df.ses);
pids = unique(df.pid);

toi = [-1500, 0]; 
tix = times >= toi(1) & times <= toi(2);

bp_win = 1; 
fs = 1/mean(diff(times))*1e3;

df.phi_echt(:) = nan;
df.amp_echt(:) = nan; 

% loop sessions
for n = 1:numel(pids)
    ix = find(df.pid == pids(n));
    
    % loop trials
    for k = 1:numel(ix)
        freq = df.freq(ix(k));

        if ~isnan(freq)
            dat = data(tix,ix(k));  % select trial data in window
            dat = dat - mean(dat);  % demean for filtering

            % hilbert filter (complex)
            hx = bpht(dat, [freq-bp_win, freq+bp_win], fs);
            df.phi_echt(ix(k)) = angle(hx(end)); 
            df.amp_echt(ix(k)) = abs(hx(end));
        end
    end
end

%%
clf
nexttile
polarplot(df.phi_w500)

nexttile
polarplot(df.phi_echt)

%%
clf
nexttile
plot(df.power, log(1+df.amp_echt),'.')
[r,p] = corrcoef(df.power, log(df.amp_echt),'rows','pairwise')

%% save
df = table2struct(df, 'toscalar', true);
save(fullfile(folder,task,'derivatives','eeg','ic','compiled-data-struct.mat'),'df')