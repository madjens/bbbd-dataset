run('config.m');

% Builds config/int_metadata.mat by combining all per-participant metadata files
% from experiment_4/metadata/ into a single struct array.
%
% Each file must contain a variable named 'metadata' (a struct) with fields
% including participant_no, doIntervention, and segments(stim, session).
%
% Run this ONCE before running bbbd_run_all.m for experiments 4 and 5.
% Output: config/int_metadata.mat  (variable: metadata_full)

metadata_dir = fullfile(data_dir, 'experiment_4', 'metadata');
par_files = dir(fullfile(metadata_dir, '*.mat'));
par_files = par_files(~[par_files.isdir]);

if isempty(par_files)
    error('No .mat files found in %s', metadata_dir);
end

fprintf('Building int_metadata.mat from %d files in %s\n', length(par_files), metadata_dir);

for iFile = length(par_files):-1:1
    gg = load(fullfile(par_files(iFile).folder, par_files(iFile).name));
    if ~isfield(gg, 'metadata')
        error('File %s does not contain a ''metadata'' variable', par_files(iFile).name);
    end
    metadata_full(iFile) = gg.metadata;
    fprintf('.');
end
fprintf(' done\n');

output_path = fullfile('config', 'int_metadata.mat');
save(output_path, 'metadata_full');
fprintf('Saved %d participant entries to %s\n', length(metadata_full), output_path);
