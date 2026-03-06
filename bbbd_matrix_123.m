experiment_nos = {1,2,3}
experiment_nos = {2}

for expno = 1:length(experiment_nos)
    experiment_no = experiment_nos{expno}
    % datatypes = {'raw', 'processed'};
    datatypes = {'processed'};
    for n = 1:length(datatypes)
        datatype = datatypes{n}
        
        data_path = sprintf('D:\\Users\\Neuro\\City College Dropbox\\NIKHIL KUPPA\\dataset_multimodal_video\\data\\experiment_%d\\%s', experiment_no, datatype);
        
        listfiles = dir(fullfile(data_path, '*mat'));
        listfiles = {listfiles.name};
        % modalities = {'ecg', 'eog', 'respiration', 'eeg', 'eye', 'pupil', 'head'};
    
        modalities = {'eeg'};
    
        for i = 1:length(modalities)
            modality = modalities{i};
    
            filename_processed = listfiles(contains(listfiles, strcat('data_', modality)));
            if isempty(filename_processed)
                fprintf(sprintf(newline, 'Modality %s doesnt exist. Skipping...', modality));
                continue
            end
            data_matrix = load(fullfile(data_path, filename_processed{1}), strcat('data_', modality));
    
            if strcmp(datatype, 'raw')
                datatype
                data = process_raw_struct(data_matrix, modality);
    
            elseif strcmp(datatype, 'processed') 
                datatype
                data = process_processed_struct(data_matrix, modality);
    
                if strcmp(modality, 'ecg') || strcmp(modality, 'eye') || strcmp(modality, 'respiration')
                    process_rate_struct(data_matrix, modality, experiment_no, datatype);
                end
            end
            
            % "D:\\Users\\Neuro\\City College Dropbox\\NIKHIL KUPPA\\dataset_multimodal_video\\BBBD\\matrix_data\\%s\\experiment%d"
            op_dir = sprintf("D:\\Users\\Neuro\\City College Dropbox\\NIKHIL KUPPA\\dataset_multimodal_video\\BBBD\\matrix_data\\%s\\experiment%d", datatype, experiment_no)
            if ~exist(op_dir, 'dir')
                mkdir(op_dir);
            end
    
    
            if strcmp(modality, 'eye')
                filename_new = sprintf("%s\\%s_experiment%d_%s.mat", op_dir, datatype, experiment_no, 'gaze_visualangle');
            else
                filename_new = sprintf("%s\\%s_experiment%d_%s.mat", op_dir, datatype, experiment_no, modality);
            end

            save(filename_new, 'data', '-v7.3');
            fileInfo = dir(filename_new);
            fprintf('%s File size: %.2f GB\n', filename_new, fileInfo.bytes / (1024^3));
            
        end
    end
end
%%
function process_rate_struct(dataStruct, modality, experiment_no, datatype)
    fprintf(newline, 'Processing Rate...');
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
                cols = 2; % heartrate
            case 'fixationrate'
                cols = 3; % breathrate
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
    
    % op_dir = sprintf('experiment%d\\%s', experiment_no, datatype);
    op_dir = sprintf("D:\\Users\\Neuro\\City College Dropbox\\NIKHIL KUPPA\\dataset_multimodal_video\\BBBD\\matrix_data\\%s\\experiment%d", datatype, experiment_no)
    if ~exist(op_dir, 'dir')
        mkdir(op_dir);
    end
    
    for i = 1:length(rate_types)
        rate_type = rate_types{i};
    
        data.(rate_type) = cellfun(@(x) ...
        x(:, get_ratecolumns_to_keep(rate_type, size(x, 2)), :), ...
        rate_data, 'UniformOutput', false);
    
        filename_new = sprintf('%s\\%s_experiment%d_%s.mat', op_dir, datatype, experiment_no, rate_type);
        save(filename_new, 'data', '-v7.3');
    
        fileInfo = dir(filename_new);
        fprintf('%s File size: %.2f GB\n', filename_new, fileInfo.bytes / (1024^3));
        clear data
    end
end

function data = process_raw_struct(dataStruct, modality)
    fprintf(newline, 'Processing Raw...');
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
    
    fprintf(newline, 'Processing Processed...');
    function cols = get_columns_to_keep(modality, totalColumns)
        switch modality
            case 'eye'
                cols = [1:2, 5:6]; % gaze (2), vdxy (2)
            case 'pupil'
                cols = 1; % pupil diameter
            case 'head'
                cols = 1:3; % x, y, z
            case 'ecg'
                cols = 3; % filt ECG
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