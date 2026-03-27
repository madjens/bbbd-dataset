%% =========================
% CONFIG
% =========================
baseDir = "D:\Users\Neuro\City College Dropbox\NIKHIL KUPPA\dataset_multimodal_video\BBBD-unzipped";

bidsDirs = { ...
    fullfile(baseDir, 'experiment2', 'derivatives'), ...
    fullfile(baseDir, 'experiment3', 'derivatives') ...
};

sessions = {'ses-01', 'ses-02'};
lowCutoff = 8;
highCutoff = 12;

alphaPower.ses_01 = [];
alphaPower.ses_02 = [];
subjectList = {};

%% =========================
% LOAD + COMPUTE SUBJECT-LEVEL POWER
% =========================
for expIdx = 1:length(bidsDirs)
    bidsDir = bidsDirs{expIdx};

    subjects = dir(fullfile(bidsDir, 'sub-*'));
    subjects = subjects([subjects.isdir]);

    for subjIdx = 1:length(subjects)
        subject = subjects(subjIdx).name;
        fprintf('Processing %s (Exp %d)\n', subject, expIdx);

        subjData = struct();

        for sesIdx = 1:length(sessions)
            session = sessions{sesIdx};
            sessionField = strrep(session, '-', '_');

            sessionDir = fullfile(bidsDir, subject, session, 'eeg', '*.bdf');
            bdfFiles = dir(sessionDir);

            if isempty(bdfFiles)
                continue;
            end

            allFilePower = [];

            for fileIdx = 1:length(bdfFiles)
                bdfFile = fullfile(bdfFiles(fileIdx).folder, bdfFiles(fileIdx).name);
                fprintf('  Reading %s\n', bdfFile);

                EEG = pop_biosig(bdfFile);
                EEG = pop_eegfiltnew(EEG, lowCutoff, highCutoff);

                powerPerChannel = mean(EEG.data.^2, 2);
                allFilePower = [allFilePower, powerPerChannel]; %#ok<AGROW>
            end

            if ~isempty(allFilePower)
                subjData.(sessionField) = mean(allFilePower, 2);
            end
        end

        % Keep only subjects with BOTH conditions
        if isfield(subjData, 'ses_01') && isfield(subjData, 'ses_02')
            alphaPower.ses_01 = [alphaPower.ses_01, subjData.ses_01];
            alphaPower.ses_02 = [alphaPower.ses_02, subjData.ses_02];
            subjectList{end+1} = subject; %#ok<AGROW>
        end
    end
end

fprintf('\nTotal subjects used: %d\n', length(subjectList));

%% =========================
% STATS (CHANNEL-WISE)
% =========================
[nChannels, nSubjects] = size(alphaPower.ses_01);

pvals = zeros(nChannels,1);
tvals = zeros(nChannels,1);

for ch = 1:nChannels
    [~, p, ~, stats] = ttest(alphaPower.ses_02(ch,:), alphaPower.ses_01(ch,:));
    pvals(ch) = p;
    tvals(ch) = stats.tstat;
end

% FDR correction
% Benjamini-Hochberg FDR correction
[p_sorted, sort_idx] = sort(pvals);
m = length(pvals);

q = 0.05; % FDR level

thresholds = (1:m)'/m * q;

below = p_sorted <= thresholds;

if any(below)
    max_idx = find(below, 1, 'last');
    cutoff_p = p_sorted(max_idx);
else
    cutoff_p = 0;
end

p_fdr = pvals; % keep original for reference
sigMask = pvals <= cutoff_p;

%% =========================
% EFFECT SIZE (CHANNEL-WISE)
% =========================
diffVals = alphaPower.ses_02 - alphaPower.ses_01;
cohen_d = mean(diffVals, 2) ./ std(diffVals, 0, 2);

%% =========================
% GLOBAL STATS (BEST FOR PAPER)
% =========================
meanAlpha_01 = mean(alphaPower.ses_01, 1);
meanAlpha_02 = mean(alphaPower.ses_02, 1);

[~, p_global, ~, stats_global] = ttest(meanAlpha_02, meanAlpha_01);

