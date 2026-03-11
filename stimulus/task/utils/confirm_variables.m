function [varargout] = confirm_variables(varargin)
% open a dialog to allow adjustment of variables. return with same type.

assert(~mod(length(varargin), 2), 'unmatching name-value pairs')

% keep track of type changes
convert_back = zeros(1, length(varargin)/2);

% loop through the defaults
for i = 2:2:length(varargin)
  
    % change any numeric types to char
    if isnumeric(varargin{i})
        varargin{i} = num2str(varargin{i});
        convert_back(i/2) = 1;  % make note to convert later
    end
end

% open a dialog
prompt = varargin(1:2:end);
defaults = cellstr(varargin(2:2:end));
varargout = inputdlg(prompt, 'Confirm setup', [1,50], defaults, 'on');

% undo type changes from num2str to str2num
for i = 1:length(varargout);
    if convert_back(i)
        varargout{i} = double(str2num(varargout{i}));
    end
end

end