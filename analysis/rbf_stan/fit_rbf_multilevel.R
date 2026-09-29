# Fit B1, B2 or B3 from rbf_multilevel.stan at one electrode.
#
#   Rscript analysis/rbf_stan/fit_rbf_multilevel.R model=b3 electrode=POz ntrial=20
#
# Arguments, all key=value:
#   model      b1  subject deviations only, one averaged curve per subject
#              b2  trial deviations only, all trials of one subject
#              b3  subject and trial deviations, single trials
#              b4  b3 plus two predictors, each with an effect curve over
#                  time: standardised log odds accuracy (subject level)
#                  and standardised log(larger / smaller) numerosity ratio
#                  (trial level)
#   electrode  default POz
#   p          AR order, default 2
#   ntrial     b3 and b4, trials per subject drawn at random; 0 means all
#   fixeff     b4 only: 1 fixes the effect curves' ridge and curvature
#              scales at effrid and effcurv (defaults 5 and 10) instead of
#              estimating them; default 0
#   addeff     b4 only: 2 adds realistic known effects (1.5 uV at 300 ms,
#              sd 40 ms, per unit of the subject predictor, and 0.3 uV at
#              250 ms, sd 25 ms, per unit of the trial predictor), sizes
#              taken from the raw data; 1 adds known effect curves to the data before
#              fitting, for checking that they are recovered (a 3 uV
#              Gaussian bump at 270 ms, sd 30 ms, per unit of the subject
#              predictor, and a -1.5 uV bump at 170 ms, sd 20 ms, per unit of
#              the trial predictor); default 0
#   nofirst    1 excludes the first trial of each block. In 179 of 188
#              blocks it is the same hard stimulus (47 against 51 dots) and
#              its ERP differs greatly from other trials, which
#              manufactured a ratio effect. Default 0
#   prevratio  b4 only: 1 adds the previous trial's standardised log ratio
#              as a second trial-level predictor with its own effect curve,
#              since consecutive ratios are correlated (r = 0.15). Trials
#              whose immediately preceding trial is not in the data (the
#              first of each block, and trials after a gap) are dropped.
#              Default 0
#   items      b3 and b4: 1 adds stimulus pairs (left and right numerosity)
#              as a random factor crossed with subjects, each with its own
#              random deviation waveform on the coarse basis. Every
#              participant saw the same fixed sequence of pairs
#              (notes/fixed-trial-sequence.md). Default 0
#   subject    b2 only, default the subject with most usable trials
#   metric     diag_e (default) or dense_e
#   marginal   2 (default) integrates the trial deviations out
#              analytically using sufficient statistics, 1 does the same
#              curve by curve, 0 samples them
#   loglik     1 computes per-curve log_lik, default 0
#   msubj      b3 with marginal=2 only: 1 (default) integrates the subject
#              deviations out too, 0 samples them
#   stanfile   Stan file to compile, default the one in analysis/rbf_stan
#   kc, kd     number of coarse and dense basis functions, default 8 and 8
#   dw         end of the dense window in ms (it starts at 0), default 300
#   adapt      adapt_delta, default 0.8
#   ks         basis functions for subject deviations: "coarse" (the old
#              behaviour) or "all" (default)
#   fc, fd     width multipliers for the coarse and dense blocks. For b1 the
#              default is to estimate them. For b2 and b3 they are fixed,
#              by default at the b1 estimates at POz (0.51 and 0.27),
#              because estimating them from single trials made the
#              posterior multimodal.
#   warmup, sampling   iterations per chain, default 1000 each
#
# Reads tmp/trials_decimated.parquet, written by prepare_trials.R. Writes
# tmp/ml_<tag>_draws.rds (draws of everything except the trial-level z and
# log_lik), tmp/ml_<tag>_summary.rds, and tmp/ml_<tag>.png.

library(tidyverse)
library(cmdstanr)
library(posterior)

source("analysis/rbf_stan/rbf_common.R")

args <- commandArgs(trailingOnly = TRUE)
opt <- list(model = "b3", electrode = "POz", p = "2", ntrial = "20",
            subject = NA, metric = "diag_e", warmup = "1000",
            sampling = "1000", fc = NA, fd = NA,
            marginal = "2", loglik = "0", msubj = "1",
            stanfile = "analysis/rbf_stan/rbf_multilevel.stan",
            kc = "8", kd = "8", dw = "300", ks = "all", adapt = "0.8",
            addeff = "0", fixeff = "0", effrid = "5", effcurv = "10",
            nofirst = "0", prevratio = "0", items = "0")
