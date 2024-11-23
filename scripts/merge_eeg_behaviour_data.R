library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)

print("Reading eeg data")
eeg_df <- arrow::read_feather(args[2])
print("EEG data read")

print("Read behaviour data")
behaviour_df <- readr::read_csv(args[1]) %>%
  # remove the participant for whom the EEG data is missing
  filter(participant != "ThB_03_21_2024_12_10_57")
print("Behaviour data read")

# Do the EEG and behavioural data match? ----------------------------------

# The recorded response on each trial in each block for each participant should
# be identical in the eeg and behavioural data:
behaviour_subset_df <- behaviour_df %>%
  select(participant, block, trial = trials, stimulus = type, response = key_pressed) %>%
  arrange(participant, block, trial)

eeg_df_subset <- eeg_df %>%
  select(participant, block, trial, stimulus, response) %>%
  distinct() %>%
  arrange(participant, block, trial)

stopifnot(all.equal(behaviour_subset_df, eeg_df_subset))

# Merge EEG and behavioural data ------------------------------------------

eeg_behaviour_merge <- behaviour_df %>% left_join(eeg_df, by = c("participant", "block", "trials" = "trial", "type" = "stimulus", "key_pressed" = "response"))

print("EEG and behaviour data merged")

# Delete some objects as we are running out of space ----------------------

rm(behaviour_subset_df)
rm(eeg_df_subset)
rm(eeg_df)
# rm(behaviour_df)

# # Test merged data --------------------------------------------------------

# # test if the eeg data in the merged data frame matches that of the original eeg data
# A <- eeg_behaviour_merge %>%
#   rename(trial = trials, stimulus = type, response = key_pressed) %>%
#   select(names(eeg_df)) %>%
#   arrange(participant, block, trial)
# B <- eeg_df %>% arrange(participant, block, trial)
# stopifnot(
#   all.equal(A, B)
# )

# test if the behaviour data in the merged data frame matches that of the original behaviour data
stopifnot(
  all.equal(
    eeg_behaviour_merge %>% select(names(behaviour_df)) %>% distinct() %>% arrange(participant, block, trials),
    behaviour_df %>% as_tibble() %>% arrange(participant, block, trials)
  )
)
# print("All tests passed")

# # Free up memory ----------------------------------------------------------

# rm(eeg_df, eeg_df_subset, behaviour_df, behaviour_subset_df)
# print("Free up memory")

# # Write to file -----------------------------------------------------------

# arrow::write_feather(eeg_behaviour_merge, sink = args[3])
arrow::write_parquet(eeg_behaviour_merge, sink = args[3])
