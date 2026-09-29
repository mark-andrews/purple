# The child version of process_behaviour_raw_data.R, to be merged with it
# later. It differs only in how the participant identifier is set.
#
# purputils builds the identifier from the participant_id field of the
# json file and the session's date-time. In the adult files that field
# holds a short code (such as ThA), giving ThA_03_21_2024_12_10_57, the
# name of the raw files. In the child files it also holds a date (such as
# ThA_28August2025), and in one session a different code from the file
# name, so the identifiers would not match the EEG, which is named after
# the raw file. Each session's date-time, the last 19 characters of the
# identifier, is unique, so the identifier is replaced by the name of the
# input file with the same date-time.

library(argparse)

parser <- ArgumentParser(description = "Convert the json behavioural data files to single csv file.")
parser$add_argument("--input", nargs = "+", required = TRUE, help = "adak json files")
parser$add_argument("--output", required = TRUE, help = "Output csv file")
args <- parser$parse_args()

behaviour_df <- purputils::read_behavioural_results(args$input)

file_ids <- tools::file_path_sans_ext(basename(args$input))
session_time <- stringr::str_sub(behaviour_df$participant, -19)
file_time <- stringr::str_sub(file_ids, -19)
stopifnot(!anyDuplicated(file_time))
matched <- match(session_time, file_time)
stopifnot(!anyNA(matched))
behaviour_df$participant <- file_ids[matched]
stopifnot(dplyr::n_distinct(behaviour_df$participant) == length(args$input))

readr::write_csv(behaviour_df, file = args$output)
