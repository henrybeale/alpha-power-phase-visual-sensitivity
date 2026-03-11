function x = get_from_fname(filestr, targ)
% Use as: 
%   x = get_from_fname(filestr, targ)
% 
% Helper function to return the value of a target BIDS attrib that is
% encoded within a file name.

% remove any folder paths
if contains(filestr, filesep)
    filestr = strsplit(filestr, filesep);
    filestr = filestr{end};
end

% split file into attributes
attrib = strsplit(filestr, '_');

% split attributes into key value pairs
for i = 1:numel(attrib)
    thisattr = strsplit(attrib{i}, '-');
    [key{i}, val{i}] = deal(thisattr{:});
end

% get the value for the requested key (returns empty if not found)
ind = ismember(key, targ);
if ~any(ind)  % return empty char if no key is found in the filestr
    x = '';
    return
else
    x = val{ind};
end

% convert to numeric if it is a number
tmp = sscanf(x, '%f');
if ~isempty(tmp)
    x = tmp; 
end
