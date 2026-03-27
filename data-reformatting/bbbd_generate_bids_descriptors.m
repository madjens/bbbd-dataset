run('config.m');

% Generates participants.tsv, participants.json, dataset_description.json
% and phenotype/ files for each experiment, writing into output_dir.
%
% Run from the data_code/ root after setting paths in config.m.
% data_dir must point to the folder containing experiment_1..experiment_4.

tired_labels = {'VeryAwake', 'Awake', 'Moderate', 'Tired', 'VeryTired'};

%% EXPERIMENTS 1, 2, 3
for experiment_no = 1:3

    demo_file = dir(fullfile(data_dir, sprintf('experiment_%d', experiment_no), sprintf('Experiment_%d_demographics.mat', experiment_no)));
    if isempty(demo_file)
        % fallback: find any demographics file
        demo_file = dir(fullfile(data_dir, sprintf('experiment_%d', experiment_no), '*demographics*.mat'));
    end
    demo = load(fullfile(demo_file(1).folder, demo_file(1).name));
    demo = demo.(fieldnames(demo){1});

    exp_output = fullfile(output_dir, sprintf('experiment%d', experiment_no));
    make_dir(exp_output);
    phenotype_dir = fullfile(exp_output, 'phenotype');
    make_dir(phenotype_dir);

    %% Static per-experiment files
    write_bidsignore(exp_output);
    copy_readme(exp_output, experiment_no);

    %% dataset_description.json
    write_dataset_description(exp_output, experiment_no);

    %% participants.tsv + .json
    use_tired_labels = (experiment_no == 2);
    has_hearing = (experiment_no == 2);
    write_participants(demo, exp_output, tired_labels, use_tired_labels, has_hearing);

    %% phenotype: stimuli_questionnaire_scores.tsv
    q_tsv = fullfile('config', sprintf('experiment%d_stimuli_questionnaire.tsv', experiment_no));
    write_scores_from_questionnaire(q_tsv, phenotype_dir, experiment_no);

    %% phenotype: feedback, ASRS, digit span (exp2 and 3 only)
    if experiment_no >= 2
        q_file = dir(fullfile(data_dir, sprintf('experiment_%d', experiment_no), sprintf('Experiment_%d_questionnaire.mat', experiment_no)));
        if ~isempty(q_file)
            q = load(fullfile(q_file(1).folder, q_file(1).name));
            if isfield(q, 'questionnaireStimulusData')
                write_stimuli_feedback(q.questionnaireStimulusData, [demo.no], phenotype_dir);
            end
        end

        copy_static_phenotype_file('asrs_questionnaire', experiment_no, phenotype_dir);
        copy_static_phenotype_file('digit_span_scores', experiment_no, phenotype_dir);
    end

    fprintf('Experiment %d descriptors written to %s\n', experiment_no, exp_output);
end

%% EXPERIMENTS 4 and 5 (shared raw data, split by doIntervention)
demo_all = load(fullfile(data_dir, 'experiment_4', 'Experiment_6_demographics.mat'));
demo_all = demo_all.(fieldnames(demo_all){1});

di = load(fullfile('config', 'doIntervention_indexing.mat'));
doIntervention = di.doIntervention;

demo_exp4 = demo_all(~doIntervention);  % no intervention
demo_exp5 = demo_all(doIntervention);   % intervention

q6_file = fullfile(data_dir, 'experiment_4', 'Experiment_6_questionnaire.mat');

for exp_no = [4, 5]
    if exp_no == 4
        demo = demo_exp4;
    else
        demo = demo_exp5;
    end

    exp_output = fullfile(output_dir, sprintf('experiment%d', exp_no));
    make_dir(exp_output);
    phenotype_dir = fullfile(exp_output, 'phenotype');
    make_dir(phenotype_dir);

    write_bidsignore(exp_output);
    copy_readme(exp_output, exp_no);
    write_dataset_description(exp_output, exp_no);
    write_participants(demo, exp_output, tired_labels, true, false);

    % Scores from static questionnaire TSV
    q_tsv = fullfile('config', sprintf('experiment%d_stimuli_questionnaire.tsv', exp_no));
    write_scores_from_questionnaire(q_tsv, phenotype_dir, exp_no);

    % Feedback (using exp4 raw source)
    q_file = dir(fullfile(data_dir, 'experiment_4', '*questionnaire*.mat'));
    if ~isempty(q_file)
        q = load(fullfile(q_file(1).folder, q_file(1).name));
        if isfield(q, 'questionnaireStimulusData')
            write_stimuli_feedback(q.questionnaireStimulusData, [demo.no], phenotype_dir);
        end
    end

    copy_static_phenotype_file('asrs_questionnaire', exp_no, phenotype_dir);
    copy_static_phenotype_file('digit_span_scores', exp_no, phenotype_dir);

    fprintf('Experiment %d descriptors written to %s\n', exp_no, exp_output);
