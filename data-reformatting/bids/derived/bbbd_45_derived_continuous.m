run('config.m');

% Only for Experiments 4, 5
% Compute continuous processed signals (filtECG, heartrate, respirationrate, saccaderate, blinkrate, fixationrate)

addpath(eeglab_path)
eeglab nogui;
chan = load(fullfile('config', 'BioSemi64.mat'));

processed_signals = true;

exp_nos = [4, 5];

doIntervention = load(fullfile('config', 'doIntervention_indexing.mat'));
doIntervention = doIntervention.doIntervention;

metadata = load(fullfile('config', 'int_metadata.mat'));
metadata = metadata.metadata_full;

for exp_no = 1:length(exp_nos)
    experiment_no = exp_nos(exp_no)

    input_dirs = {'eog', 'respiration'};
    process_input_dirs = {'eog', 'respiration'};

    if experiment_no == 4
        intervention = 0;
    elseif experiment_no == 5
        intervention = 1;
    end

    bids_raw = true;

    sampling_frequency = 128;

    base_exp_no = 4;
    base_dir_processed = fullfile(data_dir, sprintf('experiment_%d', base_exp_no), 'processed');
    par_id_dir = fullfile(data_dir, sprintf('experiment_%d', base_exp_no), 'metadata');

    listfiles_processed = dir(fullfile(base_dir_processed, '*mat'));
    listfiles_processed = {listfiles_processed.name};

    exp_output_dir = fullfile(output_dir, sprintf('experiment%d', experiment_no));
    make_dir(exp_output_dir);

    fprintf('Loading metadata\n')

    if experiment_no == 4
        metadata_exp = metadata(~doIntervention);
    elseif experiment_no == 5
        metadata_exp = metadata(doIntervention);
    end

    par_ids = cat(1, metadata_exp.participant_no);

    demodata = load(fullfile('config', sprintf('experiment%d_demographic.mat', experiment_no)));
    ages_char = {demodata.demographicData.Age};
    ages = cellfun(@str2double, ages_char);

    for i = 1:length(input_dirs)
        modality = input_dirs{i}

        if strcmp(modality, 'ecg') || strcmp(modality, 'eog') || strcmp(modality, 'respiration')
            processed_subdir = 'beh';
        elseif strcmp(modality, 'eye') || strcmp(modality, 'pupil') || strcmp(modality, 'head')
            processed_subdir = 'eyetrack';
        elseif strcmp(modality, 'eeg')
            processed_subdir = 'eeg';
        end

        if processed_signals == true && any(strcmp(process_input_dirs, modality))
            filename_processed = listfiles_processed(contains(listfiles_processed, strcat('data_', modality)));
            if strcmp(modality, 'eeg')
                modality_data_processed = load(fullfile(data_dir, 'experiment_4', 'processed', 'data_eeg_processed.mat'));
            else
                modality_data_processed = load(fullfile(base_dir_processed, filename_processed{1}));
            end

            field_names = fieldnames(modality_data_processed);
            total_data_processed = modality_data_processed.(field_names{1});

            if intervention == 1
                intervention_data_processed = total_data_processed{1,1}; % YES INTERVENTION
            else
                intervention_data_processed = total_data_processed{2,1}; % NO INTERVENTION
            end

            n_sessions = size(intervention_data_processed, 1);
            n_stimuli = size(intervention_data_processed, 2);

            clear modality_data_processed total_data_processed

            fprintf('Total processed data loaded....');
        end

        for session_idx = 1:n_sessions
            for stimulus_idx = 1:n_stimuli

                if session_idx == 1
                    current_data = intervention_data_processed{1,stimulus_idx};
                    [~, ~, n_subs] = size(current_data);
                else
                    current_data = intervention_data_processed{2,stimulus_idx};
                    [~, ~, n_subs] = size(current_data);
                end

                for subj_idx = 1:n_subs
                    if ages(subj_idx) < 18
                        fprintf('\nSkipping subject %d for being under age', subj_idx);
                        continue
                    end

                    if intervention == 0 && session_idx == 1
                        stim_id = stimulus_idx + 3; % stimuli 4, 5, 6 in block 1 for no-intervention data
                    else
                        stim_id = stimulus_idx;
                    end

                    view_id = session_idx;
                    par_id_num = par_ids(subj_idx);

                    bids_ses = sprintf('ses-%02d', view_id);
                    bids_task = sprintf('task-stim%02d', stim_id);
                    bids_sub = sprintf('sub-%02d', subj_idx);

                    if processed_signals == true && any(strcmp(process_input_dirs, modality))
                        if ~isempty(processed_subdir)
                            processed_bids_dir = fullfile(exp_output_dir, 'derivatives', bids_sub, bids_ses, processed_subdir);
                            make_dir(processed_bids_dir);

                            subject_data_processed = current_data(:, :, subj_idx);

                            if isempty(subject_data_processed) || all(subject_data_processed(:) == 0) || all(isnan(subject_data_processed(:)))
                                fprintf('\nSkipping empty or all-zero data file for %d, %s, %s, %s', experiment_no, bids_sub, bids_ses, bids_task);
                                continue

                            elseif strcmp(modality, 'eye') || strcmp(modality, 'ecg') || strcmp(modality, 'respiration')
                                derived = extract_deriveddata(subject_data_processed, modality);
                                write_derived_bids(derived, processed_bids_dir, bids_sub, bids_ses, bids_task, modality)
                            end

                            data_processed = extract_rawdata(subject_data_processed, modality);

                            if strcmp(modality, 'eye') || strcmp(modality, 'pupil') || strcmp(modality, 'head')
                                fprintf('\nProcessing BIDS Eyetrack Signals...')
                                write_eyetracking_bids(data_processed, processed_bids_dir, bids_sub, bids_ses, bids_task, modality, true)

                            elseif strcmp(modality, 'respiration')
                                disp('Processing respiration...')
                                derivedResp.respiration = data_processed;
                                saveAndCompressData(derivedResp, processed_bids_dir, bids_sub, bids_ses, bids_task);

                            elseif strcmp(modality, 'eog')
                                disp('Processing eog...')
                                derivedeog.eog = data_processed;
                                saveAndCompressData(derivedeog, processed_bids_dir, bids_sub, bids_ses, bids_task);

                            elseif strcmp(modality, 'eeg')
                                disp('Processing EEG...')
                                write_eeg_bdf(sampling_frequency, data_processed, chan, bids_sub, bids_ses, bids_task, processed_bids_dir, modality, true);
                            end

                        end
                    end
                end
            end
        end
    end
