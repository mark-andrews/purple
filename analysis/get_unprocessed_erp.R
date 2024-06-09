library(tidyverse)
epochs <- arrow::read_feather('pyutils/epochs_7_sept.feather') %>% 
  select(-contains('index_level_')) %>% 
  relocate(subject) %>% 
  pivot_longer(cols = A1:B32,
               names_to = 'channel',
               values_to = 'volts')

arrow::write_feather(epochs, 'pyutils/epochs_7_sept_pivot.feather')

epochs <- arrow::read_feather('pyutils/epochs_7_sept_pivot.feather')

average_epochs <- epochs %>% group_by(channel, time, stimulus) %>% summarize(y = mean(volts), .groups = 'drop') %>% 
  mutate(channel = factor(channel, levels = c(str_c('A', seq(32)), str_c('B', seq(32))), ordered = TRUE))
      
average_epochs %>% 
  filter(time <= 500, channel != 'B29') %>% 
  ggplot(aes(x = time, y = y, colour = stimulus)) + geom_line() + 
  facet_wrap(~channel)  #, scales = 'free_y') + theme(axis.text.y = element_blank())

average_epochs_wa_23 <- 

plot_one_subject <- function(subject_id = 'WA__08_23_2023_09_39_23', free = F){
  
  if (free) {scales = 'free_y'} else {scales = 'fixed'}
  
  epochs %>%
    filter(subject == subject_id) %>% 
    group_by(channel, time, stimulus) %>% summarize(y = mean(volts), .groups = 'drop') %>% 
    mutate(channel = factor(channel, levels = c(str_c('A', seq(32)), str_c('B', seq(32))), ordered = TRUE)) %>% 
    filter(time <= 500) %>% #, channel != 'B29') %>% 
    ggplot(aes(x = time, y = y, colour = stimulus)) + geom_line() + 
    facet_wrap(~channel, scales = scales) + ggtitle(subject_id)  + theme(axis.text.y = element_blank())
}

'TA__08_29_2023_14_16_18
ThA__08_24_2023_12_13_47
ThB__08_24_2023_14_08_22
WA__08_23_2023_09_39_23
WB__08_23_2023_12_39_15
WC__08_23_2023_14_48_19'


epochs %>%
  filter(subject == 'WA__08_23_2023_09_39_23', channel == 'B2') %>% 
  group_by(time, stimulus) %>% summarize(y = mean(volts), .groups = 'drop') %>% 
  ggplot(aes(x = time, y = y, colour = stimulus)) + geom_line() + 
  ggtitle('WA0823 A2')