end

%% -----------------------------------------------------------------------

function write_dataset_description(exp_output, experiment_no)
    desc.Name = sprintf('The Brain, Body, and Behaviour Dataset (1.0.0) - Experiment %d', experiment_no);
    desc.BIDSVersion = '1.10.0';
    desc.DatasetType = 'derivative';
    desc.License = 'CC BY 4.0';
    desc.Authors = {'Jens Madsen', 'Nikhil Kuppa', 'Lucas Parra'};
    desc.Acknowledgements = 'We acknowledge the National Science Foundation Grant DRL-1660548 for supporting this project.';
    desc.HowToAcknowledge = 'Cite us';
    desc.Funding = {'DRL-2201835'};
    desc.EthicsApprovals = {'The City University of New York (CUNY) University Integrated Institutional Review Board'};
    desc.GeneratedBy = struct('Name', 'Manual', 'Description', ...
        'MATLAB: Converted .mat files to .bdf files for EEG recordings, and .mat files to tsv.gz files for physiological and eyetracking recordings (eg: ECG, gaze etc)');

    write_json(fullfile(exp_output, 'dataset_description.json'), desc);
end

function write_participants(demo, exp_output, tired_labels, use_tired_labels, has_hearing)
    n = length(demo);

    participant_id = cell(n, 1);
    species        = repmat({'homosapiens'}, n, 1);
    Sex            = cell(n, 1);
    Age            = zeros(n, 1);
    Occupation     = cell(n, 1);
    Tired          = cell(n, 1);
    Study_time     = zeros(n, 1);
    GPA            = zeros(n, 1);
    Caffeine       = zeros(n, 1);
    Occupation_field = cell(n, 1);
    if has_hearing
        Hearing = repmat({'Yes'}, n, 1);
    end

    for i = 1:n
        participant_id{i} = sprintf('sub-%02d', demo(i).no);
        Sex{i}            = demo(i).Sex;
        Age(i)            = demo(i).Age;
        Occupation{i}     = demo(i).Occupation;
        Study_time(i)     = demo(i).Study_time;
        GPA(i)            = demo(i).GPA;
        Caffeine(i)       = demo(i).Caffeine;
        Occupation_field{i} = demo(i).Occupation_field;

        t = demo(i).Tired;
        if use_tired_labels
            if isnumeric(t) && t >= 1 && t <= 5
                Tired{i} = tired_labels{t};
            else
                Tired{i} = char(t);
            end
        else
            if isnumeric(t)
                Tired{i} = num2str(t);
            else
                Tired{i} = char(t);
            end
        end
    end

    % Build table
    if has_hearing
        T = table(participant_id, species, Sex, Age, Occupation, Tired, Hearing, ...
            Study_time, GPA, Caffeine, Occupation_field);
    else
        T = table(participant_id, species, Sex, Age, Occupation, Tired, ...
            Study_time, GPA, Caffeine, Occupation_field);
    end

    writetable(T, fullfile(exp_output, 'participants.tsv'), ...
        'FileType', 'text', 'Delimiter', '\t', 'WriteVariableNames', true);

    % participants.json sidecar
    sidecar.participant_id.Description = 'unique identifier for the participant';
    sidecar.species.Description = 'species of the participant';
    sidecar.species.Levels.homosapiens = 'human';
    sidecar.Sex.Description = 'sex of the participant as reported by the participant';
    sidecar.Sex.Levels.Male = 'male';
    sidecar.Sex.Levels.Female = 'female';
    sidecar.Age.Description = 'age of the participant';
    sidecar.Age.Units = 'years';
    sidecar.Occupation.Description = 'occupation of the participant';
    sidecar.Tired.Description = 'current state of tiredness of the participant';
    sidecar.Tired.Levels.VeryAwake = 'not tired at all';
    sidecar.Tired.Levels.Awake = 'feeling awake';
    sidecar.Tired.Levels.Moderate = 'moderate level of tiredness';
    sidecar.Tired.Levels.Tired = 'feeling tired';
    sidecar.Tired.Levels.VeryTired = 'extremely tired';
    if has_hearing
        sidecar.Hearing.Description = 'hearing status of the participant';
        sidecar.Hearing.Levels.Yes = 'hearing';
        sidecar.Hearing.Levels.No = 'not hearing';
    end
    sidecar.Study_time.Description = 'number of hours the participant studied';
    sidecar.Study_time.Units = 'hours';
    sidecar.GPA.Description = 'Grade Point Average of the participant';
    sidecar.Caffeine.Description = 'Time since last caffeine consumption of the participant';
    sidecar.Caffeine.Units = 'Hours';
    sidecar.Occupation_field.Description = 'field of occupation of the participant';

    write_json(fullfile(exp_output, 'participants.json'), sidecar);
end

