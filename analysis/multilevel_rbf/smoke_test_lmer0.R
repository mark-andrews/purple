# Smoke test M0: subject variability only, in lme4.
#
# First of a step-by-step sequence, replacing the earlier combined
# smoke_test_lmer.R draft, which jumped between the full model and its
# two decompositions out of order. This script has exactly one model:
# each subject's ERP averaged over all their trials, no trial-level
# variability at all, subject as the only random effect. Later steps
# add trial variability (one subject, all trials) and then combine the
# two, each in their own script.
#
# As before: a fixed-basis regression (RBF centers and width supplied
# as data, not estimated) is linear in its weights, so this is an
# ordinary linear mixed model with the basis-function values as both
# fixed-effect predictors and random-slope terms, the same trick as
# `gam_script2.R`'s spline example. `(b1 + ... + bK || subject)` uses
# uncorrelated random slopes: the target Stan model
# (`m1_3_subject_trial_single_electrode.stan`) gives each basis function
# its own independent tau, no covariance between basis dimensions, so
# `||` is the closer analog, and it is also more likely to converge than
# a full covariance matrix would be.
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

# One row per subject per time point: average over that subject's
# trials, discarding trial-level variability entirely. All subjects, not
# a subset: this collapses the data enough that including everyone costs
# nothing, and having only a handful of subjects to estimate K+1
# independent random-slope variances from is what produced a degenerate
# Hessian in the earlier draft.
eeg_df_subject_avg <- eeg_df |>
  summarise(voltage = mean(voltage), .by = c(subject, time))

# Basis functions -----------------------------------------------------------

# Two basis-function densities, not one. The first pass's 8 evenly spaced
# centers spanning the whole epoch stay as they are: they're kept, not
# replaced, so this section only adds to what was already there. Added
# to them, a second, denser and narrower set of 8 centers confined to
# 0-300ms, where P1, N1, and P2p all sit and where the coarse set alone
# under-resolved the response and flattened its peak (see the 26 August
# logbook entry on the first smoke_test_lmer0.R run). Centers and widths
# for both sets are still fixed, not estimated, same as before: adding
# more of them doesn't reopen the overfitting question, it's still
# ordinary linear regression on a richer, but still fixed, set of
# predictors. Neither the count nor the placement is being tuned or
# optimized here, just moved from "spread evenly" to "concentrated where
# the signal is known to be."
K_coarse <- 8
K_dense <- 8
dense_window <- c(0, 300)

centers_coarse <- seq(
  min(eeg_df_subject_avg$time),
  max(eeg_df_subject_avg$time),
  length.out = K_coarse
)
width_coarse <- diff(centers_coarse)[1]

centers_dense <- seq(dense_window[1], dense_window[2], length.out = K_dense)
width_dense <- diff(centers_dense)[1]

centers <- c(centers_coarse, centers_dense)
width <- c(rep(width_coarse, K_coarse), rep(width_dense, K_dense))
K <- length(centers)

# `width` is now one value per center, not a single value shared by all
# of them, so each basis function is paired with its own width (mapply)
# rather than every center broadcasting the same scalar (sapply, as
# before). Passing a single scalar `width` still works exactly as
# before, recycled across all centers, so this is a superset of the
# previous behaviour, not a break from it.
rbf_design_matrix <- function(x, centers, width) {
  mapply(function(ctr, w) exp(-0.5 * (x - ctr)^2 / w^2), centers, width)
}

eeg_df_subject_avg <- eeg_df_subject_avg |>
  bind_cols(
    rbf_design_matrix(eeg_df_subject_avg$time, centers, width) |>
      as.data.frame() |>
      rename_with(~ str_c("b", seq_along(.)))
  )

# Model -------------------------------------------------------------------

basis_terms <- str_c("b", 1:K)
fixed_formula <- str_c("voltage ~ ", str_c(basis_terms, collapse = " + "))
random_formula <- str_c(
  " + (",
  str_c(basis_terms, collapse = " + "),
  " || subject)"
)

# bobyqa: lme4's own suggested first step for "unable to evaluate scaled
# gradient" warnings, standard, not a hack. Left in as a cheap safeguard,
# though fitting on all subjects rather than a small subset is what
# actually resolved the earlier convergence failure.
# Running time: Approximately 240 seconds
M0 <- lmer(
  as.formula(str_c(fixed_formula, random_formula)),
  data = eeg_df_subject_avg,
  control = lmerControl(optimizer = "bobyqa")
)
summary(M0)

# Diagnostics ---------------------------------------------------------------

# Which basis functions actually carry subject-level variability, worth
# a look before trusting the plots below.
print(VarCorr(M0), comp = "Std.Dev.")

eeg_fitted <- eeg_df_subject_avg |>
  mutate(
    fitted_subject = predict(M0),
    fitted_population = predict(M0, re.form = NA)
  )

# 1. Population-level (fixed-effect only) fitted curve against the grand
# average: does the mean waveform shape look right.
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
  ggtitle(str_c(electrode, ": grand average (black) vs population fit (red)"))
ggsave(str_c("tmp/smoke_test_lmer0_", electrode, "_population.png"))

# 2. All subjects' fitted curves overlaid on the population fit: the
# between-subject variability directly, rather than one subject at a
# time.
ggplot() +
  geom_line(
    data = eeg_fitted,
    mapping = aes(x = time, y = fitted_subject, group = subject),
    colour = "black",
    alpha = 0.3
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
    ": subject fits (black) around population fit (red)"
  ))
ggsave(str_c("tmp/smoke_test_lmer0_", electrode, "_subject_overlay.png"))

# 3. Subject-level fit against each subject's own raw average, one panel
# per subject, for closer inspection.
eeg_fitted |>
  ggplot(aes(x = time)) +
  geom_line(aes(y = voltage), colour = "black", alpha = 0.5) +
  geom_line(aes(y = fitted_subject), colour = "red") +
  facet_wrap(~subject) +
  theme_minimal() +
  ggtitle(str_c(electrode, ": subject average (black) vs subject fit (red)"))
ggsave(str_c("tmp/smoke_test_lmer0_", electrode, "_subject_facet.png"))

# tmp/, not kept long-term, just so the fit survives this session for
# further inspection without refitting.
saveRDS(M0, "tmp/smoke_test_lmer0_M0.rds")
