% config.m  -  Edit the four paths below, then run bbbd_run_all.m.

% Root directory containing experiment_1, experiment_2, ... subfolders.
% Each subfolder must have: raw/, processed/, metadata/ subdirectories.
data_dir = 'C:\data';

% Directory where all BBBD output will be written.
output_dir = 'C:\output\bbbd';

% Path to EEGLAB toolbox directory (required by EEG and derived scripts).
eeglab_path = 'C:\tools\eeglab';

% Path to BioSig toolbox directory (required by bbbd_123_derived_continuous only).
biosig_path = 'C:\tools\biosig';
