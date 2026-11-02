% bbbd_config_stimuli_feedback_meta_23.m
% Generate config/experiment{2,3}_stimuli_feedback_meta.tsv from source .mat files.
%
% Run from data-reformatting/ after setting data_dir in config.m.
% Source files required:
%   experiment_2/Experiment_2_stimuli_meta_questions.mat
%   experiment_3/Experiment_3_stimuli_meta_questions.mat
%
% T_stimuli_meta_questions is a MATLAB opaque table extracted via writetable.
% Columns expected: participant_no, stimulus_no (or stimulus), engaging, enjoyable, educational
% All rating fields are on a 1-7 Likert scale.
%
% Output columns: participant_id, stimulus, engaging, enjoyable, educational

run('config.m');

script_dir = fileparts(mfilename('fullpath'));
config_dir = fullfile(script_dir, '..', 'config');

write_feedback_meta(2, data_dir, config_dir);
write_feedback_meta(3, data_dir, config_dir);

% -------------------------------------------------------------------------

function write_feedback_meta(exp_no, data_dir, config_dir)
    mat_name = sprintf('Experiment_%d_stimuli_meta_questions.mat', exp_no);
    d = load(fullfile(data_dir, sprintf('experiment_%d', exp_no), mat_name));
    T = d.T_stimuli_meta_questions;

    % Dump opaque table to temp CSV, read back
    tmp = [tempname '.csv'];
    writetable(T, tmp);
    Tread = readtable(tmp, 'TextType', 'string');
    delete(tmp);

    cols = Tread.Properties.VariableNames;
    fprintf('Exp%d stimuli_feedback_meta columns (%d rows): %s\n', ...
        exp_no, height(Tread), strjoin(cols, ', '));

    % Map column names (handle possible variations)
    par_col  = find_col(cols, {'participant_no','participant_id','ParticipantNo'});
    stim_col = find_col(cols, {'stimulus_no','stimuli_no','stimulus','StimulusNo','Stimulus'});
    eng_col  = find_col(cols, {'engaging','Engaging'});
    enj_col  = find_col(cols, {'enjoyable','Enjoyable'});
    edu_col  = find_col(cols, {'educational','Educational'});

    assert(~isempty(par_col),  'Cannot find participant column in T_stimuli_meta_questions');
    assert(~isempty(stim_col), 'Cannot find stimulus column in T_stimuli_meta_questions');
    assert(~isempty(eng_col),  'Cannot find engaging column');
    assert(~isempty(enj_col),  'Cannot find enjoyable column');
    assert(~isempty(edu_col),  'Cannot find educational column');

    % Sort by participant_no then stimulus to match config ordering
    pno_vals  = double(Tread.(par_col));
    stim_vals = double(Tread.(stim_col));
    [~, sort_ord] = sortrows([pno_vals, stim_vals]);
    Tread = Tread(sort_ord, :);

    out = fullfile(config_dir, sprintf('experiment%d_stimuli_feedback_meta.tsv', exp_no));
    fid = fopen(out, 'w');
    fprintf(fid, 'participant_id\tstimulus\tengaging\tenjoyable\teducational\n');

    for i = 1:height(Tread)
        pno  = double(Tread.(par_col)(i));
        stim = double(Tread.(stim_col)(i));
        eng  = double(Tread.(eng_col)(i));
        enj  = double(Tread.(enj_col)(i));
        edu  = double(Tread.(edu_col)(i));
        fprintf(fid, 'sub-%02d\tStim-%02d\t%d\t%d\t%d\n', pno, stim, eng, enj, edu);
    end
    fclose(fid);
    fprintf('Exp%d stimuli_feedback_meta: %d rows → %s\n', exp_no, height(Tread), out);
end

function col = find_col(cols, candidates)
    col = '';
    for k = 1:length(candidates)
        if ismember(candidates{k}, cols)
            col = candidates{k};
            return;
        end
    end
end
