function eeg = decomp_ica(eeg)

% ICA cleaning on a new copy
ica = pop_eegfiltnew(eeg, 'locutoff', 1);  % filter < 1Hz

% Remove any bad epochs
[~, i_bad] = pop_autorej(ica, 'nogui', 'on', 'electrodes', (1:eeg.nbchan), ...
    'startprob', 6, 'maxrej', 5);
ica = pop_rejepoch(ica, i_bad, false);
eeg.info.removed.epochs_before_ICA = i_bad;  % keep record

% Remove epoch means as per Groppe et al. 
ica = pop_rmbase(ica, []);

% Run decomposition
t0 = tic;
ica = pop_runica(ica, 'icatype', 'runica', 'extended', 1, ...
    'chanind', 1:eeg.nbchan); 
eeg.info.ica.fit_time = toc(t0)/60;
fprintf('ICA fit time: %.2f min.\n', eeg.info.ica.fit_time)

% Transfer weights to original data
eeg.icasphere = ica.icasphere; 
eeg.icaweights = ica.icaweights; 
eeg.icachansind = 1:eeg.nbchan;
eeg = eeg_checkset(eeg, 'ica');  % recompute other ica variables


