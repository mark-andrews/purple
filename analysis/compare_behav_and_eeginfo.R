library(tidyverse)
library(rutils)

# Get the behav data, trials info from EEG, and combine them
data_df <- read_results_json("raw-data/pilots/pilot_26July2023/EM_Pilot_07_26_2023_14_53_26_results.json")
eeg_df <- read_csv('data/pilots/pilot_26July2023/EM_Pilot_07_26_2023_14_53_26_results.csv')
data_df2 <- bind_cols(data_df, rename(eeg_df, eeg_block = block))

# do they match?
data_df2 %>% summarize(all(block == eeg_block))
data_df2 %>% summarize(all(type == stimulus))
data_df2 %>% summarize(all(key_pressed == response))

# How about the reaction times?
data_df2 %>% mutate(rt2 = (stop_tic-1) - start_tic, rt2 = rt2/1024) %>% summarize(mean(abs(rt - rt2)) * 1000)
data_df2 %>% mutate(rt2 = (stop_tic-1) - start_tic, rt2 = rt2/1024) %>% summarize(max(abs(rt - rt2)) * 1000)
data_df2 %>% mutate(rt2 = (stop_tic-1) - start_tic, rt2 = rt2/1024) %>% summarize(min(abs(rt - rt2)) * 1000)
