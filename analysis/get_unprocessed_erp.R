#library(tidyverse)
#epochs <- arrow::read_feather('data/main/epochs_8_sept_2024.feather') %>% 
  select(-contains('index_level_')) %>% 
  relocate(subject) 

averaged_epochs <- epochs %>% 
  group_by(time, stimulus) %>% 
  summarise(across(A1:B32, mean)) %>% 
  pivot_longer(cols = A1:B32,
               names_to = 'channel',
               values_to = 'volts') %>% 
  mutate(channel = factor(channel, levels = c(str_c('A', seq(32)), str_c('B', seq(32))), ordered = TRUE))

averaged_epochs %>% 
  filter(time <= 500) %>%
  ggplot(aes(x = time, y = volts, colour = stimulus)) + geom_line() + 
  facet_wrap(~channel, scales = 'free') +
  scale_x_continuous(breaks = seq(-100, 1000, by = 100)) +
  theme_minimal() +
  theme(
    axis.text.y=element_blank(), 
    axis.ticks.y=element_blank()) 



averaged_epochs %>% 
  group_by(time, stimulus) %>% 
  summarise(volts = mean(volts)) %>% 
  filter(time <= 500) %>% 
  ungroup() %>% 
  ggplot(aes(x = time, y = volts, colour = stimulus)) + geom_line() + 
  scale_x_continuous(breaks = seq(-100, 500, by = 100)) +
  theme_minimal() +
  theme(
    axis.text.y=element_blank(), 
    axis.ticks.y=element_blank()) 

# what is avg volt before time = 0 for each stimulus type?
baseline_avg <- averaged_epochs %>% 
  group_by(time, stimulus) %>% 
  summarise(volts = mean(volts), .groups = 'drop') %>% 
  filter(time <= 500) %>% 
  ungroup() %>% 
  pivot_wider(names_from = stimulus, values_from = volts) %>% 
  filter(time < 0) %>% 
  select(-time) %>% 
  colMeans()
  

averaged_epochs %>% 
  group_by(time, stimulus) %>% 
  summarise(volts = mean(volts), .groups = 'drop') %>% 
  filter(time <= 500) %>% 
  ungroup() %>% 
  mutate(
    volts = case_when(
      stimulus == 'dots' ~ volts - baseline_avg['dots'],
      stimulus == 'blobs' ~ volts - baseline_avg['blobs'])
  ) %>% 
  ggplot(aes(x = time, y = volts, colour = stimulus)) + geom_line(size = 3) + #geom_smooth(method = 'gam', se = F, formula = y ~ s(x, bs = "tp")) + 
  scale_x_continuous(breaks = seq(-100, 500, by = 100)) +
  theme_minimal() +
  theme(
    axis.text.y=element_blank(), 
    axis.ticks.y=element_blank()) +
  ggtitle("Average over all channels")
