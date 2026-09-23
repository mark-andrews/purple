# Shared machinery for the B0-B3 ladder.
#
# Everything here is deliberately boring and inspectable. The basis, the
# decimation and the prior scales are the three things that have to be the
# same across models for the ladder to mean anything, so they live in one
# place rather than being copied into each driver.
#
# source() this at the top of each fit_*.R script.

library(tidyverse)

# Decimation ---------------------------------------------------------------

# The epochs are at 1024 Hz and band-pass filtered at 1-30 Hz, so the
# record is band-limited well below the 64 Hz Nyquist of a 128 Hz grid.
# Decimating by 8 is close to lossless and it is also necessary: at 1024 Hz
# a low-order AR likelihood degenerates, because consecutive samples are
# nearly perfectly predictable from each other. See the technical appendix in models.qmd.
#
# NOTE. The best place to do this is upstream, in MNE, with
# `epochs.resample(128)`, which uses a proper polyphase resampler and
# handles the epoch edges correctly. If the parquet has already been
# resampled, skip this function entirely and pass the data straight
# through. The version below is a fallback for working from the existing
# 1024 Hz file. It applies an FIR anti-alias filter before subsampling,
# which plain `slice(seq(1, n(), by = 8))` does not, and without it any
# residual power above 64 Hz folds into the retained band. A 100 Hz mains
# harmonic, for instance, folds to 28 Hz, directly into the range of
# interest.

decimate_voltage <- function(voltage, by = 8L) {
  stopifnot(requireNamespace("signal", quietly = TRUE))
  out <- as.numeric(signal::decimate(voltage, by, ftype = "fir"))
  keep_n <- length(seq(1L, length(voltage), by = by))
  stopifnot(length(out) == keep_n)
  out
}

# Decimate a long-format table one curve at a time. `curve` names the
# column identifying a single waveform (trial_id, or subject for
# subject-averaged data). Decimating across concatenated curves would run
# the filter over the join between them and the error would be silent.
decimate_curves <- function(df, curve, by = 8L, filter = TRUE) {
  df |>
    arrange({{ curve }}, time) |>
    group_by({{ curve }}) |>
    group_modify(function(d, key) {
      keep <- seq(1L, nrow(d), by = by)
      tibble(
        time = d$time[keep],
        voltage = if (filter) decimate_voltage(d$voltage, by) else d$voltage[keep]
      )
    }) |>
    ungroup()
}

# Basis --------------------------------------------------------------------

# Two densities, not one. A coarse set spanning the whole epoch, plus a
# denser and narrower set confined to the window where P1, N1 and P2p sit.
# This is the placement validated in the lme4 smoke tests: the coarse set
# alone flattened the early structure, and adding the dense tier fixed it.
#
# Centres and widths are fixed as data. Only a single global multiplier on
# the widths is estimated, which removes the need to guess the length scale
# without opening up the multimodal geometry that free centres bring.
#
# The coarse block comes FIRST in the returned ordering. The Stan model
# takes the first Kr columns as the group-level basis, so this ordering is
# load-bearing, not cosmetic.

make_basis <- function(
  time_range,
  K_coarse = 8L,
  K_dense = 8L,
  dense_window = c(0, 300)
) {
  centres_coarse <- seq(time_range[1], time_range[2], length.out = K_coarse)
  centres_dense <- seq(dense_window[1], dense_window[2], length.out = K_dense)

  # Width equal to centre spacing, as in the lme4 scripts. Note the failure
  # mode this convention has at very small K: with K = 2, seq() puts the
  # centres at the two ends of the epoch and the width becomes the whole
  # epoch, making the two functions nearly collinear.
  list(
    centre = c(centres_coarse, centres_dense),
    width = c(
      rep(diff(centres_coarse)[1], K_coarse),
      rep(diff(centres_dense)[1], K_dense)
    ),
    K = K_coarse + K_dense,
    Kr = K_coarse,
    n_block = 2L,
    block_start = c(1L, K_coarse + 1L),
    block_size = c(K_coarse, K_dense)
  )
}

rbf_design_matrix <- function(time, centre, width, width_mult = 1) {
  mapply(
    function(ctr, wd) exp(-0.5 * (time - ctr)^2 / (width_mult * wd)^2),
    centre,
    width
  )
}

# Prior scales -------------------------------------------------------------

# All half-normal or lognormal, all passed as data so they can be varied
# without touching the model. The voltage scale at POz is a few uV of noise
# and peaks up to roughly 20 uV, which is what these are calibrated
# against. They are weak rather than uninformative, which is the point: the
# earlier `prior_sd_w = 100` was so wide that it left the collinear
# directions of the design effectively unpenalised.
#
# Run prior_predictive_check() below before trusting any of them.

