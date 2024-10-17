# Logbook

This logbook is used to describe what we are doing, or what we have done, or what we will do.
Its purpose is so that anyone can come back to this project at any point in the future and understand what it is about, what was being done and why, where all the data and the code and so on is.
It is like a readme and like the Git repo's logs, but unlike the readme, it gives a running commentary on the development of the project as it happens, and unlike the Git repo's logs, it provides more context or description and explanation than just about the changes to the files.
This is all part of an effort to make this project as fully reproducible as possible.

All entries below are in reverse chronological order.

## 17 October, 2024; 07:49

Starting doing nonlinear regression. Started with one trial for one subject and with one channel.
Looked at rbf and gp models.
The two main problems faced so far are:

- GPs are extremely slow; though it looks like optimization and/or variational Bayes etc might be possible with cmdstanr
- There is high frequency correlated noise, which looks like it needs a separate GP, which is fine in principle, but I have not exactly got it working yet.

Next steps:

- Get a GP model of slow (which is the main focus) and fast (essentially noise) working
- Get the optimization and/or VB methods working
- Look at downsampling; maybe that will solve it
- Look at the GAM models in neurokit

## 15 October, 2024; 18:11

Add a new preprocessing step using autoreject.

## 21 September, 2024; 21:55

Remove an ThB_03_21_2024_12_10_57.bdf because this was a copy of ThA on that same date.
The original version of ThB is incomplete or not saved properly and it was incorrectly assumed that the ThA on that date was the correct version.
See commit 9498264537196746c2c3fc3bccdf50fb57b552e4 (main) for more details.

## 20 September, 2024; 22:25

- Change the participant id inside the json file of MB*11_13_2023_13_56_39 to \_MB* from *WB*

## 19 September, 2024; 20:13

- Two EEG sessions were recorded at 2048HZ, not 1024HZ. These are downsampled to 1024hz. The sessions can be identified by their file size.
  - raw-data/main/WA_11_22_2023_13_54_06.bdf
  - raw-data/main/MA_11_20_2023_11_46_10.bdf

## 11 September, 2023; 08:08

- As a very preliminary analysis, plot the ERPs for each channel for each of the two tasks. For this, we will average over all subjects and all trials. This required reading in the EEG data and changing some code to do and then writing new code to plot ERPs etc.
- The principal relevant files are, so far,
  - pyutils/get_epochs_from_bdfs.py to read in the raw EEG data and create a feather data frame for exporting
  - analysis/get_unprocessed_erp.R

What I need to do now is do all the preprocessing. Which is?

- Filtering
- Re-referencing to average
- ICA for artefact rejection
- Epoching
- Bad channel detection?
- Baseline correction

## 10 August, 2024; 22:58

- Rename the raw-data files to use a standard basename for each of the N = 48 bdf and N = 48 json files.
- Add Python script to check if the raw-data is complete and correct.

## 10 August, 2024; 15:00

- At around 1pm today, added all the raw EEG data files, using their original filenames.
- Pushed them to GitHub. Upload took around 2 hours.

## 9 June, 2024; 21:48

- Did a preliminary exploratory analysis of the behavioural data.
- With that, all looks fine thus far: as task difficulty decreases, accuracy increases and reaction time decreases, both for the dots and the blobs.
- There is quite a lot of intersubject variability in those effects.
- I also updated the R package to sort subjects by s1, s2 ... and not s1, s11, s12 ...

## 9 June, 2024; 19:43

- I have added the behavioural data files of all subjects thus far, which is 48 subjects.
- Data from 6 of these subjects already had been added.
- I have not added the EEG data files yet due to some trouble downloading them from OneDrive, which I did not persist with due to the fact that I don't need to do any EEG analysis immediately.
- I have updated the R utilities package, renamed purputils, to include a function to read in all behavioural data json files from a single directory in one command, amongst some other changes (see Git repo log).
- I have updated the top level readme to provide a bit more guidance of how to set things up and start doing analysis.
