library(tidyverse)

xyz <- arrow::read_parquet('data/main/merged_eeg_behaviour_data.parquet')

# flag the very high or low variance channels for deletion
xyz_drop_channels <- xyz %>%
  filter(!drop) %>%
  group_by(subject, block, trials) %>%
  # variance on each trial for each subject
  summarise(across(Fp1:O2, var)) %>%
  ungroup() %>%
  pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'variance') %>%
  mutate(
    drop2 = (variance > quantile(variance, probs = 0.999)) |
      (variance < quantile(variance, probs = 1 - 0.999))
  )

averaged_epochs <- xyz %>%
  group_by(time, type) %>%
  summarise(across(Fp1:O2, mean), .groups = 'drop') %>%
  pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'volts')

averaged_epochs %>%
  ggplot(aes(x = time, y = volts, colour = type, group = type)) +
  geom_line() +
  facet_wrap(~channel)

averaged_epochs2 <- xyz %>%
  select(subject, type, time, P10) %>%
  filter(type == 'blobs') %>%
  group_by(subject, time) %>%
  summarise(volts = mean(P10), .groups = 'drop')

averaged_epochs2 %>%
  ggplot(aes(x = time, y = volts)) +
  geom_line() +
  facet_wrap(~subject)

# function to plot specific channel for specific subject
# averaged over all trials
plot_subject_channel_trials <- function(s, channel) {
  msg <- glue::glue('Subject {s}, channel {ensym(channel)}.')
  xyz %>%
    filter(subject == s) %>%
    group_by(type, time, trials) %>%
    summarise(volts = mean({{ channel }}), .groups = 'drop') %>%
    ggplot(aes(x = time, y = volts, colour = type)) +
    geom_line() +
    facet_wrap(~trials) +
    theme_minimal() +
    ggtitle(msg)
}

plot_subject_channel_trials('s34', P10)

# function to plot specific channel for specific subject
# averaged over all trials
plot_subject_channel <- function(s, channel) {
  msg <- glue::glue('Subject {s}, channel {ensym(channel)}.')
  xyz %>%
    filter(subject == s) %>%
    group_by(type, time) %>%
    summarise(volts = mean({{ channel }}), .groups = 'drop') %>%
    ggplot(aes(x = time, y = volts, colour = type)) +
    geom_line() +
    ggtitle(msg)
}

plot_subject_channel('s34', P10)

plot_subject_channel2 <- function(s, channel) {
  msg <- glue::glue('Subject {s}, channel {ensym(channel)}.')
  xyz %>%
    filter(subject == s) %>%
    unite('xy', block, trials) %>%
    group_by(xy, time) %>%
    summarise(volts = mean({{ channel }}), .groups = 'drop') %>%
    ungroup() %>%
    group_by(xy) %>%
    nest(data = c(time, volts)) %>%
    ungroup() %>%
    sample_n(50) %>%
    unnest(data) %>%
    ggplot(aes(x = time, y = volts)) +
    geom_line() +
    facet_wrap(~xy) +
    ggtitle(msg)
}

plot_subject_channel2('s34', P10)

plot_subject <- function(s) {
  msg <- glue::glue('Subject {s}')
  xyz %>%
    filter(subject == s) %>%
    pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'volts') %>%
    group_by(type, time) %>%
    summarise(volts = mean(volts), .groups = 'drop') %>%
    ggplot(aes(x = time, y = volts, colour = type)) +
    geom_line() +
    ggtitle(msg)
}

plot_subject('s34')

# average per-trial variance of each channel
xyz_1 <- xyz %>%
  group_by(subject, block, trials) %>%
  # variance on each trial for each subject
  summarise(across(Fp1:O2, var)) %>%
  ungroup() %>%
  # # group by subject
  # group_by(subject) %>%
  # summarise(across(Fp1:O2, median)) %>%
  # # for each subject, histogram over per-channel average variance
  # # or change for each channel, histogram over per-subject average variance
  # # to spot high variance subjects, if any
  pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'variance')

#
#   arrange(desc(variance)) %>%
#   tail(50)
#   print(n = 100)
# #  ggplot(aes(x = variance)) + geom_histogram(bins = 10)
#
#
plot_subject <- function(s) {
  xyz %>%
    filter(!drop) %>%
    filter(subject == s) %>%
    pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'volts') # %>%
  left_join(
    select(xyz_drop_channels, -variance),
    by = c(subject, block, trials, channel)
  ) %>%
    filter(!drop2) %>%
    select(time, channel, volts) %>%
    group_by(time, channel) %>%
    summarise(volts = mean(volts), .groups = 'drop') %>%
    ggplot(aes(x = time, y = volts)) +
    geom_line() +
    facet_wrap(~channel)
}

xyz %>%
  filter(subject == 's13') %>%
  pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'volts') %>%
  select(time, block, trials, channel, volts) %>%
  unite('xy', c(block, trials)) %>%
  #group_by(time, channel) %>%
  #summarise(volts = mean(volts), .groups = 'drop') %>%
  ggplot(aes(x = time, y = volts, group = xy)) +
  geom_line() +
  facet_wrap(~channel)


#library(lme4)
# plot_subject_channel(s = 's4', channel = P10)
result_1 <- lmer(log10(variance) ~ (1 | subject) + (1 | channel), data = xyz_1)
result_2 <- lmer(log10(variance) ~ (1 | subject:channel), data = xyz_1)
result_3 <- lmer(
  log10(variance) ~ (1 | subject) + (1 | channel) + (1 | subject:channel),
  data = xyz_1
)

ranef(result_2)[['subject:channel']] %>%
  as_tibble(rownames = 'subj_channel') %>%
  rename(y = `(Intercept)`) %>%
  arrange(desc(y))

xyz_2 <- xyz %>%
  unite('trials', c(block, sb_trials)) %>%
  select(subject, trials, time, Fp1:O2) %>%
  group_by(subject) %>%
  group_split()

xyz_3 <- map(
  xyz_2,
  ~ pivot_longer(., cols = Fp1:O2, names_to = 'channel', values_to = 'volt')
)


#library(tidyverse)
#x <- arrow::read_feather('foo_not_fix.feather')
#x <- arrow::read_feather('foo_fix.feather') %>% filter(!drop)

x %>%
  pivot_longer(cols = Fp1:O2, names_to = 'channel', values_to = 'volts') %>%
  select(block, trial, time, channel, volts) %>%
  #filter(block == 1, trial == 1)  %>%
  group_by(time, channel) %>%
  summarise(volts = mean(volts), .groups = 'drop') %>%
  filter(channel == 'Fp2') %>%
  ggplot(aes(x = time, y = volts)) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 0.1, colour = 'red') +
  facet_wrap(~channel) +
  scale_x_continuous(breaks = seq(-200, 1000, by = 50))
