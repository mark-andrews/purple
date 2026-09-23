# Smoke test M1: trial variability only, one subject, in lme4.
#
# Second of the step-by-step sequence started in smoke_test_lmer0.R.
# One randomly chosen subject, all of their trials at full trial-level
# resolution, no averaging over trials this time, trial as the only
# random effect. No subject term: there is only one subject in this
# script's data.
#
# Same basis-function setup as smoke_test_lmer0.R, carried over
# unchanged: 8 coarse centers spanning the whole epoch plus 8 narrower
# centers confined to 0-300ms, since that combination is what the
# earlier script established resolves the response adequately at this
# electrode. Centers and widths are fixed constants here, computed from
# the full, unfiltered epoch time range before subsetting to one
# subject, not recomputed per subject, since they're meant to be the
# same basis regardless of whose data is passed through it.
#
# `(b1 + ... + bK || trial)` uses uncorrelated random slopes, for the
# same reason as before: `analysis/rbf_stan/rbf_multilevel.stan`
# gives each basis function its own independent tau, no covariance
# between basis dimensions.
#
# Must be run inside the Podman devcontainer (or equivalent): the host
# has no `arrow` installation, per readme.md.

library(tidyverse)
library(lmerTest)

set.seed(10101)

electrode <- "POz"

# Data ------------------------------------------------------------------

eeg_df <-
  arrow::read_parquet(
    "data/main/merged_eeg_behaviour_data_masked.parquet"
  ) |>
  filter(type == "dots") |>
  select(subject, block, trials, time, all_of(electrode)) |>
  drop_na() |>
  rename(voltage = all_of(electrode))

# One subject, chosen at random, at full trial resolution: every trial,
# every time point, nothing averaged away.
one_subject <- sample(unique(eeg_df$subject), size = 1)

eeg_df_one_subject <- eeg_df |>
  filter(subject == one_subject) |>
  mutate(trial_id = interaction(block, trials, drop = TRUE))

# Basis functions -----------------------------------------------------------

# Unchanged from smoke_test_lmer0.R: same two densities, same window,
# computed from the full epoch's time range before subsetting to one
# subject, so this is the same fixed basis regardless of which subject
# gets picked.
K_coarse <- 8
K_dense <- 8
dense_window <- c(0, 300)

centers_coarse <- seq(min(eeg_df$time), max(eeg_df$time), length.out = K_coarse)
width_coarse <- diff(centers_coarse)[1]

centers_dense <- seq(dense_window[1], dense_window[2], length.out = K_dense)
width_dense <- diff(centers_dense)[1]

centers <- c(centers_coarse, centers_dense)
width <- c(rep(width_coarse, K_coarse), rep(width_dense, K_dense))
K <- length(centers)

rbf_design_matrix <- function(x, centers, width) {
  mapply(function(ctr, w) exp(-0.5 * (x - ctr)^2 / w^2), centers, width)
}

eeg_df_one_subject <- eeg_df_one_subject |>
  bind_cols(
    rbf_design_matrix(eeg_df_one_subject$time, centers, width) |>
      as.data.frame() |>
      rename_with(~ str_c("b", seq_along(.)))
  )

# Model -------------------------------------------------------------------

# The fixed effect uses all 16 basis functions, so the population (here,
# this one subject's own trial-average) mean curve keeps the resolution
# established in smoke_test_lmer0.R. The random effect, trial deviation
# from that mean, uses only the 8 coarse basis functions, not all 16:
# nothing requires the two design matrices to match, a random intercept
# is already the same idea taken to its zero-basis-function extreme.
# This is a deliberate response to the single-trial overfitting seen in
# the first run of this script: the 8 dense, narrow centers in 0-300ms
# are exactly the ones capable of representing the fine, jagged
# structure individual trial fits were chasing, so restricting trial
# deviations to the coarse set removes that capacity directly, rather
# than shrinking flexibility everywhere by an arbitrary amount. Centers
# and widths are still fixed constants either way, so this is still
# ordinary linear regression on two differently sized, but still fixed,
# sets of predictors.
basis_terms <- str_c("b", 1:K)
random_terms <- basis_terms[1:K_coarse]

