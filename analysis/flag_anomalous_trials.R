# Flags channel/trial combinations in the merged EEG data that are still
# anomalous after AutoReject's own trial-level rejection during
# preprocessing. See logbook.md, entry dated 25 August 2026, for why this
# step turned out to be needed and how the rule below was arrived at.
#
# Method: for each subject, block, trial and channel, compute the "voltage
# IPR" (ipr(), p = 0.99), the range containing the central 99% of that
# trial's ~1229 timepoints for that channel. This is a robust measure of a
# single trial's amplitude spread, insensitive to any one glitched sample.
# A channel on a trial is flagged if its IPR is more than 5 robust
# (MAD-based) standard units above that channel's own median IPR, with the
# median and MAD computed per channel, not pooled across channels, since
# channels genuinely differ in typical amplitude (posterior/temporal sites
# run wider than central ones even when nothing is wrong) and a pooled
# threshold would just re-flag the same channels for being wide rather than
# for being anomalous on a given trial.
#
# This script only computes the flags (zflag_channels) and provides
# plot_subject() to verify what the threshold does to any one subject's
# waveforms, with or without it applied. It does not modify or write out
# the merged data. Turning the flags into a cleaned dataset, masking
# flagged cells to NA rather than dropping whole rows, is the next step,
# not yet done here (see logbook.md for why: a naive pivot_longer over the
# full merged table used over 90GB of RAM and crashed the machine, so this
# needs a more careful approach than the exploratory code above it used).

library(tidyverse)

ipr <- function(x, p = 0.99) {
  # calculate range
  # within which lie proportion p of the
  # values of x
  q <- (1 - p) / 2
  quantile(x, probs = c(0 + q, p + q)) |> diff() |> unname()
}


eeg_df <- arrow::read_parquet('data/main/merged_eeg_behaviour_data.parquet') |>
  filter(!drop) |>
  select(-drop)

channel_voltage_df <- eeg_df |>
  group_by(subject, block, trials) |>
  summarise(across(Fp1:O2, ipr)) |>
  ungroup()

ipr_summary_by_channel <-
  channel_voltage_df |>
  pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'voltage') |>
  summarise(
    median = median(voltage),
    mad = mad(voltage),
    .by = channel
  )

zflag_channels <-
  channel_voltage_df |>
  pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'voltage') |>
  left_join(ipr_summary_by_channel, by = 'channel') |>
  mutate(z = abs(voltage - median) / mad) |>
  select(-voltage, -median, -mad)

# Plots every trial's waveform for every channel for subject s.
# threshold = Inf (the default) plots everything, unfiltered.
# threshold = 5, for example, drops any channel/trial whose z exceeds 5.
plot_subject <- function(
  s,
  threshold = Inf
) {
  data_df <- eeg_df |>
    filter(subject == s) %>%
    pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'volts') |>
    left_join(zflag_channels, by = c('subject', 'block', 'trials', 'channel'))

  if (threshold < Inf) {
    data_df <- data_df |> filter(z <= threshold)
  }

  ggplot(
    data_df,
    aes(x = time, y = volts, group = interaction(block, trials))
  ) +
    geom_line() +
    facet_wrap(~channel)
}

# Interactive only, not run when this script is sourced/batched.
if (FALSE) {
  plot_subject('s13') # see F8, FC6, PO4 etc
  plot_subject('s13', threshold = 5.0) # about 20 channels completely removed
  plot_subject('s23') # see C4, F5, Iz, Oz etc
  plot_subject('s23', threshold = 5.0) # about three channels lost; all the others approx within +/- 30muv now
}
