
import zipfile
import os
import requests

def bbbd_download_unzip(expno, output_dir, output_file=None):
    url = f'https://fcp-indi.s3.amazonaws.com/data/Projects/CUNY_MADSEN/BBBD/bids_data/experiment{expno}.zip'
    if output_file is None:
        output_file = os.path.join(output_dir, url.split("/")[-1])
    os.makedirs(output_dir, exist_ok=True)
    
    # Download 
    print(f"Downloading from {url}...")
    response = requests.get(url, stream=True)
    if response.status_code == 200:
        with open(output_file, 'wb') as file:
            for chunk in response.iter_content(chunk_size=8192):
                file.write(chunk)
        print(f"Download completed: {output_file}")
    else:
        print(f"Failed to download. Status code: {response.status_code}")
        return None
    
    # Unzip
    if zipfile.is_zipfile(output_file):
        print(f"Unzipping {output_file}...")
        with zipfile.ZipFile(output_file, 'r') as zip_ref:
            zip_ref.extractall(output_dir)
        print(f"Extracted to: {output_dir}")
        os.remove(output_file)
    else:
        print(f"{output_file} is not a ZIP file, skipping extraction.")
    return output_file

base_dir = r'.\bbbd_datasets' 
expnos = [1,2,3,4,5]
for expno in expnos:
    bbbd_download_unzip(expno, base_dir)

                        