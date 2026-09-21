# Fit the single-trial RBF basis-function regression with AR(p) noise
# using cmdstanr, under each of CmdStan's inference algorithms.
#
# One Stan file (stan/rbf_arp.stan) covers every model: p = 0 gives iid
# Gaussian noise, p = 1 gives AR(1), p = 2 gives AR(2), and so on.

library(tidyverse)
library(cmdstanr)
library(posterior)

# ------------------------------------------------------------------------
# Data and basis
# ------------------------------------------------------------------------

eeg_df0_trial <- read_csv("eeg_df0_trial.csv", show_col_types = FALSE)

# Decimate 1024 -> 128 Hz. See the accompanying document for why this is
# safe (the data are already low-passed at 30 Hz) and why it is
# necessary (at 1024 Hz the AR likelihood degenerates).
trial_df <- eeg_df0_trial |>
  slice(seq(1, n(), by = 8))

rbf_design_matrix <- function(x, centers, width) {
  mapply(function(ctr, w) exp(-0.5 * (x - ctr)^2 / w^2), centers, width)
}

K_coarse <- 8
K_dense <- 8
dense_window <- c(0, 300)

centers_coarse <- seq(
  min(trial_df$time),
  max(trial_df$time),
  length.out = K_coarse
)
centers_dense <- seq(dense_window[1], dense_window[2], length.out = K_dense)

centers <- c(centers_coarse, centers_dense)
width <- c(
  rep(diff(centers_coarse)[1], K_coarse),
  rep(diff(centers_dense)[1], K_dense)
)

B <- rbf_design_matrix(trial_df$time, centers, width)

make_stan_data <- function(p) {
  list(
    T = nrow(trial_df),
    K = ncol(B),
    p = p,
    B = B,
    y = trial_df$voltage,
    # The weights are voltages, but overlapping RBFs mean heavy
    # cancellation and individually large weights. A prior of 100 is
    # weak relative to the fitted values (order 10^2) but still proper,
    # and it regularises the collinearity a little.
    prior_sd_w = 100,
    prior_sd_sigma = 10
  )
}

# ------------------------------------------------------------------------
# Compile once
# ------------------------------------------------------------------------

model <- cmdstan_model("stan/rbf_arp.stan")

# ------------------------------------------------------------------------
# 1. Full HMC. This is the reference. Everything else is judged
#    against it, not the other way round.
# ------------------------------------------------------------------------

fit_hmc <- function(p, ...) {
  model$sample(
    data = make_stan_data(p),
    seed = 10101,
    chains = 4,
    parallel_chains = 4,
    iter_warmup = 1000,
    iter_sampling = 1000,
    refresh = 500,
    ...
  )
}

hmc_iid <- fit_hmc(0)
hmc_ar1 <- fit_hmc(1)
hmc_ar2 <- fit_hmc(2)
hmc_ar4 <- fit_hmc(4)

# Always look at the diagnostics before the estimates.
hmc_ar2$diagnostic_summary()

hmc_ar2$summary(c("alpha", "sigma", "phi", "sigma_innovation"))

# ------------------------------------------------------------------------
# 2. Pathfinder. Quasi-Newton optimisation, then importance-resampled
#    draws from a normal approximation along the trajectory. Fast, and
#    designed partly to supply initial values for HMC.
# ------------------------------------------------------------------------

pf_ar2 <- model$pathfinder(
  data = make_stan_data(2),
  seed = 10101,
  num_paths = 8,
  draws = 4000
)

# Pathfinder draws can also be handed to HMC as inits, which usually
# shortens warmup considerably.
hmc_ar2_init <- fit_hmc(2, init = pf_ar2)

# ------------------------------------------------------------------------
# 3. Laplace. Optimise to the posterior mode, then draw from the
#    Gaussian defined by the Hessian there. Exact if the posterior is
#    Gaussian, degrading smoothly as it departs from one.
#
#    Note jacobian = TRUE. The mode must be found on the unconstrained
#    scale with the Jacobian adjustment included, otherwise the
#    approximation is centred on the penalised MLE rather than the
#    posterior mode. This matters here because sigma is
#    positive-constrained and r is interval-constrained.
# ------------------------------------------------------------------------

mode_ar2 <- model$optimize(
  data = make_stan_data(2),
  seed = 10101,
  jacobian = TRUE
)

lap_ar2 <- model$laplace(
  data = make_stan_data(2),
  mode = mode_ar2,
  draws = 4000,
  seed = 10101
)

# ------------------------------------------------------------------------
# 4. ADVI. Stochastic gradient fit of a Gaussian approximation. The
#    least reliable of the four, and its own diagnostics are weak, so
#    treat any result as provisional until checked against HMC.
# ------------------------------------------------------------------------

advi_meanfield <- model$variational(
  data = make_stan_data(2),
  seed = 10101,
  algorithm = "meanfield",
  draws = 4000
)

