% Master script to run 4 scripts sequentially with error handling



% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 1 2 3
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 

disp('Experiments 1, 2, 3 executing...');
% try
%     disp('Running mevd_123_raw_eye_heart.m...');
%     run('mevd_123_raw_eye_heart.m'); 
% catch ME
%     disp(['Error in mevd_123_raw_eye_heart: ' ME.message]);
%     return;
% end

% try
%     disp('Running mevd_123_raw_eeg.m...');
%     run('mevd_123_raw_eeg.m'); 
% catch ME
%     disp(['Error in mevd_123_raw_eeg: ' ME.message]);
%     return;
% end
% 
% try
%     disp('Running mevd_123_derived_continuous.m...');
%     disp('Running mevd_123_derived_continuous.m...');
%     disp('Running mevd_123_derived_continuous.m...');
%     disp('Running mevd_123_derived_continuous.m...');
%     disp('Running mevd_123_derived_continuous.m...');
% 
%     run('mevd_123_derived_continuous.m'); 
% catch ME
%     disp(['Error in mevd_123_derived_continuous: ' ME.message]);
%     return;
% end
% 
% try
%     disp('Running mevd_123_derived_discrete.m...');
%     disp('Running mevd_123_derived_discrete.m...');
%     disp('Running mevd_123_derived_discrete.m...');
%     disp('Running mevd_123_derived_discrete.m...');
%     disp('Running mevd_123_derived_discrete.m...');
% 
%     run('mevd_123_derived_discrete.m'); 
% catch ME
%     disp(['Error in mevd_123_derived_discrete: ' ME.message]);
%     return;
% end

disp('Experiments 1, 2, 3 executed successfully.');

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% % % % % % % % % % % % % % % % % % % % % % % % % % % % Intervention
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% 
% disp('Experiments 4,5 executing...');
% 
% try
%     disp('Running mevd_45_raw_eye_heart.m...');
%     run('mevd_45_raw_eye_heart.m');
% catch ME
%     disp(['Error in mevd_45_raw_eye_heart: ' ME.message]);
%     return;
% end
% 
% try
%     disp('Running mevd_45_raw_eeg.m...');
%     run('mevd_45_raw_eeg.m'); 
% catch ME
%     disp(['Error in mevd_45_raw_eeg: ' ME.message]);
%     return;
% end
% 
% try
%     disp('Running mevd_45_derived_continuous.m...');
%     disp('Running mevd_45_derived_continuous.m...');
%     disp('Running mevd_45_derived_continuous.m...');
%     disp('Running mevd_45_derived_continuous.m...');
%     disp('Running mevd_45_derived_continuous.m...');
% 
%     run('mevd_45_derived_continuous.m'); 
% catch ME
%     disp(['Error in mevd_45_derived_continuous: ' ME.message]);
%     return;
% end
% 
% try
%     disp('Running mevd_45_derived_discrete.m...');
%     disp('Running mevd_45_derived_discrete.m...');
%     disp('Running mevd_45_derived_discrete.m...');
%     disp('Running mevd_45_derived_discrete.m...');
%     disp('Running mevd_45_derived_discrete.m...');
% 
%     run('mevd_45_derived_discrete.m'); 
% catch ME
%     disp(['Error in mevd_45_derived_discrete: ' ME.message]);
%     return;
% end
% 


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% matrices %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

try
    disp('Running bbbd_matrix_123.m...');
    run('bbbd_matrix_123.m');
catch ME
    disp(['Error in bbbd_matrix_123: ' ME.message]);
    return;
end

try
    disp('Running bbbd_matrix_45.m...');
    run('bbbd_matrix_45.m'); 
catch ME
    disp(['Error in bbbd_matrix_45: ' ME.message]);
    return;
end
% 
% try
%     disp('Running bbbd_discrete_123.m...');
% 
%     run('bbbd_discrete_123.m'); 
% catch ME
%     disp(['Error in bbbd_discrete_123: ' ME.message]);
%     return;
% end
% 
% try
%     disp('Running bbbd_discrete_45.m...');
% 
%     run('bbbd_discrete_45.m'); 
% catch ME
%     disp(['Error in bbbd_discrete_45: ' ME.message]);
%     return;
% end
% 
% disp('All scripts executed successfully.');
