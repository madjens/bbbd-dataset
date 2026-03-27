function [data_out,breath_location_sec] = preprocessRespirationData(data,time_axis_sec,fs,options)

%determine if the respiration signal should be flipped
if (mean(data) - median(data))<0
    data = -data;
end

data_out = data;

%% compute respiration rate
% Filters
HPcutoff =0.05; % HP filter cut-off frequequency in Hz
LPcutoff = 25; % HP filter cut-off frequequency in Hz

% pick your preferred high-pass filter
[zhp,php,khp]=butter(5,HPcutoff/fs*2,'high');

% pick your preferred low-pass filter
[zlp,plp,klp]=butter(5,LPcutoff/fs*2,'low');
Z = [zhp;zlp];
P = [php;plp];
k = khp*klp;

[sos,g] = zp2sos(Z,P,k);
data_hp_filtered = filtfilt(sos,g,data-data(1));

%peak picking
% A respiration rate under 12 or over 25 breaths per minute while resting is considered abnormal.
BPMlimit = 30;
BPSlimit = BPMlimit/60;
deltaBeatTime = 1/BPSlimit;
deltaBeatSample = deltaBeatTime*fs;

%% Find the peaks
[respiration_peak_voltage,breath_location_samples]= findpeaks(data_hp_filtered,'MinPeakDistance',deltaBeatSample,'MinPeakHeight',median(data_hp_filtered));

breath_location_sec = time_axis_sec(breath_location_samples)';

if(0)
    figure, plot(time_axis_sec,data_hp_filtered,'k'), hold on
    plot(breath_location_sec,respiration_peak_voltage,'ro')
end

%% compute RR
[RR_interpolated,RR_instantaneous,time_axis_rr_instantaneous,breath_location_sec]= computeRRdata(breath_location_sec,time_axis_sec,options);

%% add respiration rate to output signal
data_out(:,2) = RR_interpolated;

%% Respiration volume
data_out(:,4) = abs(hilbert(data));

%% HELPERS
    function [RR_interpolated,RR_instantaneous,time_axis_rr_instantaneous,breath_location_sec]= computeRRdata(breath_location_sec,time_axis_sec,options)
        fprintft('Computing HR...')

        if size(time_axis_sec,1)<size(time_axis_sec,2)
            time_axis_sec = time_axis_sec';
        end

        if size(breath_location_sec,1)<size(breath_location_sec,2)
            breath_location_sec = breath_location_sec';
        end

        %% Calculating HR
        [~,breath_location_sample] = ismember(breath_location_sec,time_axis_sec);

        Ntime= size(breath_location_sec,1);
        time_diff= nan(Ntime-1,1);
        RR_instantaneous= nan(size(time_diff,1),1);

        breath_location_min = breath_location_sec/60;
        time_axis_min = time_axis_sec/60;

        for iTime= 1:Ntime-1
            time_diff(iTime,:)= breath_location_min(iTime+1,:)-breath_location_min(iTime); %time difference between 2 peaks
            RR_instantaneous(iTime,:)= 1/(time_diff(iTime,:));%heart rate in bpm
        end

        LOCS_RR=breath_location_min(2:length(breath_location_min));


        %% remove any unlikely breath values
        RR_limit_min = 4;
        RR_limit_max = 60;

        idx_not_likely = RR_instantaneous > RR_limit_max | RR_instantaneous<RR_limit_min;

        if ~isempty(idx_not_likely)
            RR_instantaneous(idx_not_likely) = [];
            LOCS_RR(idx_not_likely) = [];
            breath_location_sample(idx_not_likely) = [];
        end

        breath_location_sec = time_axis_sec(breath_location_sample);

        %%
        time_axis_rr_instantaneous = breath_location_sec(1:end-1);

        %define the time axis for inter and extra polation
        time_within=time_axis_min(breath_location_sample(2):breath_location_sample(end));
        time_out1=(time_axis_min(1:(breath_location_sample(2)-1)));
        time_out2=(time_axis_min((breath_location_sample(end)+1):size(time_axis_min,1)));

        % size(time_within,1)+size(time_out1,1)+size(time_out2,1) for checking

        RR_interp=interp1(LOCS_RR,RR_instantaneous,time_within,options.hrv_int_method);
        RR_extrap1=interp1(LOCS_RR,RR_instantaneous,time_out1,'nearest','extrap');
        RR_extrap2=interp1(LOCS_RR,RR_instantaneous,time_out2,'nearest','extrap');

        RR_interpolated = [RR_extrap1;RR_interp;RR_extrap2];

        fprintf('done\n')

    end
end