function s = make_bids_attrib(key, val)
% helper function to make a blank string if the key-value pair is blank or
% empty. assumes val is numeric

% return if empty val (no string made)
if isempty(val)
    s = '';
    return   
end

% convert to numeric if text
if ~isnumeric(val)
    val = sscanf(val, '%f');
end

s = sprintf('_%s-%02d', key, val);

end