baseDir = 'path\to\experiments\parent\directory';
% baseDir = 'C:\Users\Nikhil\research\bbbd\BBBD';

% Define the experiment paths relative to the base directory
bidsDirs = { ...
    fullfile(baseDir, 'experiment2', 'derivatives'), ...
    fullfile(baseDir, 'experiment3', 'derivatives') ...
};

sessions = {'ses-01', 'ses-02'};
eegPower = struct('ses_01', [], 'ses_02', []); 

% Alpha band filter parameters (8-12 Hz)
lowCutoff = 8;  
highCutoff = 12; 

% Loop through subjects across all experiments
for expIdx = 1:length(bidsDirs)
    bidsDir = bidsDirs{expIdx};

    % Loop through sessions
    for sesIdx = 1:length(sessions)
        session = sessions{sesIdx};
        sessionField = strrep(session, '-', '_'); 
        fprintf('  Processing session: %s...\n', session);

        sessionPower = [];

        % Get a list of all subjects in the BIDS directory
        subjects = dir(fullfile(bidsDir, 'sub-*'));
        subjects = subjects([subjects.isdir]); 

        % Loop through subjects
        for subjIdx = 1:length(subjects)
            subject = subjects(subjIdx).name;
            subjectField = strrep(subject, '-', '_'); 
            fprintf('Processing subject: %s\n', subject);

            sessionDir = fullfile(bidsDirs{expIdx}, subject, session, 'eeg', '*.bdf');
            bdfFiles = dir(sessionDir);

            if isempty(bdfFiles)
                fprintf('    No .bdf files found for %s %s in Experiment %d\n', subject, session, expIdx);
                continue;
            end

            allFilePower = [];
            for fileIdx = 1:length(bdfFiles)
                bdfFile = fullfile(bdfFiles(fileIdx).folder, bdfFiles(fileIdx).name);
                fprintf('    Reading %s...\n', bdfFile);
                EEG = pop_biosig(bdfFile); % Load EEG data using EEGLAB
                EEG = pop_eegfiltnew(EEG, lowCutoff, highCutoff); % Bandpass filter
                powerPerChannel = mean(EEG.data.^2, 2); % Mean power for each channel
                allFilePower = [allFilePower, powerPerChannel]; %#ok<AGROW>
            end
            
            % Aggregate power across files for this session and experiment
            if ~isempty(allFilePower)
                allFileAvgPower = mean(allFilePower, 2);
                sessionPower = [sessionPower, allFileAvgPower]; %#ok<AGROW>
            else
                fprintf('    No valid data found for %s %s in Experiment %d\n', subject, session, expIdx);
            end
        end

        % Calculate average power across experiments for this session
        if ~isempty(sessionPower)
            if strcmp(session, 'ses-01')
                eegPower.ses_01 = [eegPower.ses_01, mean(sessionPower, 2)]; %#ok<AGROW>
            elseif strcmp(session, 'ses-02')
                eegPower.ses_02 = [eegPower.ses_02, mean(sessionPower, 2)]; %#ok<AGROW>
            end
        else
            fprintf('    No valid data found for %s %s across all experiments\n', subject, session);
        end

    end
end

eegPowerTotal.ses_01 = mean(eegPower.ses_01, 2);  % Average across subjects for ses-01
eegPowerTotal.ses_02 = mean(eegPower.ses_02, 2);  % Average across subjects for ses-02

% Plot results with topoplot
sessions = {'ses-01', 'ses-02'};

figure;
absPowerLimits = [min(cellfun(@(x) min(x), struct2cell(eegPowerTotal))), ...
                  max(cellfun(@(x) max(x), struct2cell(eegPowerTotal)))];
dbPowerLimits = 10 * log10(absPowerLimits);

diffabsPowerLimits = [min(cellfun(@(x) min(x), num2cell(double(eegPowerTotal.ses_02) - double(eegPowerTotal.ses_01)))), ...
                  max(cellfun(@(x) max(x), num2cell(double(eegPowerTotal.ses_02) - double(eegPowerTotal.ses_01))))];
diffdbPowerLimits = 10 * log10(diffabsPowerLimits);

% Plot absolute power (\muV^2) for both sessions
for sesIdx = 1:length(sessions)
    session = sessions{sesIdx};
    sessionField = strrep(session, '-', '_'); 
    if isfield(eegPowerTotal, sessionField)
        % Convert to dB
        sessionPowerDB = 10 * log10(eegPowerTotal.(sessionField));
        ax(sesIdx) = subplot(1, 3, sesIdx);
        topoplot(sessionPowerDB, EEG.chanlocs, 'maplimits', dbPowerLimits);
        if strcmp(session, 'ses-01')
            title('Attentive');
        else
            title('Distracted');
        end
    end
end

cbShared = colorbar('Position', [0.63, 0.3, 0.01, 0.5]); 
ylabel(cbShared, 'dB');
set(cbShared, 'Ticks', linspace(round(dbPowerLimits(1)), round(dbPowerLimits(2)), 5));
fontsize(22,"points")

%  Difference b/w powers in ses-02 and ses-01
if isfield(eegPowerTotal, 'ses_01') && isfield(eegPowerTotal, 'ses_02')
    powerDifferenceDB = 10 * log10(eegPowerTotal.ses_02) - 10 * log10(eegPowerTotal.ses_01);
    ax(3) = subplot(1, 3, 3);  
    topoplot(powerDifferenceDB, EEG.chanlocs, 'maplimits', dbPowerLimits);  
    caxis([min(powerDifferenceDB), max(powerDifferenceDB)]);  % Set color axis limits
    title({'Power Difference','(Distracted - Attentive)'});  
end

customColormap = [linspace(1, 1, 256)', linspace(1, 0.5, 256)', linspace(1, 0, 256)'];  
colormap(ax(3), customColormap);  % custom colormap for the third subplot

cbDiff = colorbar('Position', [0.92, 0.3, 0.01, 0.5]);  
ylabel(cbDiff, 'dB');
cbDiff.Limits = [min(powerDifferenceDB), max(powerDifferenceDB)];
set(cbDiff);
fontsize(22,"points");  % Colorbar for the difference plot


ax = gca;  
fig = gcf; 

% Position the annotation slightly higher
annotation(fig, 'textbox', [0.27, 0.95, 0.5, 0], 'String', 'Average Alpha Band EEG Power', ...
           'FontSize', 22, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
           'EdgeColor', 'none', 'LineStyle', 'none', 'Interpreter', 'none');
set(gcf, 'Color', 'w');
