run('config.m');

exp_nos = [4, 5];

fprintf('Loading metadata\n')
metadata = load(fullfile('config', 'int_metadata.mat'));
metadata = metadata.metadata_full;
doIntervention = load(fullfile('config', 'doIntervention_indexing.mat'));
doIntervention = doIntervention.doIntervention;
modality = 'eeg';

addpath(eeglab_path)
eeglab nogui;
chan = load(fullfile('config', 'BioSemi64.mat'));
bids_raw = true;

sampling_frequency = 128;

base_dir = fullfile(data_dir, sprintf('experiment_%d', 4), 'raw');

listfiles = dir(fullfile(base_dir, '*mat'));
listfiles = {listfiles.name};

fprintf('Loading Total Data\n')
modality_data = load(fullfile(data_dir, 'experiment_4', 'raw', 'data_eeg.mat'));
field_names = fieldnames(modality_data);
total_data = modality_data.(field_names{1});
clear modality_data
fprintf('Total Data Loaded\n')

for exp_no = 1:length(exp_nos)
    experiment_no = exp_nos(exp_no)

    if experiment_no == 4
        intervention = 0;
    elseif experiment_no == 5
        intervention = 1;
    end

    exp_output_dir = fullfile(output_dir, sprintf('experiment%d', experiment_no));
    make_dir(exp_output_dir);

    if experiment_no == 4
        metadata_exp = metadata(~doIntervention);
    elseif experiment_no == 5
        metadata_exp = metadata(doIntervention);
    end

    par_ids = cat(1, metadata_exp.participant_no);

    demodata = load(fullfile('config', sprintf('experiment%d_demographic.mat', experiment_no)));
    ages_char = {demodata.demographicData.Age};
    ages = cellfun(@str2double, ages_char);

    if intervention == 1
        intervention_data = total_data{1,1}; % YES INTERVENTION
    else
        intervention_data = total_data{2,1}; % NO INTERVENTION
    end

    fprintf('Total data loaded....');
    n_sessions = size(intervention_data, 1);
    n_stimuli = size(intervention_data, 2);

    for session_idx = 1:n_sessions
        for stimulus_idx = 1:n_stimuli

            if session_idx == 1
                current_data = intervention_data{1,stimulus_idx};
                [~, ~, n_subs] = size(current_data);
            else
                current_data = intervention_data{2,stimulus_idx};
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

                fprintf('\nSession %d, Subject %d, Stimulus %d', session_idx, subj_idx, stimulus_idx);
                subject_data = current_data(:, :, subj_idx);

                if bids_raw == true
                    fprintf('\nProcessing BIDS Raw...');
                    clear data

                    data = extract_rawdata(subject_data, modality);

                    if isempty(data) || all(data(:) == 0)
                        fprintf('\nSkipping empty or all-zero data file for %d, %s, %s, %s', experiment_no, bids_sub, bids_ses, bids_task);
                        continue;
                    end

                    bids_dir = fullfile(exp_output_dir, bids_sub, bids_ses, 'eeg');
                    make_dir(bids_dir)
                    write_eeg_bdf(sampling_frequency, data, chan, bids_sub, bids_ses, bids_task, bids_dir, modality, false)
                    write_eeg_json(size(data,2), bids_sub, bids_ses, bids_task, 'eeg', bids_dir, stim_id, view_id, experiment_no)
                    write_channels(chan.chanlocs, bids_dir, bids_sub, bids_ses, bids_task)
                    write_electrodes(chan.chanlocs, bids_dir, bids_sub, bids_ses)
                    write_coordinates(experiment_no, bids_dir, bids_sub, bids_ses)
                    create_events(data, sampling_frequency, bids_sub, bids_ses, bids_task, bids_dir);

                end
            end
        end
    end
end

%% EEG

function write_channels(chanlocs, bids_dir, bids_sub, bids_ses, bids_task)
    name = cell(length(chanlocs), 1);
    type = repmat({'EEG'}, length(chanlocs), 1);
    units = repmat({'uV'}, length(chanlocs), 1);
    for i = 1:length(chanlocs)
        name{i} = chanlocs(i).labels;
    end

    sidecar_table = table(name, type, units, ...
        'VariableNames', {'name', 'type', 'units'});

    output_filename = sprintf('%s_%s_%s_channels.tsv', bids_sub, bids_ses, bids_task);
    output_filename_final = fullfile(bids_dir, output_filename);
    writetable(sidecar_table, output_filename_final, 'FileType', 'text', 'Delimiter', '\t', 'WriteVariableNames', true);