# Full-rank keeps the posterior correlations, which matter here: the
# basis weights are strongly correlated with each other because the
# RBFs overlap. Meanfield will badly understate their joint
# uncertainty for exactly that reason.
advi_fullrank <- model$variational(
  data = make_stan_data(2),
  seed = 10101,
  algorithm = "fullrank",
  draws = 4000
)

# ------------------------------------------------------------------------
# 5. Penalised maximum likelihood. Point estimate only, no uncertainty.
#    jacobian = FALSE gives the MLE/MAP on the constrained scale, which
#    is what you want if the point estimate is the goal.
# ------------------------------------------------------------------------

mle_ar2 <- model$optimize(
  data = make_stan_data(2),
  seed = 10101,
  jacobian = FALSE
)

# ------------------------------------------------------------------------
# Comparing the algorithms
# ------------------------------------------------------------------------

# The comparison that matters is not whether the point estimates agree.
# They usually will, because the mean model is linear. It is whether
# the *uncertainty* agrees, since that is the whole reason for changing
# the noise model in the first place.

extract_summary <- function(fit, label, vars = c("alpha", "sigma", "phi[1]", "phi[2]")) {
  fit$draws(vars) |>
    as_draws_df() |>
    as_tibble() |>
    select(all_of(vars)) |>
    pivot_longer(everything(), names_to = "parameter") |>
    group_by(parameter) |>
    summarise(
      mean = mean(value),
      sd = sd(value),
      q5 = quantile(value, 0.05),
      q95 = quantile(value, 0.95),
      .groups = "drop"
    ) |>
    mutate(algorithm = label)
}

algorithm_comparison <- bind_rows(
  extract_summary(hmc_ar2, "HMC"),
  extract_summary(pf_ar2, "Pathfinder"),
  extract_summary(lap_ar2, "Laplace"),
  extract_summary(advi_meanfield, "ADVI meanfield"),
  extract_summary(advi_fullrank, "ADVI fullrank")
) |>
  arrange(parameter, algorithm)

print(algorithm_comparison, n = Inf)

# The quantity of scientific interest is the fitted waveform, not the
# individual weights, which are collinear and unstable. Compare the
# posterior sd of the fitted curve across algorithms and across AR
# order. This is the criterion that decides whether any of this
# mattered.
fitted_uncertainty <- function(fit, label) {
  fit$draws("mu_fitted") |>
    as_draws_matrix() |>
    apply(2, sd) |>
    (\(s) tibble(time = trial_df$time, sd_fitted = s, model = label))()
}

bind_rows(
  fitted_uncertainty(hmc_iid, "iid"),
  fitted_uncertainty(hmc_ar1, "AR(1)"),
  fitted_uncertainty(hmc_ar2, "AR(2)"),
  fitted_uncertainty(hmc_ar4, "AR(4)")
) |>
  ggplot(aes(x = time, y = sd_fitted, colour = model)) +
  geom_line() +
  theme_minimal() +
  labs(
    x = "Time from stimulus onset (ms)",
    y = "Posterior sd of fitted waveform (uV)",
    colour = NULL
  )

# ------------------------------------------------------------------------
# Diagnostics for the noise model itself
# ------------------------------------------------------------------------

# Criterion 1: do the normalised (one-step prediction error) residuals
# look white? If they do, the AR order is sufficient. See the document
# for why this test does not settle the question on a single trial.
normalised_residuals <- function(fit) {
  d <- fit$draws(c("phi", "mu_fitted", "sigma_innovation")) |> as_draws_matrix()
  phi <- colMeans(d[, grep("^phi", colnames(d)), drop = FALSE])
  mu <- colMeans(d[, grep("^mu_fitted", colnames(d)), drop = FALSE])
  p <- length(phi)
  eps <- trial_df$voltage - mu
  e <- numeric(length(eps) - p)
  for (t in (p + 1):length(eps)) {
    e[t - p] <- eps[t] - sum(phi * eps[(t - 1):(t - p)])
  }
  e
}

acf(normalised_residuals(hmc_ar2), lag.max = 30,
    main = "Normalised residuals, AR(2)")

Box.test(normalised_residuals(hmc_ar2), lag = 20, type = "Ljung-Box", fitdf = 2)

# Criterion 2: nested comparison by approximate leave-one-out. Note
# that ordinary LOO is not appropriate for autocorrelated data, since
# neighbouring points are near-duplicates. Use it only as a rough
# guide, and prefer the stability criterion below.
library(loo)
loo_compare(
  loo(hmc_iid$draws("log_lik")),
  loo(hmc_ar1$draws("log_lik")),
  loo(hmc_ar2$draws("log_lik")),
  loo(hmc_ar4$draws("log_lik"))
)

# Criterion 3, and the one to trust: is the reported quantity stable
# across AR order? Posterior sd of the fitted waveform at the P2p
# latency.
target_index <- which.min(abs(trial_df$time - 240))
map_dbl(
  list(iid = hmc_iid, ar1 = hmc_ar1, ar2 = hmc_ar2, ar4 = hmc_ar4),
  \(f) sd(as_draws_matrix(f$draws("mu_fitted"))[, target_index])
)