for (a in args) {
  kv <- str_split_1(a, "=")
  stopifnot(length(kv) == 2, kv[1] %in% names(opt))
  opt[[kv[1]]] <- kv[2]
}
model_name <- opt$model
electrode <- opt$electrode
p <- as.integer(opt$p)
ntrial <- as.integer(opt$ntrial)
is_b34 <- model_name %in% c("b3", "b4")
tag <- str_c(model_name, "_", electrode, "_p", p,
             if (is_b34) str_c("_n", ntrial) else "",
             if (opt$marginal != "0") str_c("_marg", opt$marginal) else "",
             if (is_b34 && opt$marginal == "2" && opt$msubj == "1")
               "_msubj" else "",
             "_", opt$metric, "_kc", opt$kc, "_kd", opt$kd, "_dw", opt$dw,
             if (!is.na(opt$fc)) str_c("_fc", opt$fc, "_fd", opt$fd) else "",
             "_ks", opt$ks,
             if (opt$addeff == "1") "_addeff" else "",
             if (opt$addeff == "2") "_addeffreal" else "",
             if (opt$fixeff == "1") str_c("_fixeff", opt$effrid, "_", opt$effcurv) else "",
             if (opt$nofirst == "1") "_nofirst" else "",
             if (opt$prevratio == "1") "_prevratio" else "",
             if (opt$items == "1") "_items" else "")

set.seed(10101)

# Data ---------------------------------------------------------------------

trials_all <- arrow::read_parquet("tmp/trials_decimated.parquet")

# Trial order within blocks: the previous trial's log ratio where the
# immediately preceding trial is in the data, and a first-of-block flag.
trial_order <- trials_all |>
  distinct(subject, block, trials, trial_id, ratio, left_size, right_size) |>
  arrange(subject, block, trials) |>
  group_by(subject, block) |>
  mutate(first_of_block = row_number() == 1,
         prev_log_ratio = if_else(trials - lag(trials) == 1,
                                  log(1 / lag(ratio)), NA_real_)) |>
  ungroup() |>
  mutate(item_id = str_c(left_size, "_", right_size)) |>
  select(trial_id, first_of_block, prev_log_ratio, item_id)

trials <- trials_all |>
  select(subject, trial_id, ratio, accuracy, time, voltage = all_of(electrode)) |>
  filter(!is.na(voltage)) |>
  left_join(trial_order, by = "trial_id")
if (opt$nofirst == "1") {
  trials <- trials |> filter(!first_of_block)
}
if (opt$prevratio == "1") {
  trials <- trials |> filter(!is.na(prev_log_ratio))
}

# Subject accuracy uses every trial the subject did, including those whose
# EEG was masked at this electrode, since it is a behavioural measure.
accuracy_by_subject <- trials_all |>
  distinct(subject, trial_id, accuracy) |>
  summarise(accuracy = mean(accuracy), .by = subject)

basis <- make_basis(range(trials$time), K_coarse = as.integer(opt$kc),
                    K_dense = as.integer(opt$kd),
                    dense_window = c(0, as.numeric(opt$dw)))
estimate_width <- model_name == "b1" && is.na(opt$fc)
if (!estimate_width) {
  fc <- if (is.na(opt$fc)) 0.51 else as.numeric(opt$fc)
  fd <- if (is.na(opt$fd)) 0.27 else as.numeric(opt$fd)
  basis$width <- basis$width *
    c(rep(fc, basis$block_size[1]), rep(fd, basis$block_size[2]))
  cat("widths fixed at multipliers", fc, fd, "\n")
}

curves <- switch(
  model_name,
  b1 = trials |>
    summarise(voltage = mean(voltage), .by = c(subject, time)) |>
    mutate(curve_id = subject),
  b2 = {
    subj <- if (is.na(opt$subject)) {
      trials |> distinct(subject, trial_id) |> count(subject) |>
        slice_max(n, n = 1, with_ties = FALSE) |> pull(subject)
    } else opt$subject
    trials |> filter(subject == subj) |> mutate(curve_id = trial_id)
  },
  b3 = , b4 = {
    chosen <- trials |> distinct(subject, trial_id)
    if (ntrial > 0) {
      chosen <- chosen |> slice_sample(n = ntrial, by = subject)
    }
    trials |> semi_join(chosen, by = "trial_id") |> mutate(curve_id = trial_id)
  }
)

wide <- curves |>
  select(curve_id, time, voltage) |>
  arrange(time) |>
  pivot_wider(names_from = curve_id, values_from = voltage)
Y <- wide |> select(-time) |> as.matrix()
stopifnot(!anyNA(Y))
curve_subject <- curves |> distinct(curve_id, subject)
curve_subject <- curve_subject[match(colnames(Y), curve_subject$curve_id), ]
subject_levels <- sort(unique(curve_subject$subject))

