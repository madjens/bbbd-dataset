"""
Generate config/experiment{4,5}_stimuli_questionnaire.tsv from source .mat files.

Usage (run from data-reformatting/):
    python tools/bbbd_config_stimuli_questionnaire_45.py <data_dir>

data_dir: root containing experiment_4/ subfolder with Experiment_6_Points.mat.

EXP4 (no intervention) and EXP5 (yes intervention) share raw data in experiment_4/.
Split is determined by config/doIntervention_indexing.mat.

Columns: participant_id, stim_no, question_no, numberofanswers, answers, correct_answers, score, is_correct
  - No_correct_option = n → options 1..n are all correct
  - score = |selected ∩ {1..n}| / n  (partial credit)
  - is_correct = 1 only if selected == {1..n} exactly

EXP5 sub-09 is excluded (participant index 9 in EXP5 sorted ordering has no signal data).
"""
import scipy.io
import csv
import os
import sys

DATA_DIR   = sys.argv[1] if len(sys.argv) > 1 else os.path.join('..', 'data')
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_DIR = os.path.join(SCRIPT_DIR, '..', 'config')

# ── qid metadata: stim_no (bbbd), local question position, n_correct ──────────
# Hardcoded from MATLAB exploration of answers_post_per_question (opaque table).
# Stars (stim1): qids 48-59, all n=1
# Immune (stim2): qids 71-82, all n=1
# Related (stim3): qids 119-130, n varies
REL_CORRECT = [1, 3, 1, 1, 1, 1, 1, 2, 1, 1, 1, 3]
QID_INFO = {}
for i, q in enumerate(range(48, 60)):
    QID_INFO[q] = (1, i + 1, 1)
for i, q in enumerate(range(71, 83)):
    QID_INFO[q] = (2, i + 1, 1)
for i, q in enumerate(range(119, 131)):
    QID_INFO[q] = (3, i + 1, REL_CORRECT[i])

STIM_QIDS = {
    1: list(range(48, 60)),
    2: list(range(71, 83)),
    3: list(range(119, 131)),
}

HEADER = ['participant_id', 'stim_no', 'question_no', 'numberofanswers',
          'answers', 'correct_answers', 'score', 'is_correct']

EXCLUDE = {4: set(), 5: {'sub-09'}}


def compute_row(answers_raw, n_correct):
    if isinstance(answers_raw, (int, float)):
        selected = [int(answers_raw)]
    else:
        selected = [int(x) for x in answers_raw]
    correct_set  = set(range(1, n_correct + 1))
    selected_set = set(selected)
    overlap      = len(selected_set & correct_set)
    score        = round(overlap / n_correct, 10)
    is_correct   = 1 if selected_set == correct_set else 0
    return (' '.join(str(x) for x in selected),
            ' '.join(str(x) for x in range(1, n_correct + 1)),
            score, is_correct)


def generate(source_pars, par_idx, pars_data, exp_no):
    rows = []
    for bbbd_idx, par_no in enumerate(source_pars, 1):
        sub_id = f'sub-{bbbd_idx:02d}'
        if sub_id in EXCLUDE.get(exp_no, set()):
            continue
        p = pars_data[par_idx[par_no]]
        qid_ans = {int(qid): ans for qid, ans in zip(p['qid_global'], p['answers'])}
        for stim_no in [1, 2, 3]:
            for qid in STIM_QIDS[stim_no]:
                _, q_local, n_correct = QID_INFO[qid]
                ans_raw = qid_ans.get(qid, 1)
                answers_str, correct_str, score, is_correct = compute_row(ans_raw, n_correct)
                rows.append([sub_id, stim_no, q_local, n_correct,
                              answers_str, correct_str, score, is_correct])
    out = os.path.join(CONFIG_DIR, f'experiment{exp_no}_stimuli_questionnaire.tsv')
    with open(out, 'w', newline='') as f:
        w = csv.writer(f, delimiter='\t')
        w.writerow(HEADER)
        w.writerows(rows)
    print(f'Exp{exp_no}: {len(rows) // 36} participants, {len(rows)} rows → {out}')


# ── Load data ──────────────────────────────────────────────────────────────────
mat  = scipy.io.loadmat(
    os.path.join(DATA_DIR, 'experiment_4', 'Experiment_6_Points.mat'),
    simplify_cells=True)
pars_data = mat['answers_post_per_participant']
par_idx   = {p['participant_no']: i for i, p in enumerate(pars_data)}

doi = scipy.io.loadmat(
    os.path.join(CONFIG_DIR, 'doIntervention_indexing.mat'), simplify_cells=True)
do_interv = doi['doIntervention'].astype(bool)

exp4_pars = sorted(p['participant_no'] for i, p in enumerate(pars_data) if not do_interv[i])
exp5_pars = sorted(p['participant_no'] for i, p in enumerate(pars_data) if do_interv[i])
print(f'Exp4: {len(exp4_pars)} source participants, Exp5: {len(exp5_pars)} source participants')

generate(exp4_pars, par_idx, pars_data, 4)
generate(exp5_pars, par_idx, pars_data, 5)
