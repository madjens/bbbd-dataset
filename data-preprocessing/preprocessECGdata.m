function [data_hrhrv,ecg] = preprocessECGdata(data_ecg,time_axis_sec,options,iParticipant)

directory_ECG= [options.datadir 'ecg/peaks/'];
directory_HRHRV= [options.datadir 'ecg/hrhrv/'];

filename_hrhrv = sprintf('hrhrv_par_%02d_win_%1.0fsec_int_%s_outlier_%d.mat',iParticipant,options.hrv_window,options.hrv_int_method,options.doHRoutlierRemoval);
filename_ecg = sprintf('ECG_peaks_%02d.mat',iParticipant);

if ~exist(directory_ECG,'dir') %if folder doesn't exist it opens gui
    mkdir(directory_ECG) %create a folder with specific name
end

if ~exist(directory_HRHRV,'dir') %if folder doesn't exist it opens gui
    mkdir(directory_HRHRV) %create a folder with specific name
end

data_ecg_original = data_ecg;

if ~exist([directory_ECG filename_ecg],'file') || options.rePreProcessECG

    %% Filters
    HPcutoff = 0.5; % HP filter cut-off frequequency in Hz
    LPcutoff = 25; % HP filter cut-off frequequency in Hz
    fs = options.fs_exg;

    % pick your preferred high-pass filter
    [zhp,php,khp]=butter(5,HPcutoff/fs*2,'high');

    % pick your preferred low-pass filter
    [zlp,plp,klp]=butter(5,LPcutoff/fs*2,'low');
    Z = [zhp;zlp];
    P = [php;plp];
    k = khp*klp;
    [sos] = zp2sos(Z,P,k);
    data_ecg = sosfilt(sos,data_ecg);

    %peak picking
    BPMlimit = 160;
    BPSlimit = BPMlimit/60;
    deltaBeatTime = 1/BPSlimit;
    deltaBeatSample = deltaBeatTime*fs;

    %% Detect if its upsidedown
    %     data_ecg_size=size(data_ecg,1);
    %     if max(data_ecg(400000:data_ecg_size,1))<max(-data_ecg(400000:data_ecg_size,1))
    %         data_ecg=-data_ecg;
    %     end

    %% Find the peaks
    if iParticipant==16
        [ECG_peak_voltage,beat_location_samples]= findpeaks(data_ecg,'MinPeakDistance',deltaBeatSample,'MinPeakHeight',prctile(data_ecg,90),'Threshold',1e-4);
    else
        [ECG_peak_voltage,beat_location_samples]= findpeaks(data_ecg,'MinPeakDistance',deltaBeatSample,'MinPeakHeight',prctile(data_ecg,95),'Threshold',1e-4);
    end

    % LOCS: location of peak
    % PKS: peak value
    idx_PKS= ECG_peak_voltage <= mean(ECG_peak_voltage)+11*std(ECG_peak_voltage);
    beat_location_samples = beat_location_samples(idx_PKS,1);
    ECG_peak_voltage = ECG_peak_voltage(idx_PKS,1);

    %  remove peaks that are less than 1/2 in size as the others.
    idx_PKS= find(ECG_peak_voltage > median(ECG_peak_voltage)/2 & ECG_peak_voltage < median(ECG_peak_voltage)*2);
    beat_location_samples = beat_location_samples(idx_PKS,1);
    ECG_peak_voltage = ECG_peak_voltage(idx_PKS,1);

    %% go/not to gui
    if options.doManualPeaks
        if exist([directory_ECG filename_ecg],'file')
            gg = load([directory_ECG filename_ecg]);
            if isfield(gg,'beat_location_samples')
                beat_location_samples = gg.beat_location_samples;
            elseif isfield(gg,'beat_location_sec')
                beat_location_samples = NaN(size(gg.beat_location_sec));

                for iBeat = 1:length(gg.beat_location_sec)
                    [~,beat_location_samples(iBeat)] = min(abs(gg.beat_location_sec(iBeat)-time_axis_sec));
                end
            end
            bla = 1;
        end
    end

    if options.doManualPeaks && options.reDoManualPeaks
        % beat_location_samples = guiECG(data_ecg,time_axis_sec,beat_location_samples,options);
        save([directory_ECG filename_ecg],'beat_location_samples','time_axis_sec');
    elseif ~exist([directory_ECG filename_ecg],'file') && options.doManualPeaks
        % beat_location_samples = guiECG(data_ecg,time_axis_sec,beat_location_samples,options);
        save([directory_ECG filename_ecg],'beat_location_samples','time_axis_sec');
    elseif exist([directory_ECG filename_ecg],'file') && options.reDoManualPeaks
        load([directory_ECG filename_ecg],'beat_location_samples');
    end
