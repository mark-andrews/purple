# 25 August, 2026; 17:07

Ran sanity checks on `data/main/merged_eeg_behaviour_data.parquet`, beyond what AutoReject already does during preprocessing.
Per-subject, per-channel descriptive statistics (variance, MAD, skewness, kurtosis) showed that AutoReject's trial-level rejection was not catching everything, a small number of subjects and channels still contained implausible voltage excursions, into the hundreds of microvolts, concentrated in specific subject-channel combinations rather than spread evenly across the sample.
Two subjects stood out in particular, one (s13) with spread elevated fairly uniformly across nearly all 64 channels, consistent with a session that was noisier throughout, the other (s23) with a close-to-normal spread but far fatter tails on about 50 of its 64 channels, consistent with more frequent moderate excursions rather than a few extreme ones.
Neither was explained by AutoReject's own trial-drop rate, which was unremarkable for both.
Waveform plots of every trial for every channel, across all 47 subjects, confirmed the pattern by eye: not every channel or every subject is affected, both isolated bad trials and whole-channel problems for one subject occur, and the affected electrodes recur non-randomly (central sites, the posterior/inferior edge of the montage, frontopolar sites) and are often physically clustered within a subject, more consistent with session-specific contact problems than with a channel-labelling bug.

Decided AutoReject needed a second pass after it, at the level of individual channel-trial combinations rather than whole subjects or channels.
For each subject, channel and trial, computed the "voltage IPR", the range containing the central 99% of that trial's amplitude, a robust measure of a single trial's spread.
A channel on a trial is flagged if its IPR is more than 5 robust (MAD-based) standard deviations above that channel's own median IPR, computed per channel since channels genuinely differ in typical amplitude and a pooled threshold would just flag naturally wider channels rather than genuinely anomalous trials.
The threshold of 5, rather than the conventional 3.5, was chosen because 3.5 removed close to 5% of all data with no visible benefit over 5 on the cases checked, and 8 was rejected on the assumption that the nonlinear regression's residual error model won't itself be robust to occasional extreme trials, worth confirming once that model is specified.

The rule, and a `plot_subject()` function to verify what it does to any subject's waveforms with or without the threshold applied, are in `analysis/flag_anomalous_trials.R`, the definitive record of this piece of work in place of the exploratory scripts and plots that led to it.
Not yet applied to the data.
The next step is turning the flags into a cleaned dataset, setting specific (subject, block, trial, channel) cells to `NA` in a new version of the merged parquet file rather than dropping whole rows, expected to need care around memory given that a naive `pivot_longer` over the full merged table earlier in this exercise used over 90GB of RAM and crashed the machine.

# 23 August, 2026; 23:11

Added three background notes in `notes/`, written before starting the actual sanity checks on the merged EEG data, since I have no EEG background myself and needed the groundwork written down first.

- `notes/electrode-labels.md`: plain-language explanation of the 64 channel labels (`Fp1`, `AFz`, and so on).
Covers the difference between the physical connector labels (`A1`-`A32`, `B1`-`B32`) and the anatomical 10-20/10-10 labels actually used in the merged data, the naming convention (region letters front to back, odd/even/`z` for left/right/midline), and what the main regions (frontal, central, parietal, occipital, temporal) correspond to on the scalp.
Confirmed the coordinates in `analysis/Cap_coords_all.xls` (sheet `64-chan`) and the renaming done in `pyutils/eegutils.py` both follow MNE's standard `biosemi64` montage, in the same channel order, so the mapping used in the code is a standard, off-the-shelf convention, not something bespoke to this study.
- `notes/preprocessing-pipeline.qmd`: a Quarto methods-style writeup of the full pipeline, numbered step by step, from the raw BDF file through channel renaming, downsampling, ICA/ICLabel artefact removal, filtering, trigger decoding, trial extraction, epoching with baseline correction, AutoReject, participant concatenation, and the final merge with behavioural data.
Reconstructed by reading the Snakefile, `scripts/preprocess_eeg.py`, `pyutils/eegutils.py`, `scripts/combine_preprocessed_eeg.py`, and `scripts/merge_eeg_behaviour_data.R`.
Notes where the Snakefile's actual parameters (1-30 Hz filter, `fix_bad = yes`) differ from the Python script's own coded defaults, since it's the Snakefile's values that describe what was actually run.
- `notes/sanity-checks.md`: what to check in the merged data before trusting it, and what it should look like if preprocessing was done correctly.
Separates two distinct failure modes that need different checks: a code-level channel-labelling bug, which would corrupt every participant identically and is caught by a group-averaged topography check, versus a session-specific wiring error, which shows up as one participant looking anomalous relative to the rest.
Gives concrete checks: amplitude scale, baseline-near-zero, average-reference-sums-to-zero, the expected frontal eye-blink signature, the expected posterior visual response in the first 100-250 ms post-stimulus, left-right symmetry, and per-channel variance screening.

