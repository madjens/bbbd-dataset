function [data,metadata,idx_missing_data] = preprocessEyelinkData(data,timestamps,metadata,options)
% [data,metadata,data_nan] = preprocessEyelinkData(data,timestamps,metadata,options)
%
% data          (samples x modality) : eye link data matrix containing a column per measurement e.g. horizontal, vertical eye movements, pupil and head movements
% timestamps    (samples x 1)        : column vector with timestamps for each sample
%
% metadata.blinks.timestamps_edf (#blinks x 2): contains a two column
% vector with start and end sample numbers of each blink. This function takes that
% as input and potentially adds more rows if it finds more blinks. 
%
% options: this has grown conciderably, check calling function
% mainPupilClean to see an overview. 
%
% options.doVisualization = 1 % if you want to see something
%
% jmad/jenma 2022
% jmad/jenma 2025 (updated)

if ~isfield(options,'fs_eyeheadtracking')
    options.fs_eyeheadtracking = 1/(mean(diff(timestamps))/1000);
    fprintf('No sampking frequency specifief for data etting to %dHz\n',options.fs_eyeheadtracking)
end

fs = options.fs_eyeheadtracking;

% eye tracking extension of blinks (we usually see the onset and offset of blinks detected by the eyelink 1000 to result unreliable detection of
% gaze position and pupil size. We could maybe use saccade data to do this more reliably in the future
buffer_eye_ms  = options.buffer_eye_ms;                  % time on each side of a blink to nan out for eye tracking data (measured in ms)
buffer_eye_samples = round((buffer_eye_ms/1000)*fs);     % buffer in samples

% pupil size extension of blink interpolation period
buffer_pupil_ms  = options.buffer_pupil_ms;              % time on each side of a blink to nan out for pupil data (measured in ms)
buffer_pupil_samples = round((buffer_pupil_ms/1000)*fs); % buffer in samples

% for each EyeLink EDF files these indices might change. Please update according to your specific recording
if size(data,2)>3
    idx_eyes = 1:2;
    idx_pupil = 3;
    idx_resolution = 4:5;
    idx_head = 6:8;
end

% this is to keep track of missing data in each of the modalities measured by the eyelink 1000
idx_missing_data.all = false(size(timestamps));

for iMissing = 1:size(metadata.missing_data.sampleidx_edf,1)
    idx_missing_data.all(metadata.missing_data.sampleidx_edf(iMissing,1):metadata.missing_data.sampleidx_edf(iMissing,2)) = true;
end

idx_missing_data.eye = idx_missing_data.all;
idx_missing_data.pupil = idx_missing_data.all;

mask_eye = idx_missing_data.all;
mask_pupil = idx_missing_data.all;

%% find blinks and set them to NaN
if options.doBlinkRemoval
    fprintft('Removing blinks from eye tracker')
    for ii = 1:size(metadata.blinks.timestamps_edf,1)

        % Get start and end times of blink
        time_blink_start = metadata.blinks.timestamps_edf(ii,1);
        time_blink_end   = metadata.blinks.timestamps_edf(ii,2);

        % Get index for start and end of blink
        [~,idx_blink_start]   = min(abs(timestamps(:,1) - time_blink_start));
        [~,idx_blink_end]     = min(abs(timestamps(:,1) - time_blink_end));

        % blink length (keep metadata about blinks)
        metadata.blinks.duration_samples(ii,1) = length(idx_blink_start:idx_blink_end);
        metadata.blinks.duration_time(ii,1) = length(idx_blink_start:idx_blink_end)/fs;

        % extend with buffer_samples on each side of blink (eye movements)
        idx_blink_eye_start = max(1,idx_blink_start-buffer_eye_samples);
        idx_blink_eye_end = min(length(data),idx_blink_end+buffer_eye_samples);

        % extend with buffer_samples on each side of blink (pupil size)
        idx_blink_pupil_start = max(1,idx_blink_start-buffer_pupil_samples);
        idx_blink_pupil_end = min(length(data),idx_blink_end+buffer_pupil_samples);

        % fill eye movemetns with nans
        mask_eye(idx_blink_eye_start:idx_blink_eye_end,1) = true;

        % fill pupil size with nans
        mask_pupil(idx_blink_pupil_start:idx_blink_pupil_end,1) = true;

        if rem(ii,50)==0
            fprintf('.')
        end
    end
end
fprintf('done\n')

%% do closing operation on mask to remove small spurious outliers
if options.imclose_pupil>0
    SE = strel("rectangle",[round(options.imclose_pupil*fs) 1]);
    mask_pupil = imclose(mask_pupil,SE);
end

% what is missing now?
idx_missing_data.eye(:,end+1) = any(mask_eye,2);
idx_missing_data.pupil(:,end+1) = any(mask_pupil,2);

%% detect outliers in pupil signal (negative outliers are likely blinks, 
%% possitive outliers are likely imagine artefacts) and extend detected to the left and right
if isfield(options, 'doBlinkArtefactRemoval') && options.doBlinkArtefactRemoval

    Nsamples = size(data,1);

    % only operate on valid samples 
    idx_valid = ~isnan(data(:,idx_pupil)); 
    data_pupil_valid = data(idx_valid,idx_pupil);
    
    % find outliers
    k = 4; % really only extreem outliers
    d = data_pupil_valid - medfilt1(data_pupil_valid,round(fs*options.filter_length_mfd_pupil),'truncate'); % deviation from median
    mask_positive = d>k*iqr(d); 
    mask_negative = d<-k*iqr(d); 

    mask_blinks = false(Nsamples,1);
    mask_artifacts = false(Nsamples,1);

    clear data_pupil_valid
    
    % mark outlies as missing (in addition to what is already marked from the edf file)
    mask_blinks(idx_valid) = mask_negative;
    mask_artifacts(idx_valid) = mask_positive;

    % set even and odd index if either is set, so as to catch NaN from the upsampling
    if mod(find(mask_blinks,1),2)==0
        mask_blinks(1:2:end-1) = mask_blinks(1:2:end-1) | mask_blinks(2:2:end);
        mask_artifacts(1:2:end-1) = mask_artifacts(1:2:end-1) | mask_artifacts(2:2:end);
    else
        mask_blinks(2:2:end) = mask_blinks(1:2:end-1) | mask_blinks(2:2:end);
        mask_artifacts(2:2:end) = mask_artifacts(1:2:end-1) | mask_artifacts(2:2:end);
    end

    % finding start and stop of outlier data
    d_blinks = diff([0; mask_blinks(1:end-1); 0]); % add zero at begin/end in case that is also bad data
    metadata.blinks.timestamps_edf_additional = timestamps([find(d_blinks>0) find(d_blinks<0)]);

    d_artifacts = diff([0; mask_artifacts(1:end-1); 0]); % add zero at begin/end in case that is also bad data
    metadata.artifacts.timestamps_edf = timestamps([find(d_artifacts>0) find(d_artifacts<0)]);
    metadata.artifacts.duration_time = metadata.artifacts.timestamps_edf(:,2) - metadata.artifacts.timestamps_edf(:,1);

    timestamps_artifact_blinks = [metadata.blinks.timestamps_edf_additional; metadata.artifacts.timestamps_edf];

    %% remove the artifacts and blinks
    fprintft('Removing additional blinks/artifacts from eye tracker')
    for ii = 1:size(timestamps_artifact_blinks,1)
        % Get start and end times of blink
        time_blink_artifact_start = timestamps_artifact_blinks(ii,1);
        time_blink_artifact_end   = timestamps_artifact_blinks(ii,2);

        % Get index for start and end of blink
        [~,idx_blink_artifact_start]   = min(abs(timestamps(:,1) - time_blink_artifact_start));
        [~,idx_blink_artifact_end]     = min(abs(timestamps(:,1) - time_blink_artifact_end));

        % fill pupil size with nans
        mask_pupil(idx_blink_artifact_start:idx_blink_artifact_end,2) = true;

        if rem(ii,50)==0
            fprintf('.')
        end
    end
end

%% combine all masks
mask_eye = any(mask_eye,2);
mask_pupil = any(mask_pupil,2);

% what is missing now?
idx_missing_data.eye(:,end+1) = any(mask_eye,2);
idx_missing_data.pupil(:,end+1) = any(mask_pupil,2);

%% replace missing data with NaNs
data(mask_eye,idx_eyes) = NaN;
data(mask_pupil,idx_pupil) = NaN;

%% get timestamps of all the interpolated/missing data
d_interpolated_pupil = diff([0; mask_pupil(1:end-1); 0]); % add zero at begin/end in case that is also bad data
d_interpolated_eye = diff([0; mask_eye(1:end-1); 0]); % add zero at begin/end in case that is also bad data

metadata.interpolated_eye.timestamps_edf = timestamps([find(d_interpolated_eye>0) find(d_interpolated_eye<0)]);
metadata.interpolated_pupil.timestamps_edf = timestamps([find(d_interpolated_pupil>0) find(d_interpolated_pupil<0)]);

%% fill in nans with linearly interpolated data
if options.doBlinkInterpolation
    % take all the NaNs and use interpolation to fill in to values
    data(:,idx_eyes) = fillmissing(data(:,idx_eyes),options.interpolation_method,'EndValues','nearest');
end

if options.doBlinkInterpolation
    % take all the NaNs and use interpolation to fill in to values
    data(:,idx_pupil) = fillmissing(data(:,idx_pupil),options.interpolation_method,'EndValues','nearest');
end

% head
data(:,idx_head) = fillmissing(data(:,idx_head),options.interpolation_method,'EndValues','nearest');

if options.doVisualization
    datanames = {'eye_x','eye_y','pupil'};
    Ts = 1/options.fs_eyeheadtracking;
    Nsec = Ts*size(data,1);
    timeaxis = 0:Ts:Nsec-Ts;
    
    figure('Name','After blink correction','units','normalized','outerposition',[0 0 1 1])
    for iCord = 1:3
        subplot(3,1,iCord)
        plot(timeaxis,data(:,iCord),'k'), hold on
        if size(idx_missing_data.pupil,2)==3
            tmp = nan(size(data,1),1); tmp(idx_missing_data.pupil(:,3))=data(idx_missing_data.pupil(:,3),iCord); plot(timeaxis,tmp,'b'), hold on
        end
        tmp = nan(size(data,1),1); tmp(idx_missing_data.pupil(:,2))=data(idx_missing_data.pupil(:,2),iCord); plot(timeaxis,tmp,'r'), hold on
        tmp = nan(size(data,1),1); tmp(idx_missing_data.pupil(:,1))=data(idx_missing_data.pupil(:,1),iCord); plot(timeaxis,tmp,'g'), hold off

        xlim([min(timeaxis) max(timeaxis)])
        title(datanames{iCord})
        set(gca,'Position',get(gca,'Position') + [-0.11 -0.0 0.2 0.0])
    end
figure
plot(timeaxis,data(:,3),'k'), hold on

end

%% filter the eye tracking data to remove spurious blinks
no_taps_eye = round(fs*options.filter_length_eye);

if no_taps_eye>0
    data(:,idx_eyes) = medfilt1(data(:,idx_eyes)-data(1,idx_eyes),no_taps_eye)+data(1,idx_eyes);
end

%% filter the pupil data to remove spurious blinks
no_taps_pupil = round(fs*options.filter_length_pupil);

if no_taps_pupil>0
    data(:,idx_pupil) = medfilt1(data(:,idx_pupil)-data(1,idx_pupil),no_taps_eye)+data(1,idx_pupil);
end

%% filter the head movement data to remove spurious movement
no_taps_head = round(fs*options.filter_length_head);

if no_taps_head>0
    data(:,idx_head) = medfilt1(data(:,idx_head)-data(1,idx_head),no_taps_head)+data(1,idx_head);
end

%% remove initial sample offsets in data
if data(1,1)~=mean(round(data(fs*0.1,1)))
    data(1:5,:) = NaN;
    data = fillmissing(data,'linear','EndValues','extrap');
end

fprintf('done\n')

%% check if nan painting succeeded
if any(isnan(data(:)))
    error('NaNs not cleaned')
end
