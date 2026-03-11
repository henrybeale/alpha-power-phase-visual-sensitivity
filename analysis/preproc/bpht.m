function [X,h] = bpht(X, h, fs)
% Return a frequency domain filter that both performs the hilbert transform
% and bandpass filters with a causal, butterworth filter. Written to be
% fast for realtime, creates the weights on first call if the band limits
% are passed as 'h' with the sample rate, then the returned weights can be
% reused with the function.
%
% H.A.Beale. 2024.

% operates on first dimension only!
[X,ns] = shiftdim(X);
n = size(X,1); 

if numel(h) == 2
    % create filter using the band limits
    [b,a] = butter(2, h/(fs/2), 'bandpass'); 
    f = fftfreq(fs,n); 
    h = freqz(b,a,f',fs);  % return Nx1 filter
    
    % hilbert weights
    m = zeros(n,1); 
    if mod(n,2)
        m(1) = 1; 
        m(2:(n+1)/2) = 2; 
    else
        m([1,n/2+1]) = 1;  % DC and nyq
        m(2:n/2) = 2; 
    end
    
    % combine the hilbert weights and the filter
    h = h.*m;
end

% apply to the data
X = ifft(fft(X).*h);
X = shiftdim(X,-ns); 



