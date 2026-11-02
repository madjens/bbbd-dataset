% bbbd_config_asrs_digitspan_23.m
% Generate config/experiment{2,3}_asrs_questionnaire.tsv and
% config/experiment{2,3}_digit_span_scores.tsv from source .mat files.
%
% Run from data-reformatting/ after setting data_dir in config.m.
% Source files required:
%   experiment_2/Experiment_2_questionnaire.mat
%   experiment_2/Experiment_2_asrs.mat
%   experiment_2/Experiment_2_Points.mat
%   experiment_3/Experiment_3_questionnaire.mat
%   experiment_3/Experiment_3_asrs.mat
%   experiment_3/Experiment_4_digitspan.mat  (EXP3 digitspan uses this filename)
%   experiment_3/Experiment_3_Points.mat

run('config.m');

script_dir = fileparts(mfilename('fullpath'));
config_dir = fullfile(script_dir, '..', 'config');

write_asrs_digitspan(2, data_dir, config_dir);
write_asrs_digitspan(3, data_dir, config_dir);

% -------------------------------------------------------------------------

function write_asrs_digitspan(exp_no, data_dir, config_dir)

    exp_folder = sprintf('experiment_%d', exp_no);

    % ASRS source
    if exp_no == 2
        d_q  = load(fullfile(data_dir, exp_folder, 'Experiment_2_questionnaire.mat'));
        d_as = load(fullfile(data_dir, exp_folder, 'Experiment_2_asrs.mat'));
        d_ds = load(fullfile(data_dir, exp_folder, 'Experiment_2_digitspan.mat'));
        d_pt = load(fullfile(data_dir, exp_folder, 'Experiment_2_Points.mat'));
    else
        d_q  = load(fullfile(data_dir, exp_folder, 'Experiment_3_questionnaire.mat'));
        d_as = load(fullfile(data_dir, exp_folder, 'Experiment_3_asrs.mat'));
        d_ds = load(fullfile(data_dir, exp_folder, 'Experiment_4_digitspan.mat'));
        d_pt = load(fullfile(data_dir, exp_folder, 'Experiment_3_Points.mat'));
    end

    pars     = d_q.questionnaireParticipantData;
    T_asrs   = d_as.T_asrs_summary;
    T_ds     = d_ds.T_digitspan_summary;
    pts_list = d_pt.answers_post_per_participant;
    pnos     = sort(arrayfun(@(x) x.participant_no, pts_list));

    % ── ASRS ──────────────────────────────────────────────────────────────
    asrs_out = fullfile(config_dir, sprintf('experiment%d_asrs_questionnaire.tsv', exp_no));
    fid = fopen(asrs_out, 'w');
    fprintf(fid, ['participant_id\tq1\tq2\tq3\tq4\tq5\tq6\tq7\tq8\tq9\tq10\t' ...
                  'q11\tq12\tq13\tq14\tq15\tq16\tq17\tq18\t' ...
                  'dichotomous_screener_score\tdichotomous_full_score\t' ...
                  'likert_screener_score\tlikert_full_score\t' ...
                  'hyperactivity_subscore\tinattention_subscore\n']);

    for i = 1:length(pnos)
        pno    = pnos(i);
        sub_id = sprintf('sub-%02d', pno);
        p      = pars{i};

        resp = double(p.swanData.responses(:)) - 1;  % 18×1, 0-4 scale
        if numel(resp) < 18, continue; end           % incomplete participant (NaN placeholder)
        lik_scr  = sum(resp(1:6));
        lik_full = sum(resp);

        idx = find(T_asrs.participant_no == pno, 1);
        if isempty(idx)
            fprintf('WARNING: sub-%02d missing from ASRS summary, skipping\n', pno);
            continue;
        end
        dich_scr  = T_asrs.screen_test_score(idx);
        dich_full = T_asrs.full_test_score(idx);
        ia_sub    = T_asrs.inattentive(idx)  + 10;
        hi_sub    = T_asrs.hyperactive(idx)  + 8;

        fprintf(fid, '%s', sub_id);
        for q = 1:18
            fprintf(fid, '\t%d', resp(q));
        end
        fprintf(fid, '\t%d\t%d\t%d\t%d\t%d\t%d\n', ...
            dich_scr, dich_full, lik_scr, lik_full, hi_sub, ia_sub);
    end
    fclose(fid);
    fprintf('Exp%d ASRS: %d participants → %s\n', exp_no, length(pnos), asrs_out);

    % ── Digit span ────────────────────────────────────────────────────────
    ds_out = fullfile(config_dir, sprintf('experiment%d_digit_span_scores.tsv', exp_no));
    fid = fopen(ds_out, 'w');
    fprintf(fid, 'participant_id\tscore\tweighted_score\n');

    [sorted_pnos, sort_idx] = sort(T_ds.participant_no);
    for i = 1:length(sorted_pnos)
        pno    = sorted_pnos(i);
        sub_id = sprintf('sub-%02d', pno);
        sc     = T_ds.digitspan_score(sort_idx(i));
        wsc    = T_ds.digitspan_score_weighted(sort_idx(i));
        if isnan(sc)
            fprintf(fid, '%s\tn/a\tn/a\n', sub_id);
        else
            fprintf(fid, '%s\t%g\t%g\n', sub_id, sc, wsc);
        end
    end
    fclose(fid);
    fprintf('Exp%d digit span: %d participants → %s\n', exp_no, length(sorted_pnos), ds_out);
end
