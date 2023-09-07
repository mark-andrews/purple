library(tidyverse)
epochs <- arrow::read_feather('pyutils/epochs_7_sept.feather') %>% 
  select(-contains('index_level_')) %>% 
  relocate(subject) %>% 
  pivot_longer(cols = A1:B32,
               names_to = 'channel',
               values_to = 'volts')

average_epochs <- epochs %>% group_by(channel, time, stimulus) %>% summarize(y = mean(volts), .groups = 'drop') %>% 
  mutate(channel = factor(channel, levels = c(str_c('A', seq(32)), str_c('B', seq(32))), ordered = TRUE))
      
average_epochs %>% 
  filter(time <= 500) %>% 
  ggplot(aes(x = time, y = y, colour = stimulus)) + geom_line() + 
  facet_wrap(~channel, scales = 'free_y') +
  theme(axis.text.y = element_blank())
