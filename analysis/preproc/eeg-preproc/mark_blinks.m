function eeg = mark_blinks(eeg, blink_chans, blink_win, blink_thres)

% store settings and output
blink = []; 
blink.hicut = 10; 
blink.locut = 1; 
blink.cfg.blink_win = blink_win;
blink.cfg.blink_thres = blink_thres; 
blink.cfg.blink_chans = blink_chans;

% filter the data first to remove any drifts
eeg2 = pop_eegfiltnew(eeg, 'hicutoff', blink.hicut);
eeg2 = pop_eegfiltnew(eeg2, 'locutoff', blink.locut);

% get the vertical blink channel from the eeg
chn = find(ismember({eeg.chanlocs.labels}, blink_chans)); 
veog = eeg2.data(chn,:,:); 

% create a combined channel via subtraction
if numel(blink_chans) > 1
    veog = veog(2,:,:) - veog(1,:,:); 
end
veog = squeeze(veog);  % time by trials 

% mark the trials that exceed threshold within the window

% find the indices of the time window of interest
t_ind = find(eeg.times >= blink_win(1) & eeg.times < blink_win(2)); 

% get the maximum absolute amplitude in the window
[M, ii] = max(abs(veog(t_ind,:)), [], 1);

% find the time of the maximum
peak_times = eeg.times(t_ind);
peak_times = peak_times(ii);

% threshold for blinks
blinks = M > blink_thres;

% store info
blink.bad_trials = blinks; 
blink.peak_times = peak_times; 
blink.amp = M; 
blink.veog = veog; 

eeg.blink = blink;

return

%% plot blinks by magnitude

[M2, jj] = sort(M, 'descend');

figure
for i = 1:sum(blinks)*2
    hold on 
    ln = plot(eeg.times, abs(veog(:,jj(i))));
    if ~blinks(jj(i))
        ln.Color(4) = .2;
    end
end

% xline(blink_win(1), 'color', 'r', 'linewidth', 2)
% xline(blink_win(2), 'color', 'r', 'linewidth', 2)
ax = gca; 
fill([blink_win(1),blink_win(1),blink_win(2),blink_win(2)],[ax.YLim(1),ax.YLim(2),ax.YLim(2),ax.YLim(1)], 'r', 'edgecolor','none', 'facealpha', .2)

title('Blinks plotted by strength')
xlabel('Time'); ylabel('Absolute magnitude')
% xlim(blink_win)
%% plot the blink trialwise

figure
imagesc(eeg.times, 1:eeg.trials, (veog)')
xlabel('Time'); ylabel('Trial')
clb = colorbar;
clb.Title.String = 'Amplitude';
title('Blink channel activity')
colormap(viridis)

hold on 
scatter(peak_times(blinks), find(blinks), 5, 'filled', 'markerfacealpha', .8, 'markerfacecolor', 'w')
xline(blink_win(1))
xline(blink_win(2))
