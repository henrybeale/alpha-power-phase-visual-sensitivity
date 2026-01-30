% this script sorts ERPs by decibel contrast for plotting

%% load data
task = 'contrDetectBadpt';
% task = 'contrLocalBadpt';
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

%% sort contrast 
pids = unique(df.pid);
Q = 5; 

for n = 1:numel(pids)
    ix = df.pid == pids(n); 
    contr = df.contrast(ix); 
    thr = 10.^mean(log10(contr(contr>0 & contr < 1)));

    df.ratio_contr(ix) = contr ./ thr; 
end

%% bin ERP by contrast
% equally filled bins
contr = df.ratio_contr;
Q = 7;
edges = quantile(df.ratio_contr, linspace(0,1,Q+1));
[~,~,bin] = histcounts(df.ratio_contr, edges);

cvals = grpstats(df.ratio_contr, bin, 'mean');

clf
nexttile
hold on 
cols = flip(gray(Q+2),1);

ERP = [];

for m = 1:Q
    ix = bin==m;

    ERP(m,:) = mean(data(:,ix),2); 
    plot(times, ERP(m,:), color=cols(m+1,:),linewidth=2);
end
xlim([-200,400])
legend(num2str(cvals),'location','best','box','off')

title(task)


save(fullfile(folder,task,'plot-data','contrast-erp.mat'),'ERP','times','cvals')

