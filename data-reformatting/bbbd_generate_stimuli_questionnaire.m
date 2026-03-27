run('config.m');

% Copies pre-built stimuli_questionnaire.tsv and .json files from config/
% into each experiment's phenotype/ directory under output_dir.
%
% The source files in config/ are static assets copied from the BBBD-unzipped
% reference release. The individual question text and per-participant answers
% are not reconstructible from the data/ metadata files alone.

for exp_no = 1:5
    phenotype_dir = fullfile(output_dir, sprintf('experiment%d', exp_no), 'phenotype');
    make_dir(phenotype_dir);

    for ext = {'tsv', 'json'}
        src = fullfile('config', sprintf('experiment%d_stimuli_questionnaire.%s', exp_no, ext{1}));
        dst = fullfile(phenotype_dir, sprintf('stimuli_questionnaire.%s', ext{1}));
        if isfile(src)
            copyfile(src, dst);
            fprintf('Experiment %d: copied stimuli_questionnaire.%s\n', exp_no, ext{1});
        else
            fprintf('Experiment %d: %s not found in config/ — skipping\n', exp_no, ext{1});
        end
    end
end

function make_dir(d)
    if ~exist(d, 'dir')
        mkdir(d);
    end
end
