function [data,metadata] = preprocessEEGdata(data,options,fs,chanlocs)
% All the usual EEG preprocessing, except epoching and epoch rejection as
% there are not events to epoch with in natural stimuli. duh! Instead, bad
% data is set = 0 in the continuous stream, which makes sense when
% computing covariance matrices but maybe not for other purposes.

% debug = 0;   % turn this on to show data before/after preprocessing.

% If you use this script please
% Please cite "Madsen, J., Kuppa, N. & Parra, L. C. The Brain, Body, and Behavior Dataset (BBBD):
% Multimodal Recordings during Educational Videos. bioRxiv (2025). https://doi.org/10.1101/2025.04.29.651259"

fprintft('Preprocessing EEG data\n')

%% Design filters
HPcutoff =0.3; % HP filter cut-off frequequency in Hz
[zhp,php,khp]=butter(5,HPcutoff/fs*2,'high'); % drift removal
[znotch,pnotch,knotch]=butter(5,[59 61]/fs*2,'stop'); % 60Hz line noise
Z = [zhp;znotch];
P = [php;pnotch];
k = khp*knotch;
sos = zp2sos(Z,P,k);

%% Preprocess data
% high-pass filter and remove line noise
data = sosfilt(sos,data);

%% remove eye blinks using least squares filtering using EOG channels
if options.doEOGregression
    data_eog = data(:, options.eogchannels);

    % remove eog channels that are constant
    data_eog(:, std(data_eog,[],1) == 0) = [];

    %do not include outliers when doing the eog removal
    mask = all(bsxfun(@lt,abs(data-median(data,1)),options.kIQR_eog*iqr(data,1)),2);

    % regression with clean eog
    data = data - data_eog*(data_eog(mask,:)\data(mask,:));
end

% return only eeg channels
data = data(:,options.eegchannels);
clear data_eog

if contains(options.badchannel_position,'pre')
    % do pre badchannel removal
    kIQD = 1.5;
    badchannels = automaticChannelRejection(data,'LOGPOWER',options,kIQD);
    data = fillBadchannels(data,badchannels,'interp',options.locationfile);
end

if options.doRPCA
    fprintft('Computing RPCA...')
    % run RPCA on data
    data = inexact_alm_rpca(data);
    fprintf('done\n')

    if options.doVisualization
        visualizeEEGdata(resample(data,options.fs_eeg,fs),[],100,options.fs_eeg,'post RPCA')
    end
end

%% artifact rejection
if options.doEEGArtifactRejection
    if options.doRPCA, kIQD=4; else kIQD = 3; end      % multiple of interquartile differences to mark as outliers
    threshold = kIQD*iqr(data,1); %diff(prctile(data,[25 75]));
    mask = bsxfun(@gt,abs(data-median(data,1)),threshold);

    % NaN data
    data(mask) = NaN;

    % remove 40ms before and after an artifact;
    h=[1; zeros(round(0.04*fs)-1,1)];
    data = filter(h,1,flipud(filter(h,1,flipud(data))));

    % keep stats of how much data was removed
    metadata.artifacts_removed = sum(isnan(data),1)./size(data,1);
    metadata.artifacts = isnan(data);
end

%fill bad sampled (artifacts)
data = fillBadSamples(data,options.artifactFill,chanlocs,fs,options);

% Mark outliers as 0, to avoid NaN coding and to discount noisy channels
if sum(sum(isnan(data)))~=0
    fprintf('Setting %d NaNs to zero\n',sum(isnan(data(:))))
    data(isnan(data))=0;
end

