# Posterior predictive check of a B4 fit against the exploratory statistics.
#
#   Rscript analysis/rbf_stan/ppc_b4.R <draws file> <electrode> [ndraws] [out_dir]
#
# For each of ndraws posterior draws (default 100), simulate a complete
# replicate data set, every trial the model saw:
#
#   y_n = mu_subj[, j] + x_n * effect_trial + B_c v_n + eps_n
#
# with v_n ~ N(0, diag(tau_trial^2)) and eps_n AR(p) with the draw's sigma
# and phi. mu_subj already contains the accuracy effect and the draw of the
# subject's deviation. Then compute on each replicate, and on the real data,
# the exploratory statistics used in the model-free checks:
#
#   ratio_diff  easiest minus hardest third of trials, within subject, mean
#               across subjects
#   ratio_slope within-subject slope of voltage on the standardised
#               predictor, mean across subjects
#   acc_diff    grand average of the higher-accuracy minus lower-accuracy
#               half of subjects
#   acc_slope   slope of subject averages on standardised accuracy
#
# A model passes if the real statistic lies inside the replicates' 90%
# range. Note what this does not test: which part of the model an effect is
# attributed to. A model that puts the accuracy effect into the subject
# deviations still reproduces acc_diff and acc_slope. That is tested by the
# recovery runs, and by comparing the effect curve with the slope of the
# model's own subject waveforms on accuracy.
#
# Writes <out_dir>/ppc_<electrode>.png and .csv, default tmp/ppc.

library(tidyverse)
library(posterior)

args <- commandArgs(trailingOnly = TRUE)
draws_file <- args[1]
electrode <- args[2]
ndraws <- if (length(args) >= 3) as.integer(args[3]) else 100L
out_dir <- if (length(args) >= 4) args[4] else "tmp/ppc"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
set.seed(20260928)

res <- readRDS(draws_file)
time <- res$time; T <- length(time); J <- length(res$subjects)
sc <- res$pred_scale
basis <- res$basis
Kr <- basis$Kr
Bc <- sapply(seq_len(Kr), function(k)
  exp(-0.5 * ((time - basis$centre[k]) / basis$width[k])^2))

# The trials the model saw: every usable trial at this electrode.
trials <- arrow::read_parquet("tmp/trials_decimated.parquet") |>
  select(subject, trial_id, ratio, time, v = all_of(electrode)) |>
  filter(!is.na(v), subject %in% res$subjects) |>
  arrange(trial_id, time)
tinfo <- trials |> distinct(trial_id, subject, ratio) |>
  mutate(x = (log(1 / ratio) - sc$log_ratio_mean) / sc$log_ratio_sd,
         j = match(subject, res$subjects))
N <- nrow(tinfo)
Y <- matrix(trials$v, nrow = T)          # T x N, trial_id order
stopifnot(ncol(Y) == N)

# Fixed structures for the statistics.
a <- res$a_subj
acc_hi <- a >= median(a)
third <- tinfo |> group_by(j) |> mutate(th = ntile(x, 3)) |> ungroup() |> pull(th)
avg_by <- function(Ymat, idx) {               # T x J means over trials with idx
  out <- matrix(NA_real_, T, J)
  for (jj in seq_len(J)) {
    k <- which(tinfo$j == jj & idx)
    out[, jj] <- rowMeans(Ymat[, k, drop = FALSE])
  }
  out
}
xc_by_subj <- split(seq_len(N), tinfo$j)
stats <- function(Ymat) {
  easy <- avg_by(Ymat, third == 3); hard <- avg_by(Ymat, third == 1)
  subj_avg <- avg_by(Ymat, rep(TRUE, N))
  slopes <- sapply(seq_len(J), function(jj) {
    k <- xc_by_subj[[jj]]; xx <- tinfo$x[k] - mean(tinfo$x[k])
    drop(Ymat[, k, drop = FALSE] %*% xx) / sum(xx^2)
  })
  ac <- a - mean(a)
  list(ratio_diff = rowMeans(easy - hard),
       ratio_slope = rowMeans(slopes),
       acc_diff = rowMeans(subj_avg[, acc_hi]) - rowMeans(subj_avg[, !acc_hi]),
       acc_slope = drop(subj_avg %*% ac) / sum(ac^2))
}

