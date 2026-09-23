# Smoke test M2: subject and trial variability together, in lme4.
#
# Third of the step-by-step sequence: smoke_test_lmer0.R (subject only,
# all subjects, trials pre-averaged away) and smoke_test_lmer1.R (trial
# only, one subject, full trial resolution) combined into one model with
# both crossed random effects.
#
# Two earlier attempts here cut the number of subjects as well as
# trials, to keep runtime down, and that turned out to be the wrong
# dimension to cut. Reducing subjects to 15 while trying to estimate a
# real subject-level basis reproduced smoke_test_lmer0.R's original
# degenerate-Hessian failure (too few groups for the number of variance
# components) at K_subject = 4, and produced numerically unstable
# nonsense, near-straight-line "fits" that were really just collinear
# basis functions blowing up, at K_subject = 2. Falling back further to
# a plain random intercept for subject avoided both failures but is
# uselessly rigid: an intercept can only shift the shared curve up or
# down, never reshape it, so of course every subject's "fit" looked like
# the same curve moved vertically, that's the only thing the model was
# mathematically capable of producing.
#
# The actual fix isn't a smaller subject-level basis, it's not cutting
# subjects at all. smoke_test_lmer0.R already showed all 47 subjects
# comfortably support an 8-term coarse subject-level random effect; the
# problem was only ever the artificial 15-subject cut made for speed.
# Trial count is the safe dimension to cut instead, since the number of
# trial groups is subjects x trials-per-subject and stays large
# regardless of how many trials per subject are kept. So this version
# keeps every subject and subsets trials only, and gives both random
# effects the same 8 coarse basis functions already validated separately
# in smoke_test_lmer0.R and smoke_test_lmer1.R, real shape flexibility
# on both, nothing reduced to an intercept.
#
# This will be slower than anything tried so far, genuinely, not a
# guess: full subjects x 20 trials each x ~1230 timepoints is around 1.4
# million rows, several times any single run before this one. That cost
# is the actual trade-off for real flexibility at both levels
# simultaneously, and part of why this project was always going to move
# past lme4 to a properly specified Bayesian model in Stan, where a
# prior on tau_subject and tau_trial can shrink a weakly-identified
# component smoothly instead of forcing a choice between crashing and
# cutting flexibility. This script is the last thing worth trying in
# lme4 before that, not a final answer.
#
# The fixed effect is untouched: all 16 basis functions (8 coarse, 8
# dense in 0-300ms), exactly as validated in smoke_test_lmer0.R.
# Everything below is still fixed centers and widths, not estimated, so
# none of this reopens the overfitting-via-adaptive-basis question,
# only how much of that fixed basis each random effect is allowed to
# use.
#
# Must be run inside the Podman devcontainer (or equivalent): the host
# has no `arrow` installation, per readme.md.

library(tidyverse)
library(lmerTest)

set.seed(10101)

electrode <- "POz"

# Trials only are subsetted now, not subjects. See header comment.
n_trials_per_subject <- 20

# Data ------------------------------------------------------------------

eeg_df <-
  arrow::read_parquet(
    "data/main/merged_eeg_behaviour_data_masked.parquet"
  ) |>
  filter(type == "dots") |>
  select(subject, block, trials, time, all_of(electrode)) |>
  drop_na() |>
  rename(voltage = all_of(electrode))

# Trial id must be globally unique across subjects: block and trials
# alone repeat across subjects.
eeg_df_subset <- eeg_df |>
  mutate(trial_id = interaction(subject, block, trials, drop = TRUE))

# n_trials_per_subject trials per subject, sampled at random. Every
# subject has at least ~55 trials surviving masking (see 26 August
# logbook), comfortably above 20, so this shouldn't run out for anyone
# sampled above.
trials_kept <- eeg_df_subset |>
  distinct(subject, trial_id) |>
  slice_sample(n = n_trials_per_subject, by = subject) |>
  pull(trial_id)

eeg_df_subset <- eeg_df_subset |>
  filter(trial_id %in% trials_kept)

cat(
  "Subset: ",
  n_distinct(eeg_df_subset$subject),
  " subjects, ",
  n_distinct(eeg_df_subset$trial_id),
  " trials, ",
  nrow(eeg_df_subset),
  " rows\n",
  sep = ""
)

# Basis functions -----------------------------------------------------------

# Fixed-effect basis: unchanged from smoke_test_lmer0.R, coarse (8,
# whole epoch) plus dense (8, 0-300ms), computed from the full,
# unfiltered epoch time range, not the subset, so it's the same basis
# regardless of which subjects or trials got sampled.
K_coarse <- 8
K_dense <- 8
dense_window <- c(0, 300)

centers_coarse <- seq(min(eeg_df$time), max(eeg_df$time), length.out = K_coarse)
width_coarse <- diff(centers_coarse)[1]

centers_dense <- seq(dense_window[1], dense_window[2], length.out = K_dense)
width_dense <- diff(centers_dense)[1]

centers_fixed <- c(centers_coarse, centers_dense)
width_fixed <- c(rep(width_coarse, K_coarse), rep(width_dense, K_dense))
K_fixed <- length(centers_fixed)

