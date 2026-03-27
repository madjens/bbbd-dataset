run('config.m');

experiment_nos = {1, 2, 3};

for expno = 1:length(experiment_nos)
    experiment_no = experiment_nos{expno}
    datatypes = {'processed'};
    for n = 1:length(datatypes)
        datatype = datatypes{n}

        data_path = fullfile(data_dir, sprintf('experiment_%d', experiment_no), datatype);

        listfiles = dir(fullfile(data_path, '*mat'));
        listfiles = {listfiles.name};

        modalities = {'eeg'};

        for i = 1:length(modalities)
            modality = modalities{i};

            filename_processed = listfiles(contains(listfiles, strcat('data_', modality)));
            if isempty(filename_processed)
                fprintf('Modality %s doesnt exist. Skipping...\n', modality);
                continue
            end
            data_matrix = load(fullfile(data_path, filename_processed{1}), strcat('data_', modality));

            if strcmp(datatype, 'raw')
                data = process_raw_struct(data_matrix, modality);

            elseif strcmp(datatype, 'processed')
                data = process_processed_struct(data_matrix, modality);

                if strcmp(modality, 'ecg') || strcmp(modality, 'eye') || strcmp(modality, 'respiration')
                    process_rate_struct(data_matrix, modality, experiment_no, datatype, output_dir);
                end
            end

            op_dir = fullfile(output_dir, 'matrix_data', datatype, sprintf('experiment%d', experiment_no));
            if ~exist(op_dir, 'dir')
                mkdir(op_dir);
            end

            if strcmp(modality, 'eye')
                filename_new = fullfile(op_dir, sprintf('%s_experiment%d_%s.mat', datatype, experiment_no, 'gaze_visualangle'));
            else
                filename_new = fullfile(op_dir, sprintf('%s_experiment%d_%s.mat', datatype, experiment_no, modality));
            end

            save(filename_new, 'data', '-v7.3');
            fileInfo = dir(filename_new);
            fprintf('%s File size: %.2f GB\n', filename_new, fileInfo.bytes / (1024^3));

        end
    end
end

%%
function process_rate_struct(dataStruct, modality, experiment_no, datatype, output_dir)
    function cols = get_columns_to_keep(modality, totalColumns)
        switch modality
            case 'eye'
                cols = [8, 9, 10]; % saccaderate, blinkrate, fixationrate
            case 'ecg'
                cols = 1; % heartrate
            case 'respiration'
                cols = 2; % breathrate
            otherwise
                error('Unknown modality: %s', modality);
        end
        cols = intersect(1:totalColumns, cols);
    end

    function cols = get_ratecolumns_to_keep(modality, totalColumns)
        switch modality
            case 'saccaderate'
                cols = 1;
            case 'blinkrate'
                cols = 2;
            case 'fixationrate'
                cols = 3;
            case 'heartrate'
                cols = 1;
            case 'breathrate'
                cols = 1;
            otherwise
                error('Unknown modality: %s', modality);
        end
        cols = intersect(1:totalColumns, cols);
    end

    field_names = fieldnames(dataStruct);
    rate_data = cellfun(@(x) x(:, get_columns_to_keep(modality, size(x, 2)), :), dataStruct.(field_names{1}), 'UniformOutput', false);

    switch modality
        case 'eye'
            rate_types = {'saccaderate', 'blinkrate', 'fixationrate'};
        case 'ecg'
            rate_types = {'heartrate'};
        case 'respiration'
            rate_types = {'breathrate'};
        otherwise
            error('Unknown modality: %s', modality);
    end

    op_dir = fullfile(output_dir, 'matrix_data', datatype, sprintf('experiment%d', experiment_no));
    if ~exist(op_dir, 'dir')
        mkdir(op_dir);
    end

    for i = 1:length(rate_types)
        rate_type = rate_types{i};

        data.(rate_type) = cellfun(@(x) ...
        x(:, get_ratecolumns_to_keep(rate_type, size(x, 2)), :), ...
        rate_data, 'UniformOutput', false);

        filename_new = fullfile(op_dir, sprintf('%s_experiment%d_%s.mat', datatype, experiment_no, rate_type));
        save(filename_new, 'data', '-v7.3');

        fileInfo = dir(filename_new);
        fprintf('%s File size: %.2f GB\n', filename_new, fileInfo.bytes / (1024^3));
        clear data
    end
end

function data = process_raw_struct(dataStruct, modality)
    function cols = get_columns_to_keep(modality, totalColumns)
        switch modality
            case 'eye'
                cols = [1:2, 5:6]; % gaze (2), vdxy (2)
            case 'pupil'
                cols = 1; % pupil diameter
            case 'head'
                cols = 1:3; % x, y, z
            case 'ecg'
                cols = 4; % raw ECG
            case 'eog'
                cols = 1:6; % all EOG channels
            case 'respiration'
                cols = 1; % single channel
            case 'eeg'
                cols = 1:64; % 64 EEG channels
            otherwise
                error('Unknown modality: %s', modality);
        end

        cols = intersect(1:totalColumns, cols);
    end

    field_names = fieldnames(dataStruct);
    if strcmp(modality, 'eye')
        data.('gaze_visualangle') = cellfun(@(x) ...
            x(:, get_columns_to_keep(modality, size(x, 2)), :), ...
            dataStruct.(field_names{1}), 'UniformOutput', false);

    else
        data.(modality) = cellfun(@(x) ...
            x(:, get_columns_to_keep(modality, size(x, 2)), :), ...
            dataStruct.(field_names{1}), 'UniformOutput', false);
    end
end

function data = process_processed_struct(dataStruct, modality)
    function cols = get_columns_to_keep(modality, totalColumns)
        switch modality
            case 'eye'
                cols = [1:2, 5:6]; % gaze (2), vdxy (2)
            case 'pupil'
                cols = 1; % pupil diameter
            case 'head'
                cols = 1:3; % x, y, z
            case 'ecg'
                cols = 3; % filtered ECG
            case 'eog'
                cols = 1:6; % all EOG channels
            case 'respiration'
                cols = 1; % single channel
            case 'eeg'
                cols = 1:64; % 64 EEG channels
            otherwise
                error('Unknown modality: %s', modality);
        end

        cols = intersect(1:totalColumns, cols);
    end

    field_names = fieldnames(dataStruct);

    if strcmp(modality, 'eye')
        data.('gaze_visualangle') = cellfun(@(x) ...
            x(:, get_columns_to_keep(modality, size(x, 2)), :), ...
            dataStruct.(field_names{1}), 'UniformOutput', false);

    else
        data.(modality) = cellfun(@(x) ...
            x(:, get_columns_to_keep(modality, size(x, 2)), :), ...
            dataStruct.(field_names{1}), 'UniformOutput', false);
    end
end