Next step, to be done tomorrow morning (24 August, 2026): actually run the sanity checks described in `notes/sanity-checks.md` against `data/main/merged_eeg_behaviour_data.parquet`.
`analysis/check_erp_plots.R` (a hacky, interactive script, not part of the pipeline) already has a first pass at some of this, grand-average ERP traces per channel and a per-trial per-channel variance screen, and was modified again tonight.
Not committed as part of this entry, still ropey, interactive scratch code.
Not yet decided whether to keep extending that script tomorrow or start fresh; either is fine.

# 22 August, 2026; 22:07

Removed the host renv/venv bootstrap now that the container covers reproducibility.
Deleted `.Renviron`, `.Rprofile`, `renv/`, `renv.lock` (renv, superseded by the container for the pipeline), `arrow_install.R` (a scratch file of failed host attempts at getting R's `arrow` package to build, the exact problem the container now solves), and `install.sh`, `.envrc`, `requirements.txt` (the host Python venv bootstrap and its direnv auto-activation, confirmed no longer wanted, not just for the pipeline but for interactive work too).
`readme.md` never referenced any of these, so no changes needed there.

# 22 August, 2026; 21:08

Fixed the `snakemake -j4` failure from earlier today (host venv broken by the Arch Python 3.13 to 3.14 upgrade, leaving `mne_icalabel`'s ICLabel step without a working backend).
Rather than patch the venv again, containerised the whole pipeline with Apptainer instead of repairing host Python/R state.
Decisions: Apptainer, not Docker.
`onnxruntime`, not `torch`, as the ICLabel backend, since nothing else in the repo uses either.
No `renv` for R, the image itself is the reproducibility mechanism, packages installed straight from CRAN at build time.
Full pipeline ran to completion under the container: `data/main/merged_eeg_behaviour_data.parquet` now exists (23,124,000 rows, 85 columns).
Renamed from `.feather` to `.parquet`: the file is written with `arrow::write_parquet()`, not `arrow::write_feather()`, so `.feather` was always the wrong extension.
Updated the Snakefile's output path and `analysis/check_erp_plots.R`'s (commented-out) read call to match.

Two real bugs turned up along the way, both fixed:

- `fs`, `systemfonts`, `ragg` and friends need `libuv1-dev`, `libfontconfig-dev`, `libfreetype-dev`, `libharfbuzz-dev`, `libfribidi-dev`, `libpng-dev`, `libtiff-dev`, `libjpeg-dev` to build from source on Debian trixie, not just the curl/ssl/xml dev packages that cover `arrow`.
- `process_behaviour_data` failed deterministically with "evaluation nested too deeply: infinite recursion" whenever Snakemake ran it under Apptainer.
Cause: Snakemake's apptainer integration passes `--home <cwd>`, so `$HOME` equals the project directory.
The repo's own `.Rprofile` sources `renv/activate.R`, and renv 1.1.4's activate script re-sources itself repeatedly when `$HOME` and the project directory coincide, blowing R's expression-nesting limit.
Setting `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` was not sufficient, it stops renv from switching library paths but not the repeated re-sourcing.
Fixed by setting `R_PROFILE_USER=/dev/null` in the container image, so `.Rprofile` is never sourced by R processes running inside it at all.
This is specific to Apptainer's `--home` behaviour and would not show up running R normally on the host.

`container/purple.def` has the full build recipe.
`*.sif` is gitignored, rebuild locally with `apptainer build --fakeroot container/purple.sif container/purple.def`.
`readme.md` updated with build/run instructions.

Priority now is completing as much as possible of the analysis described in the abstract below for the presentation at the BPS Cognitive Section Annual Conference, which is held in Liverpool from 26 to 28 August, 2026.

Time, date, location: Oral presentation at 11:10am in Room i3B114 in Liverpool Hope University, Day 2, 27 August 2026.

Title: Identifying the Neural Signature of the Approximate Number System via Multilevel Nonlinear Regression of Single-Trial EEG
Author: Dr Jessica Ann Diaz (Birmingham City University), & Dr Mark Andrews (Nottingham Trent University)

Abstract: The Approximate Number System (ANS) underlies our ability to estimate numerical quantities without counting. Performance on the ANS task correlates with mathematical ability across the lifespan, making its neural basis relevant to conditions such as dyscalculia. We present data from approximately 100 participants, comprising 50 children aged 4 to 12 years and 50 adults, who completed a 64-channel EEG experiment. Each participant performed a standard ANS task, judging which of two dot arrays was more numerous, and a control task requiring size judgments of blob pairs, matched in visual complexity but without  numerosity demands. Our primary analysis applies a novel multilevel nonlinear regression framework to the single-trial ERP data. We model the voltage waveform at each electrode as a smooth nonlinear function of time, represented via basis function expansion. This function is treated as a random quantity that varies probabilistically across trials and participants, yielding random-function effects that generalise random slopes and intercepts in linear mixed models to the nonlinear domain. Stimulus covariates, including dot numerosity, numerosity ratio, and array density, enter as predictors of the population-level mean function, allowing the model to characterise how the ERP varies systematically with task difficulty and stimulus properties. Comparing estimated waveform functions between the numerosity and control conditions aims to isolate those ERP components that constitute the neural signature of ANS processing specifically. Results will assess how well this method identifies the neural signature of ANS processing, how it develops from childhood to adulthood, and what this implies for conditions such as dyscalculia.

# 17 October, 2024; 07:49

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

# 15 October, 2024; 18:11

Add a new preprocessing step using autoreject.

# 21 September, 2024; 21:55

Remove an ThB_03_21_2024_12_10_57.bdf because this was a copy of ThA on that same date.
The original version of ThB is incomplete or not saved properly and it was incorrectly assumed that the ThA on that date was the correct version.
See commit 9498264537196746c2c3fc3bccdf50fb57b552e4 (main) for more details.

# 20 September, 2024; 22:25

- Change the participant id inside the json file of MB*11_13_2023_13_56_39 to \_MB* from *WB*

# 19 September, 2024; 20:13

- Two EEG sessions were recorded at 2048HZ, not 1024HZ. These are downsampled to 1024hz. The sessions can be identified by their file size.
  - raw-data/main/WA_11_22_2023_13_54_06.bdf
  - raw-data/main/MA_11_20_2023_11_46_10.bdf

# 11 September, 2023; 08:08

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

# 10 August, 2024; 22:58

- Rename the raw-data files to use a standard basename for each of the N = 48 bdf and N = 48 json files.
- Add Python script to check if the raw-data is complete and correct.

# 10 August, 2024; 15:00

- At around 1pm today, added all the raw EEG data files, using their original filenames.
- Pushed them to GitHub. Upload took around 2 hours.

# 9 June, 2024; 21:48

- Did a preliminary exploratory analysis of the behavioural data.
- With that, all looks fine thus far: as task difficulty decreases, accuracy increases and reaction time decreases, both for the dots and the blobs.
- There is quite a lot of intersubject variability in those effects.
- I also updated the R package to sort subjects by s1, s2 ... and not s1, s11, s12 ...

# 9 June, 2024; 19:43

- I have added the behavioural data files of all subjects thus far, which is 48 subjects.
- Data from 6 of these subjects already had been added.
- I have not added the EEG data files yet due to some trouble downloading them from OneDrive, which I did not persist with due to the fact that I don't need to do any EEG analysis immediately.
- I have updated the R utilities package, renamed purputils, to include a function to read in all behavioural data json files from a single directory in one command, amongst some other changes (see Git repo log).
- I have updated the top level readme to provide a bit more guidance of how to set things up and start doing analysis.
