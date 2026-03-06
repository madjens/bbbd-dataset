%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Only for Experiments 4, 5
% Compute Discrete processed signals (rpeaks, breaths, saccades, blinks, fixations)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% process_input_dirs = {'eeg'};
outputFolderName = 'bbbd';

doDerivatives = true
eye_discrete_list = ["blinks", "saccades", "fixations"];
ecg_discrete_list = 'rpeak_timestamps';
resp_discrete_list = 'breath_peak_timestamps';
sampling_frequency = 128;
exp_nos = [4, 5];
metadata_full = load('C:\Users\Neuro\research\mevd\mat_mevd\intervention_mat_files\int_metadata.mat');
metadata_full = metadata_full.metadata_full;
doIntervention = load('C:\Users\Neuro\research\mevd\mat_mevd\intervention_mat_files\doIntervention_indexing.mat');
doIntervention = doIntervention.doIntervention;

for exp_no = 1:1:length(exp_nos)
    experiment_no = exp_nos(exp_no)

    input_dirs = {'ecg', 'respiration', 'eye'};

    if experiment_no == 4
        intervention = 0
    elseif experiment_no == 5
        intervention = 1
    end
    
    sampling_frequency = 128;
    
    base_exp_no = 4;
    demodata_path = sprintf('C:\\Users\\Neuro\\Dropbox\\dataset_multimodal_video\\data\\experiment_%d\\Experiment_%d_demographics.mat', 4, 6);
    base_dir = sprintf('C:\\Users\\Neuro\\Dropbox\\dataset_multimodal_video\\data\\experiment_%d\\processed', base_exp_no);
    par_id_dir = sprintf('C:\\Users\\Neuro\\Dropbox\\dataset_multimodal_video\\data\\experiment_%d\\metadata', base_exp_no);

    
    listfiles = dir(fullfile(base_dir, '*mat'));
    listfiles = {listfiles.name};
    
    % output_dir = fullfile('C:\Users\Neuro\Dropbox\dataset_multimodal_video\bbbd_output', outputFolderName, sprintf('experiment%d',experiment_no));
    output_dir = fullfile('C:\Users\Neuro\research\bbbd_output', outputFolderName, sprintf('experiment%d',experiment_no));
    make_dir(output_dir);

    fprintf('Loading metadata')
    
    
    if experiment_no == 4
        metadata_exp = metadata_full(~doIntervention);
    elseif experiment_no == 5
        metadata_exp = metadata_full(doIntervention);
    end
    
    par_ids = cat(1, metadata_exp.participant_no);

    demodata = load(sprintf('C:\\Users\\Neuro\\research\\mevd\\mat_mevd\\intervention_mat_files\\experiment%d_demographic.mat', experiment_no));
    ages_char = {demodata.demographicData.Age};
    ages = cellfun(@str2double, ages_char);
    
   
    for i = 1:length(input_dirs)
        modality = input_dirs{i}
    
        if strcmp(modality, 'ecg') || strcmp(modality, 'eog') || strcmp(modality, 'respiration')
            processed_subdir = 'beh';
        elseif strcmp(modality, 'eye') || strcmp(modality, 'pupil') || strcmp(modality, 'head') 
            processed_subdir = 'eyetrack';
        end

        filename = listfiles(contains(listfiles, strcat('data_', modality)));
 
        modality_data = load(fullfile(base_dir, filename{1}));
        
        field_names = fieldnames(modality_data); 
        total_data = modality_data.(field_names{1});
    
        if intervention == 1
            intervention_data = total_data{1,1}; % YES INTERVENTION
        else
            intervention_data = total_data{2,1}; % NO INTERVENTION
        end
    
        clear modality_data 
    
        fprintf('Total data loaded....');
        n_sessions = size(intervention_data, 1);
        n_stimuli = size(intervention_data, 2);
    
        for session_idx = 1:n_sessions
            for stimulus_idx = 1:n_stimuli
    
                if intervention == 0 && session_idx == 1          
                    current_data  = intervention_data{1,stimulus_idx};
                    [len, cols, n_subs] = size(current_data);
                else 
                    current_data = intervention_data{2,stimulus_idx};
                    [len, cols, n_subs] = size(current_data);
                end 
    
                for subj_idx = 1:n_subs
                    if ages(subj_idx) < 18
                        fprintf('\nSkipping subject %d for being under age', subj_idx);
                        continue
                    end
    
                    if intervention == 0 && session_idx == 1          
                        stim_id = stimulus_idx + 3; % FOR 4, 5, 6 STIMULUS NUMBERS IN BLOCK 1 NO INTERVENTION DATA
                    else
                        stim_id = stimulus_idx;
                    end
    
                    view_id = session_idx;
                    par_id_num = par_ids(subj_idx)
    
                    bids_ses = sprintf('ses-%02d', view_id);
                    bids_task = sprintf('task-stim%02d', stim_id);
                    bids_sub = sprintf('sub-%02d', subj_idx);
    
                    fprintf('\nSession %d, Subject %d, Stimulus %d', session_idx, subj_idx, stimulus_idx);
                    subject_data = current_data(:, :, subj_idx);
    
                    if doDerivatives == true
                        fprintf('\nProcessing BIDS Derivatives...');
                        derivatives_dir = fullfile(output_dir, 'derivatives', bids_sub, bids_ses, processed_subdir);
                        make_dir(derivatives_dir)
                        % metadata = load(fullfile(par_id_dir, sprintf('metadata_participant_%02d.mat', par_id_num)));
                        

                        if strcmp(modality, 'respiration')                        
                            extract_discrete_respderivatives(resp_discrete_list, metadata_exp(subj_idx), output_dir, derivatives_dir, bids_sub, bids_ses, bids_task, stimulus_idx, session_idx);
                        elseif strcmp(modality, 'ecg')                        
                            extract_discrete_ecgderivatives(ecg_discrete_list, metadata_exp(subj_idx), derivatives_dir, bids_sub, bids_ses, bids_task, stimulus_idx, session_idx);
                        elseif strcmp(modality, 'eye')                        
                            extract_discrete_eyederivatives(eye_discrete_list, metadata_exp(subj_idx), derivatives_dir, bids_sub, bids_ses, bids_task, stimulus_idx, session_idx);
                            %%% INTERPOLATION ARRAY %%%
                            write_eyetracking_interpolation_bids(metadata_exp(subj_idx), derivatives_dir, bids_sub, bids_ses, bids_task, modality, stimulus_idx, session_idx)
                        end
                    end
                    % break                
                end
                % break            
            end
            % break        
        end
    % break    
    end
