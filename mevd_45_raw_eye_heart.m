% experiment_no = 5;
% input_dirs = {'eog'};
exp_nos = [4, 5];
outputFolderName = 'bbbd';

metadata = load('C:\Users\Neuro\research\mevd\mat_mevd\intervention_mat_files\int_metadata.mat');
metadata = metadata.metadata_full;
doIntervention = load('C:\Users\Neuro\research\mevd\mat_mevd\intervention_mat_files\doIntervention_indexing.mat');
doIntervention = doIntervention.doIntervention;

for exp_no = 1:1:length(exp_nos)
    experiment_no = exp_nos(exp_no)

    input_dirs = {'ecg', 'eog', 'respiration', 'eye', 'pupil', 'head'};

    if experiment_no == 4
        intervention = 0
    elseif experiment_no == 5
        intervention = 1
    end
    
    bids_raw = true
    sampling_frequency = 128;
    
    base_exp_no = 4;
    base_dir = sprintf('C:\\Users\\Neuro\\Dropbox\\dataset_multimodal_video\\data\\experiment_%d\\raw', base_exp_no);
    
    listfiles = dir(fullfile(base_dir, '*mat'));
    listfiles = {listfiles.name};
    
    output_dir = fullfile('C:\Users\Neuro\research\bbbd_output\', outputFolderName, sprintf('experiment%d',experiment_no));
    make_dir(output_dir);

    srcdir = fullfile('C:\Users\Neuro\research\mevd\MEVD_Final_v2\', sprintf('experiment%d',experiment_no));
    move_files_and_phenotype(srcdir, output_dir);

    fprintf('Loading metadata')
    
    
    if experiment_no == 4
        metadata_exp = metadata(~doIntervention);
    elseif experiment_no == 5
        metadata_exp = metadata(doIntervention);
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
        if strcmp(modality, 'eeg')
           modality_data = load('C:\Users\Neuro\research\mevd\eeg_intervention\raw\data_eeg__arej_0_bcrej_0_eogreg_0_bc_ass_sync_audio_frames_RPCA_0_fs=128.mat'); 
        else
            modality_data = load(fullfile(base_dir, filename{1}));
        end
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
    
                if session_idx == 1          
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
                            fprintf('\nSkipping empty or all-zero data file for %s, %s, %s, %s', experiment_no, bids_sub, bids_ses, bids_task);
                            continue;
                        end
       
                        bids_dir = fullfile(output_dir, bids_sub, bids_ses, processed_subdir);
                        make_dir(bids_dir)
                        if strcmp(processed_subdir, 'beh')
                            % write_physio_bids(data, bids_dir, bids_sub, bids_ses, bids_task, modality)
                            % write_physio_json(stim_id, view_id, bids_dir, bids_sub, bids_ses, bids_task, modality, experiment_no)
                        elseif strcmp(processed_subdir, 'eyetrack')
                            % write_eyetracking_bids(data, bids_dir, bids_sub, bids_ses, bids_task, modality, false)
                            write_eyetracking_json(stim_id, view_id, bids_dir, bids_sub, bids_ses, bids_task, modality, experiment_no);
                        end
    
                    end
                end
            end
        end
    end
end

%% Eyetracking

function write_eyetracking_bids(data, bids_dir, bids_sub, bids_ses, bids_task, modality, processed_sig)
    if strcmp(modality, 'eye')
        modality = 'gaze_visualangle';
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


function write_eyetracking_json(stim_id, view_id, bids_dir, bids_sub, bids_ses, bids_task, modality, experiment_no)
    sidecar = generate_eyetrack_json_metadata(modality, stim_id,  view_id, experiment_no);

    if strcmp(modality, 'eye')
        modality = 'gaze_visualangle';
    end
    json_filename = sprintf('%s_%s_%s_%s_eyetrack.json', bids_sub, bids_ses, bids_task, modality);

    if ~isempty(sidecar)
        json_filename = fullfile(bids_dir, json_filename);
        fid = fopen(json_filename, 'w');
        if fid == -1
            error('Cannot create JSON file: %s', json_filename);
        end
        fprintf(fid, '%s', jsonencode(sidecar, 'PrettyPrint', true));
        fclose(fid);
        fprintf('Created JSON file: %s\n', json_filename);
    end
end



function sidecar = generate_eyetrack_json_metadata(dir_name, task_id, view_id, experiment_no)
    % Example functions to get columns, units, and descriptions
    if strcmp(dir_name, 'eye')
        manufacturer = 'SR Research';
        manufacturersModelName = 'EyeLink 1000 Plus';
        columns = {"x", "y", "vdx", "vdy"};
        units = {'screen pixels','screen pixels','degree','degree'};
        description = {
            'gaze positon in the horizontal direction (x-axis)', ...
            'gaze positon in the vertical direction (y-axis)', ...
            'visual angle in the horizontal direction (x-axis)', ...
            'visual angle in the vertical direction (y-axis)', ...
        };
    elseif strcmp(dir_name, 'pupil')
        manufacturer = 'SR Research';
        manufacturersModelName = 'EyeLink 1000 Plus';
        columns = {"pupilSize"};
        units = {'camera sensor pixels'};
        description = {
            'left pupil size in area' 
        };
    elseif strcmp(dir_name, 'head')
        manufacturer = 'SR Research';
        manufacturersModelName = 'EyeLink 1000 Plus';
        columns = {"x", "y", "z"};
        units = {'pixels', 'pixels', 'millimeters'};
        description = {
            'head positon in horizontal direction (x-axis)',...
            'head positon in vertical direction (y-axis)',...
            'head positon in z-direction (distance from the camera sensor)'
        };
    end
    
    sidecar = experiment_sidecar(experiment_no,  task_id, view_id);
    sidecar.SamplingFrequency = 128;
    sidecar.StartTime = 0; % Change this as needed
    sidecar.Columns = columns;
    sidecar.Manufacturer = manufacturer;
    sidecar.ManufacturersModelName = manufacturersModelName;
    sidecar.SoftwareVersions = 'EyeLink 1000 v4.594';
    sidecar.DeviceSerialNumber = 'CL1-84E15';

    % Add each column's description and units directly to the sidecar
    for i = 1:length(columns)
        col = columns{i};
        % Sanitize field names
        col = matlab.lang.makeValidName(col);
        sidecar.(col).Description = description{i};
        sidecar.(col).Units = units{i};
        % sidecar.(sprintf('%s_Description', col)) = description{i};
        % sidecar.(sprintf('%s_Units', col)) = units{1};
    end
end



%% PHYSIOLOGICAL SIGNALS 
function write_physio_bids(data, bids_dir, bids_sub, bids_ses, bids_task, modality)
    tsv_filename = sprintf('%s_%s_%s_recording-%s_physio.tsv', bids_sub, bids_ses, bids_task, modality);
    tsv_filepath = fullfile(bids_dir, tsv_filename)
    writematrix(data, tsv_filepath, 'FileType', 'text', 'Delimiter', '\t');
    gzip(tsv_filepath);
    delete(tsv_filepath);
end

function write_physio_json(stim_id, view_id, bids_dir, bids_sub, bids_ses, bids_task, modality, experiment_no)
    json_filename = sprintf('%s_%s_%s_recording-%s_physio.json', bids_sub, bids_ses, bids_task, modality);
    sidecar = generate_physio_json_metadata(modality, stim_id,  view_id, experiment_no);
    if ~isempty(sidecar)
        json_filename = fullfile(bids_dir, json_filename);
        fid = fopen(json_filename, 'w');
        if fid == -1
            error('Cannot create JSON file: %s', json_filename);
        end
        jsonencode(sidecar, 'PrettyPrint', true)
        fprintf(fid, '%s', jsonencode(sidecar, 'PrettyPrint', true));
        fclose(fid);
        fprintf('Created JSON file: %s\n', json_filename);
    end
end

function sidecar = generate_physio_json_metadata(modality, task_id, view_id, experiment_no)
    % Example functions to get columns, units, and descriptions
    if strcmp(modality, 'ecg')
        manufacturer = 'BioSemi';
        manufacturersModelName = 'Active Two';
        columns = {'rawECG'};
        units = {'mV'};
        description = {'raw ecg value'};    

    elseif strcmp(modality, 'respiration')
        manufacturer = 'BioSemi';
        manufacturersModelName = 'Active Two';
        columns = {"rawRespiration"};
        units = {'mV'};
        description = {
            'raw respiration signal - tension on a belt worn around the chest of the subject'
        };

    elseif strcmp(modality, 'eog')
        manufacturer = 'Biosemi';
        manufacturersModelName = 'ActiveTwo';
        columns = {"ch1", "ch2", "ch3", "ch4", "ch5", "ch6"};
        units = {'uV'};
        description = {
            'electrode measuring electrical activity around eyes',... 
            'electrode measuring electrical activity around eyes',... 
            'electrode measuring electrical activity around eyes',... 
            'electrode measuring electrical activity around eyes',... 
            'electrode measuring electrical activity around eyes',... 
            'electrode measuring electrical activity around eyes'
        };
    end
    
    sidecar = experiment_sidecar(experiment_no,  task_id, view_id);
    sidecar.SamplingFrequency = 128;
    sidecar.StartTime = 0; % Change this as needed
    sidecar.Columns = columns;
    sidecar.Manufacturer = manufacturer;
    sidecar.ManufacturersModelName = manufacturersModelName;
    sidecar.SoftwareVersions = 'ActiView v8.0';
    sidecar.DeviceSerialNumber = 'ADC6-04-90';

    % Add each column's description and units directly to the sidecar
    for i = 1:length(columns)
        col = columns{i};
        % Sanitize field names
        col = matlab.lang.makeValidName(col);
        sidecar.(col).Description = description{i};
        sidecar.(col).Units = units{1};
    end
end

function sidecar = experiment_sidecar(experiment_no, task_id, view_id)

    stimulus_id = {'Stim 01', 'Stim 02', 'Stim 03', 'Stim 04', 'Stim 05', 'Stim 06'};
    experiment_1 = {'Why are Stars Star-Shaped', 'How Modern Light Bulbs Work', 'The Immune System Explained – Bacteria', 'Who Invented the Internet - And Why', 'Why Do We Have More Boys Than Girls', ''};
    experiment_2 = {'Why are Stars Star-Shaped', 'How Modern Light Bulbs Work', 'The Immune System Explained – Bacteria', 'Who Invented the Internet - And Why', 'Why Do We Have More Boys Than Girls', ''};
    experiment_3 = {'What If We Killed All the Mosquitoes', 'Are We All Related', 'Work and the work-energy principle', 'Dielectrics in capacitors Circuits', 'How Do People Measure Planets & Suns', 'Three Factors That May Alter the Action of an Enzyme Chemistry Biology Concepts'};
    experiment_4 = {'Why are Stars Star-Shaped', 'The Immune System Explained – Bacteria', 'Are We All Related', 'How Modern Light Bulbs Work', 'What If We Killed All the Mosquitoes', 'Three Factors That May Alter the Action of an Enzyme Chemistry Biology Concepts'};
    experiment_5 = {'Why are Stars Star-Shaped', 'The Immune System Explained – Bacteria', 'Are We All Related', '', '', ''};
    
    % Create the table
    data_table = table(stimulus_id', experiment_1', experiment_2', experiment_3', experiment_4', experiment_5', ...
        'VariableNames', {'Stimulus_ID', 'Experiment_1', 'Experiment_2', 'Experiment_3', 'Experiment_4', 'Experiment_5'});

    rowIdx = find(strcmp(data_table.Stimulus_ID, sprintf('Stim %02d', task_id)));  % Find row for stimulus ID
    if isempty(rowIdx)
        error('Stimulus ID not found in the provided table.');
    end
    experimentField = strcat('Experiment_', num2str(experiment_no));
    if ~ismember(experimentField, data_table.Properties.VariableNames)
        error('Invalid experiment number.');
    end
    
    % Get stimulus name
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

%% MISC / GENERAL

function data = extract_rawdata(subdata, modality)
    if strcmp(modality, 'eye')
        data = [subdata(:, 1:2), subdata(:, 5:6)]; % gaze(2), vdxy(2)
    
    elseif strcmp(modality, 'pupil')
        data = subdata(:,1);
    
    elseif strcmp(modality, 'head')
        data = subdata(:,1:3); % x, y, z
    
    elseif strcmp(modality, 'ecg')
        data = [subdata(:, 4)]; % raw, filt, HR
    
    elseif strcmp(modality, 'eog')
        data = subdata(:,1:6);

    elseif strcmp(modality, 'respiration')
        data = subdata(:,1);
    
    elseif strcmp(modality, 'eeg')
        data  = subdata(:,1:64);
    end
end

function make_dir(bids_dir)
    if ~exist(bids_dir, 'dir')
        mkdir(bids_dir);  % Create BIDS directory if it doesn't exist
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


function move_files_and_phenotype(srcDir, destDir)
    allItems = dir(srcDir);
    allItems = allItems(~ismember({allItems.name}, {'.', '..'}));
    itemsToMove = allItems(~startsWith({allItems.name}, {'sub', 'derivatives'}));

    for i = 1:length(itemsToMove)
        itemName = itemsToMove(i).name;
        srcPath = fullfile(srcDir, itemName);
        destPath = fullfile(destDir, itemName);
        
        copyfile(srcPath, destPath);
        fprintf("Made copy of %s", destPath);
    end
end