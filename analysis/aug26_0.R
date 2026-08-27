library(tidyverse)

channel_voltage_summary <- arrow::read_parquet(
  'data/main/merged_eeg_behaviour_data_masked.parquet'
)

channel_voltage_summary |>
  filter(type == 'dots') |>
  select(subject, block, trials, time, Fp1) |>
  drop_na() |>
  summarise(voltage = mean(Fp1), .by = time) |>
  ggplot(aes(x = time, y = voltage)) +
  geom_line()

channel_voltage_summary |>
  filter(type == 'dots') |>
  select(subject, block, trials, time, Fp1:O2) |>
  drop_na() |>
  summarise(across(Fp1:O2, mean), .by = time) |>
  pivot_longer(cols = -time, names_to = 'channel', values_to = 'voltage') |>
  ggplot(aes(x = time, y = voltage)) +
  geom_line() +
  facet_wrap(~channel) +
  theme_minimal() +
  ggtitle("Averaged ERPs: Dots")

channel_voltage_summary |>
  filter(type == 'dots') |>
  select(subject, block, trials, time, POz, Oz, Pz) |>
  drop_na() |>
  summarise(across(c(POz, Oz, Pz), mean), .by = time) |>
  pivot_longer(cols = -time, names_to = 'channel', values_to = 'voltage') |>
  ggplot(aes(x = time, y = voltage)) +
  geom_line() +
  facet_wrap(~channel) +
  theme_minimal() +
  ggtitle("Averaged ERPs: Dots")


channel_voltage_summary |>
  select(subject, block, trials, type, time, Fp1:O2) |>
  drop_na() |>
  summarise(across(Fp1:O2, mean), .by = c(type, time)) |>
  pivot_longer(
    cols = -c(type, time),
    names_to = 'channel',
    values_to = 'voltage'
  ) |>
  ggplot(aes(x = time, y = voltage, colour = type)) +
  geom_line() +
  facet_wrap(~channel) +
  theme_minimal()

channel_voltage_summary |>
  filter(type == 'dots') |>
  select(subject, block, trials, time, Cz) |>
  drop_na() |>
  summarise(voltage = mean(Cz), .by = c(subject, time)) |>
  ggplot(aes(x = time, y = voltage)) +
  geom_line() +
  facet_wrap(~subject) +
  theme_minimal()

A <- channel_voltage_summary |>
  filter(subject == 's20', type == 'dots') |>
  select(block, trials, time, voltage = Cz) |>
  drop_na()


ggplot(
  data = A,
  mapping = aes(x = time, y = voltage, group = interaction(block, trials))
) +
  geom_line(alpha = 0.1) +
  geom_line(
    data = summarise(A, voltage = mean(voltage), .by = time),
    inherit.aes = FALSE,
    mapping = aes(x = time, y = voltage),
    colour = 'blue'
  ) +
  theme_minimal()
