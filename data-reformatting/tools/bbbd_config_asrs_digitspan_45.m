% bbbd_config_asrs_digitspan_45.m
% Generate config/experiment{4,5}_asrs_questionnaire.tsv and
% config/experiment{4,5}_digit_span_scores.tsv from source .mat files.
%
% Run from data-reformatting/ after setting data_dir in config.m.
% Source file required:
%   experiment_4/Experiment_6_questionnaire.mat
%   config/doIntervention_indexing.mat
%
% EXP4 (no intervention) and EXP5 (yes intervention) share raw data.
% T_asrs_summary and T_digitspan_summary are MATLAB opaque tables extracted
% via writetable → readtable. Columns are printed for inspection on first run.
%
% EXP5 sub-09: participant at index 9 (1-indexed, sorted by participant_no
% within the EXP5 subset) is excluded — no signal data recorded.
%
% KNOWN LIMITATION: individual ASRS item responses (q1-q18) are NOT present
% in Experiment_6_questionnaire.mat (T_asrs_summary has 8 summary cols only).
% The config files contain q1-q18 columns whose source is unknown/unavailable.
% This script reproduces all summary columns exactly but omits q1-q18.

run('config.m');

script_dir = fileparts(mfilename('fullpath'));
config_dir = fullfile(script_dir, '..', 'config');

% Load source and split index
d   = load(fullfile(data_dir, 'experiment_4', 'Experiment_6_questionnaire.mat'));
doi = load(fullfile(config_dir, 'doIntervention_indexing.mat'));
do_interv = logical(doi.doIntervention);  % 92×1

% ── Dump opaque tables to temp CSV, read back ────────────────────────────────
tmp_asrs = [tempname '.csv'];
tmp_ds   = [tempname '.csv'];
writetable(d.T_asrs_summary,    tmp_asrs);
writetable(d.T_digitspan_summary, tmp_ds);

T_asrs = readtable(tmp_asrs, 'TextType', 'string');
T_ds   = readtable(tmp_ds,   'TextType', 'string');
delete(tmp_asrs); delete(tmp_ds);

fprintf('ASRS columns (%d rows): %s\n', height(T_asrs), ...
    strjoin(T_asrs.Properties.VariableNames, ', '));
fprintf('DigitSpan columns (%d rows): %s\n', height(T_ds), ...
    strjoin(T_ds.Properties.VariableNames, ', '));

assert(height(T_asrs) == 92, 'Expected 92 rows in T_asrs_summary (one per raw participant)');
assert(height(T_ds)   == 92, 'Expected 92 rows in T_digitspan_summary');

% ── Split rows by intervention ────────────────────────────────────────────────
T_asrs_4 = T_asrs(~do_interv, :);   % EXP4: no intervention, 43 participants
T_asrs_5 = T_asrs( do_interv, :);   % EXP5: yes intervention, 49 raw (1 excluded)
T_ds_4   = T_ds(~do_interv, :);
T_ds_5   = T_ds( do_interv, :);

% Sort each subset by participant_no for stable bbbd sub-ID assignment
if ismember('participant_no', T_asrs_4.Properties.VariableNames)
    [~, idx4] = sort(double(T_asrs_4.participant_no));
    [~, idx5] = sort(double(T_asrs_5.participant_no));
else
    idx4 = 1:height(T_asrs_4);
    idx5 = 1:height(T_asrs_5);
    fprintf('WARNING: no participant_no column — assuming rows are sorted\n');
end
T_asrs_4 = T_asrs_4(idx4, :);  T_ds_4 = T_ds_4(idx4, :);
T_asrs_5 = T_asrs_5(idx5, :);  T_ds_5 = T_ds_5(idx5, :);

% EXP5 sub-09 exclusion (index 9 in sorted EXP5 order)
sub09_row = 9;
T_asrs_5([sub09_row], :) = [];
T_ds_5([sub09_row], :)   = [];

% EXP4: hyperactive/inattentive stored as raw sum (0-based), needs +8/+10 to match config sub-scores.
% EXP5: hyperactive/inattentive already stored as sub-scores; no offset needed.
% Both: scale_24_screen/full_score are 1-based sums; config uses 0-based, so subtract 6/18.
write_asrs(T_asrs, T_asrs_4, 4, config_dir, [], 8, 10);
write_asrs(T_asrs, T_asrs_5, 5, config_dir, sub09_row, 0, 0);
write_ds(T_ds_4, 4, config_dir, []);
write_ds(T_ds_5, 5, config_dir, sub09_row);

% ── Output functions ──────────────────────────────────────────────────────────

