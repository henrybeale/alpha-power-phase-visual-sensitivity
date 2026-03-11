
% load a window
[wh, w] = setupWindow('pos', [], 'vpixx', 1, 'skip_sync', 1, ...
                        'gamma', [], 'hide_cursor', 0, 'bitsteal', 0);

% save the default LUT
old_clut = Screen('ReadNormalizedGammaTable', wh);

% check colorimeter is connected
if ~I1('IsConnected')
    fprintf('Colorimeter not connected'); return
end

%% load uniform clut
BackupCluts();
Screen('LoadNormalizedGammaTable', wh, repmat(linspace(0,1,256)', 1, 3));
pause(.1);

DrawFormattedText(wh, 'Measure min. and max. luminance. \nAny key to continue.', 'center', 'center');
Screen('Flip', wh);
KbWait;

%% measure black and white levels
n_reps = 3;
lums = 0:1;
lums_names = {'Black','White'};
meas_lums = [];

log_file = './black_white_levels.txt';
fid = fopen(log_file, 'w');

fprintf(fid, 'Run at: %s\n', char(datetime));
fprintf(fid, '\n\nMeasuring black and white levels\n')

for i = 1:length(lums)
    Screen('FillRect', wh, lums(i));
    Screen('Flip', wh);
    WaitSecs(.1);
    
    fprintf(fid,'\n%s luminance.\n', lums_names{i})

    for j = 1:n_reps
        Lxy = I1('GetTriStimulus');
        WaitSecs(.01);
        meas_lums(i,j) = Lxy(1);

        fprintf(fid,'\tMeasurement %d: %.4fcd/m^2\n', j, meas_lums(i,j))
    end

    fprintf(fid,'\tMean (SD): %.3f (%.3f)\n', mean(meas_lums(i,:)), std(meas_lums(i,:)))
end

fclose(fid);
WaitSecs(.2);
Screen('FillRect', wh, w.BG_color);
DrawFormattedText(wh, 'Done', 'center', 'center');
Screen('Flip', wh);

%% calibrate each gun

n_steps = 60;
lums = linspace(0,1,n_steps);

n_reps = 5; 
meas_lums = nan(length(lums), 3, n_reps); 

tic
for i = 1:length(lums)
    for j = 1:3
        % set just one color to the luminance
        rgb = [0,0,0];
        rgb(j) = lums(i);
        Screen('FillRect', wh, rgb);
        Screen('Flip', wh);
        WaitSecs(0.01);
        
        % take multiple measurements
        for k = 1:n_reps
            Lxy = I1('GetTriStimulus');
            meas_lums(i,j,k) = Lxy(1);
        end
    end
end
toc

% take the mean measurement
% avg_lum = mean(meas_lums, 3);
avg_lum = median(meas_lums,3);  % this works way better

WaitSecs(.2);
Screen('FillRect', wh, w.BG_color);
DrawFormattedText(wh, 'Done', 'center', 'center');
Screen('Flip', wh);


%% create interpolated LUT

LUT = nan(256,3);  % must be 256 length for Windows 

% create desired luminance function (normalised)
desired_lum = linspace(0, 1, length(lums)); 

for j = 1:3
    % normalise the measurements for this color
    tmp = avg_lum(:,j); 
    norm_lum = (tmp-min(tmp)) / (tmp(end)-tmp(1));

    % interpolate to get the corrected power for a linear output
    corrected_power(:,j) = interp1(norm_lum, desired_lum, lums);

    % interpolate linearly to fill the 256 LUT
    LUT(:,j) = interp1(lums, corrected_power(:,j), linspace(0,1,256));

    % check monotonicity
    monotonicity_broken = any(diff(LUT(:,j)) < 0)
end

save ./LUT.mat LUT

%% load corrected clut and re-measure

Screen('LoadNormalizedGammaTable', wh, LUT);

meas_lums2 = nan(size(meas_lums)); 

tic
for i = 1:length(lums)
    for j = 1:3
        % set just one color to the luminance
        rgb = [0,0,0];
        rgb(j) = lums(i);
        Screen('FillRect', wh, rgb);
        Screen('Flip', wh);
        WaitSecs(0.01);
        
        % take multiple measurements
        for k = 1:n_reps
            Lxy = I1('GetTriStimulus');
            meas_lums2(i,j,k) = Lxy(1);
        end
    end
end
toc

WaitSecs(.2);
Screen('FillRect', wh, w.BG_color);
DrawFormattedText(wh, 'Done', 'center', 'center');
Screen('Flip', wh);
sca

%% plot 
figure
ax = nan(1,3);
labels = {'Red', 'Green', 'Blue'};
avg_lum2 = mean(meas_lums2, 3);

for j = 1:3
    ax(j) = subplot(1,3,j);

    % plot the initial measured gamma
    plot(lums, avg_lum(:,j), '.', 'DisplayName', 'Measured');
    hold on 

    % plot the expected linear luminance in cd/m^2
    desired_lum_incdm2 = desired_lum*range(avg_lum(:,j)) + min(avg_lum(:,j));
    plot(lums, desired_lum_incdm2, '.', 'DisplayName', 'Expected')

    % plot luminances for the corrected display power
    plot(lums, avg_lum2(:,j), '.', 'DisplayName', 'Corrected');

    title(labels{j});
    xlabel('Gun Power'); ylabel('Lum. cd/m^2')
end

linkaxes(ax, 'y')
legend

savefig(sprintf('monitor-calib_%s', num2str(yyyymmdd(datetime))))

%% measure gray level

try
    % load a window with bit stealing
    [wh, w] = setupWindow('pos', [], 'vpixx', 1, 'skip_sync', 1, ...
                            'load_gamma', './task/utils/LUT.mat', ...
                            'hide_cursor', 0, 'bitsteal', 0);
    
catch ME
    sca
    rethrow(ME)
end

fid = fopen(log_file, 'a');

gray = .25;  % chosen for this experiment
fprintf(fid,'\nMeasuring custom gray level %.2f\n', gray)

Screen('FillRect', wh, gray);
Screen('Flip', wh);
WaitSecs(10);
meas = []; 

for i = 1:n_reps
    Lxy = I1('GetTriStimulus');
    WaitSecs(.01);
    meas(i) = Lxy(1);

    fprintf(fid,'\tMeasurement %d: %.4fcd/m^2\n', i, meas(i))
end

fprintf(fid,'\tMean (SD): %.3f (%.3f)\n', mean(meas), std(meas))
fclose(fid)
sca

%% measure luminance differences

% load a window with bit stealing
[wh, w] = setupWindow('pos', [], 'vpixx', 1, 'skip_sync', 1, ...
                        'load_gamma', './task/utils/LUT.mat', ...
                        'hide_cursor', 0, 'bitsteal', 0);

WaitSecs(10);

base_lums = [0, .25, .5, .75];
lum_diffs = 14:-1:6;  % bit differences
n_reps = 7; 

base_data = []; 
diff_data = [];

for i = 1:length(base_lums)
    
    % measure this base luminance
    Screen('FillRect', wh, base_lums(i));
    Screen('Flip', wh);
    WaitSecs(0.01);
    
    for n = 1: n_reps
        Lxy = I1('GetTriStimulus');
        base_data(i,n) = Lxy(1);
    end
    
    % measure the base lum + all lum diffs
    for k = 1:length(lum_diffs)
        L = base_lums(i) + 2^-(lum_diffs(k));  % add increasing incr. bit
        
        Screen('FillRect', wh, L);
        Screen('Flip', wh);
        WaitSecs(0.01);
        
        for n = 1:n_reps
            Lxy = I1('GetTriStimulus');
            diff_data(i,k,n) = Lxy(1);
        end
    end
end

% average over the multiple measurements
base_lums_meas = mean(base_data, 2); 
diff_lums_meas = mean(diff_data, 3) - base_lums_meas;

base_lums_meas2 = median(base_data, 2); 
diff_lums_meas2 = median(diff_data, 3) - base_lums_meas2;
sca

%% plot
dat = diff_lums_meas;
dat(dat<0) = 0;
dat = log2(dat);

figure;hold on 
for i = 1:length(base_lums)
    plot(-lum_diffs, dat(i,:), 'linewidth',1.5);
end
lgd = legend(string(base_lums), 'Location', 'best'); lgd.Title.String = 'Base Lum.';
xlabel('log2(addition to base lum.)')
ylabel('log2(measured difference from base lum.)')
title('Luminance resolution')
savefig(sprintf('./lum-res_%s',num2str(yyyymmdd(datetime))))