end

function write_electrodes(chanlocs, bids_dir, bids_sub, bids_ses)
    labels = cell(length(chanlocs), 1);
    X = zeros(length(chanlocs), 1);
    Y = zeros(length(chanlocs), 1);
    Z = zeros(length(chanlocs), 1);
    type = repmat({'FLAT'}, length(chanlocs), 1);
    material = repmat({'Ag/AgCl'}, length(chanlocs), 1);

    for i = 1:length(chanlocs)
        labels{i} = chanlocs(i).labels;
        X(i) = chanlocs(i).X;
        Y(i) = chanlocs(i).Y;
        Z(i) = chanlocs(i).Z;
    end

    sidecar_table = table(labels, X, Y, Z, type, material, ...
        'VariableNames', {'name', 'x', 'y', 'z', 'type', 'material'});

    output_filename = sprintf('%s_%s_electrodes.tsv', bids_sub, bids_ses);
    output_filename_final = fullfile(bids_dir, output_filename);
    writetable(sidecar_table, output_filename_final, 'FileType', 'text', 'Delimiter', '\t', 'WriteVariableNames', true);
end

function write_coordinates(experiment_no, bids_dir, bids_sub, bids_ses)
    experiment = sprintf('experiment%d', experiment_no);
    sidecar.IntendedFor = fullfile('BBBD', experiment, bids_sub, bids_ses, 'eeg');
    sidecar.EEGCoordinateSystem = 'EEGLAB';
    sidecar.EEGCoordinateUnits = 'mm';
    sidecar.EEGCoordinateSystemDescription = 'Geographic coordinates';
    json_filename = fullfile(bids_dir, sprintf('%s_%s_coordsystem.json', bids_sub, bids_ses));

    fid = fopen(json_filename, 'w');
    if fid == -1
        error('Cannot create JSON file: %s', json_filename);
    end
    fprintf(fid, '%s', jsonencode(sidecar, 'PrettyPrint', true));
    fclose(fid);

    fprintf('Created JSON file: %s\n', json_filename);
end

function create_events(eeg, sampling_frequency, bids_sub, bids_ses, bids_task, bids_dir)
    [n_samp, ~] = size(eeg);

    onset = [0; n_samp/sampling_frequency];
    duration = [1/sampling_frequency; 1/sampling_frequency];
    event = {'start'; 'end'};
    T = table(onset, duration, event);

    events_filename = sprintf('%s_%s_%s_events.tsv', bids_sub, bids_ses, bids_task);
    writetable(T, fullfile(bids_dir, events_filename), 'FileType', 'text', 'Delimiter', '\t', 'WriteVariableNames', true);

    events_sidecar = struct();
    events_sidecar.onset = struct('description', 'time (sec) of event', 'units', 'seconds');
    events_sidecar.duration = struct('description', 'duration (sec) of event', 'units', 'seconds');
    events_sidecar.event = struct('start', 'time when recording starts', 'end', 'time when recording ends');

    events_json_filename = sprintf('%s_%s_%s_events.json', bids_sub, bids_ses, bids_task);
    json_filename = fullfile(bids_dir, events_json_filename);

    fid = fopen(json_filename, 'w');
    if fid == -1
        error('Cannot create JSON file: %s', json_filename);
    end
    fprintf(fid, '%s', jsonencode(events_sidecar, 'PrettyPrint', true));
    fclose(fid);

    fprintf('Created JSON file: %s\n', json_filename);
end

function write_eeg_json(eeg_nsamples, bids_sub, bids_ses, bids_task, subdir, bids_dir, task_id, view_id, experiment_no)
    eeg_metadata = generate_eeg_json_metadata(eeg_nsamples, task_id, view_id, experiment_no);

    json_filename = sprintf('%s_%s_%s_%s.json', bids_sub, bids_ses, bids_task, subdir);
    json_filepath = fullfile(bids_dir, json_filename);
    fid = fopen(json_filepath, 'w');
    if fid == -1
        error('Cannot create JSON file: %s', json_filepath);
    end
    fprintf(fid, '%s', jsonencode(eeg_metadata, 'PrettyPrint', true));
    fclose(fid);

    fprintf('Created EEG JSON file: %s\n', json_filepath);
