function [file, max_time] = get_latest_file(files)
% search through files and return the latest
fprintf('Searching existing files ... \n')
for i = 1:numel(files)
    % load in the date that each session is started
    info = getfield(load([files(i).folder,'/',files(i).name], 'info'), 'info');
    times(i) = datetime(info.date);
end

max_time = max(times);
file = files(find(times == max_time));
end