function write_asrs(T_full, T_exp, exp_no, config_dir, skip_idx, hi_offset, ia_offset)
    cols  = T_full.Properties.VariableNames;
    out   = fullfile(config_dir, sprintf('experiment%d_asrs_questionnaire.tsv', exp_no));
    n     = height(T_exp);

    % Detect individual response columns (q1-q18 or similar)
    q_cols = cols(startsWith(cols, 'q') & arrayfun(@(c) ~isnan(str2double(c{1}(2:end))), cols));
    has_q  = length(q_cols) == 18;

    fid = fopen(out, 'w');
    if has_q
        fprintf(fid, ['participant_id\tq1\tq2\tq3\tq4\tq5\tq6\tq7\tq8\tq9\tq10\t' ...
                      'q11\tq12\tq13\tq14\tq15\tq16\tq17\tq18\t' ...
                      'dichotomous_screener_score\tdichotomous_full_score\t' ...
                      'likert_screener_score\tlikert_full_score\t' ...
                      'hyperactivity_subscore\tinattention_subscore\n']);
    else
        fprintf(fid, ['participant_id\tdichotomous_screener_score\tdichotomous_full_score\t' ...
                      'likert_screener_score\tlikert_full_score\t' ...
                      'hyperactivity_subscore\tinattention_subscore\n']);
        fprintf('NOTE: Exp%d ASRS — individual q1-q18 not in source (Experiment_6_questionnaire.mat)\n', exp_no);
    end

    for i = 1:n
        % skip_idx: the excluded participant's position in the original sorted list;
        % participants after that position get sub-IDs shifted by +1 to preserve the gap.
        sub_no = i + (~isempty(skip_idx) && i >= skip_idx);
        sub_id = sprintf('sub-%02d', sub_no);
        fprintf(fid, '%s', sub_id);

        if has_q
            for qi = 1:18
                val = T_exp.(q_cols{qi})(i);
                fprintf(fid, '\t%s', num2str(double(val)));
            end
        end

        % Summary scores — try common column name variants
        dich_scr  = get_col(T_exp, i, {'dichotomous_screener_score','screen_test_score'});
        dich_full = get_col(T_exp, i, {'dichotomous_full_score','full_test_score'});
        % scale_24_* stores 1-based sums; config expects 0-based (subtract n_items)
        lik_scr   = get_col(T_exp, i, {'likert_screener_score','scale_24_screen_score'}) - 6;
        lik_full  = get_col(T_exp, i, {'likert_full_score','scale_24_full_score'}) - 18;
        hi_sub    = get_col(T_exp, i, {'hyperactivity_subscore','hyperactive'}) + hi_offset;
        ia_sub    = get_col(T_exp, i, {'inattention_subscore','inattentive'}) + ia_offset;

        % If likert scores not in table, compute from q1-q18
        if isnan(lik_scr) && has_q
            qs = arrayfun(@(c) double(T_exp.(c{1})(i)), q_cols);
            lik_scr  = sum(qs(1:6));
            lik_full = sum(qs);
        end

        fprintf(fid, '\t%s\t%s\t%s\t%s\t%s\t%s\n', ...
            fmt(dich_scr), fmt(dich_full), fmt(lik_scr), fmt(lik_full), fmt(hi_sub), fmt(ia_sub));
    end
    fclose(fid);
    fprintf('Exp%d ASRS: %d participants → %s\n', exp_no, n, out);
end

function write_ds(T_ds_exp, exp_no, config_dir, skip_idx)
    out = fullfile(config_dir, sprintf('experiment%d_digit_span_scores.tsv', exp_no));
    n   = height(T_ds_exp);
    fid = fopen(out, 'w');
    fprintf(fid, 'participant_id\tscore\tweighted_score\n');
    for i = 1:n
        sub_no = i + (~isempty(skip_idx) && i >= skip_idx);
        sub_id = sprintf('sub-%02d', sub_no);
        sc  = get_col(T_ds_exp, i, {'digitspan_score','score'});
        wsc = get_col(T_ds_exp, i, {'digitspan_score_weighted','weighted_score','score_weighted'});
        if isnan(sc) || sc == 0
            fprintf(fid, '%s\tn/a\tn/a\n', sub_id);
        else
            fprintf(fid, '%s\t%s\t%s\n', sub_id, fmt(sc), fmt(wsc));
        end
    end
    fclose(fid);
    fprintf('Exp%d digit span: %d participants → %s\n', exp_no, n, out);
end

function v = get_col(T, row, names)
    v = NaN;
    for k = 1:length(names)
        n = names{k};
        if ismember(n, T.Properties.VariableNames)
            raw = T.(n)(row);
            if iscell(raw), raw = raw{1}; end
            v = double(raw);
            return;
        end
    end
end

function s = fmt(v)
    if isnan(v), s = 'n/a'; else, s = num2str(v); end
end
