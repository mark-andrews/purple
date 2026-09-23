# Extracts the single trial that B0 is fitted to, and writes it to
# tmp/b0_trial_POz.csv, one row per timepoint, columns time and voltage,
# at the full 1024 Hz. fit_b0.R and fit_b0_gls.R both read that file.
#
# The draw follows the analysis/aug27_1.R scratch script (deleted
# 22 September 2026, see purge.md) step by step, including the unused
# draw of ten test subjects, so that the same seed selects the same
# subject and trial. That script is where the single trial used in the
# early noise-model work came from. The CSV it was saved as was never
# kept, but this draw reproduces it: subject s17, block 1, trial 53. With
# the original plain-subsampling decimation, the iid residual
# autocorrelations at lags 1, 2 and 6 come out at 0.77, 0.34 and -0.46,
# exactly the values recorded in models.qmd.
#
# Run from the repository root, inside the devcontainer (needs arrow).

library(tidyverse)
set.seed(10101)

electrode <- "POz"

eeg_df <- arrow::read_parquet(
  "data/main/merged_eeg_behaviour_data_masked.parquet",
  col_select = c(subject, block, trials, time, type, all_of(electrode))
) |>
  filter(type == "dots") |>
  select(subject, block, trials, time, all_of(electrode))

all_subjects <- unique(eeg_df$subject)
test_subjects <- sample(all_subjects, size = 10) # unused, keeps the RNG in step
one_subject <- sample(all_subjects, size = 1)

trial_df <- eeg_df |>
  filter(subject == one_subject) |>
  select(block, trials, time, all_of(electrode)) |>
  group_by(block, trials) |>
  nest() |>
  ungroup() |>
  sample_n(size = 1)

cat(
  "Subject", one_subject, "block", trial_df$block, "trial", trial_df$trials,
  "\n"
)

trial_df <- trial_df |>
  unnest(cols = data) |>
  select(time, voltage = all_of(electrode))

# A masked trial is all NA at this electrode. Fail loudly rather than
# write it, since the models cannot use it.
stopifnot(!anyNA(trial_df$voltage))

write_csv(trial_df, str_c("tmp/b0_trial_", electrode, ".csv"))
