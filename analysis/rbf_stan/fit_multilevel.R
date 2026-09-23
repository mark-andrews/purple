# B1, B2, B3. The multilevel ladder, all three from one Stan file.
#
#   B1  subject variability only, trials pre-averaged away
#   B2  trial variability only, one subject
#   B3  both at once
#
# Deliberately the same decomposition as the lme4 smoke tests, so each fit
# has something to be compared against rather than only inspected. Run them
# in order and do not move on until the current one is understood.
#
# Must be run from the repository root, where the masked parquet is
# readable (the devcontainer).

library(tidyverse)
library(cmdstanr)
library(posterior)

source("analysis/rbf_stan/rbf_common.R")

set.seed(10101)
electrode <- "POz"

model <- cmdstan_model("analysis/rbf_stan/rbf_multilevel.stan")

# Data ---------------------------------------------------------------------

eeg_df <- arrow::read_parquet(
  "data/main/merged_eeg_behaviour_data_masked.parquet"
) |>
  filter(type == "dots") |>
  select(subject, block, trials, time, all_of(electrode)) |>
  drop_na() |>
  rename(voltage = all_of(electrode)) |>
  mutate(trial_id = interaction(subject, block, trials, drop = TRUE))

# The basis is built from the full epoch range before any subsetting, so it
# is the same basis regardless of which subjects or trials a given model
# sees. This matters for comparing across the ladder.
epoch_range <- range(eeg_df$time)
basis <- make_basis(epoch_range, K_coarse = 8L, K_dense = 8L,
                    dense_window = c(0, 300))

# Shared data-list builder -------------------------------------------------

# `curves_df` must have one row per timepoint per curve, with columns
# curve_id, subject, time, voltage, already decimated, and every curve on
# the same time grid.
multilevel_data <- function(curves_df, p, use_subject, use_trial, priors) {
  curves_df <- curves_df |> arrange(curve_id, time)

  time_grid <- curves_df |> filter(curve_id == first(curve_id)) |> pull(time)
  T <- length(time_grid)

  wide <- curves_df |>
    select(curve_id, time, voltage) |>
    pivot_wider(names_from = curve_id, values_from = voltage)
  stopifnot(nrow(wide) == T, !anyNA(wide))

  # Y is T x N, one curve per COLUMN. Stan matrices are column-major, so
  # Y[, n] is a contiguous read. Getting this transposed is the easiest
  # mistake to make here and it fails loudly on the dimension check.
  Y <- wide |> select(-time) |> as.matrix()

  curve_subject <- curves_df |>
    distinct(curve_id, subject) |>
    arrange(match(curve_id, colnames(Y)))
  subject_levels <- sort(unique(curves_df$subject))

  list(
    stan_data = c(
      list(
        T = T,
        N = ncol(Y),
        J = length(subject_levels),
        K = basis$K,
        Kr = basis$Kr,
        p = p,
        use_subject = as.integer(use_subject),
        use_trial = as.integer(use_trial),
        time = time_grid,
        Y = Y,
        subj = match(curve_subject$subject, subject_levels),
        centre = basis$centre,
        width = basis$width,
        n_block = basis$n_block,
        block_start = basis$block_start,
        block_size = basis$block_size
      ),
      priors
    ),
    time = time_grid,
    subject_levels = subject_levels,
    curve_ids = colnames(Y)
  )
}

# B1. Subject variability only ---------------------------------------------

# Trials averaged within subject first, so one curve per subject. The
# cheapest version of the multilevel model, and it isolates the
# subject-level random function before anything else is added.
#
# Two things to note about averaging. Averaging over roughly 180 trials
# divides the residual variance by about 180 but leaves the autocorrelation
# structure alone, so sigma is much smaller here than at B2 or B3 and the
# prior scale has to reflect that. And averaging before decimating is the
# right order, since averaging is linear and does not change the bandwidth.

b1_curves <- eeg_df |>
  summarise(voltage = mean(voltage), .by = c(subject, time)) |>
  decimate_curves(subject, by = 8L) |>
  rename(subject = 1) |>
  mutate(curve_id = as.character(subject))

b1 <- multilevel_data(
  b1_curves,
  p = 2,
  use_subject = TRUE,
  use_trial = FALSE,
  priors = default_priors(sd_sigma = 3, sd_tau_subj = 10)
)

