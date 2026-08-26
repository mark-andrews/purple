# Checks whether the large late-epoch swings seen in some subjects' average
# ERPs (aug26_1.R, figures x4/x5) are concentrated in a handful of subjects,
# consistent with a session-specific problem the trial-level anomaly mask
# in mask_anomalous_trials.R would not catch, or spread evenly across the
# sample, consistent with ordinary between-subject variability.
#
# Why the trial-level mask wouldn't catch this: it flags a (subject,
# channel, trial) cell by the IPR of that single trial, i.e. how much the
# trial wobbles around its own mean. It says nothing about where that mean
# sits. A trial that drifts smoothly away from zero (electrode impedance
# change, slow skin-potential shift) keeps a normal-looking spread around
# its own drifted level and is never flagged. If that drift is consistent
# in direction across a subject's trials rather than random trial to
# trial, it survives averaging over ~200 trials and shows up as a subject
# mean that stays away from zero late in the epoch, exactly where the
# grand-average ERP has already returned to baseline.
#
# A second, unrelated explanation for the same symptom is just a small
# effective sample size: if a subject-channel combination had many trials
# masked out already, its average late in the epoch is built from fewer
# surviving trials and is noisier for that reason alone, no drift needed.
#
# This script computes, per subject and channel, the subject-average ERP's
# peak absolute amplitude in a late window (500-1000ms, chosen because the
# grand average has returned close to baseline there, see x2/x3), alongside
# the number of trials that average was built from, and flags outliers
# with the same per-channel MAD-based z-score convention used in
# mask_anomalous_trials.R. Interactive/exploratory, not part of the
# pipeline.
#
# Only `channels` (below), not all 64, are pivoted to long format: a naive
# pivot_longer(cols = Fp1:O2) over the full merged table already crashed
# the machine once with over 90GB of RAM (logbook, 25 August 2026), and
# that was on the unfiltered 23M-row table, before multiplying by 64
# channels. Selecting the handful of channels actually being checked
# before pivoting keeps this well within reach.

library(tidyverse)

late_window <- c(500, 1000)
z_threshold <- 5.0
channels <- c('POz', 'Oz', 'Pz')

eeg_df <- arrow::read_parquet(
  'data/main/merged_eeg_behaviour_data_masked.parquet'
) |>
  filter(type == 'dots') |>
  select(subject, block, trials, time, all_of(channels))

# Step 1: the subject-average ERP curve per channel (the black line in
# aug26_1.R's x4/x5), plus how many trials survived masking to contribute
# to it at each timepoint. Masking is applied per whole trial/channel (see
# mask_anomalous_trials.R's own sanity check), so n_trials is constant
# across time within a subject/channel; it varies here only because it's
# recomputed at every timepoint.
subject_erp <- eeg_df |>
  pivot_longer(cols = all_of(channels), names_to = 'channel', values_to = 'voltage') |>
  summarise(
    .by = c(subject, channel, time),
    mean_voltage = mean(voltage, na.rm = TRUE),
    n_trials = sum(!is.na(voltage))
  )

# Step 2: summarise the late window of that curve.
subject_channel_summary <- subject_erp |>
  filter(time >= late_window[1], time <= late_window[2]) |>
  summarise(
    .by = c(subject, channel),
    late_amplitude = max(abs(mean_voltage)),
    n_trials_used = min(n_trials)
  )

# A subject-channel combination with n_trials_used == 0 was masked in
# every single trial (a dead/bridged electrode for that subject, not a
# late-epoch amplitude to assess), so late_amplitude is NaN there. Report
# these separately, and exclude them before computing each channel's
# median/MAD below: left in, a single NaN silently turns that channel's
# median() and mad() into NA, which would turn every z score NA too.
fully_masked <- subject_channel_summary |>
  filter(n_trials_used == 0) |>
  select(subject, channel)

subject_channel_summary <- subject_channel_summary |>
  filter(n_trials_used > 0) |>
  mutate(
    .by = channel,
    z = abs(late_amplitude - median(late_amplitude)) / mad(late_amplitude)
  )

outliers <- subject_channel_summary |>
  filter(z >= z_threshold) |>
  arrange(desc(z))

cat(nrow(fully_masked), "subject-channel combinations fully masked (0 trials):\n")
print(fully_masked)

# Plot: rank-ordered late-epoch amplitude per subject, per channel, point
# size showing how many trials it's built from. A handful of points well
# separated from the rest, especially if they're also built from few
# trials, points to a session-specific problem. A smooth spread with no
# clear break points to ordinary between-subject variability.
plot_late_amplitude <- function(channels) {
  subject_channel_summary |>
    filter(channel %in% channels) |>
    ggplot(aes(x = reorder(subject, late_amplitude), y = late_amplitude)) +
    geom_point(aes(size = n_trials_used)) +
    facet_wrap(~channel, scales = 'free_y') +
    coord_flip() +
    theme_minimal() +
    labs(
      x = 'subject',
      y = 'max |voltage| in 500-1000ms window',
      size = 'trials used',
      title = "Late-epoch amplitude of each subject's average ERP"
    )
}

# ============================

plot_late_amplitude(c('POz', 'Oz', 'Pz'))
ggsave('tmp/check_drift_poz_oz_pz.png', width = 10, height = 6)

print(outliers)