end

%% DERIVED DATA

function data = extract_rawdata(subdata, modality)
    if strcmp(modality, 'eye')
        data = [subdata(:, 1:2), subdata(:, 5:6)]; % gaze (2), vdxy (2)
    elseif strcmp(modality, 'pupil')
        data = subdata(:,1);
    elseif strcmp(modality, 'head')
        data = subdata(:,1:3); % x, y, z
    elseif strcmp(modality, 'ecg')
        data = subdata(:, 4); % raw ECG
    elseif strcmp(modality, 'eog')
        data = subdata(:,1:6);
    elseif strcmp(modality, 'respiration')
        data = subdata(:,1);
    elseif strcmp(modality, 'eeg')
        data = subdata(:,1:64);
    else % interpolation
        data = subdata(:,1);
    end
end

function eeg = eeg_data(eeg, sampling_frequency)
    [n_samp, n_ch] = size(eeg);
    num_blocks = ceil(n_samp / sampling_frequency);
    required_samples = num_blocks * sampling_frequency;
    num_additional_samples = required_samples - n_samp;

    if num_additional_samples > 0
        eeg = [eeg; zeros(num_additional_samples, n_ch)];
    end

    eeg = eeg.';
end

function write_eeg_bdf(sampling_frequency, eeg, chan, bids_sub, bids_ses, bids_task, bids_dir, modality, processed_sig)
    clear EEG
    EEG.srate = sampling_frequency;
    EEG.data = eeg_data(eeg, sampling_frequency);
    EEG.chanlocs.labels = {chan.chanlocs(:).labels};
    EEG.chanlocs.theta = {chan.chanlocs(:).theta};
    EEG.chanlocs.radius = {chan.chanlocs(:).radius};
    EEG.chanlocs.X = {chan.chanlocs(:).X};
    EEG.chanlocs.Y = {chan.chanlocs(:).Y};
    EEG.chanlocs.Z = {chan.chanlocs(:).Z};
    EEG.chanlocs.sph_theta = {chan.chanlocs(:).sph_theta};
    EEG.chanlocs.sph_phi = {chan.chanlocs(:).sph_phi};
    EEG.setname = 'BDF file';

    if processed_sig == true
        bids_filename = processed_data_filename(bids_sub, bids_ses, bids_task, modality);
    else
        bids_filename = sprintf('%s_%s_%s_%s.bdf', bids_sub, bids_ses, bids_task, modality);
    end

    bdf_filepath = fullfile(bids_dir, bids_filename);
    pop_writeeeg(EEG, bdf_filepath, 'TYPE', 'BDF');