cat("model", model_name, "electrode", electrode, "p", p,
    "curves", ncol(Y), "subjects", length(subject_levels),
    "timepoints", nrow(Y), "\n")

use_subject <- model_name %in% c("b1", "b3", "b4")
use_trial <- model_name %in% c("b2", "b3", "b4")
use_pred <- model_name == "b4"

# Predictors. Log odds accuracy, standardised across the subjects in this
# fit, and log(larger / smaller) numerosity ratio, standardised across the
# trials in this fit, so each effect curve is the change in the waveform
# per standard deviation of its predictor. The raw means and sds are
# saved so that plots can be put back on the original scales.
acc_j <- accuracy_by_subject$accuracy[
  match(subject_levels, accuracy_by_subject$subject)]
logit_acc <- qlogis(acc_j)
pred_scale <- list(logit_acc_mean = mean(logit_acc),
                   logit_acc_sd = sd(logit_acc))
a_subj <- (logit_acc - pred_scale$logit_acc_mean) / pred_scale$logit_acc_sd
curve_ratio <- curves |> distinct(curve_id, ratio)
log_ratio <- log(1 / curve_ratio$ratio[match(colnames(Y), curve_ratio$curve_id)])
pred_scale$log_ratio_mean <- mean(log_ratio)
pred_scale$log_ratio_sd <- sd(log_ratio)
x_trial <- if (use_pred) {
  (log_ratio - pred_scale$log_ratio_mean) / pred_scale$log_ratio_sd
} else rep(0, ncol(Y))
if (!use_pred) a_subj <- rep(0, length(subject_levels))

# Further trial-level predictors: the previous trial's log ratio,
# standardised with the current ratio's mean and sd so the two effect
# curves are on the same scale.
x_extra <- matrix(0, nrow = ncol(Y), ncol = 0)
if (use_pred && opt$prevratio == "1") {
  curve_prev <- curves |> distinct(curve_id, prev_log_ratio)
  prev <- curve_prev$prev_log_ratio[match(colnames(Y), curve_prev$curve_id)]
  stopifnot(!anyNA(prev))
  x_extra <- matrix((prev - pred_scale$log_ratio_mean) / pred_scale$log_ratio_sd,
                    ncol = 1)
  cat("previous-trial ratio added; cor with current",
      round(cor(x_extra[, 1], x_trial), 3), "\n")
}

# Stimulus pairs as a random factor.
n_items <- 0L
item_index <- rep(0L, ncol(Y))
if (opt$items == "1") {
  curve_item <- curves |> distinct(curve_id, item_id)
  item_of_curve <- curve_item$item_id[match(colnames(Y), curve_item$curve_id)]
  item_levels <- sort(unique(item_of_curve))
  n_items <- length(item_levels)
  item_index <- match(item_of_curve, item_levels)
  cat("stimulus pairs as a random factor:", n_items, "items\n")
}

# Known effects added for the recovery check.
true_effect <- NULL
if (use_pred && opt$addeff %in% c("1", "2")) {
  t <- wide$time
  true_effect <- if (opt$addeff == "1") list(
    subj = 3 * exp(-0.5 * ((t - 270) / 30)^2),
    trial = -1.5 * exp(-0.5 * ((t - 170) / 20)^2)
  ) else list(
    subj = 1.5 * exp(-0.5 * ((t - 300) / 40)^2),
    trial = 0.3 * exp(-0.5 * ((t - 250) / 25)^2)
  )
  subj_idx <- match(curve_subject$subject, subject_levels)
  Y <- Y + outer(true_effect$subj, a_subj[subj_idx]) +
    outer(true_effect$trial, x_trial)
  cat("added known effects for the recovery check\n")
}

stan_data <- c(
  list(
    T = nrow(Y), N = ncol(Y), J = length(subject_levels),
    K = basis$K, Kr = basis$Kr, p = p,
    Ks_basis = if (opt$ks == "all") basis$K else basis$Kr,
    use_subject = as.integer(use_subject), use_trial = as.integer(use_trial),
    estimate_width = as.integer(estimate_width),
    marginal_trial = as.integer(opt$marginal),
    compute_log_lik = as.integer(opt$loglik),
    marginal_subject = as.integer(is_b34 && opt$marginal == "2" &&
                                    opt$msubj == "1"),
    use_pred = as.integer(use_pred), a_subj = a_subj, x_trial = x_trial,
    fix_effect_scales = as.integer(opt$fixeff), effect_tau_ridge = as.numeric(opt$effrid),
    effect_tau_curv = as.numeric(opt$effcurv),
    P2 = ncol(x_extra), x_extra = x_extra,
    I = n_items, item = item_index,
    time = wide$time, Y = Y,
    subj = match(curve_subject$subject, subject_levels),
    centre = basis$centre, width = basis$width,
    n_block = basis$n_block, block_start = basis$block_start,
    block_size = basis$block_size
  ),
  # Averaging over about 180 trials shrinks the residual sd by a factor of
  # about 13, hence the smaller sigma scale for b1.
  default_priors(sd_sigma = if (model_name == "b1") 3 else 10,
                 sd_log_width = 0.5)
)

