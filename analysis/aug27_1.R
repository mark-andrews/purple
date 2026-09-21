library(tidyverse)
set.seed(10101)

eeg_df <- arrow::read_parquet(
  'data/main/merged_eeg_behaviour_data_masked.parquet'
) |>
  filter(type == 'dots') |>
  select(subject, block, trials, time, Fp1:O2)

channel_names <- str_split(
  "Fp1,AF7,AF3,F1,F3,F5,F7,FT7,FC5,FC3,FC1,C1,C3,C5,T7,TP7,CP5,CP3,CP1,P1,P3,P5,P7,P9,PO7,PO3,O1,Iz,Oz,POz,Pz,CPz,Fpz,Fp2,AF8,AF4,AFz,Fz,F2,F4,F6,F8,FT8,FC6,FC4,FC2,FCz,Cz,C2,C4,C6,T8,TP8,CP6,CP4,CP2,P2,P4,P6,P8,P10,PO8,PO4,O2",
  pattern = ',',
  simplify = TRUE
) |>
  as.vector()

channels0 <- c("POz")
channels1 <- c("POz", "Oz", "Pz")
channels2 <- c("P3", "P4", "P7", "P8", "PO3", "PO4", "PO7", "PO8", "O1", "O2")
channels_AF <- str_subset(channel_names, pattern = '^AF.*')
channels_PO <- str_subset(channel_names, pattern = '^PO.*')

all_subjects <- unique(eeg_df$subject)
test_subjects <- sample(all_subjects, size = 10)
one_subject <- sample(all_subjects, size = 1)

# ------------------------------------------------------------------------
eeg_df0 <-
  eeg_df |>
  filter(subject == one_subject) |>
  select(block, trials, time, all_of(channels0))

eeg_df0_trial <- eeg_df0 |>
  group_by(block, trials) |>
  nest() |>
  ungroup() |>
  sample_n(size = 1) |>
  unnest(cols = data) |>
  select(time, voltage = all_of(channels0))

# downsample
eeg_df0_trial_128 <- eeg_df0_trial |> slice(seq(1, n(), by = 8))

# ------------------------------------------------------------------------

ggplot(eeg_df0_trial, aes(x = time, y = voltage)) +
  geom_line(colour = 'grey') +
  geom_point(alpha = 0.5, size = 0.5) +
  theme_minimal()

ggplot(eeg_df0_trial_128, aes(x = time, y = voltage)) +
  geom_line(colour = 'grey') +
  geom_point(alpha = 0.5, size = 0.5) +
  theme_minimal()

recon <- spline(
  eeg_df0_trial_128$time,
  eeg_df0_trial_128$voltage,
  xout = eeg_df0_trial$time
)

check_df <- tibble(
  time = eeg_df0_trial$time,
  original = eeg_df0_trial$voltage,
  reconstructed = recon$y
)

ggplot(check_df, aes(x = time)) +
  geom_line(aes(y = original), colour = "black") +
  geom_line(aes(y = reconstructed), colour = "red", linetype = "dashed")

check_df |>
  summarise(
    rmse = sqrt(mean((original - reconstructed)^2)),
    sd_signal = sd(original)
  )