end

function filename = processed_data_filename(bids_sub, bids_ses, bids_task, modality)
    if strcmp(modality, 'eeg')
        filename = sprintf('%s_%s_%s_desc-%s.bdf', bids_sub, bids_ses, bids_task, modality);
    else
        if strcmp(modality, 'eye')
            modality = 'gaze';
        end
        filename = sprintf('%s_%s_%s_desc-%s_eyetrack.tsv', bids_sub, bids_ses, bids_task, modality);
    end
end

function data = extract_deriveddata(subdata, modality)
    if strcmp(modality, 'eye')
        data = subdata(:, 8:10); % saccaderate, blinkrate, fixationrate
    elseif strcmp(modality, 'ecg')
        data = [subdata(:, 3), subdata(:, 1)]; % filtered ECG, heartrate
    elseif strcmp(modality, 'respiration')
        data = subdata(:,2); % respiration rate
    elseif strcmp(modality, 'eog')
        data = subdata(:,1:6);
    elseif strcmp(modality, 'pupil')
        data = subdata(:,1);
    end
end

function write_derived_bids(data, derivatives_dir, bids_sub, bids_ses, bids_task, modality)
    if strcmp(modality, 'ecg')
        derivedECG.filteredECG = data(:,1);
        derivedECG.heartrate = data(:,2);
        saveAndCompressData(derivedECG, derivatives_dir, bids_sub, bids_ses, bids_task);
        disp(['Writing ' modality ' derived data for ' bids_sub, bids_ses, bids_task]);

    elseif strcmp(modality, 'eye')
        derivedEye.saccaderate = data(:,1);
        derivedEye.blinkrate = data(:,2);
        derivedEye.fixationrate = data(:,3);
        saveAndCompressData(derivedEye, derivatives_dir, bids_sub, bids_ses, bids_task);
        disp(['Writing ' modality ' derived data for ' bids_sub, bids_ses, bids_task]);

    elseif strcmp(modality, 'respiration')
        derivedResp.breathrate = data;
        saveAndCompressData(derivedResp, derivatives_dir, bids_sub, bids_ses, bids_task);
        disp(['Writing ' modality ' derived data for ' bids_sub, bids_ses, bids_task]);
    end
end

function write_eyetracking_bids(data, bids_dir, bids_sub, bids_ses, bids_task, modality, processed_sig)
    if strcmp(modality, 'eye')
        modality = 'gaze';
    end

    if processed_sig == true
        tsv_filename = processed_data_filename(bids_sub, bids_ses, bids_task, modality);
    else
        tsv_filename = sprintf('%s_%s_%s_%s_eyetrack.tsv', bids_sub, bids_ses, bids_task, modality);
    end

    tsv_filepath = fullfile(bids_dir, tsv_filename);
    writematrix(data, tsv_filepath, 'FileType', 'text', 'Delimiter', '\t');
    gzip(tsv_filepath);
    delete(tsv_filepath);
