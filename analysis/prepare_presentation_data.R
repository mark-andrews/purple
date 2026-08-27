# Precomputes small, reusable summaries of the masked EEG data for the
# BPS conference presentation (presentations/bps-cog-2026/slides.qmd) to
# read directly, so that document never has to open the multi-gigabyte
# merged parquet itself, arrow alone makes that too slow to do on every
# render, quite apart from Quarto's own caching being more trouble than
# it's worth here.
#
# Run this once, by hand, inside the Podman devcontainer (or equivalent:
# the host has no `arrow` installation, per readme.md), whenever the
# presentation needs data that isn't in tmp/ yet, or after the underlying
# masked parquet changes. Outputs go to tmp/, which is not committed and
# not kept long-term; see the 27 August 2026 logbook entry for exactly
# what this writes and why, if tmp/ has been cleared and these need
# regenerating.
#
# Approach follows analysis/aug26_1.R's grand-average ERP figures
# (Figure x.3 in particular, the fixed-y-scale per-channel facet plot),
# collapsing over subject and trial the same way: one pooled mean per
# channel per timepoint, not a subject-average-of-averages. One thing
# deliberately NOT carried over from aug26_1.R: its `drop_na()` runs
# across all 64 channel columns at once, wide format, so it drops an
# entire (subject, trial, timepoint) row, every channel's value, if even
# one of the other 63 channels was masked bad on that trial, discarding
# perfectly good data for the channel actually being analysed. With 64
# largely-independent channels that compounds fast (even a 2% per-
# channel bad rate gives roughly a 70% chance *some* channel is bad on a
# given trial), and it hits subjects unevenly depending on which of
# their other channels happened to have problems, unrelated to the
# channel being plotted. Below, NA is only dropped after pivoting to
# long format, per channel, so a bad channel only ever removes its own
# rows.

library(tidyverse)

eeg_df <- arrow::read_parquet(
  "data/main/merged_eeg_behaviour_data_masked.parquet"
) |>
  filter(type == "dots") |>
  select(subject, block, trials, time, Fp1:O2)

# Grand-average ERP per channel per timepoint, all 64 channels, dots
# task only: small enough (one row per channel per timepoint, on the
# order of 80,000 rows) to save whole and let the presentation pick
# whichever channel subset a given slide needs, rather than baking one
# specific selection in here. na.rm = TRUE per channel column here plays
# the same role the pivot-then-drop_na() pattern below does: each
# channel's own mean excludes only its own NAs.
grand_average_erp <- eeg_df |>
  summarise(across(Fp1:O2, ~ mean(.x, na.rm = TRUE)), .by = time) |>
  pivot_longer(cols = -time, names_to = "channel", values_to = "voltage")

saveRDS(grand_average_erp, "tmp/grand_average_erp.rds")

cat("Wrote tmp/grand_average_erp.rds:", nrow(grand_average_erp), "rows\n")

# Subject-average ERP, per subject per channel per timepoint (averaged
# over that subject's trials only, subjects kept separate), for the
# "zoom in" slide: a handful of parieto-occipital electrodes, subject
# averages plus the grand average, one row of panels. Restricted to
# these five channels rather than all 64, unlike grand_average_erp
# above: the subject breakdown is a much bigger table (subjects x
# channels x timepoints, not just channels x timepoints), and nothing
# downstream needs the other 59 channels at this level of detail.
# Follows the same collapse-over-trials-only approach as
# analysis/aug26_1.R's plot_channel_grid() (Figure x.4).
posterior_channels <- c("POz", "Oz", "Pz", "PO7", "PO8")

subject_average_erp_posterior <- eeg_df |>
  select(subject, time, all_of(posterior_channels)) |>
  pivot_longer(
    cols = all_of(posterior_channels),
    names_to = "channel",
    values_to = "voltage"
  ) |>
  drop_na(voltage) |>
  summarise(voltage = mean(voltage), .by = c(subject, channel, time))

saveRDS(subject_average_erp_posterior, "tmp/subject_average_erp_posterior.rds")

cat(
  "Wrote tmp/subject_average_erp_posterior.rds:",
  nrow(subject_average_erp_posterior), "rows\n"
)

# Single-subject, single-trial-resolution ERP, same five channels, for
# the inter-trial-variability slide: every trial kept separate this
# time, not averaged, so restricted to one subject as well, s47, the
# same subject smoke_test_lmer1.R happened to draw at random, rather
# than all 47: full trial resolution across every subject would be back
# to essentially the whole dataset.
trial_subject <- "s47"

trial_erp_posterior <- eeg_df |>
  filter(subject == trial_subject) |>
  select(block, trials, time, all_of(posterior_channels)) |>
  mutate(trial_id = interaction(block, trials, drop = TRUE)) |>
  pivot_longer(
    cols = all_of(posterior_channels),
    names_to = "channel",
    values_to = "voltage"
  ) |>
  drop_na(voltage)

saveRDS(trial_erp_posterior, "tmp/trial_erp_posterior_s47.rds")

cat(
  "Wrote tmp/trial_erp_posterior_s47.rds:",
  nrow(trial_erp_posterior), "rows\n"
)
