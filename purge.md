# Purged files

A record of files deliberately deleted from this repository, and why.
Deleted files remain in the Git history, but nothing in the working tree points to them, so this file says what was removed and where to look.
Entries are in reverse chronological order, most recent first.
To recover a file, check it out from the commit before its deletion, for example `git checkout <commit>^ -- <path>`.

# 22 September, 2026, fourth pass

The superseded first generation of the Stan single-trial work in `analysis/multilevel_rbf_stan/`.
The last commit containing these files is `9dda89e`.

`rbf_arp.stan` and its driver `fit_rbf_arp.R`, a single-trial RBF regression with an AR(p) residual, compared across HMC, Pathfinder, Laplace, ADVI and optimisation.
Superseded by B0, `rbf_b0_single_trial.stan`, which keeps the same exact AR likelihood and adds the ridge-plus-curvature prior, the estimated width multiplier and anti-aliased decimation.
The earlier model's flat `prior_sd_w = 100` was the defect B0 was written to fix.

`erp-noise-model.qmd`, the document written for that model, and `technical-appendix.qmd`.
Both were merged into `models.qmd`, which is now the only document.
The appendix became its technical appendix unchanged.
From the noise-model document, the parts not already covered were kept, namely the case against a squared exponential kernel, the sieve argument for AR(p), and the three criteria with the single-trial evidence.
Its sections on decimation and the Stan implementation were dropped, since the appendix and B0 supersede them.

`rbf_correlated_noise.R` was not deleted but renamed `fit_b0_gls.R`, as B0's frequentist counterpart.

# 22 September, 2026, third pass

Two more interactive scripts from August 2026.
The last commit containing them is `6c87136`.

`analysis/aug26_1.R`, grand-average and per-subject ERP plots made on 26 August while preparing the BPS presentation.
The presentation does not use its output.
`prepare_presentation_data.R` in `reports/presentations/bps-cog-2026/` reproduces its averaging approach, and some comments there and in `slides.qmd` still name it.

`analysis/check_subject_channel_drift.R`, a one-off check for late-epoch drift in subject-average ERPs at POz, Oz and Pz.
Its findings are recorded in the 26 August 2026 logbook entry, including the follow-up that remains undone, a visual check of subjects s34, s19 and s38.

# 22 September, 2026, second pass

One more file, deleted after the first pass below.
The last commit containing it is `2c1b229`.

`analysis/multilevel_rbf/m1_3_subject_trial_single_electrode.stan`, a single-electrode Stan model with subject and trial random effects, written for the BPS presentation and never fitted.
Model B3 in `analysis/multilevel_rbf_stan/rbf_multilevel.stan` covers the same structure.

# 22 September, 2026

Throwaway files from dead ends, abandoned analyses, and one-off scratch work.
None of them feeds the pipeline, the current analysis, or the BPS presentation.
The last commit containing all of them is `b06fb3d`.

## Pilot data

`data/pilots/pilot_26July2023/EM_Pilot_07_26_2023_14_53_26_results.csv`, and with it the whole `data/pilots/` directory.

Processed data from the July 2023 pilot, which should never have been committed.
No data are committed to this repository.
The raw pilot recordings are kept, untracked, in the sister repository `purple-raw-data`, in case they are ever needed again.
No planned analysis uses them.
`.gitignore` now excludes all CSV files under `data/`, as it already did for parquet files.

## Early scripts that no longer run

`analysis/get_unprocessed_erp.R` and `analysis/compare_behav_and_eeginfo.R`.

The first, from September 2023, plotted ERPs from `data/main/epochs_8_sept_2024.feather`, a file that no longer exists, and predates the whole current preprocessing pipeline.
The second was a one-off check that the EEG trigger records matched the PsychoPy records for the July 2023 pilot.
Its input data are no longer in this repository.

## Radial basis function and Gaussian process examples

`analysis/rbf_example_1.R`, `rbf_example_2.R`, `rbf_example_3.R`, `rbf_example4.R`, `rbf_example_5.R`, and the Stan models `rbf_example_1.stan`, `rbf_example_2.stan`, `rbf_example_2a.stan`, `rbf_example_3.stan`, `rbf_example_4.stan`, `rbf_example_5.stan`.
The compiled Stan binaries `analysis/rbf_example_1`, `rbf_example_2`, `rbf_example_2a`, about 8.6MB, which should never have been committed.
`analysis/s13_b2_t14.csv`, a single trial of data used as scratch input by `rbf_example_2.R` and `rbf_example_3.R`.

All from the October 2024 single-trial RBF and GP experiments, abandoned as too slow (see the 17 October 2024 logbook entry).
The commit that added them was titled "Add lots of crufty scripts to do rbfs and gps".
`notes/rbf_to_gp_proof.md`, from the same period, is kept because the RBF and GP equivalence it sets out is still discussed in `analysis/multilevel_rbf_stan/README.md`.

## Interactive scratch scripts, August 2026

`analysis/aug26_0.R`, a first pass at grand-average ERP plots, done more thoroughly in `analysis/aug26_1.R`.
`analysis/aug27_1.R`, a check of spline reconstruction of a single trial after downsampling.
`analysis/check_erp_plots.R`, early grand-average and channel-variance screening, described in the logbook at the time as hacky interactive scratch code, and superseded by `aug26_1.R` and `scripts/mask_anomalous_trials.R`.

## Unfitted M0-M7 Stan ladder

`analysis/multilevel_rbf/m0_pooled.stan`, `m1_subject.stan`, `m2_electrode.stan`, `m3_trial.stan`, `m4_subject_electrode.stan`, `m5_subject_electrode_trial.stan`, `m6_predictors_pooled.stan`, `m7_full.stan`, and their specification `model_specification.qmd`.

Written on 22 August 2026 as a ladder of increasingly complex multilevel RBF models, never fitted.
Superseded by `analysis/multilevel_rbf_stan/`.
The `lme4` smoke tests and the single-electrode Stan model in the same directory are kept, and its `readme.md` was rewritten to describe only them.
