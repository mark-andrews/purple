library(tidyverse)

xyz <- arrow::read_feather('data/main/merged_eeg_behaviour_data.feather')

averaged_epochs <- xyz %>% 
  group_by(time, type) %>% 
  summarise(across(Fp1:O2, mean), .groups = 'drop') %>% 
  pivot_longer(cols = Fp1:O2,
               names_to = 'channel',
               values_to = 'volts') 

averaged_epochs %>% 
  ggplot(aes(x= time,y = volts, colour = type, group = type)) +
  geom_line() + 
  facet_wrap(~channel)
