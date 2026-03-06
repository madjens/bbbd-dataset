experiment_nos = {1, 2,3};
% discrete_items = {'pupil', 'eye', 'blinks', 'saccades', 'fixations', 'hr'};
% discrete_items = {'hr'}
discrete_items = {'blinks', 'saccades', 'fixations'};
experiment_nos = {1};

for expno = 1:length(experiment_nos)
    experiment_no = experiment_nos{expno}
    
    directory = sprintf('D:\\Users\\Neuro\\City College Dropbox\\NIKHIL KUPPA\\dataset_multimodal_video\\data\\experiment_%d\\metadata', experiment_no);
    list = dir(directory);
    T_files = struct2table(list(3:end));
    load([T_files(1,:).folder{1} '\' T_files(1,:).name{1}], 'metadata')
    
    if experiment_no == 4
        Nstim = metadata.Nstim_post_intervention;
        Nview = metadata.Nblocks;
    else
        Nstim = metadata.Nstim;
        Nview = metadata.Nview;
    end
    
    Nparticipant = size(T_files,1);
    for item_no = 1:length(discrete_items)
        discrete_item = discrete_items{item_no}
        T_discretes = cell(Nparticipant,1);
        
        for iParticipant = 1:Nparticipant
            load([T_files(iParticipant,:).folder{1} '\' T_files(iParticipant,:).name{1}],'metadata')
            T_discrete = cell(Nstim,Nview);
            for iStim = 1:Nstim
                for iView = 1:Nview

                    if (strcmp(discrete_item, 'pupil') || strcmp(discrete_item, 'eye'))
                        if ~isempty(metadata.segments(iStim,iView).(discrete_item))  && isfield(metadata.segments(iStim, iView).(discrete_item), 'interpolated')
                            if ~isempty(metadata.segments(iStim,iView).(discrete_item).interpolated.timestamps_rel_stim) 
                                Ndiscrete = size(metadata.segments(iStim,iView).(discrete_item).interpolated.timestamps_rel_stim,1);
        
                                subject_no = repmat(sprintf("sub-%02d", iParticipant), Ndiscrete,1);
                                stim_no = repmat(metadata.segments(iStim,iView).stim_no,Ndiscrete,1);
                                session_no = repmat(iView,Ndiscrete,1);
                     
                                time_start = metadata.segments(iStim,iView).(discrete_item).interpolated.timestamps_rel_stim(:,1);    
                                time_end = metadata.segments(iStim,iView).(discrete_item).interpolated.timestamps_rel_stim(:,2);            

                                T_discrete{iStim,iView} = table(subject_no,session_no,stim_no,time_start,time_end);
                            else
                                continue
                            end
                        else
                            continue
                        end

                    elseif (strcmp(discrete_item, 'hr') || strcmp(discrete_item, 'respiration')) 
                        if ~isempty(metadata.segments(iStim,iView).(discrete_item).timestamps_rel_stim) 
                            Ndiscrete = size(metadata.segments(iStim,iView).(discrete_item).timestamps_rel_stim,1);
    
                            subject_no = repmat(sprintf("sub-%02d", iParticipant), Ndiscrete,1);
                            stim_no = repmat(metadata.segments(iStim,iView).stim_no,Ndiscrete,1);
                            session_no = repmat(iView,Ndiscrete,1);
                 
                            time_peak = metadata.segments(iStim,iView).(discrete_item).timestamps_rel_stim(:,1);            
                            T_discrete{iStim,iView} = table(subject_no,session_no,stim_no,time_peak);
                        else
                            continue
                        end
                    
                    elseif ~isempty(metadata.segments(iStim,iView).(discrete_item))  && isfield(metadata.segments(iStim, iView).(discrete_item), 'timestamps_rel_stim') 
                        Ndiscrete = size(metadata.segments(iStim,iView).(discrete_item).timestamps_rel_stim,1);

                        subject_no = repmat(sprintf("sub-%02d", iParticipant), Ndiscrete,1);
                        stim_no = repmat(metadata.segments(iStim,iView).stim_no,Ndiscrete,1);
                        session_no = repmat(iView,Ndiscrete,1);
             
                        time_start = metadata.segments(iStim,iView).(discrete_item).timestamps_rel_stim(:,1);
                        time_end = metadata.segments(iStim,iView).(discrete_item).timestamps_rel_stim(:,2);
            
                        T_discrete{iStim,iView} = table(subject_no,session_no,stim_no,time_start,time_end);
                    end

                end
            end
            T_discretes{iParticipant} = cat(1,T_discrete{:});
        end
        
        timestamps = cat(1,T_discretes{:});

        if strcmp(discrete_item, 'hr')
            discrete_item = 'rpeaks'
        elseif strcmp(discrete_item, 'pupil')
            discrete_item = 'interpolated_pupil'
        elseif strcmp(discrete_item, 'eye')
            discrete_item = 'interpolated_gaze'
        end

        % op_dir = sprintf("C:\\Users\\Neuro\\research\\bbbd\\BBBD_bids\\matrix_data_new\\%s\\experiment%d", 'processed', experiment_no)
        op_dir = sprintf("D:\\Users\\Neuro\\City College Dropbox\\NIKHIL KUPPA\\dataset_multimodal_video\\BBBD\\matrix_data\\%s\\experiment%d", 'processed', experiment_no)

        if ~exist(op_dir, 'dir')
            mkdir(op_dir);
        end

        filename_new = sprintf("%s\\%s_experiment%d_%s.mat", op_dir, 'processed', experiment_no, discrete_item);
        save(filename_new, "timestamps")
    end
end