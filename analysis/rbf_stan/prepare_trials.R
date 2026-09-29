# Extract every usable dots-epoch trial at the target electrodes, decimate
# each trial from 1024 to 128 Hz, and write one long table to
# tmp/trials_decimated.parquet, which the multilevel fits read.
#
# Columns: subject, trial_id, block, trials, ratio, accuracy, time, and one
# voltage column per electrode. A trial masked at an electrode is NA there
# and is dropped by the fitting script for that electrode only.
#
# Run from the repository root, inside the devcontainer.

library(tidyverse)
source("analysis/rbf_stan/rbf_common.R")

electrodes <- c("POz", "Oz", "Pz", "PO7", "PO8")

eeg_df <- arrow::read_parquet(
  "data/main/merged_eeg_behaviour_data_masked.parquet",
  col_select = c(subject, block, trials, type, left_size, right_size,
                 accuracy, time, all_of(electrodes))
) |>
  filter(type == "dots") |>
  select(-type) |>
  mutate(trial_id = str_c(subject, "_", block, "_", trials)) |>
  arrange(trial_id, time)

trial_info <- eeg_df |>
  distinct(trial_id, subject, block, trials, left_size, right_size, accuracy) |>
  mutate(ratio = pmin(left_size, right_size) / pmax(left_size, right_size))

time_full <- eeg_df |> filter(trial_id == first(trial_id)) |> pull(time)
n_time <- length(time_full)
stopifnot(nrow(eeg_df) == n_time * nrow(trial_info))
keep <- seq(1L, n_time, by = 8L)

# One T x N matrix per electrode, one trial per column, decimated column
# by column. A column with any NA (a masked trial) stays all NA.
decimated <- map(set_names(electrodes), function(el) {
  M <- matrix(eeg_df[[el]], nrow = n_time)
  apply(M, 2, function(x) {
    if (anyNA(x)) rep(NA_real_, length(keep)) else decimate_voltage(x, 8L)
  })
})

out <- trial_info |>
  slice(rep(seq_len(n()), each = length(keep))) |>
  mutate(time = rep(time_full[keep], nrow(trial_info)))
for (el in electrodes) out[[el]] <- as.vector(decimated[[el]])

cat("trials", nrow(trial_info), " timepoints", length(keep),
    " usable trials per electrode:",
    map_int(decimated, \(M) sum(!is.na(M[1, ]))), "\n")

dir.create("tmp", showWarnings = FALSE)
arrow::write_parquet(out, "tmp/trials_decimated.parquet")
