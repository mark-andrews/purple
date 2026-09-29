# Computes every result the Plymouth slides show, from the masked adult
# data, and writes small result files that slides.qmd reads. Everything
# slow happens here, so that rendering the slides takes seconds.
#
# Run from the repository root, inside the devcontainer image:
#
#   podman run --rm --user root -v "$PWD":/w -w /w localhost/purple-interactive \
#     Rscript reports/presentations/plymouth-october-2026/prepare_results.R
#
# Arguments, all key=value and optional:
#   test=1     a quick check of the whole pipeline: model fits on 20 trials
#              per subject with short chains, written to results-test/
#              instead of results/. Its estimates mean nothing.
#   stage=...  run only some stages, comma separated, from trials, fits,
#              behaviour, erp, raw, items, child, models. Default all, in
#              that order. The adult stages after trials read the trial
#              cache, and models reads the fits. child reads the
#              preprocessed child data, and is skipped if it is missing.
#
# Input: data/main/merged_eeg_behaviour_data_masked.parquet and
# data/main/combined_behaviour_data.csv, from the Snakemake pipeline.
#
# Every analysis excludes the first trial of each block, which in 179 of
# 188 blocks is the same hard stimulus and has a very different ERP (see
# notes/fixed-trial-sequence.md). The model fits and the item analysis
# also control for the previous trial's ratio.
#
# The model is B4 from analysis/rbf_stan/, at five electrodes in parallel,
# about five hours on 24 cores. Every random step is seeded (the Stan fits
# with the driver's fixed seed, the permutation tests here), so a rerun
# with the same container image on the same hardware gives the same files.

library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)
opt <- list(test = "0", stage = "trials,fits,behaviour,erp,raw,items,child,models")
for (a in args) {
  kv <- str_split_1(a, "=")
  stopifnot(length(kv) == 2, kv[1] %in% names(opt))
  opt[[kv[1]]] <- kv[2]
}
test <- opt$test == "1"
stages <- str_split_1(opt$stage, ",")

here <- "reports/presentations/plymouth-october-2026"
out_dir <- file.path(here, if (test) "results-test" else "results")
fit_dir <- file.path(out_dir, "fits")
dir.create(fit_dir, showWarnings = FALSE, recursive = TRUE)

# R reads a script as it executes it, so editing this file during a run
# of several hours could break the run. The script therefore copies itself
# into the results directory and runs the copy.
if (!nzchar(Sys.getenv("PLYMOUTH_FROZEN"))) {
  frozen <- file.path(out_dir, "prepare_results.R")
  file.copy(file.path(here, "prepare_results.R"), frozen, overwrite = TRUE)
  status <- system2("Rscript", c(frozen, args), env = "PLYMOUTH_FROZEN=1")
  quit(status = status)
}
trials_file <- file.path(out_dir, "trials_decimated.parquet")
masked_file <- "data/main/merged_eeg_behaviour_data_masked.parquet"

electrodes <- c("POz", "Oz", "Pz", "PO7", "PO8")
# Basis width multipliers (coarse, dense), estimated once per electrode
# with B1 and fixed since (analysis/rbf_stan/models.qmd).
width_mult <- list(POz = c(0.624, 1.03), Oz = c(0.649, 0.903),
                   Pz = c(0.635, 1.006), PO7 = c(0.684, 0.723),
                   PO8 = c(0.644, 0.969))

say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")

# Provenance: the commit and the package versions behind these results.
git_head <- tryCatch({
  h <- readLines(".git/HEAD")
  if (str_starts(h, "ref: ")) readLines(file.path(".git", str_remove(h, "ref: "))) else h
}, error = function(e) NA_character_)
writeLines(c(str_c("commit ", git_head), str_c("started ", Sys.time()),
             str_c("arguments ", paste(args, collapse = " ")), "",
             capture.output(sessionInfo())),
           file.path(out_dir, "provenance.txt"))

