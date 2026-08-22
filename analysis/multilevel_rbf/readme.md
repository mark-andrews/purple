# Multilevel RBF model ladder

This directory holds a family of Stan models, from a single pooled radial basis function (RBF) regression up to the full multilevel model with stimulus covariates.
They are not run yet.
They exist to fix the model structure and the data conventions before any fitting is attempted, since the full model may be slow and the dataset is large.

All models share the same basis function setup.
Centers and width are fixed and passed in as data, not estimated.
The design matrix `Phi` is built once in `transformed data` from `time`, `centers`, and `width`.
Weights on the basis functions are the only thing that varies across models.

The ladder, in order of increasing complexity:

- `m0_pooled.stan`: one global weight vector, no grouping, no covariates.
- `m1_subject.stan`: weights vary by subject only.
- `m2_electrode.stan`: weights vary by electrode only.
- `m3_trial.stan`: weights vary by trial only.
- `m4_subject_electrode.stan`: weights vary by subject and electrode, crossed, additive.
- `m5_subject_electrode_trial.stan`: weights vary by subject, electrode, and trial, all crossed, additive. No covariates.
- `m6_predictors_pooled.stan`: no random variation, but the population-level weight vector is a linear function of numerosity and ratio.
- `m7_full.stan`: M5 and M6 combined. This is the target model for the abstract's primary analysis.

Two conventions to note when preparing data for any of these:

`trial` in M3, M5, and M7 is expected to be a globally unique trial id, not a within-subject trial number.
Trial and electrode are crossed within a subject (every trial appears at every electrode), and trial is specific to a subject, so giving each subject's trials their own unique ids at data-prep time keeps the indexing flat and avoids an explicit nesting statement in Stan.

`numerosity` and `ratio` in M6 and M7 are expected to already be centered/standardized before being passed in, so the `g_numerosity` and `g_ratio` priors are on a sensible scale.

Electrodes are treated as an ordinary unstructured grouping factor throughout: no spatial covariance between electrodes is modelled.
Density is not included as a covariate, since nothing in this repository currently maps a stimulus uid to array density.

None of these have been fit yet.
The non-centered parameterization (`tau * z` rather than a direct hierarchical prior) is used throughout in anticipation of needing it for sampling efficiency once real data is used, but no timing or feasibility claims should be read into that choice yet.
