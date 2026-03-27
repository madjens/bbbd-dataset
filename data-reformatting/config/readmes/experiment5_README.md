# The Brain, Body, and Behaviour Dataset - Experiment 5
## Summary:

**Description:**  Subjects watched five videos, knowing they'd be tested afterward. After each video, they answered 11 to 12 factual multiple-choice questions. Videos and questions were presented in random order.

**Subjects:**  48, **Sessions:**  2 
1. *Attentive* - Watch videos with focus
2. *Intervention* - Watch videos after intervention with focus and answer questions after

Note: The intervention was monetary incentives for every question they get right. Questions that were asked were shown beforehand.

# Tasks (Stimuli)

## Experiment 5

-------------------------------------------------------------------------------------------------------------------------------------------
| **Stimulus ID** | **Name**                                                    | **URL**                                                 |
|-----------------|-------------------------------------------------------------|---------------------------------------------------------|
| Stim-01         | Why are Stars Star-Shaped                                   | [Watch Here](https://www.youtube.com/embed/VVAKFJ8VVp4) |
| Stim-02         | The Immune System Explained – Bacteria                      | [Watch Here](https://www.youtube.com/embed/zQGOcOUBi6s) |
| Stim-03         | Are We All Related                                          | [Watch Here](https://www.youtube.com/embed/mnYSMhR3jCI) |
-------------------------------------------------------------------------------------------------------------------------------------------

**Modalities Recorded:**
-   Gaze (X, Y)
-   Pupil Size
-   Blinks
-   Saccades
-   Head Position (X, Y, Z)
-   EOG
-   EEG
-   ECG
-   Respiration

# Experiment Setup:
In experiment 5, subjects were instructed to watch the same 3 instructional videos in attention condition **twice**. 

Between the two conditions there was an **intervention** - subjects were incentivised with money for every question they got right at the test that was given to them at the end of the second condition. 
They were also shown what questions were going to be asked, and were made to **watch the same videos again**. We track the same signals as in experiment 4.

We collected EEG, EOG, ECG, respiration, pupillary responses, gaze, and head position.

Sessions:

-   Ses-01 contains these signals recorded on subjects watching these videos in an attentive condition. They answered questions pertaining to each video after watching the videos one at a time.
-   Ses-02 contains the data recorded on subjects watching all of the videos again in a distracted condition in the same order as Ses-01 described above. The distraction from the stimuli was to silently count backwards from a random prime number in steps of 7. No questions were asked after this session.

# Questionnaires:  
Questionnaires and answers to them can be found in the phenotype/ directory.

1.  **stimuli_questionnaire:**

The stimuli_questionnaire tsv and json files have the questions, answers and correct answers.

- “Domain” question type is a general domain knowledge question that was asked before the subject watched a video.
- “Memory” question type is a memory testing question that is asked after the subject finishes watching the video, and has questions that are directly pertaining to the video content.

2.  **asrs_questionnaire:**

These tsv and json files have questions and answers to the ASRS questionnaire that is an adult ADHD symptom checklist test. The answers are options from 0 (never) to 4 (very often).

- There are two different scales used to score this test, and there are 2 different parts (Part A, Part B) to this test. Screen test involves just the first 6 questions (Part A), and the full-test involves the entire 18 question test (Part A + Part B). Despite lesser questions, the screen test (first 6 ques) gives one a higher indication of ADHD prevalence than the full-test.

- This is the reason why the 2 different scoring scales are based on the Screen test. Scale one is out of 6, where each question counts for just 1 point depending on the frequency of the symptom occurrence, and if one scores over 4, there is a high chance of ADHD prevalence. The next scale is out of 24 where the 5 frequencies of symptom occurrence (never, rarely, sometimes, often, very often) are assigned scores in an increasing order of 0-4, and for each question, the respective scores of the frequency is the score for that question. Out of 24, the threshold for high prevalence of ADHD is 18 for this scale.

The following are the question numbers for inattentive ADHD and Hyperactive ADHD

inattentive_questions = [1,2,3,4,7,8,9,10,11,12]
hyperactive_questions = [5,6,13,14,15,16,17,18]

# General BIDS dataset structure overview for all MEVD experiments

Each BIDS dataset (one per experiment) has files that describe the dataset, its participants, and related metadata at the root directory - dataset_description.json, participants.tsv and participants.json, providing essential information about the study and participants to anyone working with the dataset.

In the root directory, the raw data of each participant is organized by subject (sub-XX) and then further divided into sessions (ses-XX) to accommodate multi-session data collection (some experiments have 2 sessions: attentive and distracted). Inside each session folder, you'll find modality-specific subfolders, such as:

-   **eeg**: Contains electroencephalogram data files (.bdf), event logs (events.tsv), and additional metadata (.json) that describe the experiment and recording conditions.  
    
-   **beh**: Contains physiological recordings like ECG (electrocardiogram) and EOG (electrooculogram) stored in compressed .tsv.gz files, with accompanying metadata in .json files.  
    
-   **eyetrack**: Contains physiological recordings like eye-tracking (gaze coordinates and pupil size), and head movement data, stored in compressed .tsv.gz files, with accompanying metadata in .json files.
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
| Modality  | Filename Format                                                     | Data File Extension | Metadata                                     | Notes                                                                                      |
|-----------|---------------------------------------------------------------------|---------------------|----------------------------------------------|--------------------------------------------------------------------------------------------|
| EEG       | `sub_xx-ses_xx-task-stimxx_{file_of_interest.extension}`            | `.bdf`              | Exists for each file as a `.json` file       |  There are event files with a `.tsv` extension that include start and end times in seconds.|
| Beh       | `sub_xx-ses_xx-task-stimxx_recording-{modality}_physio.{extension}` | `.tsv.gz`           | Exists for each file as a `.json` file       |                                                                                            |
| EyeTrack  | `sub_xx-ses_xx-task-stimxx_{modality}_eyetrack.{extension}`         | `.tsv.gz`           | Exists for each file as a `.json` file       |                                                                                            |
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

There is also a **derivatives** directory which contains preprocessed data derived from the raw recordings, such as filtered heart rate data or preprocessed physiological signals, making it easy to work with and apply advanced analyses. Files in this directory are also stored in the BIDS structure (subject-wise → session-wise → modality-wise). A brief overview on what you can expect in the derivatives directory:

-   **eeg**: Contains filtered electroencephalogram (EEG) data files (.bdf).  
-   **beh**: Contains heart beats (r-peak timestamps synchronized with the stimulus), heart-rates, filtered ECG, breath-rates, and they are stored in compressed .tsv.gz files.  
-   **eyetrack**: Contains saccades (timestamps), saccade-rates, fixations (timestamps), fixation-rates, blinks (timestamps), blink-rates, and filtered pupil and gaze files all stored in compressed .tsv.gz files.
    

## How to Navigate the Dataset

-   **Top-Level Files**: Files like dataset_description.json and participants.tsv give you an overview of the study and participants, serving as your starting point when exploring a dataset.
    
-   **Derivatives Folder**: In this folder, processed data is organized like how raw data is organized in the BIDS directory.
    
-   **Subject Folders (sub-XX):** Inside these folders, data is organized by individual participants, providing separate directories for each person involved in the study.
    
-   **Session Folders (ses-XX)**: For longitudinal or multi-session studies, session folders contain the raw and derived data for each session, making it easy to track and analyze data collected over time.
    
-   **Modality-Specific Subfolders:** Each session is further split into subfolders according to data modalities (e.g., EEG, behavior/physio), helping you to quickly locate the data of interest, whether it’s brain recordings, heart rate data, or eye movement information.
    
-   **Tasks:** Each subject is exposed to different stimuli during data collection, and BIDS uses "tasks" in filenames to clearly differentiate recordings based on these experimental conditions. This makes it easy to identify, retrieve, and analyze data associated with specific tasks across multiple modalities.
   
## Dataset Overview

The table below is a breakdown on the total minutes of raw data available for each session across the complete dataset:

----------------------------------------
| Modality                   | Hours   | 
|----------------------------|---------|
| EEG                        | 65      |               
| ECG                        | 93.5    |  
| EOG                        | 94.35   |  
| Head                       | 92.46   |                 
| Gaze                       | 110.56  |        
| Pupil                      | 110.56  |             
| Respiration                | 44.2    |            
----------------------------------------