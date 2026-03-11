function [out] = get_bids_val(s, key, type)
% a helper function to extract a number from a bids-like filename string. 

if nargin < 3
    type = 'num';
end

% extract the key-value string 
switch type
    case 'num'
        query = [key, '-\d{1,2}'];  % match single or double digit number
    case 'str'
        query = [key, '-*_'];
end

s2 = regexp(s, query, 'match');

% extract the number value
query = [key, '-%d'];
out = sscanf(s2{1}, query);


%%

key = 'task';

% get between the key and the next underscore
r = regexp(s, [key,'-[^_]*'], 'match')

% remove the 'key-' part
r = regexp(r, ['[^', key, '-].*'], 'match'); 

if isempty(r)
    return
else
    r = r{1}{1}
end
r{1}{1}

% [a] = regexp(r, '-', 'split')


