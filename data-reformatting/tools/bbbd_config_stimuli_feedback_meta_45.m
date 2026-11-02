% bbbd_config_stimuli_feedback_meta_45.m
% Generate config/experiment{4,5}_stimuli_feedback_meta.tsv from source .mat files.
%
% Run from data-reformatting/ after setting data_dir in config.m.
% Source file required:
%   experiment_4/Experiment_6_questionnaire.mat
%   config/doIntervention_indexing.mat
%
% T_stimuli_meta_questions is a MATLAB opaque table with columns:
%   participant_no, stimuli_id, intervention, answer_no_watch,
%   learned_something, already_watched
%
% Column mapping (source → config):
%   already_watched  → watched_before
%   answer_no_watch  → prior_knowledge
%   learned_something → educational
%
% KNOWN LIMITATION: question_difficulty ("I found the questions for this video
% difficult") is not present in T_stimuli_meta_questions. This script outputs
% n/a for that column; it cannot be reproduced from the available source data.
%
% stimuli_id values [1, 3, 7] map to Stim-01, Stim-02, Stim-03 (sorted rank).
% EXP5 sub-09 exclusion applies (index 9 in sorted EXP5 order).

run('config.m');

script_dir = fileparts(mfilename('fullpath'));
config_dir = fullfile(script_dir, '..', 'config');

d   = load(fullfile(data_dir, 'experiment_4', 'Experiment_6_questionnaire.mat'));
doi = load(fullfile(config_dir, 'doIntervention_indexing.mat'));
do_interv = logical(doi.doIntervention);  % 92×1

% Dump opaque table to temp CSV, read back
tmp = [tempname '.csv'];
writetable(d.T_stimuli_meta_questions, tmp);
T = readtable(tmp, 'TextType', 'string');
delete(tmp);

fprintf('T_stimuli_meta_questions columns (%d rows): %s\n', height(T), ...
    strjoin(T.Properties.VariableNames, ', '));

% Split EXP4 (intervention=0) and EXP5 (intervention=1) using do_interv index.
% participant_no values link rows to the 92-element do_interv vector.
pnos_all   = double(T.participant_no);
interv_col = double(T.intervention);

% Build a map from participant_no → do_interv flag using demographics ordering.
% T_stimuli_meta_questions.intervention already encodes this directly.
T4 = T(interv_col == 0, :);
T5 = T(interv_col == 1, :);

write_feedback(T4, 4, config_dir, []);
write_feedback(T5, 5, config_dir, 9);

% ── Output function ───────────────────────────────────────────────────────────

function write_feedback(Texp, exp_no, config_dir, sub09_skip_pno)
    % Get sorted participant_nos for stable sub-ID assignment
    pnos = unique(double(Texp.participant_no));
    pnos = sort(pnos);

    % EXP5: identify and remove the excluded participant (index 9 in sorted order)
    skip_sub_no = [];
    if ~isempty(sub09_skip_pno)
        skip_pno        = pnos(sub09_skip_pno);
        pnos(sub09_skip_pno) = [];
        skip_sub_no     = sub09_skip_pno;   % sub-ID offset position
    end

    stim_ids = sort(unique(double(Texp.stimuli_id)));  % e.g. [1 3 7]
    n_stim   = length(stim_ids);

    out = fullfile(config_dir, sprintf('experiment%d_stimuli_feedback_meta.tsv', exp_no));
    fid = fopen(out, 'w');
    fprintf(fid, 'participant_id\tstim_id\twatched_before\tquestion_difficulty\tprior_knowledge\teducational\n');

    for pi = 1:length(pnos)
        pno    = pnos(pi);
        sub_no = pi + (~isempty(skip_sub_no) && pi >= skip_sub_no);
        sub_id = sprintf('sub-%02d', sub_no);

        Tp = Texp(double(Texp.participant_no) == pno, :);

        for si = 1:n_stim
            sid = stim_ids(si);
            row = Tp(double(Tp.stimuli_id) == sid, :);
            if isempty(row), continue; end

            wb  = double(row.already_watched);
            pk  = double(row.answer_no_watch);
            edu = double(row.learned_something);
            % question_difficulty not in source — write n/a
            fprintf(fid, '%s\tStim-%02d\t%d\tn/a\t%d\t%d\n', sub_id, si, wb, pk, edu);
        end
    end
    fclose(fid);
    fprintf('Exp%d stimuli_feedback_meta: %d participants → %s\n', exp_no, length(pnos), out);
end