pf_b1 <- model$pathfinder(data = b1$stan_data, seed = 10101,
                          num_paths = 8, draws = 2000)
fit_b1 <- model$sample(
  data = b1$stan_data, seed = 10101, chains = 4, parallel_chains = 4,
  iter_warmup = 1000, iter_sampling = 1000, refresh = 200, init = pf_b1
)

fit_b1$diagnostic_summary()
fit_b1$summary(c("alpha", "sigma", "phi", "width_mult",
                 "tau_ridge", "tau_curv", "tau_subj"))

# Population fit against the grand average. Compare directly with the lme4
# M0 plot: the shapes should agree closely, and if they do not, the
# difference is the priors and should be explicable as shrinkage.
fitted_curve_summary(fit_b1, b1$time) |>
  ggplot(aes(x = time)) +
  geom_line(
    data = b1_curves |> summarise(voltage = mean(voltage), .by = time),
    aes(y = voltage), colour = "grey40"
  ) +
  geom_ribbon(aes(ymin = q5, ymax = q95), alpha = 0.3, fill = "#BE0000") +
  geom_line(aes(y = q50), colour = "#BE0000", linewidth = 1) +
  theme_minimal() +
  labs(x = "Time from stimulus onset (ms)", y = "Voltage (uV)",
       title = "B1: grand average (grey) vs population fit")

# Which basis functions carry subject-level variability. The lme4
# counterpart is print(VarCorr(M0)), but here a weakly identified component
# shrinks smoothly towards zero instead of producing a degenerate Hessian.
# That is the specific reason for moving off lme4, so it is worth looking at.
fit_b1$summary("tau_subj")

# B2. Trial variability only -----------------------------------------------

# One subject, every trial, nothing averaged. Trial deviations use only the
# coarse basis. In the lme4 pass, giving trials all 16 basis functions
# produced visible single-trial overfitting, worst in the dense narrow
# functions, and restricting to the coarse 8 fixed it. That restriction is
# carried over here rather than rediscovered.

one_subject <- sample(unique(eeg_df$subject), 1)

b2_curves <- eeg_df |>
  filter(subject == one_subject) |>
  decimate_curves(trial_id, by = 8L) |>
  rename(curve_id = 1) |>
  mutate(curve_id = as.character(curve_id), subject = one_subject)

b2 <- multilevel_data(
  b2_curves,
  p = 2,
  use_subject = FALSE,
  use_trial = TRUE,
  priors = default_priors(sd_sigma = 10, sd_tau_trial = 10)
)

pf_b2 <- model$pathfinder(data = b2$stan_data, seed = 10101,
                          num_paths = 8, draws = 2000)
fit_b2 <- model$sample(
  data = b2$stan_data, seed = 10101, chains = 4, parallel_chains = 4,
  iter_warmup = 1000, iter_sampling = 1000, refresh = 200, init = pf_b2
)

fit_b2$diagnostic_summary()
fit_b2$summary(c("alpha", "sigma", "phi", "width_mult", "tau_trial"))

# Leave-one-trial-out. log_lik is one value per curve, not per timepoint,
# so this is genuinely leave-one-trial-out and the usual objection to LOO on
# autocorrelated data does not apply. Trials are exchangeable within
# subject in a way that neighbouring timepoints are not.
library(loo)
loo_b2 <- loo(fit_b2$draws("log_lik"))
print(loo_b2)

# B3. Subjects and trials together -----------------------------------------

# Every subject, a subset of trials each. Cut trials, not subjects: with
# only 15 subjects the lme4 pass could not support a real subject-level
# basis, whereas the number of trial groups stays large however few trials
# per subject are kept. Start at 10 and increase once it runs.

n_trials_per_subject <- 10L

trials_kept <- eeg_df |>
  distinct(subject, trial_id) |>
  slice_sample(n = n_trials_per_subject, by = subject) |>
  pull(trial_id)

b3_curves <- eeg_df |>
  filter(trial_id %in% trials_kept) |>
  decimate_curves(trial_id, by = 8L) |>
  rename(curve_id = 1) |>
  mutate(curve_id = as.character(curve_id)) |>
  left_join(
    eeg_df |> distinct(trial_id, subject) |>
      mutate(curve_id = as.character(trial_id)) |> select(curve_id, subject),
    by = "curve_id"
  )