default_priors <- function(
  sd_alpha = 10,
  sd_ridge = 10,
  sd_curv = 10,
  sd_tau_subj = 10,
  sd_tau_trial = 10,
  sd_sigma = 10,
  sd_log_width = 0.15
) {
  list(
    prior_sd_alpha = sd_alpha,
    prior_sd_ridge = sd_ridge,
    prior_sd_curv = sd_curv,
    prior_sd_tau_subj = sd_tau_subj,
    prior_sd_tau_trial = sd_tau_trial,
    prior_sd_sigma = sd_sigma,
    prior_sd_log_width = sd_log_width
  )
}

# Draw population curves from the prior alone. If these look nothing like
# an ERP, or if they run to hundreds of uV, the prior scales are wrong and
# nothing downstream will rescue that.
prior_predictive_check <- function(time, basis, priors, n_draw = 200) {
  half_normal <- function(n, sd) abs(rnorm(n, 0, sd))

  map_dfr(seq_len(n_draw), function(i) {
    tau_ridge <- half_normal(basis$n_block, priors$prior_sd_ridge)
    tau_curv <- half_normal(basis$n_block, priors$prior_sd_curv)
    mult <- rlnorm(1, 0, priors$prior_sd_log_width)

    w <- numeric(basis$K)
    for (b in seq_len(basis$n_block)) {
      idx <- basis$block_start[b] + seq_len(basis$block_size[b]) - 1L
      n <- length(idx)
      # Sample the implied prior directly: precision is the ridge term plus
      # the curvature term D'D / tau_curv^2, where D takes second
      # differences. This is the same prior the Stan model states, written
      # as a covariance so it can be sampled from.
      D <- matrix(0, nrow = max(n - 2, 0), ncol = n)
      if (n >= 3) {
        for (m in seq_len(n - 2)) D[m, m + 0:2] <- c(1, -2, 1)
      }
      P <- diag(n) / tau_ridge[b]^2
      if (n >= 3) P <- P + crossprod(D) / tau_curv[b]^2
      L <- chol(solve(P))
      w[idx] <- as.numeric(t(L) %*% rnorm(n))
    }

    B <- rbf_design_matrix(time, basis$centre, basis$width, mult)
    tibble(draw = i, time = time, voltage = as.numeric(B %*% w))
  })
}

# Rebuilding curves from draws ---------------------------------------------

# The Stan models return mu_pop and the parameter draws, not every fitted
# curve, because at B3 the fitted curves are T x N per draw and that is far
# too much output to move around. Anything else is rebuilt here. The only
# reason this works is that the centres and widths are data, so a draw of
# width_mult is enough to reconstruct that draw's design matrix.

subject_curves <- function(fit, time, basis, subject_labels) {
  d <- posterior::as_draws_df(fit$draws(c("alpha", "w", "width_mult",
                                          "tau_subj", "z_subj")))
  Kr <- basis$Kr
  J <- length(subject_labels)

  map_dfr(seq_len(nrow(d)), function(i) {
    mult <- d$width_mult[i]
    B <- rbf_design_matrix(time, basis$centre, basis$width, mult)
    w <- as.numeric(d[i, str_c("w[", seq_len(basis$K), "]")])
    tau <- as.numeric(d[i, str_c("tau_subj[", seq_len(Kr), "]")])
    pop <- d$alpha[i] + as.numeric(B %*% w)

    map_dfr(seq_len(J), function(j) {
      z <- as.numeric(d[i, str_c("z_subj[", seq_len(Kr), ",", j, "]")])
      tibble(
        draw = i,
        subject = subject_labels[j],
        time = time,
        voltage = pop + as.numeric(B[, 1:Kr] %*% (tau * z))
      )
    })
  })
}

# Reporting ----------------------------------------------------------------

# The individual weights are not separately interpretable. Overlapping
# Gaussian bumps are collinear, so the weights come out large with heavy
# cancellation between neighbours and their marginals are unstable. Report
# functions of the fitted curve instead: the amplitude at a latency, the
# height of a peak, the difference between two conditions at a timepoint.
#
# This is a constraint on what gets reported, not a defect in the fit.

# `var` is mu_fitted in B0 and mu_pop in the multilevel model.
fitted_curve_summary <- function(
  fit,
  time,
  var = "mu_pop",
  probs = c(0.05, 0.5, 0.95)
) {
  posterior::as_draws_matrix(fit$draws(var)) |>
    apply(2, quantile, probs = probs) |>
    t() |>
    as_tibble(.name_repair = "minimal") |>
    set_names(str_c("q", probs * 100)) |>
    mutate(time = time, .before = 1)
}

amplitude_at <- function(fit, time, at_ms, var = "mu_pop") {
  idx <- which.min(abs(time - at_ms))
  draws <- posterior::as_draws_matrix(fit$draws(var))[, idx]
  tibble(
    latency = time[idx],
    mean = mean(draws),
    sd = sd(draws),
    q5 = quantile(draws, 0.05),
    q95 = quantile(draws, 0.95)
  )
}