# Trial order within blocks, from the trial cache: the first trial of each
# block, and the previous trial's log ratio where the immediately
# preceding trial is in the data. Trial numbers run from 1 to 50 or 51 to
# 100 within a block, so the first trial of a block is the one with
# (trials - 1) %% 50 == 0. fit_rbf_multilevel.R instead flags the first
# trial present in the data, which differs only where AutoReject removed
# the true first trial, and those trials have no preceding trial in the
# data, so the model drops them anyway.
read_trials <- function() {
  tr <- arrow::read_parquet(trials_file) |>
    mutate(log_ratio = log(1 / ratio), item = str_c(left_size, "_", right_size))
  order_info <- tr |>
    distinct(subject, block, trials, trial_id, log_ratio) |>
    arrange(subject, block, trials) |>
    group_by(subject, block) |>
    mutate(first_of_block = (trials - 1) %% 50 == 0,
           prev_log_ratio = if_else(trials - lag(trials) == 1,
                                    lag(log_ratio), NA_real_)) |>
    ungroup() |>
    select(trial_id, first_of_block, prev_log_ratio)
  tr |> left_join(order_info, by = "trial_id")
}

# Stage: trials ----------------------------------------------------------------

if ("trials" %in% stages) {
  say("caching decimated trials")
  status <- system2("Rscript", c("analysis/rbf_stan/prepare_trials.R", trials_file))
  stopifnot(status == 0)
}

# Stage: fits (launched in the background) -------------------------------------

fit_jobs <- NULL
if ("fits" %in% stages) {
  # Compile once, from a frozen copy of the model and the driver, so that
  # five processes do not compile the same file at once and so that
  # editing either while the fits run cannot change them.
  file.copy("analysis/rbf_stan/rbf_multilevel.stan",
            file.path(fit_dir, "rbf_multilevel.stan"), overwrite = TRUE)
  file.copy("analysis/rbf_stan/fit_rbf_multilevel.R",
            file.path(fit_dir, "fit_rbf_multilevel.R"), overwrite = TRUE)
  say("compiling the model")
  cmdstanr::cmdstan_model(file.path(fit_dir, "rbf_multilevel.stan"))

  fit_args <- function(el) {
    c(file.path(fit_dir, "fit_rbf_multilevel.R"),
      "model=b4", str_c("electrode=", el),
      str_c("ntrial=", if (test) 20 else 0),
      str_c("fc=", width_mult[[el]][1]), str_c("fd=", width_mult[[el]][2]),
      "kd=31", "dw=600", "ks=all", "adapt=0.9", "metric=dense_e",
      "fixeff=1", "nofirst=1", "prevratio=1",
      if (test) c("warmup=150", "sampling=100"),
      str_c("stanfile=", file.path(fit_dir, "rbf_multilevel.stan")),
      str_c("trials=", trials_file), str_c("outdir=", fit_dir))
  }
  say("launching B4 fits at", paste(electrodes, collapse = ", "))
  fit_jobs <- map(set_names(electrodes), function(el) {
    parallel::mcparallel(
      system2("Rscript", fit_args(el),
              stdout = file.path(fit_dir, str_c("fit_", el, ".log")),
              stderr = file.path(fit_dir, str_c("fit_", el, ".log"))),
      name = el)
  })
}

# Stage: behaviour -------------------------------------------------------------

