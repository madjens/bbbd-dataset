     
base_dir = '.\bbbd_datasets';
expnos = [1, 2, 3, 4, 5];
for expno = expnos
    bbbd_download_unzip(expno, base_dir);
end
            
function bbbd_download_unzip(expno, output_dir)
    url = sprintf('https://fcp-indi.s3.amazonaws.com/data/Projects/CUNY_MADSEN/BBBD/bids_data/experiment%d.zip', expno);
    output_file = fullfile(output_dir, ['experiment', num2str(expno), '.zip']);
    
    % Create output directory if it doesn't exist
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Download the file
    fprintf('Downloading from %s...\n', url);
    try
        websave(output_file, url);
        fprintf('Download completed: %s\n', output_file);
    catch ME
        fprintf('Failed to download. Error: %s\n', ME.message);
        return;
    end
    
    % Unzip the file
    if isfile(output_file)
        fprintf('Unzipping %s...\n', output_file);
        unzip(output_file, output_dir);
        fprintf('Extracted to: %s\n', output_dir);
        delete(output_file); % Remove the ZIP file
    else
        fprintf('%s is not a valid ZIP file. Skipping extraction.\n', output_file);
    end
end
                            
                        