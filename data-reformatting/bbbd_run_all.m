try
    disp('Running bbbd_generate_bids_descriptors.m...');
    run('bbbd_generate_bids_descriptors.m');
catch ME
    disp(['Error in bbbd_generate_bids_descriptors: ' ME.message]);
    return;
end

try
    disp('Running bbbd_generate_stimuli_questionnaire.m...');
    run('bbbd_generate_stimuli_questionnaire.m');
catch ME
    disp(['Error in bbbd_generate_stimuli_questionnaire: ' ME.message]);
    return;
end

disp('Experiments 1, 2, 3 executing...');

try
    disp('Running bbbd_123_raw_eye_heart.m...');
    run('bids/raw/bbbd_123_raw_eye_heart.m');
catch ME
    disp(['Error in bbbd_123_raw_eye_heart: ' ME.message]);
    return;
end

try
    disp('Running bbbd_123_raw_eeg.m...');
    run('bids/raw/bbbd_123_raw_eeg.m');
catch ME
    disp(['Error in bbbd_123_raw_eeg: ' ME.message]);
    return;
end

try
    disp('Running bbbd_123_derived_continuous.m...');
    run('bids/derived/bbbd_123_derived_continuous.m');
catch ME
    disp(['Error in bbbd_123_derived_continuous: ' ME.message]);
    return;
end

try
    disp('Running bbbd_123_derived_discrete.m...');
    run('bids/derived/bbbd_123_derived_discrete.m');
catch ME
    disp(['Error in bbbd_123_derived_discrete: ' ME.message]);
    return;
end

disp('Experiments 1, 2, 3 executed successfully.');

disp('Experiments 4, 5 executing...');

try
    disp('Running bbbd_build_int_metadata.m...');
    run('bbbd_build_int_metadata.m');
catch ME
    disp(['Error in bbbd_build_int_metadata: ' ME.message]);
    return;
end

try
    disp('Running bbbd_45_raw_eye_heart.m...');
    run('bids/raw/bbbd_45_raw_eye_heart.m');
catch ME
    disp(['Error in bbbd_45_raw_eye_heart: ' ME.message]);
    return;
end

try
    disp('Running bbbd_45_raw_eeg.m...');
    run('bids/raw/bbbd_45_raw_eeg.m');
catch ME
    disp(['Error in bbbd_45_raw_eeg: ' ME.message]);
    return;
end

try
    disp('Running bbbd_45_derived_continuous.m...');
    run('bids/derived/bbbd_45_derived_continuous.m');
catch ME
    disp(['Error in bbbd_45_derived_continuous: ' ME.message]);
    return;
end

try
    disp('Running bbbd_45_derived_discrete.m...');
    run('bids/derived/bbbd_45_derived_discrete.m');
catch ME
    disp(['Error in bbbd_45_derived_discrete: ' ME.message]);
    return;
end

disp('Experiments 4, 5 executed successfully.');

try
    disp('Running bbbd_matrix_123.m...');
    run('matrix/bbbd_matrix_123.m');
catch ME
    disp(['Error in bbbd_matrix_123: ' ME.message]);
    return;
end

try
    disp('Running bbbd_matrix_45.m...');
    run('matrix/bbbd_matrix_45.m');
catch ME
    disp(['Error in bbbd_matrix_45: ' ME.message]);
    return;
end

try
    disp('Running bbbd_discrete_123.m...');
    run('matrix/bbbd_discrete_123.m');
catch ME
    disp(['Error in bbbd_discrete_123: ' ME.message]);
    return;
end

try
    disp('Running bbbd_discrete_45.m...');
    run('matrix/bbbd_discrete_45.m');
catch ME
    disp(['Error in bbbd_discrete_45: ' ME.message]);
    return;
end

disp('All scripts executed successfully.');
