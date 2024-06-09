#' Read the behavioural results json file
#'
#' The results from the Psychopy Python experiment are exported as a json file.
#' This command converts the main information contained in that json file into a
#' standard R data frame with, for example, one row per trial.
#'
#' @param results_json_file The path to the results json file.
#'
#' @return A tibble data frame with one row per experimental trial and columns
#'   for participant ID, block number, stimulus type, stimulus details, reaction
#'   time, accuracy, etc.
#' @export
#'
#' @examples
#' \dontrun{
#' data_df <- read_results_json("foo_results.json")
#' }
read_results_json <- function(results_json_file){

  # `results` is a list
  results <- rjson::fromJSON(file = results_json_file)

  # First element of the `results` list is information about the experiment
  # and the participants.
  experiment_info <- results[[1]]

  # Note: you can get the Python source code used for the experiment as follows:
  # cat(experiment_info['code'][[1]])
  # This can then be written to file if required.
  # This can be used to verify exactly what Python code was run in the experiment
  # that generated this data.

  # After the first element, each subsequent element of the `results` list
  # corresponds to an experimental block. The `results` sub list in each of
  # these elements contains trials. Return this block info as a data frame. The
  # participant unique identifier is a suffix like 'MA' or 'FB', recorded by the
  # experiment code as `participant_id`, followed by a datetime stamp string,
  # recorded as `datetime`. These are concatenated here.
  process_each_block <- function(i){
    results <- results[[i]]
    # the following creates a data frame of all trials in each block
    dplyr::bind_rows(results$results) |>
      dplyr::mutate(block = results$block,
                    type = results$type,
                    # the participant_id is just the suffix of the participant
                    # unique identifier in itself, it does not uniquely identify
                    # the participant it is concatenated with datetime below to
                    # create the unique identifier.
                    participant = strip_underscores(experiment_info$participant_id),
                    gender = experiment_info$participant_gender,
                    age = experiment_info$participant_age,
                    handedness = experiment_info$participant_handedness,
                    datetime = experiment_info$datetime,
                    participant = stringr::str_c(participant, datetime, sep = '_'),
                    # having concatenated the suffix and the timestamp string, we can
                    # convert the datetime to a dttm type
                    datetime = lubridate::mdy_hms(datetime)
                    ) |>
      dplyr::relocate(participant, gender, age, handedness, datetime, block, type)
  }

  # The participant_id variable sometimes has a trailing underscore, e.g. `ThA_`.
  # We want them removed. This function does that and is used above.
  strip_underscores <- function(participant_id) {
    stringr::str_squish(stringr::str_remove_all(participant_id, '_'))
  }

  # Go through each block (found in every element of `results` after the first
  # element), concatenate the data frames for each block.
  # Do some post-processing.
  purrr::map_dfr(seq(2, length(results)),
                 process_each_block) %>%
    dplyr::mutate(left_larger = left_size > right_size,
           left_press = key_pressed == 'left',
           accuracy = left_larger == left_press) |>
    dplyr::select(-c(left_larger, left_press, rt_time)) |>
    dplyr::rename(rt = rt_clock)
}


#' Import all behavioural data
#'
#' Read in each behavioural results json file that is in the results directory.
#' Concatenate the resulting data frames. Create a new "subject" data frame with
#' values s1, s2, ... sn where s1 is the first participant by date, s2 is the
#' second, and so on.
#'
#' @param behavioural_results_dir The directory that contains the _results.json behavioral data files.
#'
#' @return A date frame that concatenates the data frames from all subjects
#' @export
#'
#' @examples
#' \dontrun{
#' data_df <- read_behavioural_results("foo_results_dir")
#' }
read_behavioural_results <- function(behavioural_results_dir){

  # get the list of the json results file in the specified directory
  results_json_files <- fs::dir_ls(behavioural_results_dir, glob = '*_results.json')

  # Use the `read_results_json` to read the data from each results file into a
  # data frame. Concatenate these data frames together. Record this original
  # data frame to do some quick error checks.
  orig_df <- purrr::map_dfr(results_json_files, read_results_json)

  # Create a new variable, `subject`, with values s1, s2 ... sn This, like
  # `participant`, is a unique identifier of the participant but it is much
  # simpler.
  new_df <- orig_df |>
    dplyr::group_by(participant, datetime) |>
    tidyr::nest() |>
    dplyr::ungroup() |>
    dplyr::arrange(datetime) |>
    dplyr::mutate(
      subject = stringr::str_c('s', seq(n())),
      # sort `subject` by s1, s2, s3 ... and not s1, s10, s11
      subject = factor(subject, levels = stringr::str_c('s', seq(n())))
    )|>
    tidyr::unnest(data) |>
    relocate(subject, .after = participant)

  stopifnot(
    # the new and original data frames should be the same length
    nrow(orig_df) == nrow(new_df),
    # the number of unique values of the new subject variable should be
    # the same the number of unique values of the participant variable
    nrow(unique(new_df$subject)) == nrow(unique(new_df$participant)),
    # And this should be the same as the number of _results.json files
    nrow(unique(new_df$subject)) == length(results_json_files),
    # the new_df should be identical to the orig_df except for the new variable
    # and after we move a few variables around
    all.equal(dplyr::select(new_df, -subject),
              dplyr::relocate(orig_df, datetime, .after = participant) |> dplyr::arrange(datetime))
  )

  new_df

}
