# Multilevel basis-function models for ERPs

This directory holds the Bayesian multilevel nonlinear regression of single-trial EEG waveforms, fitted in Stan via `cmdstanr`.
At one electrode, each trial is modelled as a population waveform, plus its subject's deviation from it, plus its own deviation from its subject's waveform, plus AR(p) noise.
Each waveform is a weighted sum of Gaussian radial basis functions, and the weights at each level have a penalised (ridge-plus-curvature) prior.
B4 adds effect curves over time for subject accuracy and for the trial's numerical ratio.

The complete mathematical specification is the first section of `models.qmd`.
The rest of that document is the reasoning behind the original design, and the specification lists where it is out of date.

This RBF model is being completed for the current phase and will then be succeeded by a Gaussian process version.
See the logbook.

## Files

`rbf_multilevel.stan` is the model.
One file covers B1 (subject-averaged waveforms, subject deviations), B2 (one subject's trials, trial deviations), B3 (all trials, both) and B4 (B3 plus predictors), selected by data flags.
In B3 and B4 the trial and subject deviations are integrated out analytically and the likelihood is computed from sufficient statistics, so the cost does not depend on the number of trials.
It also supports stimulus pairs as a random factor crossed with subjects (`items=1` in the driver), but that version does not yet sample well (see the logbook).

`fit_rbf_multilevel.R` fits one model at one electrode.
Its header lists the arguments.

`prepare_trials.R` decimates every usable trial at POz, Oz, Pz, PO7 and PO8 from 1024 to 128 Hz and caches them, with ratio, accuracy and trial position attached, in `tmp/trials_decimated.parquet`.
The fits read that file.

`rbf_common.R` holds shared functions (decimation, basis construction, prior scales, curve summaries).

`check_suffstat.R` checks the sufficient-statistics computation of the likelihood against a brute-force computation with an explicit covariance matrix, on a small random problem.
Run it after any change to `total_quad` or the marginal likelihood in the Stan file.

`check_recovery_b4.R` compares B4 fits with and without known effects added to the data (`addeff=0` and `addeff=2`), whose difference should reproduce the added effects.

`ppc_b4.R` is a posterior predictive check of B4 against the exploratory statistics (easy-minus-hard difference, within-subject ratio slope, accuracy-half difference, accuracy slope).
It was written before the `nofirst` and `prevratio` options and does not yet handle them.

`models.qmd` and `references.bib` are the documentation.

## Running the analysis

Everything runs from the repository root, inside the devcontainer image (`localhost/purple-interactive`), which has every package needed, including CmdStan.
All output goes to the git-ignored `tmp/`.
The input is `data/main/merged_eeg_behaviour_data_masked.parquet`.
From the host, a script is run in the image with

    podman run --rm --user root -v "$PWD":/w -w /w localhost/purple-interactive Rscript <script> <arguments>

1. Cache the trials, about 30 s, with `analysis/rbf_stan/prepare_trials.R`.

2. The basis width multipliers were estimated once at each electrode with B1 (`model=b1 kd=31 dw=600`) and are fixed from then on.
   The values are in the table in `models.qmd`, and are, as coarse and dense, POz 0.624 and 1.03, Oz 0.649 and 0.903, Pz 0.635 and 1.006, PO7 0.684 and 0.723, PO8 0.644 and 0.969.

3. The current model is B4 with the first trial of each block excluded, the previous trial's ratio as a covariate, and fixed effect-curve scales, at POz for example

        analysis/rbf_stan/fit_rbf_multilevel.R model=b4 ntrial=0 electrode=POz fc=0.624 fd=1.03 kd=31 dw=600 ks=all adapt=0.9 metric=dense_e fixeff=1 nofirst=1 prevratio=1

   It takes 4 to 5 hours per electrode, and the five can run in parallel on 24 cores.
   R reads a script as it executes it, so run a copy of the driver if it may be edited while a fit is in progress.

Check the sampler diagnostics before looking at estimates, every time.
The fit prints divergences, tree-depth hits, the largest R-hat and the smallest bulk ESS over every parameter.

## Not yet done

Stimulus pairs as a random factor in a version that samples well, an accuracy by ratio interaction, choice of AR order (AR(2) throughout so far), and modelling electrodes jointly.