# Fit ----------------------------------------------------------------------

model <- cmdstan_model(opt$stanfile)
fit <- model$sample(
  data = stan_data, seed = 10101, chains = 4, parallel_chains = 4,
  iter_warmup = as.integer(opt$warmup),
  iter_sampling = as.integer(opt$sampling),
  refresh = 100, metric = opt$metric, show_messages = FALSE,
  adapt_delta = as.numeric(opt$adapt)
)

keep_vars <- intersect(
  c("alpha", "w", "width_mult", "tau_ridge", "tau_curv", "tau_subj",
    "tau_subj_coarse", "tau_subj_ridge", "tau_subj_curv",
    "tau_trial", "tau_item", "sigma", "phi", "mu_pop", "mu_subj", "effect_extra",
    "effect_subj", "effect_trial", "tau_g_ridge", "tau_g_curv",
    "tau_d_ridge", "tau_d_curv"),
  names(fit$metadata()$stan_variable_sizes)
)
draws <- fit$draws(keep_vars, format = "draws_df")
loo_result <- if (opt$loglik == "1") {
  loo::loo(fit$draws("log_lik", format = "draws_matrix"))
} else NULL
subject_mean <- curves |>
  summarise(voltage = mean(voltage), .by = c(subject, time)) |>
  summarise(voltage = mean(voltage), .by = time) |>
  arrange(time) |>
  pull(voltage)
saveRDS(list(draws = draws, time = wide$time, subjects = subject_levels,
             data_mean = rowMeans(Y), subject_mean = subject_mean,
             basis = basis, loo = loo_result, opt = opt,
             pred_scale = pred_scale, a_subj = a_subj,
             true_effect = true_effect),
        str_c("tmp/ml_", tag, "_draws.rds"))

scalar_vars <- intersect(
  c("alpha", "width_mult", "tau_ridge", "tau_curv", "tau_subj",
    "tau_subj_coarse", "tau_subj_ridge", "tau_subj_curv", "tau_trial", "tau_item",
    "sigma", "phi", "tau_g_ridge", "tau_g_curv", "tau_d_ridge", "tau_d_curv"),
  keep_vars
)
summ <- fit$summary(scalar_vars)
sd <- fit$sampler_diagnostics(format = "draws_df")
# Convergence over every parameter, including the trial-level z.
all_rhat <- fit$summary(NULL, "rhat", "ess_bulk")
saveRDS(list(summary = summ, all = all_rhat), str_c("tmp/ml_", tag, "_summary.rds"))

pop <- fitted_curve_summary(fit, wide$time, "mu_pop")
cat("\n==== ", tag, "\n")
cat("time", round(fit$time()$total), "s; divergent", sum(sd$divergent__),
    "; treedepth hits", sum(sd$treedepth__ >= 10),
    "; mean stepsize", signif(mean(sd$stepsize__), 3),
    "; mean leapfrog", round(mean(sd$n_leapfrog__)),
    "; max rhat (all)", round(max(all_rhat$rhat, na.rm = TRUE), 3),
    "; min ess_bulk (all)", round(min(all_rhat$ess_bulk, na.rm = TRUE)),
    "; max |pop median - mean of subject means|",
    round(max(abs(pop$q50 - subject_mean)), 2), "uV",
    "; rmse 0-500 ms",
    round(sqrt(mean(((pop$q50 - subject_mean)[wide$time >= 0 & wide$time <= 500])^2)), 3),
    "uV\n")
if (!is.null(loo_result)) print(loo_result)
print(summ, n = Inf, width = Inf)

# Plot ---------------------------------------------------------------------

g <- ggplot(pop, aes(x = time)) +
  geom_line(data = tibble(time = wide$time, v = subject_mean),
            aes(y = v), colour = "grey40") +
  geom_ribbon(aes(ymin = q5, ymax = q95), alpha = 0.3, fill = "#BE0000") +
  geom_line(aes(y = q50), colour = "#BE0000") +
  theme_minimal() +
  labs(x = "Time from stimulus onset (ms)", y = "Voltage (uV)",
       title = tag,
       subtitle = "Grey: mean of subject averages. Red: population fit, median and 90% band.")
ggsave(str_c("tmp/ml_", tag, ".png"), g, width = 7, height = 4)
