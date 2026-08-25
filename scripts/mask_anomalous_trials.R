# Flags and masks channel/trial combinations in the merged EEG data that
# are still anomalous after AutoReject's own trial-level rejection during
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
# Flagged cells are masked to NA rather than whole trials being dropped:
# the result, eeg_masked, has exactly the same rows and columns as the
# input, with individual (subject, block, trial, channel) cells set to NA
# where flagged. Written out to
# data/main/merged_eeg_behaviour_data_masked.parquet.
#
# The masking step deliberately does not pivot_longer() the full merged
# table: a naive version of that used over 90GB of RAM and crashed the
# machine. Instead, the small per-trial z-flag table is pivoted to wide
# (one flag column per channel) and joined onto the merged data by
# (subject, block, trials) only, which adds columns rather than
# multiplying rows, and each channel is then masked against its own flag
# column directly.
#
# interactive_views, below, gates two blocks of code that are not run in
# batch: an early descriptive-stats pass that first surfaced the problem,
# and plot_subject(), for looking at what the threshold does to any one
# subject's waveforms, with or without it applied. Both are kept, not
# deleted, since they're the record of how the threshold was chosen and
# useful for checking this again later. Set interactive_views <- TRUE to
# run them.

library(tidyverse)

interactive_views <- FALSE

# ===== exploration step =====
# This code is kept just to record that this step was done as a first step
if (interactive_views) {
  # In this code, we are calculating various descriptive statistics of the
  # voltages on each channel for each subject, in order to identify any anomalous
  # subjects and/or channels.
  # It shows that some channels in some subjects have extreme voltages.

  channel_voltage_summary <- arrow::read_parquet(
    'data/main/merged_eeg_behaviour_data.parquet'
  ) |>
    filter(!drop) |>
    select(subject, Fp1:O2) |>
    pivot_longer(
      cols = -subject,
      names_to = 'channel',
      values_to = 'mu_volts'
    ) |>
    summarise(
      .by = c(subject, channel),
      mean = mean(mu_volts),
      median = median(mu_volts),
      var = var(mu_volts),
      mad = mad(mu_volts),
      max = max(mu_volts),
      min = min(mu_volts),
      iqr = IQR(mu_volts),
      skewness = moments::skewness(mu_volts),
      kurtosis = moments::kurtosis(mu_volts)
    )
}

# ============================

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
if (interactive_views) {
  plot_subject('s13') # see F8, FC6, PO4 etc
  plot_subject('s13', threshold = 5.0) # about 20 channels completely removed
  plot_subject('s23') # see C4, F5, Iz, Oz etc
  plot_subject('s23', threshold = 5.0) # about three channels lost; all the others approx within +/- 30muv now
}

# ===== mask flagged cells to NA =====

z_threshold <- 5.0
channels <- unique(zflag_channels$channel)

zflag_wide <- zflag_channels |>
  mutate(flag = z >= z_threshold) |>
  select(-z) |>
  pivot_wider(
    names_from = channel,
    values_from = flag,
    names_glue = "{channel}_flag"
  )

eeg_masked <- eeg_df |>
  left_join(zflag_wide, by = c("subject", "block", "trials"))

for (ch in channels) {
  flag_col <- paste0(ch, "_flag")
  # is.na(...) is defensive, not required by the current data: checked, no
  # z is NA (e.g. from a dead/bridged channel with zero MAD). It guards
  # against eeg_df and zflag_channels drifting out of sync in a future
  # edit, so an unmatched join drops the cell instead of silently keeping it.
  drop <- is.na(eeg_masked[[flag_col]]) | eeg_masked[[flag_col]]
  eeg_masked[[ch]][drop] <- NA
}

eeg_masked <- eeg_masked |> select(-ends_with("_flag"))

# ===== sanity check =====
# Exhaustive, not sampled: for every (subject, block, trials, channel),
# either every timepoint should be NA (flagged) or none should be
# (kept). any_na != all_na catches partial masking within a single
# trial/channel, which should never happen since a flag applies to the
# whole trial/channel at once; all_na != should_be_na catches a mismatch
# against the z-threshold rule itself.

na_summary <- eeg_masked |>
  summarise(
    across(
      all_of(channels),
      list(all_na = ~ all(is.na(.x)), any_na = ~ any(is.na(.x))),
      .names = "{.col}__{.fn}"
    ),
    .by = c(subject, block, trials)
  ) |>
  pivot_longer(
    cols = -c(subject, block, trials),
    names_to = c("channel", ".value"),
    names_sep = "__"
  )

check <- zflag_channels |>
  mutate(should_be_na = z >= z_threshold) |>
  left_join(na_summary, by = c("subject", "block", "trials", "channel"))

mismatches <- check |> filter(all_na != should_be_na | all_na != any_na)

if (nrow(mismatches) > 0) {
  print(mismatches)
  stop(
    nrow(mismatches),
    " channel/trial combinations were not masked as expected"
  )
} else {
  message("All ", nrow(check), " channel/trial combinations masked correctly")
}

# write eeg_masked back to data/
arrow::write_parquet(
  eeg_masked,
  sink = 'data/main/merged_eeg_behaviour_data_masked.parquet'
)
