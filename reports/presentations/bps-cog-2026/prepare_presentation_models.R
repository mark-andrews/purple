# Computes prediction-ready summaries from the three saved lme4 smoke-
# test models (M0, M1, M2; see analysis/rbf_lme4/smoke_test_lmer0.R,
# smoke_test_lmer1.R, smoke_test_lmer2.R, and the 27 August 2026 logbook
# entry) for the BPS presentation's modelling-results slides.
#
# Deliberately does not re-read the masked parquet. Everything needed to
# generate predictions is either a fixed constant already known from the
# original scripts (the basis-function centers and widths, data-
# independent by construction) or directly recoverable from the fitted
# model objects themselves (each model's own stored subject/trial group
# levels). So this only needs `lme4` and the three tmp/*.rds model
# files, no `arrow`, no devcontainer.
#
# Predictions are made on a clean, evenly spaced 300-point time grid, not
# the original ~1230-sample recording grid: nothing here needs the
# original training rows specifically, just the fixed basis functions
# evaluated at new time points crossed with the model's own known group
# levels, so a smooth synthetic grid gives cleaner curves for the slides
# than reconstructing the exact original rows would, and sidesteps
# needing to reproduce any of the original scripts' random subsetting
# (e.g. M2's 20-trials-per-subject sample) exactly.
#
# tmp/, not committed, not kept long-term, same as everything else this
# writes there; see the 27 August 2026 logbook entry.

library(tidyverse)
library(lme4)

# Basis functions, exactly as in the smoke_test_lmer*.R scripts.
# Epoch range (-200 to 1000ms) confirmed directly against M0's own
# stored model frame before relying on it here: max(b1) == 1 in that
# frame, i.e. the leftmost coarse centre's exact time value is present
# in the real training data, not just assumed from the preprocessing
# notes.
K_coarse <- 8
K_dense <- 8
dense_window <- c(0, 300)
epoch_range <- c(-200, 1000)

centers_coarse <- seq(epoch_range[1], epoch_range[2], length.out = K_coarse)
width_coarse <- diff(centers_coarse)[1]
centers_dense <- seq(dense_window[1], dense_window[2], length.out = K_dense)
width_dense <- diff(centers_dense)[1]
centers_fixed <- c(centers_coarse, centers_dense)
width_fixed <- c(rep(width_coarse, K_coarse), rep(width_dense, K_dense))

rbf_design_matrix <- function(x, centers, width) {
  mapply(function(ctr, w) exp(-0.5 * (x - ctr)^2 / w^2), centers, width)
}

time_grid <- seq(epoch_range[1], epoch_range[2], length.out = 300)
basis_grid <- rbf_design_matrix(time_grid, centers_fixed, width_fixed) |>
  as.data.frame() |>
  rename_with(~ str_c("b", seq_along(.))) |>
  as_tibble() |>
  mutate(time = time_grid, .before = 1)

# M0: subject variability, averaging over all trials -----------------------

M0 <- readRDS("tmp/smoke_test_lmer0_M0.rds")
m0_subjects <- levels(M0@flist$subject)

m0_newdata <- basis_grid |> cross_join(tibble(subject = m0_subjects))

m0_fitted <- m0_newdata |>
  mutate(
    fitted_subject = predict(M0, newdata = m0_newdata),
    fitted_population = predict(M0, newdata = m0_newdata, re.form = NA)
  ) |>
  select(time, subject, fitted_subject, fitted_population)

saveRDS(m0_fitted, "tmp/m0_fitted.rds")
cat(
  "Wrote tmp/m0_fitted.rds:", nrow(m0_fitted), "rows,",
  length(m0_subjects), "subjects\n"
)

# M1: trial variability, one subject (s47, whichever subject the model was
# actually fit on) -----------------------------------------------------

M1 <- readRDS("tmp/smoke_test_lmer1_M1.rds")
m1_trials <- levels(M1@flist$trial_id)

m1_newdata <- basis_grid |>
  cross_join(tibble(trial_id = factor(m1_trials, levels = m1_trials)))

m1_fitted <- m1_newdata |>
  mutate(
    fitted_trial = predict(M1, newdata = m1_newdata),
    fitted_population = predict(M1, newdata = m1_newdata, re.form = NA)
  ) |>
  select(time, trial_id, fitted_trial, fitted_population)

saveRDS(m1_fitted, "tmp/m1_fitted_s47.rds")
cat(
  "Wrote tmp/m1_fitted_s47.rds:", nrow(m1_fitted), "rows,",
  length(m1_trials), "trials\n"
)

# M2: subject and trial together, one illustrative subject ------------------
# s47 again, deliberately, not the subject smoke_test_lmer2.R's own
# script happened to draw at random (s40): M2 was fit on all 46
# subjects, any of them is a legitimate choice to display, and using the
# same subject as the EEG-only slides and M1 throughout this section of
# the talk makes for one consistent running example rather than a
# different, arbitrary subject on every slide.

M2 <- readRDS("tmp/smoke_test_lmer2_M2.rds")
m2_subject <- "s47"
m2_trial_levels <- levels(M2@flist$trial_id)
m2_subject_trials <- m2_trial_levels[
  str_starts(m2_trial_levels, str_c(m2_subject, "\\."))
]

m2_newdata <- basis_grid |>
  cross_join(
    tibble(trial_id = factor(m2_subject_trials, levels = m2_trial_levels))
  ) |>
  mutate(subject = factor(m2_subject, levels = levels(M2@flist$subject)))

# re.form naming exactly the subject random-effect term as it appears in
# the fitted model, same reason as smoke_test_lmer2.R's own diagnostics:
# lme4 needs to know which of the two crossed terms (subject, trial_id)
# to keep for a subject-only prediction.
subject_re_formula <- as.formula(str_c(
  "~ (", str_c(str_c("b", 1:K_coarse), collapse = " + "), " || subject)"
))

m2_fitted <- m2_newdata |>
  mutate(
    fitted_full = predict(M2, newdata = m2_newdata),
    fitted_subject = predict(
      M2, newdata = m2_newdata, re.form = subject_re_formula
    ),
    # Fixed effect only, no subject or trial deviation: the same value
    # for every row at a given time regardless of trial_id, included so
    # the "population fit" slide doesn't need a separate file.
    fitted_population = predict(M2, newdata = m2_newdata, re.form = NA)
  ) |>
  select(time, trial_id, fitted_full, fitted_subject, fitted_population)

saveRDS(m2_fitted, "tmp/m2_fitted_s47.rds")
cat(
  "Wrote tmp/m2_fitted_s47.rds:", nrow(m2_fitted), "rows,",
  length(m2_subject_trials), "trials\n"
)
