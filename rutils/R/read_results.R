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

  results <- rjson::fromJSON(file = results_json_file)

  # First element of the `results` list is information about the experiment
  # and the participants.
  experiment_info <- results[[1]]

  # Note: you can get the Python code this way, which can be used to write it to
  # a file too
  # cat(experiment_info['code'][[1]])

  # Each subsequent element of the `results` list corresponds to a block
  # The `results` sub list in each of these elements contains trials.
  process_each_block <- function(i){
    results <- results[[i]]
    # the following creates a data frame of all trials in each block
    dplyr::bind_rows(results$results) |>
      dplyr::mutate(block = results$block,
                    type = results$type,
                    participant = experiment_info$participant_id,
                    gender = experiment_info$participant_gender,
                    age = experiment_info$participant_age,
                    handedness = experiment_info$participant_handedness,
                    datetime = experiment_info$datetime) |>
      dplyr::relocate(participant, gender, age, handedness, datetime, block, type)
  }

  # Go through each block, concatenate the data frames for each one
  # Do some further processing.
  purrr::map_dfr(seq(2, length(results)),
                 process_each_block) %>%
    dplyr::mutate(left_larger = left_size > right_size,
           left_press = key_pressed == 'left',
           accuracy = left_larger == left_press) |>
    dplyr::select(-c(left_larger, left_press, rt_time)) |>
    dplyr::rename(rt = rt_clock)
}
