
% add custom functions
addpath('./eeg-preproc')
addpath('./eeglab2023.1')

% setup EEGLAB functions
eeglab; close; clear; 

%% where is the data? 
DATA_FOLDER = getenv('DATA_FOLDER');
if isempty(DATA_FOLDER)
    DATA_FOLDER = where_is_my_data(); 
end

DERIV_FOLDER = [DATA_FOLDER, '/derivatives'];
OUTPUT_FOLDER = fullfile(DATA_FOLDER,'derivatives','eeg','ic');
if ~exist(OUTPUT_FOLDER, 'dir') 
    mkdir(OUTPUT_FOLDER);
end

SUBS = 1:8; 
SES_NUMS = 1:4; 
TASK = 'contrDetectBadpt';

%% create a template
chanlocs = getfield(load(fullfile(where_is_my_data,'derivatives','eeg','chanlocs.mat')),'chanlocs');

% channel names
roi = {'O2','PO4','PO8','POz','P4','Oz','P2','POz'};

% tune the last args for s.d. for x and y gaussian smoothing
template = geig_template(chanlocs, roi, .5, .15);  

clf
topoplot(template,chanlocs,'emarker2',{find(ismember({chanlocs.labels},roi)),'o','k'},'maplimits','maxmin');
colormap(plasma)
title('Electrode template')

%% select ICA components (targeting blinks and bad channels)

% loop participants
for i = 1:numel(SUBS)
    % loop sessions
    for n = 1:4
        
        %% load processed eeg
        filename = sprintf('sub-%02d_ses-%02d_task-%s_eeg.set', i, n, TASK);
        eeg = pop_loadset('filename', filename, 'filepath', fullfile(DERIV_FOLDER,'eeg','preproc'))

        %%
        % correlate all ICs with template
        scores = zeros(1, size(eeg.icawinv,2));
        for c = 1:numel(scores)
            scores(c) = corr(eeg.icawinv(1:64,c), template);
        end
        [~,scorerank] = sort(abs(scores),'descend');

        clf
        plot(abs(scores(scorerank)),'o-','linewidth',2)
        ylabel('abs corr')
        

        %%
        EEG = eeg;
        pop_selectcomps(EEG,10)
        %%
        clf
        nplot = 5;
        tiledlayout(4,nplot,'tilespacing','compact','tileindexing','columnmajor')
        trialind = randi(eeg.trials,1,5);
        for c = 1:nplot
            % plot the IC topography projection
            nexttile
            topoplot(eeg.icawinv(:,scorerank(c)),eeg.chanlocs);
            colormap viridis
            title(sprintf('%d', scorerank(c)))
            
            % plot the ERP
            nexttile
            compind = scorerank(c);
            dat = (zscore(eeg.icaweights(compind,:))*eeg.icasphere)*reshape(eeg.data,eeg.nbchan,[]);  % z normalise the weight vector
            dat = reshape(dat, eeg.pnts, eeg.trials);

            % baseline
            dat = dat - mean(dat,1);
            % dat = zscore(dat,[],1); 

            plot(eeg.times, mean(dat,2),'linewidth',2)
            
            % plot some random trials
            nexttile
            ln = plot(eeg.times,dat(:,trialind));
            for lni = 1:numel(ln)
                ln(lni).Color(4) = .2;
            end

            % plot the spectral power 
            nexttile
            ti = eeg.times >= -600 & eeg.times < 0;
            npad = 1024;
            [power,freqs] = pwelch(dat(ti,:),ones(1,sum(ti)),[],npad,eeg.srate,'power');
            plot(freqs, log(mean(power,2)),'linewidth',2)
            xlim([1,40])
            xlabel('Hz')
            ylabel('log power')
        end
        sgtitle('IC correlation with template')
        
        return
    end
end