function write_scores_from_questionnaire(q_tsv, phenotype_dir, exp_no)
    % Derives stimuli_questionnaire_scores.tsv by aggregating the static
    % stimuli_questionnaire.tsv from config/. Guarantees exact match with BBBD-unzipped.
    if ~isfile(q_tsv)
        fprintf('  scores: questionnaire TSV not found at %s — skipping\n', q_tsv);
        return;
    end
    T = readtable(q_tsv, 'FileType', 'text', 'Delimiter', '\t', 'TextType', 'string');
    pars = unique(T.participant_id, 'stable');
    rows = {};

    if exp_no <= 2
        % domain + memory split (exp1 uses stimulus_id, exp2 uses stim_no)
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
        % single floating-point score per stim (partial credit possible)
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

    else
        % exp4/5: integer score per stimulus (sum is_correct)
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
    end

    writetable(Tout, fullfile(phenotype_dir, 'stimuli_questionnaire_scores.tsv'), ...
        'FileType', 'text', 'Delimiter', '\t');
end

function write_stimuli_feedback(stimData, par_nos, phenotype_dir)
    % questionnaireStimulusData: 1 x Nstim struct, each has engaging/educational/enjoyable [Nsub x 1]
    rows = {};
    n_stim = length(stimData);
    for s = 1:n_stim
        engaging    = stimData(s).engaging;
        enjoyable   = stimData(s).enjoyable;
        educational = stimData(s).educational;
        for i = 1:length(par_nos)
            rows{end+1} = {sprintf('sub-%02d', par_nos(i)), sprintf('Stim-%02d', s), ...
                engaging(i), enjoyable(i), educational(i)};
        end
    end
    T = cell2table(vertcat(rows{:}), 'VariableNames', ...
        {'participant_id','stimulus','engaging','enjoyable','educational'});
    writetable(T, fullfile(phenotype_dir, 'stimuli_feedback_meta.tsv'), ...
        'FileType', 'text', 'Delimiter', '\t');

    sidecar.participant_id.Description = 'unique participant identifier';
    sidecar.stimulus.Description = 'stimulus identifier';
    sidecar.engaging.Description = 'self-reported engagement rating for the stimulus';
    sidecar.enjoyable.Description = 'self-reported enjoyability rating for the stimulus';
    sidecar.educational.Description = 'self-reported educational value rating for the stimulus';
    write_json(fullfile(phenotype_dir, 'stimuli_feedback_meta.json'), sidecar);
end

% -------------------------------------------------------------------------
% ASRS functions
% -------------------------------------------------------------------------

function write_digitspan(T, phenotype_dir)
    % T: table with columns [participant_no, score, weighted_score]
    cols = T.Properties.VariableNames;
    participant_id = arrayfun(@(x) sprintf('sub-%02d', x), T.(cols{1}), 'UniformOutput', false);
    T2 = table(participant_id, T.(cols{2}), T.(cols{3}), ...
        'VariableNames', {'participant_id', 'score', 'weighted_score'});
    writetable(T2, fullfile(phenotype_dir, 'digit_span_scores.tsv'), ...
        'FileType', 'text', 'Delimiter', '\t');

    sidecar.participant_id.Description = 'unique participant identifier';
    sidecar.score.Description = 'digit span forward score';
    sidecar.weighted_score.Description = 'weighted digit span score';
    write_json(fullfile(phenotype_dir, 'digit_span_scores.json'), sidecar);
end

function write_bidsignore(exp_output)
    fid = fopen(fullfile(exp_output, '.bidsignore'), 'w');
    fprintf(fid, 'sub-*/ses-*/eyetrack/\nphenotype/\n');
    fclose(fid);
end

function copy_static_phenotype_file(basename, experiment_no, phenotype_dir)
    % Copies config/experimentN_<basename>.tsv and .json into phenotype_dir.
    for ext = {'tsv', 'json'}
        src = fullfile('config', sprintf('experiment%d_%s.%s', experiment_no, basename, ext{1}));
        dst = fullfile(phenotype_dir, sprintf('%s.%s', basename, ext{1}));
        if isfile(src)
            copyfile(src, dst);
        else
            fprintf('  %s.%s not found in config/ for experiment %d — skipping\n', basename, ext{1}, experiment_no);
        end
    end
end

function copy_readme(exp_output, experiment_no)
    src = fullfile('config', 'readmes', sprintf('experiment%d_README.md', experiment_no));
    dst = fullfile(exp_output, 'README.md');
    if isfile(src)
        copyfile(src, dst);
    else
        fprintf('README not found at %s — skipping\n', src);
    end
end

function write_json(filepath, s)
    fid = fopen(filepath, 'w');
    if fid == -1
        error('Cannot create file: %s', filepath);
    end
    fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true));
    fclose(fid);
end

function make_dir(d)
    if ~exist(d, 'dir')
        mkdir(d);
    end
end