else
    load(GetFullPath([directory_ECG filename_ecg]),'beat_location_samples');
end

beat_location_samples_original = NaN(size(beat_location_samples));

buffer_sample = 50;

for iBeat = 1:size(beat_location_samples,1)
    idx_start = max(beat_location_samples(iBeat)-buffer_sample,0);
    idx_end = min((beat_location_samples(iBeat)+buffer_sample),size(time_axis_sec,1));
    idx_search_area = idx_start:idx_end;
    [~,idx_local] = max(data_ecg_original(idx_search_area));
    beat_location_samples_original(iBeat) = idx_search_area(idx_local);
end

beat_location_sec_original = time_axis_sec(beat_location_samples_original);
beat_location_sec = time_axis_sec(beat_location_samples);

%% HR / HRV
if ~exist([directory_HRHRV filename_hrhrv],'file') || true
    % compute HR
    [HR,HR_instant,time_HR_instant] = computeHRdata(beat_location_samples,time_axis_sec,options);

    if options.doHRoutlierRemoval
        %remove HR outliers
        TF = (HR-median(HR))>3*iqr(HR);
        HR(TF) = NaN;
        HR = fillmissing(HR,'pchip','EndValues','nearest');
        if any(isnan(HR))
            bla = 1;
        end
    end

    % compute HRV
    [HRV] = zeros(size(HR));%computeHRVdata(time_axis_sec,HR,options);

    ecg.time_HR_instant = time_HR_instant;
    ecg.HR_instant = HR_instant;
    ecg.beat_location = beat_location_sec;
    ecg.beat_location_sec_original = beat_location_sec_original;

    %save results
    save([directory_HRHRV filename_hrhrv],'HR','HRV','ecg');
else  %if all is already present it doesn't open gui
    load([directory_HRHRV filename_hrhrv],'HR','HRV','ecg');
end

%% define output
data_hrhrv(:,1)=HR;
data_hrhrv(:,2)=HRV;
data_hrhrv(:,3)=data_ecg;
data_hrhrv(:,4)=data_ecg_original;

    function [HR_interpolated,HR_instantaneous,time_axis_hr_instantaneous]= computeHRdata(beat_location_sample,time_axis_sec,options)
        fprintft('Computing HR...')

        %% Calculating HR
        % [~,beat_location_sample] = ismember(beat_location_sec,time_axis_sec);

        Ntime= size(beat_location_sample,1);
        time_diff= nan(Ntime-1,1);
        HR_instantaneous= nan(size(time_diff,1),1);

        beat_location_min = time_axis_sec(beat_location_sample)/60;
        time_axis_min = time_axis_sec/60;

        for iTime= 1:Ntime-1
            time_diff(iTime,:)= beat_location_min(iTime+1,:)-beat_location_min(iTime); %time difference between 2 peaks
            HR_instantaneous(iTime,:)= 1/(time_diff(iTime,:));%heart rate in bpm
        end

        LOCS_HR=beat_location_min(2:size(beat_location_min,1),1);

        %% remove any unlikely beat values
        HR_limit_min = 40;
        HR_limit_max = 160;

        idx_not_likely = HR_instantaneous > HR_limit_max | HR_instantaneous<HR_limit_min;

        if ~isempty(idx_not_likely)
            HR_instantaneous(idx_not_likely) = [];
            LOCS_HR(idx_not_likely) = [];
            beat_location_sample(idx_not_likely) = [];
        end

        %%
        time_axis_hr_instantaneous = time_axis_sec(beat_location_sample(1:end-1));

        %define the time axis for inter and extra polation
        time_within=time_axis_min(beat_location_sample(2,1):beat_location_sample(end));
        time_out1=(time_axis_min(1:((beat_location_sample(2))-1),1));
        time_out2=(time_axis_min((beat_location_sample(end)+1):size(time_axis_min,1),1));

        % size(time_within,1)+size(time_out1,1)+size(time_out2,1) for checking

        HR_interp=interp1(LOCS_HR,HR_instantaneous,time_within,options.hrv_int_method);
        HR_extrap1=interp1(LOCS_HR,HR_instantaneous,time_out1,'nearest','extrap');
        HR_extrap2=interp1(LOCS_HR,HR_instantaneous,time_out2,'nearest','extrap');

        HR_interpolated = [HR_extrap1;HR_interp;HR_extrap2];

        fprintf('done\n')


    end
end