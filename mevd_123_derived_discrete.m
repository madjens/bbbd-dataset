%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Only for Experiments 1, 2, 3
% Compute Discrete processed signals (rpeaks, saccades, blinks, fixations)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

eye_discrete_list = ["blinks", "saccades", "fixations"];
ecg_discrete_list = 'rpeak_timestamps';

processed_signals = true
doDerivatives = true
sampling_frequency = 128;
outputFolderName = 'bbbd';

exp_nos = [1,2,3];
for i=1:length(exp_nos)
    experiment_no = exp_nos(i)
    if experiment_no == 1
        input_dirs = {'eye'}; 
        process_input_dirs = {'eye'}; 
    else
        input_dirs = {'ecg', 'eye'};
        process_input_dirs = {'ecg', 'eye'};
    end
    % Create file paths using sprintf to incorporate the experiment number      
    demodata_path = sprintf('C:\\Users\\Neuro\\Dropbox\\dataset_multimodal_video\\data\\experiment_%d\\Experiment_%d_demographics.mat', experiment_no, experiment_no);
    base_dir = sprintf('C:\\Users\\Neuro\\Dropbox\\dataset_multimodal_video\\data\\experiment_%d\\raw', experiment_no);
    base_processed_dir = sprintf('C:\\Users\\Neuro\\Dropbox\\dataset_multimodal_video\\data\\experiment_%d\\processed', experiment_no);
    par_id_dir = sprintf('C:\\Users\\Neuro\\Dropbox\\dataset_multimodal_video\\data\\experiment_%d\\metadata', experiment_no);
    
    listfiles = dir(fullfile(base_dir, '*mat'));
    listfiles = {listfiles.name};
    
    try
        % Try to list files from the processed directory
        listfiles_processed = dir(fullfile(base_processed_dir, '*mat'));
        listfiles_processed = {listfiles_processed.name};
    catch
        % If there's an error, fall back to the base directory
        listfiles_unprocessed = dir(fullfile(base_dir, '*mat'));
        listfiles_processed = {listfiles_unprocessed.name};
    end

    output_dir = fullfile('C:\Users\Neuro\research\bbbd_output\', outputFolderName, sprintf('experiment%d',experiment_no));
    make_dir(output_dir);
    
    par_meta_files = dir(fullfile(par_id_dir, '*.mat'));
    par_ids = get_participant_ids(par_meta_files);
    
    
    for j = 1:length(input_dirs)
        modality = input_dirs{j}
        
        if strcmp(modality, 'ecg') 
            processed_subdir = 'beh';
        elseif strcmp(modality, 'eye') || strcmp(modality, 'interpolated_eye') || strcmp(modality, 'interpolated_pupil')
            processed_subdir = 'eyetrack';
        end
    
        if any(strcmp(process_input_dirs, modality))
            
            filename_processed = listfiles_processed(contains(listfiles_processed, strcat('data_', modality)));
            fullfile(base_processed_dir, filename_processed{1})
            modality_data_processed = load(fullfile(base_processed_dir, filename_processed{1}), strcat('data_', modality));
            field_names = fieldnames(modality_data_processed); 
            total_data_processed = modality_data_processed.(field_names{1});
            fprintf('Total processed data loaded....');
            n_sessions = size(total_data_processed, 1);
            n_stimuli = size(total_data_processed, 2)
        end
    
        for session_idx = 1:n_sessions
            for stimulus_idx = 1:n_stimuli
                current_data = total_data_processed{session_idx, stimulus_idx};  
                [len, cols, n_subs] = size(current_data);
    
                for subj_idx = 1:n_subs
    
                    stim_id = stimulus_idx;
    
                    view_id = session_idx;
                    par_id_num = par_ids(subj_idx);
    
                    bids_sub = sprintf('sub-%02d', par_id_num);
                    bids_ses = sprintf('ses-%02d', view_id);
                    bids_task = sprintf('task-stim%02d', stim_id);
    
                    fprintf('\nSession %d, Subject %d, Stimulus %d', session_idx, par_id_num, stimulus_idx);
    
                    if doDerivatives == true
                        fprintf('\nProcessing BIDS Derivatives...');
                        derivatives_dir = fullfile(output_dir, 'derivatives', bids_sub, bids_ses, processed_subdir);
                        make_dir(derivatives_dir);
                        metadata = load(fullfile(par_id_dir, sprintf('metadata_participant_%02d.mat', par_id_num)));

                        if strcmp(modality, 'eye') 
                            extract_discrete_eyederivatives(eye_discrete_list, metadata.metadata, derivatives_dir, bids_sub, bids_ses, bids_task, stimulus_idx, session_idx);
                            write_eyetracking_interpolation_bids(metadata.metadata, derivatives_dir, bids_sub, bids_ses, bids_task, modality, stimulus_idx, session_idx);
                        elseif strcmp(modality, 'ecg')
                            extract_discrete_ecgderivatives(ecg_discrete_list, metadata.metadata, derivatives_dir, bids_sub, bids_ses, bids_task, stimulus_idx, session_idx);
                        end
                    end
                end            
            end        
        end    
    end
end

%% DERIVED DATA
function extract_discrete_respderivatives(fieldName, metadata, derivatives_dir, bids_sub, bids_ses, bids_task, stim_idx, ses_idx)

    derived_eye.(fieldName).timestamp = metadata.segments(stim_idx, ses_idx).respiration.timestamps_rel_stim(:,1);

    fileName = sprintf('%s_%s_%s_desc-%s.tsv', bids_sub, bids_ses, bids_task, fieldName);
    filePath = fullfile(derivatives_dir, fileName);
    table_eye = struct2table(derived_eye.(fieldName))
    writetable(table_eye, filePath, 'FileType', 'text', 'Delimiter', '\t');
    gzip(filePath);
    disp(['Saved ', filePath])
    delete(filePath);

end

function make_dir(bids_dir)
    if ~exist(bids_dir, 'dir')
        mkdir(bids_dir);  % Create BIDS directory if it doesn't exist
    end
end

function extract_discrete_eyederivatives(discrete_list, metadata, derivatives_dir, bids_sub, bids_ses, bids_task, stim_idx, ses_idx)
    for i = 1:numel(discrete_list)
        fieldName = discrete_list(i);
        if isempty(metadata.segments(stim_idx, ses_idx).(fieldName))
            continue
        end

        raw_filename = sprintf('%s_%s_%s_desc-%s.tsv.gz', bids_sub, bids_ses, bids_task, 'gaze_eyetrack');
        if isfile(fullfile(derivatives_dir, raw_filename))
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
            filePath = fullfile(derivatives_dir, fileName)
            table_eye = struct2table(derived_eye.(fieldName));
            size(table_eye)
            writetable(table_eye, filePath, 'FileType', 'text', 'Delimiter', '\t');
            gzip(filePath);
            delete(filePath);
        end
    end
end

function extract_discrete_ecgderivatives(fieldName, metadata, derivatives_dir, bids_sub, bids_ses, bids_task, stim_idx, ses_idx)
    raw_filename = sprintf('%s_%s_%s_desc-%s.tsv.gz', bids_sub, bids_ses, bids_task, 'heartrate');
    
    if isfile(fullfile(derivatives_dir, raw_filename))
        
        if ~isempty(metadata.segments(stim_idx, ses_idx).hr.no_heart_beats) && metadata.segments(stim_idx, ses_idx).hr.no_heart_beats ~= 0
            disp([num2str(metadata.segments(stim_idx, ses_idx).hr.no_heart_beats) ,'heartbeats - Saving r-peaks...'])
            temp_struct.(fieldName).timestamp = metadata.segments(stim_idx, ses_idx).hr.timestamps_rel_stim(:,1);

            fileName = sprintf('%s_%s_%s_desc-%s.tsv', bids_sub, bids_ses, bids_task, fieldName);
            filePath = fullfile(derivatives_dir, fileName);
            table_eye = struct2table(temp_struct.(fieldName));
            % size(table_eye)
            writetable(table_eye, filePath, 'FileType', 'text', 'Delimiter', '\t');
            gzip(filePath);
            delete(filePath);
        
        else
            disp('No Heartbeats. Skipping File...')
            fileName = sprintf('%s_%s_%s_desc-%s.tsv.gz', bids_sub, bids_ses, bids_task, fieldName);
            filePath = fullfile(derivatives_dir, fileName)
            if isfile(filePath)
                fprintf('Deleting %s', filePath)
                delete(filePath)
            end
        end
    else
        fprintf('No raw file %s exists', fullfile(derivatives_dir, raw_filename))
    end
end

function par_ids = get_participant_ids(par_meta_files)
    par_ids = zeros(1, length(par_meta_files));
    for i = 1:length(par_meta_files)
        % Extract the numeric part from each file name
        name_parts = regexp(par_meta_files(i).name, 'metadata_participant_(\d+)', 'tokens');
        if ~isempty(name_parts)
            par_ids(i) = str2double(name_parts{1}{1});
        end
    end
end


function write_eyetracking_interpolation_bids(metadata, bids_dir, bids_sub, bids_ses, bids_task, modality, stim_idx, ses_idx)
    interp_modalities = {'interpolated_eye', 'interpolated_pupil'};
    for i = 1:2 
        interp_modality = interp_modalities{i}
        if strcmp(interp_modality, 'interpolated_eye')
            modality = 'gaze';
            fieldName = 'eye';
            filename = 'gaze_interpolation_timestamps';

        elseif strcmp(interp_modality, 'interpolated_pupil')
            modality = 'pupil';
            fieldName = 'pupil';
            filename = 'pupil_interpolation_timestamps';
        end
        raw_filename = sprintf('%s_%s_%s_desc-%s_eyetrack.tsv.gz', bids_sub, bids_ses, bids_task, modality);
    
        if isfile(fullfile(bids_dir, raw_filename))
            temp_struct.(fieldName).start_time = metadata.segments(stim_idx, ses_idx).(fieldName).interpolated.timestamps_rel_stim(:,1);
            temp_struct.(fieldName).end_time = metadata.segments(stim_idx, ses_idx).(fieldName).interpolated.timestamps_rel_stim(:,2);
    
            interp_filename = sprintf('%s_%s_%s_desc-%s.tsv', bids_sub, bids_ses, bids_task, filename);
            interp_filepath = fullfile(bids_dir, interp_filename);
    
            % disp(['tsv.gz ', raw_filename, ' exists for ' modality ', creating interpolated file ' interp_filepath]);
    
            table_eye = struct2table(temp_struct.(fieldName));
            fprintf('No of timestamps: %d, Len of array: %d', height(table_eye), length(metadata.segments(stim_idx, ses_idx).(fieldName).interpolated.timestamps_rel_stim(:,1)));
            writetable(table_eye, interp_filepath, 'FileType', 'text', 'Delimiter', '\t');
            gzip(interp_filepath);
            delete(interp_filepath);
        else
            fprintf('No raw file %s exists', fullfile(bids_dir, raw_filename))
        end
    end
end

% % Define the root directory where your data is stored
% rootDir = 'C:\Users\Nikhil\research\mevd\MEVD_BIDS\experiment5\derivatives';  % Change this to the path where your data is
% 
% % Get a list of all subdirectories (sub-01, sub-02, etc.)
% subDirs = dir(fullfile(rootDir, 'sub-*'));
% subDirs = subDirs([subDirs.isdir]);  % Filter only directories
% 
% % Initialize an empty cell array to store unmatched files
% unmatchedFiles = {};
% 
% % Loop through each subject directory
% for i = 1:length(subDirs)
%     subDir = subDirs(i).name;
%     sesDirs = dir(fullfile(rootDir, subDir, 'ses-*'));  % Get session directories
%     sesDirs = sesDirs([sesDirs.isdir]);  % Filter only directories
% 
%     % Loop through each session directory
%     for j = 1:length(sesDirs)
%         sesDir = sesDirs(j).name;
%         behDir = fullfile(rootDir, subDir, sesDir, 'beh');  % Get the 'beh' folder
% 
%         if isfolder(behDir)
%             % Get all the _desc-rpeak_timestamps files
%             rpeakFiles = dir(fullfile(behDir, '*_desc-rpeak_timestamps.tsv.gz'));
% 
%             % Loop through each _desc-rpeak_timestamps file
%             for k = 1:length(rpeakFiles)
%                 % Extract the prefix (e.g., sub-01_ses-01_task-stim01)
%                 [~, fileName, ~] = fileparts(rpeakFiles(k).name);
%                 prefix = fileName(1:end-length('_desc-rpeak_timestamps.tsv'));
%                 prefix = strrep(prefix, '_des', '');
% 
%                 % Check if there's a corresponding _desc-filteredECG file
%                 ecgFile = fullfile(behDir, [prefix, '_desc-filteredECG.tsv.gz']);
% 
%                 % If no corresponding ECG file exists, add the rpeak file to unmatched list
%                 if ~isfile(ecgFile)
%                     unmatchedFiles{end+1, 1} = fullfile(behDir, rpeakFiles(k).name);
%                 end
%             end
%         end
%     end
% end
% 
% % Display unmatched files
% if ~isempty(unmatchedFiles)
%     disp('Unmatched _desc-rpeak_timestamps files (no corresponding _desc-filteredECG files):');
%     for i = 1:length(unmatchedFiles)
%         disp(unmatchedFiles{i});
%     end
% else
%     disp('All _desc-rpeak_timestamps files have corresponding _desc-filteredECG files.');
% end
