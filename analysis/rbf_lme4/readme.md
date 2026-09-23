# lme4 smoke tests for the multilevel RBF model

This directory holds the `lme4` smoke tests run on 27 August 2026 ahead of the BPS conference presentation.
They were quick, approximate attempts at multilevel nonlinear regression, fitted by REML rather than in Stan.
See the 27 August 2026 logbook entry for what each test found.

With RBF centers and width fixed rather than estimated, the basis-function expansion is linear in its weights.
The multilevel version is therefore an ordinary linear mixed model with the basis-function values as uncorrelated random-slope terms, `(b1 + ... + bK || subject)`.

- `smoke_test_lmer0.R`: subject variability only, trials pre-averaged away, all 47 subjects.
- `smoke_test_lmer1.R`: trial variability only, one subject, full trial-level resolution.
- `smoke_test_lmer2.R`: subject and trial together, all subjects, 20 trials per subject.

`trial` must be a globally unique trial id across subjects, not a within-subject trial number.

These scripts are expected to become obsolete once the Stan models in `analysis/rbf_stan/` are working.
That directory's B0-B3 comparison table refers to them directly, so they stay until then.
The earlier M0-M7 Stan ladder and the single-electrode Stan model were deleted on 22 September 2026, see `purge.md`.