real <- stats(Y)

dm <- as_draws_matrix(res$draws)
pick <- sample(nrow(dm), ndraws)
p <- length(grep("^phi\\[", colnames(dm)))
sim_ar <- function(phi, sd_innov, T, N, burn = 60) {
  e <- matrix(0, T + burn, N)
  z <- matrix(rnorm((T + burn) * N, 0, sd_innov), T + burn, N)
  for (t in seq_len(T + burn)) {
    e[t, ] <- z[t, ]
    for (l in seq_len(p)) if (t > l) e[t, ] <- e[t, ] + phi[l] * e[t - l, ]
  }
  e[(burn + 1):(T + burn), , drop = FALSE]
}

reps <- map(pick, function(d) {
  row <- setNames(as.numeric(dm[d, ]), colnames(dm))
  mu_subj <- matrix(row[str_c("mu_subj[", rep(seq_len(T), J), ",",
                              rep(seq_len(J), each = T), "]")], T, J)
  eff_t <- row[str_c("effect_trial[", seq_len(T), "]")]
  tau_t <- row[str_c("tau_trial[", seq_len(Kr), "]")]
  phi <- row[str_c("phi[", seq_len(p), "]")]
  sigma <- row["sigma"]
  # Innovation sd from the marginal sd and the AR coefficients.
  acf_var <- if (p > 0) {
    # Marginal variance of AR with unit innovations.
    psi <- ARMAtoMA(ar = phi, lag.max = 500)
    1 + sum(psi^2)
  } else 1
  sd_innov <- sigma / sqrt(acf_var)
  V <- matrix(rnorm(Kr * N), Kr, N) * tau_t
  Yrep <- mu_subj[, tinfo$j] + outer(eff_t, tinfo$x) + Bc %*% V +
    sim_ar(phi, sd_innov, T, N)
  stats(Yrep)
})

summ <- map_dfr(names(real), function(s) {
  R <- sapply(reps, `[[`, s)                 # T x ndraws
  tibble(stat = s, time = time, real = real[[s]],
         q5 = apply(R, 1, quantile, 0.05), q50 = apply(R, 1, median),
         q95 = apply(R, 1, quantile, 0.95))
}) |>
  mutate(outside = real < q5 | real > q95)

cat("\nPPC", electrode, basename(draws_file), "\n")
# The longest run of consecutive timepoints outside the range is the more
# telling summary: a contiguous run marks a systematic failure, while
# isolated points outside a 90% range are expected by chance.
longest_run <- function(x) { r <- rle(x); if (any(r$values)) max(r$lengths[r$values]) else 0L }
summ |>
  group_by(stat) |>
  summarise(frac_outside_all = mean(outside),
            frac_outside_0_600 = mean(outside[time >= 0 & time <= 600]),
            longest_run_0_600 = longest_run(outside[time >= 0 & time <= 600]),
            longest_run_ms = 7.8125 * longest_run_0_600) |>
  print()
write_csv(summ, file.path(out_dir, str_c("ppc_", electrode, ".csv")))

g <- ggplot(summ, aes(x = time)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_ribbon(aes(ymin = q5, ymax = q95), fill = "steelblue", alpha = 0.3) +
  geom_line(aes(y = q50), colour = "steelblue") +
  geom_line(aes(y = real), colour = "black") +
  geom_point(data = ~ filter(.x, outside), aes(y = real), colour = "red", size = 0.6) +
  facet_wrap(~stat, ncol = 1, scales = "free_y") +
  theme_minimal() +
  labs(x = "Time from stimulus onset (ms)", y = "uV (or uV per sd)",
       title = str_c("Posterior predictive check, ", electrode),
       subtitle = "Black: real data. Blue: replicates, median and 90% range. Red: real outside the range.")
ggsave(file.path(out_dir, str_c("ppc_", electrode, ".png")), g, width = 8, height = 9)