end

function sidecar = generate_eeg_json_metadata(eeg_nsamples, task_id, view_id, experiment_no)
    duration_data = eeg_nsamples/128;

    sidecar = experiment_sidecar(experiment_no, task_id, view_id);

    sidecar.InstitutionName = 'City College of New York';
    sidecar.InstitutionAddress = '85 St. Nicholas Terrace';
    sidecar.InstitutionalDepartmentName = 'Biomedical Engineering';

    sidecar.SamplingFrequency = 128;
    sidecar.RecordingDuration = duration_data;
    sidecar.RecordingType = 'epoched';
    sidecar.EpochLength = 1;
    sidecar.CogAtlasID = 'https://www.cognitiveatlas.org/concept/id/trm_4a3fd79d09953/';

    sidecar.EEGChannelCount = 64;
    sidecar.EOGChannelCount = 0;
    sidecar.ECGChannelCount = 0;
    sidecar.EMGChannelCount = 0;
    sidecar.MiscChannelCount = 0;
    sidecar.TriggerChannelCount = 0;
    sidecar.PowerLineFrequency = 60;
    sidecar.EEGPlacementScheme = '10-20';
    sidecar.EEGReference = 'none';
    sidecar.EEGGround = 'CMS and DRL electrodes (see https://www.biosemi.com/faq/cms&drl.htm)';

    sidecar.SubjectArtefactDescription = 'n/a';

    sidecar.Manufacturer = 'biosemi';
    sidecar.ManufacturersModelName = 'ActiveTwo';
    sidecar.CapManufacturer = 'EasyCap';
    sidecar.CapManufacturersModelName = 'CUCHW-TDCS';
    sidecar.SoftwareVersions = 'ActiView v8.0';
    sidecar.DeviceSerialNumber = 'ADC6-04-90';

    sidecar.SoftwareFilters.HighPassFilter.Frequency = '0.3Hz';
    sidecar.SoftwareFilters.HighPassFilter.FilterOrder = '5th';
    sidecar.SoftwareFilters.HighPassFilter.Filter = 'butterworth';
    sidecar.SoftwareFilters.HighPassFilter.Function = 'butter';
    sidecar.SoftwareFilters.NotchFilter.Frequency = '60Hz';
    sidecar.SoftwareFilters.NotchFilter.FilterOrder = '5th';
    sidecar.SoftwareFilters.NotchFilter.Filter = 'butterworth';
    sidecar.SoftwareFilters.NotchFilter.Function = 'butter';

    sidecar.HardwareFilters.LowPass.FilterType = '5th order cascaded integrator-comb (CIC) filter response (see https://www.biosemi.com/faq/adjust_filter.htm)';
    sidecar.HardwareFilters.LowPass.FilterCutoff_Hz = '-3 dB point at 1/5th of 2048Hz';
    sidecar.HardwareFilters.BandPass.FilterCutoff_Hz = '0.016Hz-250Hz';
end

