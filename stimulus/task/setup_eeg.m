% setup the eeg trigger sending

% set the port address
port_addr = hex2dec('D050');

% create a location for the parallel interface object
ioObj = io64;

% check 
status = io64(ioObj);
assert(status == 0, 'Port setup failed')

% set the first trigger to zero 
io64(ioObj, port_addr, 0);