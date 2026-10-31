run('config.m');

% Generates experiment{N}_questionnaires.zip for experiments 1, 2, 3.
% All questionnaire TSVs are sourced from config/ (static files) except
% stimuli_questionnaire_scores.tsv, which is derived from the config
% stimuli_questionnaire.tsv using the same logic as bbbd_generate_bids_descriptors.m.
%
% Output: output_dir/experiment{N}/questionnaires/experiment{N}_questionnaires.zip

for experiment_no = 1:3

    q_out = fullfile(output_dir, sprintf('experiment%d', experiment_no), 'questionnaires');
    make_dir(q_out);

    % --- stimuli_questionnaire.tsv + .json (static copy) ---
    copy_config_file('stimuli_questionnaire', experiment_no, q_out);

    % --- stimuli_questionnaire_scores.tsv (derived from stim_q config TSV) ---
    q_tsv = fullfile('config', sprintf('experiment%d_stimuli_questionnaire.tsv', experiment_no));
    write_scores_from_questionnaire(q_tsv, q_out, experiment_no);

    % --- EXP2 and EXP3: additional questionnaire files ---
    if experiment_no >= 2
        copy_config_file('asrs_questionnaire',      experiment_no, q_out);
        copy_config_file('digit_span_scores',       experiment_no, q_out);
        copy_config_file('stimuli_feedback_meta',   experiment_no, q_out);
    end

    % --- zip all TSVs flat into experiment{N}_questionnaires.zip ---
    zip_name = fullfile(output_dir, sprintf('experiment%d', experiment_no), ...
        sprintf('experiment%d_questionnaires.zip', experiment_no));
    zip_questionnaire_dir(q_out, zip_name);

    fprintf('Experiment %d questionnaires written to %s\n', experiment_no, zip_name);
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

    if exp_no <= 2
        if ismember('stimulus_id', T.Properties.VariableNames)
            stim_col = 'stimulus_id';
        else
            stim_col = 'stim_no';
        end
        for p = 1:length(pars)
            Tp = T(T.participant_id == pars(p), :);
            stims = unique(Tp.(stim_col));
            for s = 1:length(stims)
                Ts = Tp(Tp.(stim_col) == stims(s), :);
                dom = Ts(Ts.question_type == "domain", :);
                mem = Ts(Ts.question_type == "memory", :);
                rows{end+1} = {char(pars(p)), stims(s), height(dom), sum(dom.is_correct), height(mem), sum(mem.is_correct)};
            end
        end
        Tout = cell2table(vertcat(rows{:}), 'VariableNames', ...
            {'participant_id', stim_col, 'total_domain_questions', 'domain_score', ...
             'total_memory_questions', 'memory_score'});

    elseif exp_no == 3
        for p = 1:length(pars)
            Tp = T(T.participant_id == pars(p), :);
            stims = unique(Tp.stim_no);
            for s = 1:length(stims)
                Ts = Tp(Tp.stim_no == stims(s), :);
                rows{end+1} = {char(pars(p)), stims(s), height(Ts), sum(Ts.score)};
            end
        end
        Tout = cell2table(vertcat(rows{:}), 'VariableNames', ...
            {'participant_id','stim_no','total_questions','score'});
    end

    writetable(Tout, fullfile(out_dir, 'stimuli_questionnaire_scores.tsv'), ...
        'FileType', 'text', 'Delimiter', '\t');
end

function zip_questionnaire_dir(src_dir, zip_path)
    % Zip all .tsv and .json files in src_dir flat into zip_path.
    files = [dir(fullfile(src_dir, '*.tsv')); dir(fullfile(src_dir, '*.json'))];
    if isfile(zip_path), delete(zip_path); end
    file_paths = cellfun(@(f, d) fullfile(d, f), {files.name}, {files.folder}, 'UniformOutput', false);
    zip(zip_path, file_paths);
end

function make_dir(d)
    if ~exist(d, 'dir'), mkdir(d); end
end
