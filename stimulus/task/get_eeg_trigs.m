function [trigs] = get_eeg_trigs
% assign the project wide triggers here

trigs.trial_start = 1; 
trigs.stim_onset = 2; 
trigs.resp_made = 3; 

trigs.block_start = 31;
trigs.block_end = 32;

trigs.contrLocalBadpt = 37; 
trigs.contrLocalSource = 39; 