fixed_formula <- str_c("voltage ~ ", str_c(basis_terms, collapse = " + "))
random_formula <- str_c(
  " + (",
  str_c(random_terms, collapse = " + "),
  " || trial_id)"
)

# bobyqa as before. Half as many random-slope terms per trial as the
# first run, so expect this to be noticeably faster than the 745 seconds
# that run took, though still likely slower than smoke_test_lmer0.R's
# 240, given the much larger number of rows.
M1 <- lmer(
  as.formula(str_c(fixed_formula, random_formula)),
  data = eeg_df_one_subject,
  control = lmerControl(optimizer = "bobyqa")
)
summary(M1)

# Diagnostics ---------------------------------------------------------------

# Which basis functions carry trial-level variability for this subject.
print(VarCorr(M1), comp = "Std.Dev.")

eeg_fitted <- eeg_df_one_subject |>
  mutate(
    fitted_trial = predict(M1),
    fitted_population = predict(M1, re.form = NA)
  )

# 1. Fixed-effect (trial-averaged) fitted curve against this subject's
# own raw trial average: should recover roughly the same curve
# smoke_test_lmer0.R's facet plot showed for this subject, now built up
# from single trials rather than a pre-averaged input.
eeg_fitted |>
  summarise(
    voltage = mean(voltage),
    fitted_population = mean(fitted_population),
    .by = time
  ) |>
  ggplot(aes(x = time)) +
  geom_line(aes(y = voltage), colour = "black", alpha = 0.5) +
  geom_line(aes(y = fitted_population), colour = "red") +
  theme_minimal() +
  ggtitle(str_c(
    electrode,
    " ",
    one_subject,
    ": trial average (black) vs fixed-effect fit (red)"
  ))
ggsave(str_c(
  "tmp/smoke_test_lmer1_",
  electrode,
  "_",
  one_subject,
  "_population.png"
))

# 2. Every trial's fitted curve overlaid on the fixed-effect curve: the
# trial-to-trial variability directly.
ggplot() +
  geom_line(
    data = eeg_fitted,
    mapping = aes(x = time, y = fitted_trial, group = trial_id),
    colour = "black",
    alpha = 0.05
  ) +
  geom_line(
    data = distinct(eeg_fitted, time, fitted_population),
    mapping = aes(x = time, y = fitted_population),
    colour = "red",
    linewidth = 1
  ) +
  theme_minimal() +
  ggtitle(str_c(
    electrode,
    " ",
    one_subject,
    ": trial fits (black) around fixed-effect fit (red)"
  ))
ggsave(str_c(
  "tmp/smoke_test_lmer1_",
  electrode,
  "_",
  one_subject,
  "_trial_overlay.png"
))

# 3. A handful of individual trials against their own raw data, for
# closer inspection: all trials faceted would be unreadable at this
# subject's trial count, so a random sample of 12 stands in for it.
sample_trials <- sample(unique(eeg_fitted$trial_id), size = 12)

eeg_fitted |>
  filter(trial_id %in% sample_trials) |>
  ggplot(aes(x = time)) +
  geom_line(aes(y = voltage), colour = "black", alpha = 0.5) +
  geom_line(aes(y = fitted_trial), colour = "red") +
  facet_wrap(~trial_id) +
  theme_minimal() +
  ggtitle(str_c(
    electrode,
    " ",
    one_subject,
    ": single trials (black) vs trial fit (red), 12 sampled trials"
  ))
ggsave(str_c(
  "tmp/smoke_test_lmer1_",
  electrode,
  "_",
  one_subject,
  "_trial_facet.png"
))

# tmp/, not kept long-term, just so the fit survives this session for
# further inspection without refitting.
saveRDS(M1, "tmp/smoke_test_lmer1_M1.rds")
