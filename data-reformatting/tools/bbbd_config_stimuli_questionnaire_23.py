"""
Generate config/experiment{2,3}_stimuli_questionnaire.tsv from source .mat files.

Usage (run from data-reformatting/):
    python tools/bbbd_config_stimuli_questionnaire_23.py <data_dir>

data_dir: root containing experiment_2/, experiment_3/ subfolders.

Exp2 columns: participant_id, stim_no, question_type, question_number, answer, correctanswer, is_correct
  - question_type: domain (pre-test) or memory (post-test)
  - stim_no: physical stimulus number from stimuli_order, not viewing position
  - correctanswer: always 1; is_correct = 1 if answer == 1

Exp3 columns: participant_id, stim_no, question_no, numberofanswers, answers, correct_answers, score
  - Questions are counterbalanced across participants (different qid sets per participant-stim)
  - n_correct per qid is fixed; the 72-entry map is hardcoded from answers_post_per_question

Note: Exp1 source .mat does not contain per-question responses; config is static.
"""
import scipy.io
import csv
import os
import sys

DATA_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join('..', 'data')
CONFIG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'config')


def to_list(val):
    if hasattr(val, '__len__') and not isinstance(val, str):
        return [int(x) for x in val]
    return [int(val)]


# ── Experiment 2 ──────────────────────────────────────────────────────────────

def generate_exp2():
    mat = scipy.io.loadmat(
        os.path.join(DATA_DIR, 'experiment_2', 'Experiment_2_Points.mat'),
        simplify_cells=True)

    pre_pars  = {int(p['participant_no']): p for p in mat['answers_pre_per_participant']}
    post_pars = {int(p['participant_no']): p for p in mat['answers_post_per_participant']}
    all_par_nos = sorted(post_pars.keys())

    header = ['participant_id', 'stim_no', 'question_type',
              'question_number', 'answer', 'correctanswer', 'is_correct']
    rows = []

    for par_no in all_par_nos:
        sub_id = f'sub-{par_no:02d}'
        for question_type, pars in [('domain', pre_pars), ('memory', post_pars)]:
            if par_no not in pars:
                continue
            p = pars[par_no]
            for pos_idx in range(len(p['stimuli_order'])):
                stim_no = int(p['stimuli_order'][pos_idx])
                qids    = p['qid_per_stim'][pos_idx]
                answers = p['answers_per_stim'][pos_idx]
                for q_local, (_, ans_raw) in enumerate(zip(qids, answers), 1):
                    ans = to_list(ans_raw)[0]
                    rows.append([sub_id, stim_no, question_type, q_local, ans, 1, 1 if ans == 1 else 0])

    rows.sort(key=lambda r: (r[0], r[2], r[1], r[3]))
    out = os.path.join(CONFIG_DIR, 'experiment2_stimuli_questionnaire.tsv')
    with open(out, 'w', newline='') as f:
        csv.writer(f, delimiter='\t').writerows([header] + rows)
    print(f'Exp2: {len(all_par_nos)} participants, {len(rows)} rows → {out}')


# ── Experiment 3 ──────────────────────────────────────────────────────────────

# qid → n_correct for EXP3 (72 questions across 6 stimuli, counterbalanced per participant).
# Derived from answers_post_per_question (MATLAB opaque table) via existing config.
QID_N_CORRECT = {
     1:1,  2:1,  3:3,  4:1,  5:1,  6:1,  7:1,  8:1,  9:2, 10:1, 11:3, 12:4,
    13:1, 14:3, 15:1, 16:1, 17:1, 18:1, 19:1, 20:2, 21:1, 22:1, 23:1, 24:3,
    25:3, 26:1, 27:1, 28:1, 29:1, 30:1, 31:2, 32:1, 33:1, 34:1, 35:1, 36:1,
    37:1, 38:3, 39:1, 40:1, 41:1, 42:1, 43:1, 44:3, 45:1, 46:1, 47:1, 48:1,
    49:3, 50:1, 51:1, 52:1, 53:1, 54:1, 55:2, 56:1, 57:1, 58:1, 59:2, 60:2,
    61:1, 62:3, 63:1, 64:1, 65:1, 66:1, 67:2, 68:1, 69:1, 70:1, 71:2, 72:2,
}


def generate_exp3():
    mat = scipy.io.loadmat(
        os.path.join(DATA_DIR, 'experiment_3', 'Experiment_3_Points.mat'),
        simplify_cells=True)
    par_map = {int(p['participant_no']): p for p in mat['answers_post_per_participant']}

    header = ['participant_id', 'stim_no', 'question_no', 'numberofanswers',
              'answers', 'correct_answers', 'score']
    rows = []

    for par_no in sorted(par_map.keys()):
        sub_id = f'sub-{par_no:02d}'
        p = par_map[par_no]
        for pos_idx in range(len(p['stimuli_order'])):
            stim_no  = int(p['stimuli_order'][pos_idx])
            qids     = p['qid_per_stim'][pos_idx]
            ans_block = p['answers_per_stim'][pos_idx]
            for q_local, (qid, ans_raw) in enumerate(zip(qids, ans_block), 1):
                qid = int(qid)
                n_correct   = QID_N_CORRECT[qid]
                selected    = to_list(ans_raw)
                correct_set = set(range(1, n_correct + 1))
                overlap     = len(set(selected) & correct_set)
                score       = round(overlap / n_correct, 10)
                rows.append([
                    sub_id, stim_no, q_local, n_correct,
                    '  '.join(str(x) for x in selected),
                    '  '.join(str(x) for x in range(1, n_correct + 1)),
                    score,
                ])

    rows.sort(key=lambda r: (r[0], r[1], r[2]))
    out = os.path.join(CONFIG_DIR, 'experiment3_stimuli_questionnaire.tsv')
    with open(out, 'w', newline='') as f:
        csv.writer(f, delimiter='\t').writerows([header] + rows)
    print(f'Exp3: {len(par_map)} participants, {len(rows)} rows → {out}')


generate_exp2()
generate_exp3()
