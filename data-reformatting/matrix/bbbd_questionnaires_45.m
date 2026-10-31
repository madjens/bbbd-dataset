run('config.m');

% Generates experiment{4,5}_questionnaires.zip.
% Same pattern as bbbd_questionnaires_123.m — all files sourced from config/.

for exp_no = [4, 5]

    q_out = fullfile(output_dir, sprintf('experiment%d', exp_no), 'questionnaires');
    make_dir(q_out);

    copy_config_file('stimuli_questionnaire', exp_no, q_out);
    write_scores_from_questionnaire( ...
        fullfile('config', sprintf('experiment%d_stimuli_questionnaire.tsv', exp_no)), ...
        q_out, exp_no);
    copy_config_file('asrs_questionnaire',  exp_no, q_out);
    copy_config_file('digit_span_scores',   exp_no, q_out);

    zip_name = fullfile(output_dir, sprintf('experiment%d', exp_no), ...
        sprintf('experiment%d_questionnaires.zip', exp_no));
    zip_questionnaire_dir(q_out, zip_name);

    fprintf('Experiment %d questionnaires written to %s\n', exp_no, zip_name);
end

% -------------------------------------------------------------------------

function copy_config_file(basename, experiment_no, out_dir)
    for ext = {'tsv', 'json'}
        src = fullfile('config', sprintf('experiment%d_%s.%s', experiment_no, basename, ext{1}));
        if isfile(src)
            copyfile(src, fullfile(out_dir, sprintf('%s.%s', basename, ext{1})));
        end
    end
end

function write_scores_from_questionnaire(q_tsv, out_dir, exp_no)
    if ~isfile(q_tsv)
        fprintf('  scores: questionnaire TSV not found at %s — skipping\n', q_tsv);
        return;
    end
    T = readtable(q_tsv, 'FileType', 'text', 'Delimiter', '\t', 'TextType', 'string');
    pars = unique(T.participant_id, 'stable');
    rows = {};
    for p = 1:length(pars)
        Tp = T(T.participant_id == pars(p), :);
        stims = unique(Tp.stimulus_no);
        for s = 1:length(stims)
            Ts = Tp(Tp.stimulus_no == stims(s), :);
            rows{end+1} = {char(pars(p)), stims(s), height(Ts), sum(Ts.is_correct)};
        end
    end
    Tout = cell2table(vertcat(rows{:}), 'VariableNames', ...
        {'participant_id','stimulus_no','total_questions','score'});
    writetable(Tout, fullfile(out_dir, 'stimuli_questionnaire_scores.tsv'), ...
        'FileType', 'text', 'Delimiter', '\t');
end

function zip_questionnaire_dir(src_dir, zip_path)
    files = [dir(fullfile(src_dir, '*.tsv')); dir(fullfile(src_dir, '*.json'))];
    if isfile(zip_path), delete(zip_path); end
    file_paths = cellfun(@(f, d) fullfile(d, f), {files.name}, {files.folder}, 'UniformOutput', false);
    zip(zip_path, file_paths);
end

function make_dir(d)
    if ~exist(d, 'dir'), mkdir(d); end
end