# Subject and trial random effects both use the same 8 coarse
# fixed-effect columns, the tier already validated separately for each:
# smoke_test_lmer0.R for subject, smoke_test_lmer1.R for trial. No
# separate basis tier for subject this time, and no collinearity risk,
# since these centers and widths are exactly the ones already shown to
# behave well.

rbf_design_matrix <- function(x, centers, width) {
  mapply(function(ctr, w) exp(-0.5 * (x - ctr)^2 / w^2), centers, width)
}

eeg_df_subset <- eeg_df_subset |>
  bind_cols(
    rbf_design_matrix(eeg_df_subset$time, centers_fixed, width_fixed) |>
      as.data.frame() |>
      rename_with(~ str_c("b", seq_along(.)))
  )

# Model -------------------------------------------------------------------

fixed_terms <- str_c("b", 1:K_fixed)
coarse_terms <- fixed_terms[1:K_coarse] # the 8 coarse fixed-effect columns
subject_terms <- coarse_terms
trial_terms <- coarse_terms

fixed_formula <- str_c("voltage ~ ", str_c(fixed_terms, collapse = " + "))
random_formula <- str_c(
  " + (",
  str_c(subject_terms, collapse = " + "),
  " || subject)",
  " + (",
  str_c(trial_terms, collapse = " + "),
  " || trial_id)"
)

# This is expected to be the slowest run yet, around 1.4 million rows
# with two crossed 8-term random effects (see header comment). If it
# runs for a long time with no sign of finishing, stop it and cut
# n_trials_per_subject further rather than waiting it out; cutting
# subjects instead is what caused the last two failures.
system.time({
  M2 <- lmer(
    as.formula(str_c(fixed_formula, random_formula)),
    data = eeg_df_subset,
    control = lmerControl(optimizer = "bobyqa")
  )
})
summary(M2)

# Diagnostics ---------------------------------------------------------------

print(VarCorr(M2), comp = "Std.Dev.")

# Three predictions: population (fixed effect only), subject (fixed
# effect plus subject deviation, trial excluded), and full (both). The
# subject-only prediction needs re.form to name exactly the subject
# random-effect term as it appears in the fitted model, not just
# `~subject`, for lme4 to know which of the two crossed terms to keep.
subject_re_formula <- as.formula(str_c(
  "~ (",
  str_c(subject_terms, collapse = " + "),
  " || subject)"
))

eeg_fitted <- eeg_df_subset |>
  mutate(
    fitted_population = predict(M2, re.form = NA),
    fitted_subject = predict(M2, re.form = subject_re_formula),
    fitted_full = predict(M2)
  )

# 1. Population-level fit against the grand average, all subjects, 20
# trials each (compare against smoke_test_lmer0.R's full-data version).
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
    ": grand average (black) vs population fit (red), ",
    n_trials_per_subject,
    " trials/subject"
  ))
ggsave(str_c("tmp/smoke_test_lmer2_", electrode, "_population.png"))

# 2. Subject-level fits (trial excluded) against each subject's own raw
# average, one panel per subject: the direct counterpart of
# smoke_test_lmer0.R's facet plot, now with a trial random effect also
# in the model, and built from a 20-trial subset rather than every trial.
eeg_fitted |>
  summarise(
    voltage = mean(voltage),
    fitted_subject = mean(fitted_subject),
    .by = c(subject, time)
  ) |>
  ggplot(aes(x = time)) +
  geom_line(aes(y = voltage), colour = "black", alpha = 0.5) +
  geom_line(aes(y = fitted_subject), colour = "red") +
  facet_wrap(~subject) +
  theme_minimal() +
  ggtitle(str_c(electrode, ": subject average (black) vs subject fit (red)"))
ggsave(str_c("tmp/smoke_test_lmer2_", electrode, "_subject_facet.png"))

# 3. For one subject, chosen at random: every trial's full fit (subject
# and trial deviations both included) overlaid on that subject's own fit
# (trial excluded), the direct counterpart of smoke_test_lmer1.R's
# trial-overlay plot, now inside the combined model rather than a
# single-subject-only one.
one_subject <- sample(unique(eeg_df_subset$subject), size = 1)

ggplot() +
  geom_line(
    data = eeg_fitted |> filter(subject == one_subject),
    mapping = aes(x = time, y = fitted_full, group = trial_id),
    colour = "black",
    alpha = 0.1
  ) +
  geom_line(
    data = eeg_fitted |>
      filter(subject == one_subject) |>
      distinct(time, fitted_subject),
    mapping = aes(x = time, y = fitted_subject),
    colour = "red",
    linewidth = 1
  ) +
  theme_minimal() +
  ggtitle(str_c(
    electrode,
    " ",
    one_subject,
    ": trial fits (black) around subject fit (red)"
  ))
ggsave(str_c(
  "tmp/smoke_test_lmer2_",
  electrode,
  "_",
  one_subject,
  "_trial_overlay.png"
))

# This fit took about 71 minutes; save it so it doesn't have to be
# refit to look at it again. tmp/, not kept long-term, just so it
# survives this session for further inspection.
saveRDS(M2, "tmp/smoke_test_lmer2_M2.rds")