if ("behaviour" %in% stages) {
  say("behaviour")
  beh <- read_csv("data/main/combined_behaviour_data.csv", show_col_types = FALSE) |>
    filter(type == "dots", sb_trials != 1) |>
    mutate(accuracy = as.numeric(accuracy),
           ratio = pmax(left_size, right_size) / pmin(left_size, right_size),
           log_ratio = log(ratio))
  # Ratio fifths over all trials, labelled by their ratio range.
  breaks <- quantile(beh$log_ratio, seq(0, 1, 0.2))
  beh <- beh |>
    mutate(ratio_bin = cut(log_ratio, breaks, include.lowest = TRUE, labels = FALSE))
  bin_labels <- beh |>
    summarise(label = sprintf("%.2f-%.2f", min(ratio), max(ratio)),
              mid = median(ratio), .by = ratio_bin) |>
    arrange(ratio_bin)
  by_subject_bin <- beh |>
    summarise(accuracy = mean(accuracy), median_rt = median(rt), n = n(),
              .by = c(subject, ratio_bin))
  by_subject <- beh |>
    summarise(accuracy = mean(accuracy), median_rt = median(rt), n = n(),
              age = first(age), gender = first(gender), .by = subject)
  slopes <- beh |>
    group_by(subject) |>
    summarise(slope = coef(glm(accuracy ~ log_ratio, family = binomial))[2])
  # Accuracy as a function of ratio for each subject, from the same
  # logistic regression, on a grid, to show individual psychometric curves.
  grid <- tibble(ratio = seq(min(beh$ratio), max(beh$ratio), length.out = 50))
  curves <- beh |>
    group_by(subject) |>
    group_modify(function(d, key) {
      f <- glm(accuracy ~ log_ratio, family = binomial, data = d)
      grid |> mutate(p = predict(f, tibble(log_ratio = log(ratio)), type = "response"))
    }) |>
    ungroup()
  saveRDS(list(bin_labels = bin_labels, by_subject_bin = by_subject_bin,
               by_subject = by_subject, slopes = slopes, curves = curves,
               n_trials = nrow(beh)),
          file.path(out_dir, "behaviour.rds"))
}

# Stage: erp, grand averages ---------------------------------------------------

if ("erp" %in% stages) {
  say("grand averages at every electrode")
  # Aggregated inside arrow, so the multi-gigabyte file is never loaded
  # whole. Each channel's mean excludes only its own masked values. The
  # first trial of each block (sb_trials == 1) is excluded.
  schema_names <- names(arrow::open_dataset(masked_file)$schema)
  channels <- schema_names[which(schema_names == "Fp1"):which(schema_names == "O2")]
  means <- set_names(map(channels, \(ch) rlang::expr(mean(!!rlang::sym(ch), na.rm = TRUE))),
                     channels)
  grand <- arrow::open_dataset(masked_file) |>
    filter(type == "dots", sb_trials != 1) |>
    group_by(time) |>
    summarise(!!!means) |>
    collect() |>
    arrange(time) |>
    pivot_longer(-time, names_to = "channel", values_to = "voltage")

  # Subject averages at the five posterior electrodes, from the trial cache.
  tr <- read_trials() |> filter(!first_of_block)
  subject_avg <- tr |>
    pivot_longer(all_of(electrodes), names_to = "channel", values_to = "voltage") |>
    filter(!is.na(voltage)) |>
    summarise(voltage = mean(voltage), n = n(), .by = c(subject, channel, time))
  saveRDS(list(grand = grand, channels = channels, subject_avg = subject_avg),
          file.path(out_dir, "erp.rds"))
}

# Stage: raw, model-free difference waves --------------------------------------

# Clusters of adjacent timepoints whose statistic exceeds a threshold in
# absolute value, with the same sign, and their mass (sum of statistics).
clusters_of <- function(stat, thresh) {
  s <- sign(stat) * (abs(stat) > thresh)
  r <- rle(s)
  ends <- cumsum(r$lengths)
  starts <- ends - r$lengths + 1
  keep <- r$values != 0
  tibble(start = starts[keep], end = ends[keep],
         mass = map2_dbl(starts[keep], ends[keep], \(a, b) sum(stat[a:b])))
}

# Cluster-based permutation test (Maris and Oostenveld, 2007) on a
# subjects x time matrix. For a within-subject difference (paired), signs
# are flipped at random per subject. For a between-subject comparison,
# group labels are permuted. The statistic is t, the cluster-forming
# threshold is the two-sided 5% t quantile, and each observed cluster's
# p-value is the proportion of permutations whose largest absolute cluster
# mass is at least as large.
cluster_test <- function(M, group = NULL, n_perm = 2000) {
  tstat <- function(M, group) {
    if (is.null(group)) {
      colMeans(M) / (apply(M, 2, sd) / sqrt(nrow(M)))
    } else {
      a <- M[group, , drop = FALSE]; b <- M[!group, , drop = FALSE]
      (colMeans(a) - colMeans(b)) /
        sqrt(apply(a, 2, var) / nrow(a) + apply(b, 2, var) / nrow(b))
    }
  }
  df <- if (is.null(group)) nrow(M) - 1 else nrow(M) - 2
  thresh <- qt(0.975, df)
  obs <- clusters_of(tstat(M, group), thresh)
  null_max <- replicate(n_perm, {
    if (is.null(group)) {
      Mp <- M * sample(c(-1, 1), nrow(M), replace = TRUE)
      cl <- clusters_of(tstat(Mp, NULL), thresh)
    } else {
      cl <- clusters_of(tstat(M, sample(group)), thresh)
    }
    if (nrow(cl) == 0) 0 else max(abs(cl$mass))
  })
  obs |> mutate(p = map_dbl(mass, \(m) mean(null_max >= abs(m))))
}

