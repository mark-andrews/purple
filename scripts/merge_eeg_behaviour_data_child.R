# The child version of merge_eeg_behaviour_data.R, differing only in the
# check that the EEG and behavioural trials match (see below) and in not
# excluding an adult participant. To be merged with the adult script later.

library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)

print("Reading eeg data")
eeg_df <- arrow::read_feather(args[2])
print("EEG data read")

print("Read behaviour data")
behaviour_df <- readr::read_csv(args[1])
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

# For the child data the check is that every EEG trial matches a
# behavioural trial with the same response, rather than that the two sets
# of trials are identical. Where a recording began inside a block
# (scripts/preprocess_eeg_child.py), that partial block has behavioural
# data but no EEG, and its rows are left with missing EEG by the left join
# below.
unmatched <- eeg_df_subset %>%
  anti_join(behaviour_subset_df, by = c("participant", "block", "trial", "stimulus", "response"))
stopifnot(nrow(unmatched) == 0)
no_eeg <- behaviour_subset_df %>%
  anti_join(eeg_df_subset, by = c("participant", "block", "trial", "stimulus")) %>%
  count(participant, block, stimulus)
print("Behavioural trials without EEG, by participant and block:")
print(no_eeg)

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
