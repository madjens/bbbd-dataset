function [data_eye,data_pupil,data_head] = postprocessEyelinkData(data,timestamps,metadata,options)

fprintft('Postprocessing Eyetracking data\n')

%% seperate data streams (head, eye and pupil)
data_eye = data(:,1:2); %x,y
data_pupil = data(:,3); % pupil
data_head = data(:,6:8); % head
data_resolution = data(:,4:5); % resolution

%% normalized gaze position data (referenced to the screen)
data_eye(:,3) = data_eye(:,1)/options.monitor_resolution(1);
data_eye(:,4) = data_eye(:,2)/options.monitor_resolution(2);

%% Visual degree
% centered around the screen
data_x_centered = data_eye(:,1)-options.monitor_resolution(1)/2;
data_y_centered = data_eye(:,2)-options.monitor_resolution(2)/2;

data_eye(:,5) = data_x_centered./data_resolution(:,1); % horizontal
data_eye(:,6) = data_y_centered./data_resolution(:,2); % vertical

%% gaze variation
data_eye(:,7) = sqrt(abs(hilbert(data_eye(:,4))).^2 + abs(hilbert(data_eye(:,5))).^2);

%% saccade rate
time_offset = timestamps(1);
saccade_locations = metadata.saccades.timestamps_edf(:,1);
saccade_locations_corrected = saccade_locations-time_offset;
timestamps_corrected = timestamps-time_offset;

data_eye(:,8) = computeSRdata(saccade_locations_corrected,timestamps_corrected,options);

%% blink rate
time_offset = timestamps(1);
blink_locations = metadata.blinks.timestamps_edf(:,1);
blink_locations_corrected = blink_locations-time_offset;
timestamps_corrected = timestamps-time_offset;

data_eye(:,9) = computeSRdata(blink_locations_corrected,timestamps_corrected,options);

%% fixation rate
time_offset = timestamps(1);
fixation_locations = metadata.fixations.timestamps_edf(:,1);
fixation_locations_corrected = fixation_locations-time_offset;
timestamps_corrected = timestamps-time_offset;

data_eye(:,10) = computeSRdata(fixation_locations_corrected,timestamps_corrected,options);

%% pupil size
%regress out head position in z-direction from pupil size
data_pupil(:,2) = regressout(data_head(:,3),data_pupil(:,1));

%pupil size normalize with 95th percentile
data_pupil(:,3) = data_pupil(:,2) ./ prctile(data_pupil(:,2),95);

%% compute head velocity
[data_head(:,4), data_head(:,5), data_head(:,6),~] = headMovementNorm(data_head(:,1),data_head(:,2),data_head(:,3));

fprintft('Done\n')


    function [HeadMovementLength, HeadMovementLog, HeadMovementSqrt,HeadMovementHilbert] = headMovementNorm(X,Y,Z)

        XYZ = permute(cat(3,X,Y,Z),[ 1 3 2]);

        %compute movement vectors
        HeadMovementHilbert = imag(hilbert(XYZ));
        HeadMovementLength = sqrt(nansum(HeadMovementHilbert.^2,2));
        HeadMovementLog = log(HeadMovementLength);
        HeadMovementSqrt = sqrt(HeadMovementLength);
    end

    function [SR_interpolated,SR_instantaneous,time_axis_sr_instantaneous]= computeSRdata(saccade_location_sec,time_axis_sec,options)
        fprintft('Computing SR...')

        %% Calculating SR
        [~,beat_location_sample] = ismember(saccade_location_sec,time_axis_sec);

        Ntime= size(saccade_location_sec,1);
        time_diff= nan(Ntime-1,1);
        SR_instantaneous= nan(size(time_diff,1),1);

        saccade_location_min = saccade_location_sec/60;
        time_axis_min = time_axis_sec/60;

        % DO NOT USE diff
        for iTime= 1:Ntime-1
            time_diff(iTime,:) = saccade_location_min(iTime+1,:)-saccade_location_min(iTime); %time difference between 2 saccades
            SR_instantaneous(iTime,:)= 1/(time_diff(iTime,:)); %heart rate in bpm
        end

        LOCS_SR=saccade_location_min(2:size(saccade_location_min,1),1);

        %% remove any unlikely beat values
        % HR_limit_min = 30;
        % HR_limit_max = 160;
        %
        % idx_not_likely = SR_instantaneous > HR_limit_max | SR_instantaneous<HR_limit_min;
        %
        % if ~isempty(idx_not_likely)
        %     SR_instantaneous(idx_not_likely) = [];
        %     LOCS_SR(idx_not_likely) = [];
        %     beat_location_sample(idx_not_likely) = [];
        % end

        %%
        time_axis_sr_instantaneous = saccade_location_sec(1:end-1);

        %define the time axis for inter and extra polation
        time_within=time_axis_min(beat_location_sample(2,1):beat_location_sample(end));
        time_out1=(time_axis_min(1:((beat_location_sample(2))-1),1));
        time_out2=(time_axis_min((beat_location_sample(end)+1):size(time_axis_min,1),1));

        % size(time_within,1)+size(time_out1,1)+size(time_out2,1) for checking

        SR_interp=interp1(LOCS_SR,SR_instantaneous,time_within,options.sr_int_method);
        SR_extrap1=interp1(LOCS_SR,SR_instantaneous,time_out1,'nearest','extrap');
        SR_extrap2=interp1(LOCS_SR,SR_instantaneous,time_out2,'nearest','extrap');

        SR_interpolated = [SR_extrap1;SR_interp;SR_extrap2];

        fprintf('done\n')


    end

    function yhat = regressout(X,y)
        %X: what you want to regress out
        %y: your variable

        X = [ones(size(X,1),1) X];

        %remove nans in data
        X_nnan = X(all(~isnan(X) & ~isnan(y),2),:);
        y_nnan = y(all(~isnan(X) & ~isnan(y),2),:);

        %estimate weights
        w = (X_nnan\y_nnan);

        y_m = nanmean(y);

        %project data and subtract
        yhat = y - X*w + y_m;
    end
end