if ("raw" %in% stages) {
  say("raw difference waves and cluster permutation tests")
  set.seed(20261014)
  tr <- read_trials() |> filter(!first_of_block)
  subj_acc <- tr |>
    distinct(subject, trial_id, accuracy) |>
    summarise(accuracy = mean(accuracy), .by = subject) |>
    mutate(logit_acc = qlogis(accuracy),
           higher = logit_acc >= median(logit_acc))
  ci90 <- function(x) {
    m <- mean(x); se <- sd(x) / sqrt(length(x)); q <- qt(0.95, length(x) - 1)
    tibble(mean = m, lo = m - q * se, hi = m + q * se)
  }
  raw <- map(set_names(electrodes), function(el) {
    d <- tr |> select(subject, trial_id, log_ratio, time, v = all_of(el)) |>
      filter(!is.na(v))
    time <- sort(unique(d$time))

    # Ratio: easiest third minus hardest third of each subject's trials.
    thirds <- d |>
      group_by(subject) |>
      mutate(third = ntile(log_ratio, 3)) |>
      ungroup() |>
      filter(third %in% c(1, 3)) |>
      summarise(v = mean(v), .by = c(subject, time, third)) |>
      pivot_wider(names_from = third, values_from = v, names_prefix = "t") |>
      mutate(diff = t3 - t1)
    M_ratio <- thirds |> select(subject, time, diff) |>
      pivot_wider(names_from = time, values_from = diff) |>
      select(-subject) |> as.matrix()
    ratio_wave <- thirds |> summarise(ci90(diff), easy = mean(t3), hard = mean(t1),
                                      .by = time)

    # Accuracy: higher-accuracy minus lower-accuracy half of subjects.
    subj_erp <- d |> summarise(v = mean(v), .by = c(subject, time)) |>
      left_join(subj_acc, by = "subject")
    M_subj <- subj_erp |> select(subject, time, v) |>
      pivot_wider(names_from = time, values_from = v)
    higher <- subj_acc$higher[match(M_subj$subject, subj_acc$subject)]
    M_subj <- M_subj |> select(-subject) |> as.matrix()
    acc_wave <- subj_erp |>
      summarise({
        hi <- v[higher]; lo <- v[!higher]
        tt <- t.test(hi, lo, conf.level = 0.90)
        tibble(mean = mean(hi) - mean(lo), lo = tt$conf.int[1], hi = tt$conf.int[2],
               higher_mean = mean(hi), lower_mean = mean(lo))
      }, .by = time)

    list(ratio = ratio_wave |> mutate(electrode = el),
         accuracy = acc_wave |> mutate(electrode = el),
         ratio_clusters = cluster_test(M_ratio) |>
           mutate(electrode = el, start = time[start], end = time[end]),
         accuracy_clusters = cluster_test(M_subj, group = higher) |>
           mutate(electrode = el, start = time[start], end = time[end]))
  })
  saveRDS(list(ratio = map_dfr(raw, "ratio"), accuracy = map_dfr(raw, "accuracy"),
               ratio_clusters = map_dfr(raw, "ratio_clusters"),
               accuracy_clusters = map_dfr(raw, "accuracy_clusters"),
               subj_acc = subj_acc),
          file.path(out_dir, "raw.rds"))
}

# Stage: items, ratio with stimulus pairs as the unit --------------------------