end
%% DERIVED DATA
function extract_discrete_respderivatives(fieldName, metadata, output_dir, derivatives_dir, bids_sub, bids_ses, bids_task, stim_idx, ses_idx)

    derived_eye.(fieldName).timestamp = metadata.segments(stim_idx, ses_idx).respiration.timestamps_rel_stim(:,1);

    raw_filename = sprintf('%s_%s_%s_recording-%s_physio.tsv.gz', bids_sub, bids_ses, bids_task, 'respiration');
    bids_dir = fullfile(output_dir, bids_sub, bids_ses, 'beh');

    if isfile(fullfile(bids_dir, raw_filename))
        fileName = sprintf('%s_%s_%s_desc-%s.tsv', bids_sub, bids_ses, bids_task, fieldName);
        filePath = fullfile(derivatives_dir, fileName);
        table_eye = struct2table(derived_eye.(fieldName))
        writetable(table_eye, filePath, 'FileType', 'text', 'Delimiter', '\t');
        gzip(filePath);
        disp(['Saved ', filePath])
        delete(filePath);
    else
        fprintf('No raw file %s exists', fullfile(bids_dir, raw_filename))
    end
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
    raw_filename = sprintf('%s_%s_%s_desc-%s.tsv.gz', bids_sub, bids_ses, bids_task, 'filteredECG');
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

    