function sidecar = experiment_sidecar(experiment_no, task_id, view_id)
    stimulus_id = {'Stim 01', 'Stim 02', 'Stim 03', 'Stim 04', 'Stim 05', 'Stim 06'};
    experiment_1 = {'Why are Stars Star-Shaped', 'How Modern Light Bulbs Work', 'The Immune System Explained – Bacteria', 'Who Invented the Internet - And Why', 'Why Do We Have More Boys Than Girls', ''};
    experiment_2 = {'Why are Stars Star-Shaped', 'How Modern Light Bulbs Work', 'The Immune System Explained – Bacteria', 'Who Invented the Internet - And Why', 'Why Do We Have More Boys Than Girls', ''};
    experiment_3 = {'What If We Killed All the Mosquitoes', 'Are We All Related', 'Work and the work-energy principle', 'Dielectrics in capacitors Circuits', 'How Do People Measure Planets & Suns', 'Three Factors That May Alter the Action of an Enzyme Chemistry Biology Concepts'};
    experiment_4 = {'Why are Stars Star-Shaped', 'The Immune System Explained – Bacteria', 'Are We All Related', 'How Modern Light Bulbs Work', 'What If We Killed All the Mosquitoes', 'Three Factors That May Alter the Action of an Enzyme Chemistry Biology Concepts'};
    experiment_5 = {'Why are Stars Star-Shaped', 'The Immune System Explained – Bacteria', 'Are We All Related', '', '', ''};

    data_table = table(stimulus_id', experiment_1', experiment_2', experiment_3', experiment_4', experiment_5', ...
        'VariableNames', {'Stimulus_ID', 'Experiment_1', 'Experiment_2', 'Experiment_3', 'Experiment_4', 'Experiment_5'});

    rowIdx = find(strcmp(data_table.Stimulus_ID, sprintf('Stim %02d', task_id)));
    if isempty(rowIdx)
        error('Stimulus ID not found in the provided table.');
    end
    experimentField = strcat('Experiment_', num2str(experiment_no));
    if ~ismember(experimentField, data_table.Properties.VariableNames)
        error('Invalid experiment number.');
    end

    stimulusName = data_table.(experimentField){rowIdx};
    if isempty(stimulusName)
        error('Stimulus name is empty for the given ID and experiment.');
    end

    if experiment_no == 4

        if view_id == 1
            view = 'Attentive';
            test_condition = '- Not tested on this content';
            test_desc = 'without being tested on the content of this stimulus';
        else
            view = 'Attentive';
            test_condition = '- Tested on this content';
            test_desc = 'and be tested on the content of this stimulus';
        end

        sidecar = struct();
        sidecar.TaskName = sprintf('Stim %02d, %s Condition %s', task_id, view, test_condition);
        sidecar.TaskDescription = sprintf('Watch educational video [ %s ] in %s Condition %s', stimulusName, view, test_desc);

    elseif experiment_no == 5

        if view_id == 1
            view = 'Attentive';
            test_condition = '- Test not given';
            test_desc = 'without being tested on the stimuli content';
        else
            view = 'Intervention';
            test_condition = '- Test given';
            test_desc = 'and be tested on the stimuli content, after being incentivized';
        end

        sidecar = struct();
        sidecar.TaskName = sprintf('Stim %02d, %s Condition %s', task_id, view, test_condition);
        sidecar.TaskDescription = sprintf('Watch educational video [ %s ] in %s Condition %s', stimulusName, view, test_desc);

    else
        if view_id == 1
            view = 'Attentive';
        else
            view = 'Distracted';
        end

        sidecar = struct();
        sidecar.TaskName = sprintf('Stim %02d, %s Condition', task_id, view);
        sidecar.TaskDescription = sprintf('Watch educational video [ %s ] in %s Condition', stimulusName, view);
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
    EEG.setname = 'BDF file';

    nChannels = length(chan.chanlocs);
    EEG.chanlocs = struct('labels', [], 'theta', [], 'radius', [], ...
                           'X', [], 'Y', [], 'Z', [], ...
                           'sph_theta', [], 'sph_phi', []);
    for i = 1:nChannels
        EEG.chanlocs(i).labels = chan.chanlocs(i).labels;
        EEG.chanlocs(i).theta = chan.chanlocs(i).theta;
        EEG.chanlocs(i).radius = chan.chanlocs(i).radius;
        EEG.chanlocs(i).X = chan.chanlocs(i).X;
        EEG.chanlocs(i).Y = chan.chanlocs(i).Y;
        EEG.chanlocs(i).Z = chan.chanlocs(i).Z;
        EEG.chanlocs(i).sph_theta = chan.chanlocs(i).sph_theta;
        EEG.chanlocs(i).sph_phi = chan.chanlocs(i).sph_phi;
    end

    if processed_sig == true
        bids_filename = processed_data_filename(bids_sub, bids_ses, bids_task, modality);
    else
        bids_filename = sprintf('%s_%s_%s_%s.bdf', bids_sub, bids_ses, bids_task, modality);
    end

    bdf_filepath = fullfile(bids_dir, bids_filename);
    pop_writeeeg(EEG, bdf_filepath, 'TYPE', 'BDF');
end

%% MISC / GENERAL

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
    end
end

function make_dir(bids_dir)
    if ~exist(bids_dir, 'dir')
        mkdir(bids_dir);
    end
end