if ("items" %in% stages) {
  say("item-level analysis of ratio")
  # Every participant saw the same fixed sequence of stimulus pairs, so for
  # ratio the pair, not the trial, is the unit of evidence. At each
  # electrode and timepoint, lmer(v ~ x + xp + (1 | subject) + (1 | item))
  # on single trials, with x and xp the standardised log ratio of the
  # trial and of the previous trial, crossed random intercepts for
  # subjects and pairs (Clark, 1973). Intervals use t on 42 df (44 pairs,
  # less two predictors).
  tr <- read_trials() |>
    filter(!first_of_block, !is.na(prev_log_ratio))
  tr <- tr |>
    mutate(x = (log_ratio - mean(log_ratio)) / sd(log_ratio),
           xp = (prev_log_ratio - mean(log_ratio)) / sd(log_ratio))
  n_items <- n_distinct(tr$item)
  items <- parallel::mclapply(electrodes, function(el) {
    d <- tr |> select(subject, item, time, x, xp, v = all_of(el)) |> filter(!is.na(v))
    d |>
      group_by(time) |>
      group_modify(function(g, key) {
        f <- lme4::lmer(v ~ x + xp + (1 | subject) + (1 | item), data = g,
                        control = lme4::lmerControl(calc.derivs = FALSE))
        tibble(est = lme4::fixef(f)[["x"]], se = sqrt(as.matrix(vcov(f))[2, 2]))
      }) |>
      ungroup() |>
      mutate(electrode = el)
  }, mc.cores = 4)
  stopifnot(!map_lgl(items, inherits, "try-error"))
  items <- bind_rows(items) |>
    mutate(df = n_items - 2,
           lo = est - qt(0.95, df) * se, hi = est + qt(0.95, df) * se)
  saveRDS(list(items = items, n_items = n_items,
               log_ratio_sd = sd(tr$log_ratio), log_ratio_mean = mean(tr$log_ratio)),
          file.path(out_dir, "items.rds"))
}

# Stage: child, behaviour and grand averages ------------------------------------

child_masked <- "data/child/merged_eeg_behaviour_data_masked.parquet"
child_beh_file <- "data/child/combined_behaviour_data.csv"
if ("child" %in% stages) {
  if (!file.exists(child_masked) || !file.exists(child_beh_file)) {
    say("skipping child: preprocessed child data not found")
  } else {
    say("child behaviour and grand averages")
    # As for the adults: dots trials, first trial of each block excluded.
    cbeh <- read_csv(child_beh_file, show_col_types = FALSE) |>
      filter(type == "dots", sb_trials != 1) |>
      mutate(accuracy = as.numeric(accuracy),
             ratio = pmax(left_size, right_size) / pmin(left_size, right_size),
             log_ratio = log(ratio))
    by_subject <- cbeh |>
      summarise(accuracy = mean(accuracy), median_rt = median(rt, na.rm = TRUE),
                n = n(), age = first(age), gender = first(gender), .by = subject)
    grid <- tibble(ratio = seq(min(cbeh$ratio), max(cbeh$ratio), length.out = 50))
    curves <- cbeh |>
      group_by(subject) |>
      group_modify(function(d, key) {
        f <- glm(accuracy ~ log_ratio, family = binomial, data = d)
        grid |> mutate(p = predict(f, tibble(log_ratio = log(ratio)), type = "response"))
      }) |>
      ungroup()
    slopes <- cbeh |>
      group_by(subject) |>
      summarise(slope = coef(glm(accuracy ~ log_ratio, family = binomial))[2])

    schema_names <- names(arrow::open_dataset(child_masked)$schema)
    channels <- schema_names[which(schema_names == "Fp1"):which(schema_names == "O2")]
    means <- set_names(map(channels, \(ch) rlang::expr(mean(!!rlang::sym(ch), na.rm = TRUE))),
                       channels)
    grand <- arrow::open_dataset(child_masked) |>
      filter(type == "dots", sb_trials != 1) |>
      group_by(time) |>
      summarise(!!!means) |>
      collect() |>
      arrange(time) |>
      pivot_longer(-time, names_to = "channel", values_to = "voltage")
    subject_avg <- arrow::open_dataset(child_masked) |>
      filter(type == "dots", sb_trials != 1) |>
      select(subject, time, all_of(electrodes)) |>
      collect() |>
      pivot_longer(all_of(electrodes), names_to = "channel", values_to = "voltage") |>
      filter(!is.na(voltage)) |>
      summarise(voltage = mean(voltage), n = n(), .by = c(subject, channel, time))
    # Trials per child with usable EEG at POz, after AutoReject and masking.
    usable <- arrow::open_dataset(child_masked) |>
      filter(type == "dots", sb_trials != 1, time == 0) |>
      select(subject, POz) |>
      collect() |>
      summarise(n_trials = n(), n_usable = sum(!is.na(POz)), .by = subject)
    saveRDS(list(by_subject = by_subject, curves = curves, slopes = slopes,
                 n_trials = nrow(cbeh), grand = grand, subject_avg = subject_avg,
                 usable = usable),
            file.path(out_dir, "child.rds"))
  }
}

