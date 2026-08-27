library(tidyverse)
set.seed(10101)

eeg_df <- arrow::read_parquet(
  'data/main/merged_eeg_behaviour_data_masked.parquet'
) |>
  filter(type == 'dots') |>
  select(subject, block, trials, time, Fp1:O2) |>
  drop_na()

channel_names <- str_split(
  "Fp1,AF7,AF3,F1,F3,F5,F7,FT7,FC5,FC3,FC1,C1,C3,C5,T7,TP7,CP5,CP3,CP1,P1,P3,P5,P7,P9,PO7,PO3,O1,Iz,Oz,POz,Pz,CPz,Fpz,Fp2,AF8,AF4,AFz,Fz,F2,F4,F6,F8,FT8,FC6,FC4,FC2,FCz,Cz,C2,C4,C6,T8,TP8,CP6,CP4,CP2,P2,P4,P6,P8,P10,PO8,PO4,O2",
  pattern = ',',
  simplify = TRUE
) |>
  as.vector()

channels0 <- c("POz", "Oz")
channels1 <- c("POz", "Oz", "Pz")
channels2 <- c("P3", "P4", "P7", "P8", "PO3", "PO4", "PO7", "PO8", "O1", "O2")
channels_AF <- str_subset(channel_names, pattern = '^AF.*')
channels_PO <- str_subset(channel_names, pattern = '^PO.*')

all_subjects <- unique(eeg_df$subject)
test_subjects <- sample(all_subjects, size = 10)

# Functions --------------------------------------------------------------

plot_channel_grid <- function(channels) {
  # average ERP per channel (red), averaged over all trials/subjects
  # average ERP per channel per subject (black), averaged over all trials
  eeg_df0 <-
    eeg_df |>
    select(subject, block, trials, time, all_of(channels)) |>
    drop_na() |>
    pivot_longer(
      cols = all_of(channels),
      names_to = 'channel',
      values_to = 'voltage'
    ) |>
    summarise(voltage = mean(voltage), .by = c(subject, time, channel))

  ggplot() +
    geom_line(
      data = eeg_df0,
      mapping = aes(
        x = time,
        y = voltage,
        group = subject
      ),
      colour = 'black',
      alpha = 0.2
    ) +
    geom_line(
      data = summarize(
        eeg_df0,
        voltage = mean(voltage),
        .by = c(channel, time)
      ),
      mapping = aes(
        x = time,
        y = voltage,
      ),
      colour = 'red'
    ) +
    facet_wrap(~channel, scales = 'free_y') +
    theme_minimal() +
    ggtitle('Average ERP per channel (black: per each subject)')
}

plot_channel_subject_grid <- function(subjects, channels) {
  eeg_df0 <-
    eeg_df |>
    select(subject, block, trials, time, all_of(channels)) |>
    drop_na() |>
    pivot_longer(
      cols = all_of(channels),
      names_to = 'channel',
      values_to = 'voltage'
    ) |>
    filter(subject %in% subjects)

  ggplot() +
    geom_line(
      data = eeg_df0,
      mapping = aes(
        x = time,
        y = voltage,
        group = interaction(block, trials)
      ),
      colour = 'black',
      alpha = 0.1
    ) +
    geom_line(
      data = summarize(
        eeg_df0,
        voltage = mean(voltage),
        .by = c(subject, channel, time)
      ),
      mapping = aes(
        x = time,
        y = voltage,
      ),
      colour = 'red'
    ) +
    facet_grid(subject ~ channel, scales = 'free_y') +
    theme_minimal()
}

# ========================================================================

# Figure x.1: All ERPs averaged across all trials and all subjects and all channels
eeg_df |>
  summarise(across(Fp1:O2, mean), .by = time) |>
  pivot_longer(
    cols = -time,
    names_to = 'channel',
    values_to = 'voltage'
  ) |>
  summarise(voltage = mean(voltage), .by = time) |>
  ggplot(aes(x = time, y = voltage)) +
  geom_line() +
  theme_minimal() +
  ggtitle("ERP (averaged over all subjects, trials, channels)")

ggsave("tmp/aug26_1_x1.png")

# Figure x.2: All ERPs per channel, averaged across all trials and all subjects
# Free y scale in facet plot
eeg_df |>
  summarise(across(Fp1:O2, mean), .by = time) |>
  pivot_longer(
    cols = -time,
    names_to = 'channel',
    values_to = 'voltage'
  ) |>
  ggplot(aes(x = time, y = voltage)) +
  geom_line() +
  facet_wrap(~channel, scales = 'free_y') +
  theme_minimal() +
  ggtitle("ERP per channel (averaged over all subjects, trials)")
ggsave("tmp/aug26_1_x2.png")

# Figure x.3: All ERPs per channel, averaged across all trials and all subjects
# Fixed y scale in facet plot
eeg_df |>
  summarise(across(Fp1:O2, mean), .by = time) |>
  pivot_longer(
    cols = -time,
    names_to = 'channel',
    values_to = 'voltage'
  ) |>
  ggplot(aes(x = time, y = voltage)) +
  geom_line() +
  facet_wrap(~channel, scales = 'fixed') +
  theme_minimal() +
  ggtitle("ERP per channel (averaged over all subjects, trials)")
ggsave("tmp/aug26_1_x3.png")

# Figure x.4: Average ERP, and subject average ERP, per channel
# averaged over all trials
plot_channel_grid(channels0)
ggsave("tmp/aug26_1_x4.png")

# Figure x.5: Average ERP per channel for selected subjects
# trial ERP, no averaging, in black
plot_channel_subject_grid(test_subjects, channels1)
ggsave("tmp/aug26_1_x5.png")

# Figure x.6: Average ERP per channel for selected subjects
# AF channels
# trial ERP, no averaging, in black
plot_channel_grid(channels_AF)
ggsave("tmp/aug26_1_x6.png")

# Figure x.7: Average ERP per channel for selected subjects
# PO channels
# trial ERP, no averaging, in black
plot_channel_grid(channels_PO)
ggsave("tmp/aug26_1_x7.png")