b3 <- multilevel_data(
  b3_curves,
  p = 2,
  use_subject = TRUE,
  use_trial = TRUE,
  priors = default_priors(sd_sigma = 10)
)

cat(
  "B3: ", b3$stan_data$J, " subjects, ", b3$stan_data$N, " curves, ",
  b3$stan_data$T, " timepoints, ",
  b3$stan_data$N * b3$stan_data$T, " observations\n", sep = ""
)

# This is the expensive one. The trial level alone carries Kr x N
# parameters, which at 47 subjects and 10 trials each is about 3,800, and
# the cost of one gradient evaluation scales with N x T. Do NOT go straight
# to HMC. Pathfinder first, then Laplace, and only then sampling, and
# expect hours rather than minutes for the sampling run.
pf_b3 <- model$pathfinder(data = b3$stan_data, seed = 10101,
                          num_paths = 4, draws = 1000)
pf_b3$summary(c("alpha", "sigma", "phi", "tau_subj", "tau_trial"))

lap_b3 <- model$laplace(
  data = b3$stan_data, seed = 10101, draws = 1000, jacobian = TRUE
)

# jacobian = TRUE is not optional here. sigma, tau and width_mult are
# positive-constrained and r is interval-constrained, so without the
# Jacobian adjustment the optimiser finds the penalised MLE rather than the
# posterior mode and the approximation is centred in the wrong place.

fit_b3 <- model$sample(
  data = b3$stan_data, seed = 10101, chains = 4, parallel_chains = 4,
  iter_warmup = 1000, iter_sampling = 1000, refresh = 50, init = pf_b3
)

fit_b3$diagnostic_summary()
fit_b3$summary(c("alpha", "sigma", "phi", "width_mult",
                 "tau_ridge", "tau_curv", "tau_subj", "tau_trial"))

# Compare the approximations against HMC on the quantity that matters. If
# Pathfinder and Laplace agree with HMC on the fitted curve, they can be
# used for iteration and HMC reserved for final fits, which is the whole
# reason for running all three.
bind_rows(
  fitted_curve_summary(pf_b3, b3$time) |> mutate(algorithm = "Pathfinder"),
  fitted_curve_summary(lap_b3, b3$time) |> mutate(algorithm = "Laplace"),
  fitted_curve_summary(fit_b3, b3$time) |> mutate(algorithm = "HMC")
) |>
  ggplot(aes(x = time, colour = algorithm, fill = algorithm)) +
  geom_ribbon(aes(ymin = q5, ymax = q95), alpha = 0.2, colour = NA) +
  geom_line(aes(y = q50)) +
  theme_minimal() +
  labs(x = "Time from stimulus onset (ms)", y = "Voltage (uV)")

# Subject curves, rebuilt from the draws. The model does not return these
# because at B3 they are T x J per draw, which is too much output to move
# around, and the centres and widths are data so a draw of width_mult is
# all that is needed to reconstruct them.
subj_curves <- subject_curves(fit_b3, b3$time, basis, b3$subject_levels)

subj_curves |>
  summarise(voltage = median(voltage), .by = c(subject, time)) |>
  ggplot(aes(x = time, y = voltage, group = subject)) +
  geom_line(alpha = 0.3) +
  geom_line(
    data = fitted_curve_summary(fit_b3, b3$time),
    aes(x = time, y = q50), inherit.aes = FALSE,
    colour = "#BE0000", linewidth = 1
  ) +
  theme_minimal() +
  labs(x = "Time from stimulus onset (ms)", y = "Voltage (uV)",
       title = "B3: subject curves around the population fit")

# Known open question, carried over from the lme4 pass and not yet
# resolved. Trial-level spread was largest at the two epoch edges, which
# looks more like a basis boundary artefact than a finding about neural
# variability, because the outermost weights are the least constrained.
# Check whether the curvature prior has reduced it. If it has not, the
# remedy is to extend the coarse centres beyond the epoch rather than to
# add more of them inside it.

saveRDS(
  list(
    b1 = fit_b1$summary(), b2 = fit_b2$summary(), b3 = fit_b3$summary(),
    basis = basis, one_subject = one_subject,
    n_trials_per_subject = n_trials_per_subject
  ),
  str_c("tmp/multilevel_", electrode, "_summaries.rds")
)