# Wait for the fits ------------------------------------------------------------

if (!is.null(fit_jobs)) {
  say("waiting for the fits")
  status <- parallel::mccollect(fit_jobs)
  say("fits finished, exit status", paste(names(status), unlist(status), collapse = ", "))
  if (any(unlist(status) != 0)) stop("a fit failed; see the logs in ", fit_dir)
}

# Stage: models, summaries of the fits -----------------------------------------

if ("models" %in% stages) {
  say("summarising the fits")
  band <- function(M) {
    tibble(q5 = apply(M, 2, quantile, 0.05), q50 = apply(M, 2, median),
           q95 = apply(M, 2, quantile, 0.95))
  }
  models <- map(set_names(electrodes), function(el) {
    f <- list.files(fit_dir, pattern = str_c("^ml_b4_", el, "_.*_draws\\.rds$"),
                    full.names = TRUE)
    stopifnot(length(f) == 1)
    res <- readRDS(f)
    summ <- readRDS(str_replace(f, "_draws\\.rds$", "_summary.rds"))
    dm <- posterior::as_draws_matrix(res$draws)
    time <- res$time
    T <- length(time)
    J <- length(res$subjects)
    col <- function(v) dm[, str_c(v, "[", seq_len(T), "]")]
    pop <- col("mu_pop")
    es <- col("effect_subj")
    et <- col("effect_trial")
    ep <- dm[, str_c("effect_extra[", seq_len(T), ",1]")]
    sc <- res$pred_scale
    # Subject waveforms, one T x J matrix per draw, stored column-major as
    # mu_subj[t, j].
    subj_names <- str_c("mu_subj[", rep(seq_len(T), J), ",", rep(seq_len(J), each = T), "]")
    subj <- dm[, subj_names]
    between_sd <- t(apply(subj, 1, function(x) apply(matrix(x, T, J), 1, sd)))
    subj_median <- matrix(apply(subj, 2, median), T, J)
    acc_lo <- plogis(sc$logit_acc_mean - sc$logit_acc_sd)
    acc_hi <- plogis(sc$logit_acc_mean + sc$logit_acc_sd)
    list(
      population = band(pop) |> mutate(time = time, data = res$subject_mean),
      effects = bind_rows(
        band(es) |> mutate(effect = "accuracy", time = time),
        band(et) |> mutate(effect = "ratio", time = time),
        band(ep) |> mutate(effect = "previous ratio", time = time)
      ),
      predicted_accuracy = bind_rows(
        band(pop - es) |> mutate(level = "lower", accuracy = acc_lo, time = time),
        band(pop + es) |> mutate(level = "higher", accuracy = acc_hi, time = time)
      ),
      between_sd = band(between_sd) |> mutate(time = time),
      subjects = as_tibble(subj_median, .name_repair = ~ res$subjects) |>
        mutate(time = time) |>
        pivot_longer(-time, names_to = "subject", values_to = "fitted"),
      a_subj = tibble(subject = res$subjects, a = res$a_subj),
      diagnostics = summ$diagnostics,
      parameters = summ$summary,
      pred_scale = as_tibble(sc)
    ) |> map(\(d) mutate(d, electrode = el))
  })
  out <- map(set_names(names(models[[1]])), \(nm) map_dfr(models, nm))
  saveRDS(out, file.path(out_dir, "models.rds"))
}

say("done")
