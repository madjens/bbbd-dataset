experiment_nos = {4, 5}
for expno = 1:length(experiment_nos)
    experiment_no = experiment_nos{expno}

    if experiment_no == 4
        intervention = 0;
    else
        intervention = 1;
    end
    
    % datatypes = {'raw', 'processed'};
    datatypes = {'processed'};
    for n = 1:length(datatypes)
        datatype = datatypes{n}
        data_path = sprintf('D:\\Users\\Neuro\\City College Dropbox\\NIKHIL KUPPA\\dataset_multimodal_video\\data\\experiment_%d\\%s', 4, datatype);
        
        listfiles = dir(fullfile(data_path, '*mat'));
        listfiles = {listfiles.name};
        % modalities = {'ecg', 'eog', 'respiration', 'eye', 'pupil', 'head', 'eeg'};
        % modalities = {'ecg', 'respiration', 'eye'};
        % modalities = {'ecg', 'respiration'}
        modalities = {'eye'}
    
        for i = 1:length(modalities)
            modality = modalities{i};
            filename_processed = listfiles(contains(listfiles, strcat('data_', modality)));
            if isempty(filename_processed)
                fprintf(sprintf(newline, 'Modality %s doesnt exist. Skipping...', modality));
                continue
            end
    
            clear data_matrix
            clear all_data
    
            % if strcmp(modality, 'eeg')  
            %     if strcmp(datatype, 'raw')
            %         data_matrix = load(sprintf("C:\\Users\\Nikhil\\research\\mevd\\eeg_intervention\\%s\\data_eeg__arej_0_bcrej_0_eogreg_0_bc_ass_sync_audio_frames_RPCA_0_fs=128.mat", datatype));
            % 
            %     elseif strcmp(datatype, 'processed') 
            %         data_matrix = load(sprintf("C:\\Users\\Nikhil\\research\\mevd\\eeg_intervention\\%s\\data_eeg__arej_1_bcrej_1_eogreg_1_bc_ass_sync_audio_frames_RPCA_1_fs=128.mat", datatype));
            %     end
            % 
            % else
            data_matrix = load(fullfile(data_path, filename_processed{1}), strcat('data_', modality));
            % end
            
            field_names = fieldnames(data_matrix);
            fieldname = field_names{1}
            all_data = data_matrix.(field_names{1});
    
            if intervention == 1
                data_matrix = all_data{1,1}; % YES INTERVENTION
            else
                data_matrix = all_data{2,1}; % NO INTERVENTION
            end
    
            data = process_matrix(data_matrix, modality, experiment_no, datatype);

            if strcmp(datatype, 'processed') 
                if (strcmp(modality, 'ecg') || strcmp(modality, 'eye') || strcmp(modality, 'respiration'))
                    process_rate_matrix(data_matrix, modality, experiment_no, datatype);
                end
    
            end
        
            op_dir = sprintf("C:\\Users\\Neuro\\research\\bbbd_output\\bbbd\\matrix_data\\%s\\experiment%d", datatype, experiment_no)
            if ~exist(op_dir, 'dir')
                mkdir(op_dir);
            end
    
    
            if strcmp(modality, 'eye')
                filename_new = sprintf("%s\\%s_experiment%d_%s.mat", op_dir, datatype, experiment_no, 'gaze_visualangle');
            % elseif strcmp(modality, 'respiration')
            %     filename_new = sprintf("%s\\%s_experiment%d_%s.mat", op_dir, datatype, experiment_no, 'breathrate');
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
function process_rate_matrix(dataStruct, modality, experiment_no, datatype)
    function cols = get_columns_to_keep(modality, totalColumns)
        switch modality
            case 'eye'
                cols = [8, 9, 10]; % saccaderate, blinkrate, fixationrate
                sprintf('rates computation')
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
    
    if experiment_no == 5
        rate_data = cellfun(@(x) x(:, get_columns_to_keep(modality, size(x, 2)), setdiff(1:size(x, 3), 9)), dataStruct, 'UniformOutput', false);
    else
        rate_data = cellfun(@(x) x(:, get_columns_to_keep(modality, size(x, 2)), :), dataStruct, 'UniformOutput', false);
    end

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
        rate_type = rate_types{i}

        if experiment_no == 5
            data.(rate_type) = cellfun(@(x) ...
            x(:, get_ratecolumns_to_keep(rate_type, size(x, 2)), setdiff(1:size(x, 3), 9)), ...
            rate_data, 'UniformOutput', false);
        else
            data.(rate_type) = cellfun(@(x) ...
            x(:, get_ratecolumns_to_keep(rate_type, size(x, 2)), :), ...
            rate_data, 'UniformOutput', false);
        end
    
        filename_new = sprintf('%s\\%s_experiment%d_%s.mat', op_dir, datatype, experiment_no, rate_type);
        save(filename_new, 'data', '-v7.3');
    
        fileInfo = dir(filename_new);
        fprintf('%s File size: %.2f GB\n', filename_new, fileInfo.bytes / (1024^3));
        clear data
    end
end

function data = process_matrix(dataStruct, modality, experiment_no, datatype)

    function cols = get_columns_to_keep(datatype, modality, totalColumns)
        switch modality
            case 'eye'
                cols = [1:2, 5:6]; % gaze (2), vdxy (2)
            case 'pupil'
                cols = 1; % pupil diameter
            case 'head'
                cols = 1:3; % x, y, z
            case 'ecg'
                if strcmp(datatype, 'raw')
                    cols = 4; % raw ECG
                elseif strcmp(datatype, 'processed')
                    cols = 3; % filt ECG 
                end
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

    if experiment_no == 5
         if strcmp(modality, 'eye')
            data.('gaze_visualangle') = cellfun(@(x) ...
                x(:, get_columns_to_keep(datatype, modality, size(x, 2)), :), ...
                dataStruct, 'UniformOutput', false);
    
        else
            data.(modality) = cellfun(@(x) ...
                x(:, get_columns_to_keep(datatype, modality, size(x, 2)), :), ...
                dataStruct, 'UniformOutput', false);
        end
    else
        if strcmp(modality, 'eye')
            data.('gaze_visualangle') = cellfun(@(x) ...
                x(:, get_columns_to_keep(datatype, modality, size(x, 2)), setdiff(1:size(x, 3), 9)), ...
                dataStruct, 'UniformOutput', false);
        else
            data.(modality) = cellfun(@(x) ...
                x(:, get_columns_to_keep(datatype, modality, size(x, 2)), setdiff(1:size(x, 3), 9)), ...
                dataStruct, 'UniformOutput', false);
        end
    end
end