cohen_d_global = mean(meanAlpha_02 - meanAlpha_01) / std(meanAlpha_02 - meanAlpha_01);

fprintf('\n===== GLOBAL STATS =====\n');
fprintf('t(%d) = %.3f\n', nSubjects-1, stats_global.tstat);
fprintf('p = %.5f\n', p_global);
fprintf('Cohen''s d = %.3f\n', cohen_d_global);

%% =========================
% TOPOPLOTS (custom colormap, shared colorbars)
% =========================

% Load electrode locations
chanlocs = readlocs('C:\Users\Neuro\research\mevd\eeg_loc\location_file\BioSemi64.loc', 'filetype', 'locs');

% Convert alpha power to dB
powerDB_01 = 10*log10(mean(alphaPower.ses_01, 2));
powerDB_02 = 10*log10(mean(alphaPower.ses_02, 2));
diffDB = 10*log10(mean(alphaPower.ses_02, 2) - mean(alphaPower.ses_01, 2));

% Ensure channel numbers match
nChans = min([length(powerDB_01), length(chanlocs)]);
powerDB_01 = powerDB_01(1:nChans);
powerDB_02 = powerDB_02(1:nChans);
diffDB     = diffDB(1:nChans);
sigMask    = sigMask(1:nChans);
chanlocs   = chanlocs(1:nChans);

figure('Color','w','Position',[100 100 1600 500]);

% --- Custom colormap
customColormap = [linspace(1,1,256)', linspace(1,0.5,256)', linspace(1,0,256)'];

% Shared absolute power limits
absPowerLimits = [min([powerDB_01; powerDB_02]), max([powerDB_01; powerDB_02])];

% --- Attentive
ax(1) = subplot(1,3,1);
topoplot(powerDB_01, chanlocs, 'maplimits', absPowerLimits, 'plotrad', 0.5);
title('Attentive', 'FontSize', 16);
colormap(ax(1), customColormap);

% --- Distracted
ax(2) = subplot(1,3,2);
topoplot(powerDB_02, chanlocs, 'maplimits', absPowerLimits, 'plotrad', 0.5);
title('Distracted', 'FontSize', 16);
colormap(ax(2), customColormap);

% --- Shared colorbar for absolute power plots
cbAbs = colorbar('Position', [0.63, 0.3, 0.01, 0.5]); 
ylabel(cbAbs, 'dB', 'FontSize', 22);
caxis(ax(1), absPowerLimits);
caxis(ax(2), absPowerLimits);

% --- Difference (symmetric scale, significant channels circled)
ax(3) = subplot(1,3,3);
maxAbs = max(abs(diffDB));
topoplot(diffDB, chanlocs, 'maplimits', [-maxAbs maxAbs]);
title({'Difference (Distracted - Attentive)'}, 'FontSize', 16);
colormap(ax(3), customColormap);

% --- Colorbar for difference plot
cbDiff = colorbar('Position', [0.92, 0.3, 0.01, 0.5]); 
ylabel(cbDiff, 'dB', 'FontSize', 22);
cbDiff.Limits = [-maxAbs maxAbs]; % symmetric scale
set(cbDiff);

% --- Overall title
sgtitle('Alpha Band Power (8–12 Hz)', 'FontSize', 18);

%% =========================
% READY-TO-REPORT TEXT
% =========================
fprintf('\n===== REPORT TEXT =====\n');

if p_global < 0.05
    fprintf(['Alpha-band power (8–12 Hz) was significantly higher in the Distracted ' ...
        'condition compared to the Attentive condition (paired t-test, t(%d)=%.2f, p=%.4f, d=%.2f).\n'], ...
        nSubjects-1, stats_global.tstat, p_global, cohen_d_global);
else
    fprintf(['No significant difference in alpha-band power between conditions ' ...
        '(t(%d)=%.2f, p=%.4f).\n'], ...
        nSubjects-1, stats_global.tstat, p_global);
end

fprintf('Number of significant channels (FDR < 0.05): %d / %d\n', sum(sigMask), nChannels);