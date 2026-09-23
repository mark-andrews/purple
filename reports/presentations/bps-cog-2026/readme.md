# BPS Cognitive Section 2026 presentation

Slides for the talk given at the BPS Cognitive Section Annual Conference, Liverpool Hope University, 27 August 2026.
The rendered slides are at https://mark-andrews.github.io/bps-cog-2026/slides.html.

## Reproducibility

This deck was put together in haste on 26 and 27 August 2026 and is not fully reproducible as it stands.
The slides using the EEG data and the fitted models read `.rds` files from `tmp/` at the repository root.
That directory is gitignored and was never meant to last, and the files are gone.
Rendering the deck now still works, but those slides show a placeholder saying which file is missing.
The affected slides are "Grand-Average ERPs by Electrode", "Parieto-Occipital Electrodes", "Inter-Trial Variability, One Participant", the three "Multilevel Model" slides, and "Fitted Population Waveform: P1, N1, P2p".
The behavioural slides read `data/main/combined_behaviour_data.csv` directly and render correctly.

The chain of scripts that produced those files is all in the repository, and it looks recoverable in principle.
All the relevant code was committed between 03:37 and 04:12 on 27 August, hours before the talk, and has not changed since except for file paths.
The three model-fitting scripts set a random seed and save their fitted models, so re-running them should reproduce the same data subsets.
There are several reasons not to take that for granted, and they are listed after the steps.

## Steps to regenerate the missing files

All paths below are relative to the repository root, and every R script must be run from there.
Steps 3 and 4 read the parquet file with `arrow`, so they need the devcontainer described in the top-level `readme.md`.

1. Regenerate `data/main/merged_eeg_behaviour_data.parquet` and `data/main/combined_behaviour_data.csv` with the Snakemake pipeline.
The raw data have moved to the sister repository `purple-raw-data`, but `snakefile` still reads from `raw-data/main`, so either `INPUT_DIR` or a symlink needs sorting out first.
2. Run `Rscript scripts/mask_anomalous_trials.R` to write `data/main/merged_eeg_behaviour_data_masked.parquet`.
This step is not yet part of the Snakemake pipeline and has to be run by hand.
3. Run `mkdir -p tmp`, then `Rscript reports/presentations/bps-cog-2026/prepare_presentation_data.R`.
This writes `tmp/grand_average_erp.rds`, `tmp/subject_average_erp_posterior.rds`, and `tmp/trial_erp_posterior_s47.rds`.
4. Run `analysis/rbf_lme4/smoke_test_lmer0.R`, `smoke_test_lmer1.R`, and `smoke_test_lmer2.R`, all with `Rscript`.
These fit the three `lme4` models, M0, M1, and M2, at electrode POz, and save them as `tmp/smoke_test_lmer0_M0.rds`, `tmp/smoke_test_lmer1_M1.rds`, and `tmp/smoke_test_lmer2_M2.rds`.
On 27 August M0 took about 4 minutes, M1 about 12, and M2 about 71.
5. Run `Rscript reports/presentations/bps-cog-2026/prepare_presentation_models.R`.
This computes predictions from the three models and writes `tmp/m0_fitted.rds`, `tmp/m1_fitted_s47.rds`, and `tmp/m2_fitted_s47.rds`.
It needs `lme4` but not `arrow`.
6. From this directory, run `quarto render slides.qmd`, which writes `docs/slides.html`.

## Why the result may differ from the talk

The logbook for 27 August records that the lines saving M0 and M1 were added after those models had been fitted.
Whether they were re-run with exactly the committed code before the slides were made is not recorded.

`prepare_presentation_data.R` and `prepare_presentation_models.R` hard-code subject s47 as the running example.
The comments say s47 is the subject that `smoke_test_lmer1.R` drew at random for M1.
If a re-run of that script draws a different subject, the M1 slide will show a different participant from the other slides.
That is the most direct check that a re-run has reproduced the original.

The seeded draws depend on the exact rows and row order of the masked parquet file, so any change upstream, such as a package update altering preprocessing, could change which subject and which trials are drawn.
The model estimates themselves could also move slightly with different `lme4` versions.

## Files

`slides.qmd` is the deck, with `theme.scss`, `references.bib`, and `figs/dots_example.png`.
`prepare_presentation_data.R` and `prepare_presentation_models.R` compute the small summaries the EEG slides read, as described above.

A more careful and reproducible version of this analysis is planned for a later presentation, and this note should point to it once it exists.
