# B0. One subject, one trial, one electrode.
#
# The base case. Nothing here is multilevel. The point is to establish that
# the basis, the decimation, the prior on the weights and the AR(p) noise
# model all behave on a single waveform, because if any of them is wrong
# here it will be wrong everywhere above it and much harder to diagnose.
#
# Run order within this script:
#   1. prior predictive check, before any fitting
#   2. p = 0 (iid) and p = 2 (AR) under Pathfinder, for speed
#   3. the same two under HMC, as the reference
#   4. compare the posterior sd of the FITTED CURVE, not the weights
#
# Expected runtime: seconds for Pathfinder, well under a minute for HMC.

library(tidyverse)
library(cmdstanr)
library(posterior)

source("R/rbf_common.R")

set.seed(10101)
electrode <- "POz"

# Data ---------------------------------------------------------------------

# One trial, at full 1024 Hz, long format with columns time and voltage.
# Substitute the project's own extraction here. Kept as a separate file so
# this script does not need the multi-gigabyte parquet or the devcontainer.
trial_raw <- read_csv("data/eeg_df0_trial.csv", show_col_types = FALSE)

trial_df <- trial_raw |>
  mutate(curve = 1L) |>
  decimate_curves(curve, by = 8L)

cat("T after decimation:", nrow(trial_df), "\n")
cat("sampling rate:", round(1000 / median(diff(trial_df$time)), 1), "Hz\n")

# Basis --------------------------------------------------------------------

basis <- make_basis(range(trial_df$time), K_coarse = 8L, K_dense = 8L,
                    dense_window = c(0, 300))
priors <- default_priors(sd_sigma = 10)

# Prior predictive check ---------------------------------------------------

# Do this first and look at it. Curves that wander into the hundreds of uV
# mean the prior scales are wrong, and that was precisely the defect in the
# earlier version of this model, where prior_sd_w = 100 left the collinear
# directions of the design unpenalised.
#
# For reference, with the default scales and this basis the peak absolute
# amplitude of a prior draw has a median of about 18 uV and a 95th
# percentile of about 52 uV, against observed peaks at POz of up to roughly
# 20 uV. That is weak rather than uninformative, which is what is wanted.
# If the numbers come out an order of magnitude away from this, something
# has changed in the basis or the scales.
prior_predictive_check(trial_df$time, basis, priors, n_draw = 200) |>
  ggplot(aes(x = time, y = voltage, group = draw)) +
  geom_line(alpha = 0.1) +
  geom_hline(yintercept = c(-20, 20), linetype = "dashed", colour = "red") +
  theme_minimal() +
  labs(
    x = "Time from stimulus onset (ms)",
    y = "Voltage (uV)",
    title = "B0 prior predictive: population curves from the prior alone",
    subtitle = "Dashed lines mark the observed amplitude range at POz"
  )

# Stan data ----------------------------------------------------------------

b0_data <- function(p) {
  c(
    list(
      T = nrow(trial_df),
      K = basis$K,
      p = p,
      time = trial_df$time,
      y = trial_df$voltage,
      centre = basis$centre,
      width = basis$width,
      n_block = basis$n_block,
      block_start = basis$block_start,
      block_size = basis$block_size
    ),
    priors[c("prior_sd_alpha", "prior_sd_ridge", "prior_sd_curv",
             "prior_sd_sigma", "prior_sd_log_width")]
  )
}

model <- cmdstan_model("stan/rbf_b0_single_trial.stan")

# Fast approximate inference first -----------------------------------------

# Pathfinder before HMC, every time. It costs seconds, it catches gross
# specification errors, and its draws are good initial values for HMC.
pf_iid <- model$pathfinder(data = b0_data(0), seed = 10101,
                           num_paths = 8, draws = 2000)
pf_ar2 <- model$pathfinder(data = b0_data(2), seed = 10101,
                           num_paths = 8, draws = 2000)

# HMC ----------------------------------------------------------------------

fit_hmc <- function(p, init = NULL, ...) {
  model$sample(
    data = b0_data(p),
    seed = 10101,
    chains = 4,
    parallel_chains = 4,
    iter_warmup = 1000,
    iter_sampling = 1000,
    refresh = 500,
    init = init,
    ...
  )
}

hmc_iid <- fit_hmc(0, init = pf_iid)
hmc_ar2 <- fit_hmc(2, init = pf_ar2)
hmc_ar4 <- fit_hmc(4)

# Diagnostics before estimates, always.
hmc_ar2$diagnostic_summary()
hmc_ar2$summary(c("alpha", "sigma", "sigma_innovation", "phi",
                  "width_mult", "tau_ridge", "tau_curv"))

# What to check ------------------------------------------------------------

# 1. Does the fitted curve track the trial, without chasing it? The AR
#    residual should absorb the fast wiggle, not the mean model.
bind_rows(
  fitted_curve_summary(hmc_iid, trial_df$time, "mu_fitted") |>
    mutate(model = "iid"),
  fitted_curve_summary(hmc_ar2, trial_df$time, "mu_fitted") |>
    mutate(model = "AR(2)")
) |>
  ggplot(aes(x = time)) +
  geom_line(data = trial_df, aes(y = voltage), colour = "grey50") +
  geom_ribbon(aes(ymin = q5, ymax = q95, fill = model), alpha = 0.3) +
  geom_line(aes(y = q50, colour = model)) +
  theme_minimal() +
  labs(x = "Time from stimulus onset (ms)", y = "Voltage (uV)")

# 2. Is the estimated residual rhythm physiologically recognisable? With
#    complex AR(2) roots the residual autocorrelation is a damped cosine,
#    and at a parieto-occipital electrode the implied frequency should come
#    out near the alpha band. This is a check, not a target.
ar2_frequency <- function(fit, fs = 128) {
  d <- as_draws_matrix(fit$draws("phi"))
  f <- apply(d, 1, function(ph) {
    if (ph[1]^2 + 4 * ph[2] >= 0) return(NA_real_)
    acos(ph[1] / (2 * sqrt(-ph[2]))) / (2 * pi) * fs
  })
  quantile(f, c(0.05, 0.5, 0.95), na.rm = TRUE)
}
ar2_frequency(hmc_ar2)

# 3. Is the conclusion stable across AR order? This is the criterion to
#    trust. Order selection by likelihood is not well posed on a single
#    trial, for reasons set out in the appendix, so what matters is whether
#    the reported quantity moves.
map_dfr(
  list(iid = hmc_iid, `AR(2)` = hmc_ar2, `AR(4)` = hmc_ar4),
  \(f) amplitude_at(f, trial_df$time, 240, var = "mu_fitted"),
  .id = "model"
)

# 4. Did the width multiplier move away from 1? If its posterior is pinned
#    against the prior, the nominal widths were already about right. If it
#    has moved, the fixed-width convention was wrong and it is worth
#    knowing before the same widths get carried up the ladder.
hmc_ar2$summary("width_mult")

# 5. Are the weights still enormous with heavy cancellation between
#    neighbours? Under the old prior they were of order 1e2 against data
#    with an sd of 8 uV. Under this prior they should not be. If they are,
#    the ridge and curvature scales need revisiting.
hmc_ar2$summary("w")

saveRDS(
  list(iid = hmc_iid$summary(), ar2 = hmc_ar2$summary(),
       ar4 = hmc_ar4$summary(), basis = basis, priors = priors),
  str_c("tmp/b0_", electrode, "_summaries.rds")
)
