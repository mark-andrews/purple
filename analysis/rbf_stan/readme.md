# Multilevel basis-function models for single-trial ERPs

This directory holds the Bayesian multilevel nonlinear regression of single-trial EEG waveforms, fitted in Stan via `cmdstanr`.
It replaces the `lme4` smoke tests in `analysis/rbf_lme4/`, which were a quick approximation of the same models.
None of the multilevel models has yet been fitted to real data.

## The approach in brief

The waveform at one electrode is modelled as a weighted sum of fixed Gaussian bumps in time,

    y(t) = alpha + sum_k w_k * phi_k(t) + noise

where each `phi_k` is a Gaussian centred at latency `mu_k` with width `ell_k`.
Because the centres and widths are fixed, the model is linear in the weights `w_k`, like polynomial or spline regression.
Giving every weight a subject deviation and a trial deviation,

    w_k(subject, trial) = w_k + u_{k,subject} + v_{k,trial}

gives each subject and each trial its own random function of time, a whole waveform deviating from the population waveform rather than an amplitude offset.
Stimulus covariates enter the same way, as a `K`-vector of coefficients, so a change in numerical ratio can change the waveform at one latency without changing it elsewhere.

Two things make this harder than an ordinary mixed model.
The residual is not iid, because the data are band-pass filtered at 1 to 30 Hz and ongoing EEG is rhythmic, so it is modelled as a stationary AR(p) process, AR(2) by default.
Treating the residual as iid understates the uncertainty on the fitted waveform by roughly half.
And overlapping Gaussian bumps are collinear, so the weights get a ridge-plus-curvature prior with estimated scales, which is a penalised spline penalty written as a prior.
The effective smoothness of the fitted curve is then set by the data, not by the number of basis functions.

`models.qmd` gives the full specification and the reasoning for each choice.

## The four models

Each model adds one thing to the one before, and each has a frequentist counterpart to be checked against.

| Model | Data | Random effects | Frequentist counterpart |
|---|---|---|---|
| B0 | one subject, one trial | none | `fit_b0_gls.R` |
| B1 | all subjects, trials averaged | subject | `analysis/rbf_lme4/smoke_test_lmer0.R` |
| B2 | one subject, all trials | trial | `analysis/rbf_lme4/smoke_test_lmer1.R` |
| B3 | all subjects, a subset of trials | subject and trial | `analysis/rbf_lme4/smoke_test_lmer2.R` |

All four are at a single electrode, POz by default.
Stimulus and subject covariates would be B4, the first model that answers a scientific question rather than checking machinery.
B4 is not written yet.

## Files

`models.qmd` is the model specification, B0 to B3, with a technical appendix covering decimation, the prior as a precision matrix, the AR parameterisation, scaling to the full trial count, and the argument and single-trial evidence for the AR noise model.
It is the only document, and the Stan files are commented on the assumption that it has been read.
`references.bib` holds its references.

`rbf_b0_single_trial.stan` is B0.
`rbf_multilevel.stan` is B1, B2 and B3 in one file, selected by the data flags `use_subject` and `use_trial`.

`rbf_common.R` holds what must be identical across the models, namely decimation, basis construction, prior scales, the prior predictive check, and functions for summarising fitted curves.
The drivers `source()` it.

`extract_b0_trial.R` writes the single trial that B0 is fitted to, `tmp/b0_trial_POz.csv`.
It is subject s17, block 1, trial 53, the same trial used in the earlier noise-model work.
`fit_b0_gls.R` fits B0's mean model with iid, AR(1) and AR(2) residuals using `nlme::gls`.
`fit_b0.R` is the driver for B0.
`fit_multilevel.R` is the driver for B1, B2 and B3.

## Requirements

Every script is run from the repository root, and all output goes to `tmp/`.

