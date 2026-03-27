run('config.m');

% Only for Experiments 1, 2, 3
% Compute continuous processed signals (heartrate, saccaderate, blinkrate, fixationrate)

input_dirs = {'eog'};
process_input_dirs = {'eog'};

processed_signals = true;
sampling_frequency = 128;

exp_nos = [1, 2, 3];
for i=1:length(exp_nos)
    experiment_no = exp_nos(i)

    addpath(eeglab_path)
    addpath(biosig_path)
    eeglab nogui;
    chan = load(fullfile('config', 'BioSemi64.mat'));

    base_dir = fullfile(data_dir, sprintf('experiment_%d', experiment_no), 'raw');
    base_processed_dir = fullfile(data_dir, sprintf('experiment_%d', experiment_no), 'processed');
    par_id_dir = fullfile(data_dir, sprintf('experiment_%d', experiment_no), 'metadata');

    listfiles_processed = dir(fullfile(base_processed_dir, '*mat'));
    listfiles_processed = {listfiles_processed.name};

    exp_output_dir = fullfile(output_dir, sprintf('experiment%d', experiment_no));
    make_dir(exp_output_dir);

    par_meta_files = dir(fullfile(par_id_dir, '*.mat'));
    par_ids = get_participant_ids(par_meta_files);

    for i = 1:length(input_dirs)
        modality = input_dirs{i}
        if strcmp(modality, 'ecg') || strcmp(modality, 'eog')
            processed_subdir = 'beh';

        elseif strcmp(modality, 'eye') || strcmp(modality, 'pupil') || strcmp(modality, 'head')
            processed_subdir = 'eyetrack';

        elseif strcmp(modality, 'eeg')
            processed_subdir = 'eeg';
        end

        if processed_signals == true && any(strcmp(process_input_dirs, modality))
            filename_processed = listfiles_processed(contains(listfiles_processed, strcat('data_', modality)));
            if ~isempty(filename_processed)
                modality_data_processed = load(fullfile(base_processed_dir, filename_processed{1}), strcat('data_', modality));
                field_names = fieldnames(modality_data_processed);
                total_data_processed = modality_data_processed.(field_names{1});
                fprintf('Total processed data loaded....');
                n_sessions = size(total_data_processed, 1);
                n_stimuli = size(total_data_processed, 2);
            else
                continue
            end
        end

        for session_idx = 1:n_sessions
            for stimulus_idx = 1:n_stimuli
                current_data = total_data_processed{session_idx, stimulus_idx};
                [~, ~, n_subs] = size(current_data);

                for subj_idx = 1:n_subs

                    stim_id = stimulus_idx;
                    view_id = session_idx;
                    par_id_num = par_ids(subj_idx);

                    bids_sub = sprintf('sub-%02d', par_id_num);
                    bids_ses = sprintf('ses-%02d', view_id);
                    bids_task = sprintf('task-stim%02d', stim_id);

                    fprintf('\nSession %d, Subject %d, Stimulus %d', session_idx, subj_idx, stimulus_idx);

                    if processed_signals == true && any(strcmp(process_input_dirs, modality))
                        if ~isempty(processed_subdir)
                            processed_bids_dir = fullfile(exp_output_dir, 'derivatives', bids_sub, bids_ses, processed_subdir);
                            make_dir(processed_bids_dir);

                            current_data_processed = total_data_processed{session_idx, stimulus_idx};
                            subject_data_processed = current_data_processed(:, :, subj_idx);

                            if isempty(subject_data_processed) || all(subject_data_processed(:) == 0) || all(isnan(subject_data_processed(:)))
                                fprintf('\nSkipping empty or all-zero data file for %s, %s, %s, %s', experiment_no, bids_sub, bids_ses, bids_task);
                                continue

                            elseif strcmp(modality, 'eye') || strcmp(modality, 'ecg')
                                derived = extract_deriveddata(subject_data_processed, modality);
                                write_derived_bids(derived, processed_bids_dir, bids_sub, bids_ses, bids_task, modality)
                            end

                            data_processed = extract_rawdata(subject_data_processed, modality);
                            if strcmp(modality, 'eye') || strcmp(modality, 'pupil') || strcmp(modality, 'head')
                                fprintf('\nProcessing BIDS Eyetrack Signals...')
                                write_eyetracking_bids(data_processed, processed_bids_dir, bids_sub, bids_ses, bids_task, modality, true)

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

function par_ids = get_participant_ids(par_meta_files)
    par_ids = zeros(1, length(par_meta_files));
    for i = 1:length(par_meta_files)
        name_parts = regexp(par_meta_files(i).name, 'metadata_participant_(\d+)', 'tokens');
        if ~isempty(name_parts)
            par_ids(i) = str2double(name_parts{1}{1});
        end
    end
end