end

function saveAndCompressData(data, derivatives_dir, bids_sub, bids_ses, bids_task)
    fields = fieldnames(data);
    for i = 1:numel(fields)
        fieldName = fields{i};
        fileName = sprintf('%s_%s_%s_desc-%s.tsv.gz', bids_sub, bids_ses, bids_task, fieldName);
        filePath = fullfile(derivatives_dir, fileName);
        if exist(filePath,"file")
            delete(filePath)
            disp(['Deleted ', filePath])
        end
        fileName = sprintf('%s_%s_%s_desc-%s.tsv', bids_sub, bids_ses, bids_task, fieldName);
        filePath = fullfile(derivatives_dir, fileName);
        writematrix(data.(fieldName), filePath, 'FileType', 'text', 'Delimiter', '\t');
        gzip(filePath);
        delete(filePath);
    end
end

function make_dir(bids_dir)
    if ~exist(bids_dir, 'dir')
        mkdir(bids_dir);
    end
end

function extract_discrete_eyederivatives(discrete_list, metadata, derivatives_dir, bids_sub, bids_ses, bids_task, stim_idx, ses_idx)
    for i = 1:numel(discrete_list)
        fieldName = discrete_list(i);
        if isempty(metadata.segments(stim_idx, ses_idx).(fieldName))
            continue
        end

        derived_eye.(fieldName).start_time = metadata.segments(stim_idx, ses_idx).(fieldName).timestamps_rel_stim(:,1);
        derived_eye.(fieldName).end_time = metadata.segments(stim_idx, ses_idx).(fieldName).timestamps_rel_stim(:,2);
        derived_eye.(fieldName).duration = derived_eye.(fieldName).end_time - derived_eye.(fieldName).start_time;

        if strcmp(fieldName, 'saccades')
            derived_eye.(fieldName).start_x = metadata.segments(stim_idx, ses_idx).(fieldName).start_x_pos;
            derived_eye.(fieldName).start_y = metadata.segments(stim_idx, ses_idx).(fieldName).start_y_pos;
            derived_eye.(fieldName).end_x = metadata.segments(stim_idx, ses_idx).(fieldName).end_x_pos;
            derived_eye.(fieldName).end_y = metadata.segments(stim_idx, ses_idx).(fieldName).end_y_pos;
            derived_eye.(fieldName).start_vdx = metadata.segments(stim_idx, ses_idx).(fieldName).start_vdx_pos;
            derived_eye.(fieldName).start_vdy = metadata.segments(stim_idx, ses_idx).(fieldName).start_vdy_pos;
            derived_eye.(fieldName).end_vdx = metadata.segments(stim_idx, ses_idx).(fieldName).end_vdx_pos;
            derived_eye.(fieldName).end_vdy = metadata.segments(stim_idx, ses_idx).(fieldName).end_vdy_pos;

        elseif strcmp(fieldName, 'fixations')
            derived_eye.(fieldName).x_pos = metadata.segments(stim_idx, ses_idx).(fieldName).x_pos;
            derived_eye.(fieldName).y_pos = metadata.segments(stim_idx, ses_idx).(fieldName).y_pos;
            derived_eye.(fieldName).vdx_pos = metadata.segments(stim_idx, ses_idx).(fieldName).vdx_pos;
            derived_eye.(fieldName).vdy_pos = metadata.segments(stim_idx, ses_idx).(fieldName).vdy_pos;
        end

        fileName = sprintf('%s_%s_%s_desc-%s.tsv', bids_sub, bids_ses, bids_task, fieldName);
        filePath = fullfile(derivatives_dir, fileName);
        table_eye = struct2table(derived_eye.(fieldName));
        writetable(table_eye, filePath, 'FileType', 'text', 'Delimiter', '\t');
        gzip(filePath);
        delete(filePath);
    end
end