The R packages needed are `tidyverse`, `cmdstanr` with a working CmdStan installation, `posterior`, `loo`, `signal` for the anti-aliased decimation, `nlme` for the gls counterpart, and `arrow` for the two scripts that read the parquet file, `extract_b0_trial.R` and `fit_multilevel.R`.
The Podman devcontainer has all of these, with CmdStan built into `/opt/cmdstan` and found through the `CMDSTAN` environment variable.

The input is `data/main/merged_eeg_behaviour_data_masked.parquet`, written by `scripts/mask_anomalous_trials.R`, which is not yet part of the Snakemake pipeline.

## Procedure

Work through these in order, and do not move on until the current model is understood.
Check sampler diagnostics before looking at estimates, every time.
At every model, run Pathfinder before HMC, since it costs seconds, catches gross specification errors, and supplies good initial values.

1. Read `models.qmd`.
2. Run `Rscript analysis/rbf_stan/extract_b0_trial.R` to write `tmp/b0_trial_POz.csv`.
This takes a few seconds.
3. Run `fit_b0_gls.R`.
It gives the frequentist baseline for B0, AIC across noise models, how much AR(2) inflates the standard errors, and the frequency of the implied residual rhythm, which should be near 11 Hz at POz.
4. Work through `fit_b0.R` interactively.
Look at the prior predictive check first, before fitting anything.
If curves drawn from the prior alone run to hundreds of microvolts, the prior scales are wrong.
The script then fits B0 at `p = 0`, 2 and 4, and lists what to check.
The check that matters most is whether the fitted amplitude at 240 ms is stable across AR order.
5. Work through `fit_multilevel.R` interactively, one section at a time, B1, then B2, then B3.
Compare each population fit with the corresponding `lme4` smoke test.
B1 and B2 take minutes.
B3 takes hours under HMC, so iterate on it with Pathfinder and Laplace, and compare both with HMC on the fitted curve before relying on them.
6. B4, adding stimulus covariates, comes once B3 is understood.

Summaries of each fit are saved to `tmp/`.

## Two standing rules

Report functions of the fitted curve, never individual weights.
The basis functions overlap heavily, so the individual weights are not separately interpretable and their marginals are unstable.
Report things like the fitted amplitude at 240 ms, the height of the fitted P2p peak, or the difference between two fitted curves at a latency.

The basis functions are not ERP components.
There is no expected correspondence between any one basis function and P1, N1 or P2p.
The components are properties of the fitted curve and emerge from the sum.

## Known issues

B0 as written does not yet work.
It was first run on real data, the trial above, on 22 September 2026, and the fits at every AR order were unusable.
The ridge and curvature scales collapsed to around 1e-6, which shrinks every weight to zero, so the fitted curve is a flat line at the intercept and the residual absorbs the whole waveform.
The chains did not agree, with R-hat between 1.7 and 3.3 and bulk ESS around 5, and at AR(2) 92% of transitions hit the maximum tree depth.
This happens even with iid noise, while the unpenalised `fit_b0_gls.R` finds clear structure on the same trial, so the likeliest cause is the sampler getting stuck in the collapsed region of the prior, the funnel between the weights and their estimated scales, rather than an absence of signal.
Non-centring the weights, or putting a prior on the scales that keeps them away from zero, are the obvious first things to try.
B1 to B3 use the same prior on the population weights, so B0 needs fixing before moving up the ladder.
Each HMC fit took about two and a half minutes, not the under a minute that `fit_b0.R` expects.

The single-trial numbers quoted in `models.qmd` were obtained with plain subsampling rather than the anti-aliased decimation now used.
Examples are the residual autocorrelation of 0.77 at lag 1 and −0.46 at lag 6, and the AIC and standard-error tables in the appendix.
On the same trial, anti-aliased decimation gives 0.76 at lag 1 but −0.30 at lag 6.
The qualitative conclusions do not depend on this, but the numbers should be updated once B0 has been fitted.

The trial-level spread in the `lme4` fits was largest at the two edges of the epoch, which looks like a basis boundary artefact.
`fit_multilevel.R` notes how to check whether the curvature prior has reduced it.