fprintft('Preprocessing complete\n')

    function data = fillBadSamples(data,method,chanlocs,fs,options)
        % data = fillBadSamples(data,method,chanlocs,fs)
        %
        %
        % data          : samples x channels
        % method        : either 'interp' or 'zeros'
        % chanlocs      : only used for interp method (channel number, theta, rho, channel name)
        %
        % jmad/jenma 2018
        %
        % If you use this script please
        % Please cite "Madsen, J., Kuppa, N. & Parra, L. C. The Brain, Body, and Behavior Dataset (BBBD):
        % Multimodal Recordings during Educational Videos. bioRxiv (2025). https://doi.org/10.1101/2025.04.29.651259"
        %

        if nargin < 1
            data = randn(1000,64);
        end
        if nargin < 2
            badsamples = randi(64,3,1);
        end
        if nargin < 3
            method = 'interp';
        end
        if nargin < 4
            locationfile = '..\data\location_file\BioSemi64.mat';
        end

        Nchannels = size(data,2);
        Nsamples = size(data,1);
        badsamples = isnan(data);

        if strcmpi(method,'interp')
            fprintft('Starting interpolation...')

            %% read the location file
            %calcuate the X and Y coordinates i.e. the 3D coordinated projected in to 2D space
            theta = [chanlocs.theta];
            theta_rad = (theta+90)/360*2*pi; % rotate the coordinate system and convert to radian
            rho  = [chanlocs.radius]; %get the lenght of the vector
            [X,Y] = pol2cart(theta_rad,rho); %convert from polar to cartesian coordinate system

            % start interpolating
            parfor iSample = 1:Nsamples
                goodchannels = find(~badsamples(iSample,:));
                badchannels = find(badsamples(iSample,:));

                if length(badchannels)<Nchannels/3 && ~isempty(badchannels)

                    %good channels coordinates
                    Xgc = X(goodchannels)';
                    Ygc = Y(goodchannels)';

                    %bad channels coordinates
                    Xbc = X(badchannels)';
                    Ybc = Y(badchannels)';

                    %pick out the timeslice/sample across channels you want to correct
                    data_sample = data(iSample,:);

                    %get the eeg sample values for the good channels
                    Vgc = data_sample(goodchannels)';

                    %create a scatter interpolation function
                    F = scatteredInterpolant(Xgc,Ygc,Vgc);

                    %use the function to interpolate missing values
                    data_sample(badchannels) = F(Xbc,Ybc);

                    %put back the corrected sample in to the data structure
                    data(iSample,:) = data_sample;
                end
                if rem(iSample,10000)==0
                    fprintf('.')
                end
            end

            % set the nans that were not filled to zero
            badsamples = isnan(data);
            fprintf('done\n')
        elseif strcmpi(method,'zeros')
            fprintf('Filling with zeros...')
            fprintf('done\n')
        end

        if any(badsamples(:))

            data(badsamples) = 0;

            if options.doArtifactSmoothing
                fprintft('Smoothing around artifacts')
                % Create window for smoothing around the artifacts
                h = hann(round(0.04*fs));
                [sos,g] = tf2sos(h,1);
                win = filtfilt(sos,g,double(badsamples));

                % Normalize window
                win = 1 - win./max(win(:));

                % Apply window to data
                data = data.*win;
            end
        end
        fprintf('...done\n')
    end

    function badchannels = automaticChannelRejection(data,type,metadata)
        if nargin < 2
            type = 'LOGPOWER';
        end
        bla = 1;

        %% read the coordinates of the channels
        coordinates = [[metadata.chanlocs.X]' [metadata.chanlocs.Y]' [metadata.chanlocs.Z]'];

        %% match the two sets of information

        if contains(type,'LOGPOWER') || contains(type,'COMBI')
            % first take the power of the data and take it into the log domain
            channel_logpower = db(std(data),'power') - median(db(std(data),'power'));
            kIQD=1.5;      % multiple of interquartile differences to mark as outliers
            threshold = kIQD*(diff(prctile(channel_logpower,[25 75])));
            badchannels_power = find(bsxfun(@gt,channel_logpower,threshold)~=0)';

            fprintf('\nFound %d channels using logpower method: ',length(badchannels_power))
            fprintf('%d ',badchannels_power)
            fprintf('\n')
            badchannels = badchannels_power;

            if length(badchannels_power)>5
                bla = 1;
            end

            if(0)
                kIQD=1.5;      % multiple of interquartile differences to mark as badchannels
                channel_logpower = log(std(data))-median(log(std(data)));
                data(:,channel_power>kIQD*(diff(prctile(channel_logpower,[25 75])))) = NaN;

                figure, hist(data_transformed,20)
                figure, hist(std(data),20)
            end
        end

        if strcmpi(type,'CORR')
            %% measure distances between all electrodes
            normfactor = sqrt(sum(abs(coordinates).^2,2));
            coordinates = bsxfun(@rdivide,coordinates,normfactor);

            % matrix method
            similarity = coordinates*coordinates';

            for ii = 1:size(coordinates,1)
                [~,idx] = sort(similarity(ii,:),'descend');
                neighborChannels(ii,:) = idx(2:5);
            end

            %% compute correlations between neighboring electrodes
            for ii = 1:size(coordinates,1)
                for ll = 1:size(neighborChannels,2)
                    R = corrcoef(data(ii,:)',data(neighborChannels(ii,ll),:)');
                    correlations(ii,ll) = R(1,2);
                end
            end

            %% decide if channels are bad based on the average correlation between its 4 neighbors
            %     threshold = 0.05;
            correlations_m = (mean(correlations,2));

            threshold = 0;
            badchannels_corr = find(correlations_m<threshold);
            fprintf('Found %d channels using correlation method: ',length(badchannels_corr))
            fprintf('%d ',badchannels_corr)
            fprintf('\n')
            badchannels = badchannels_corr;
            if length(badchannels_corr)>5
                bla = 1;
            end
            if(0)
                figure,
                hist(correlations_m,100)
            end
        end
    end
end