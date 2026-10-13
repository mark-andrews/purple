# Response time as a function of ratio, on correct trials, for the adults
# and the children, for the Plymouth slides. Writes results/rt.rds.
#
# This is separate from prepare_results.R only so that it can be run on
# its own in seconds, on the host, without the model fits or the EEG data.
# It reads only the two combined behaviour CSVs and needs only tidyverse.
# To be folded into prepare_results.R when the deck is tidied up.
#
# Run from the repository root:
#   Rscript reports/presentations/plymouth-october-2026/prepare_rt_results.R
#
# Trials are selected as in prepare_results.R (dots trials, first trial of
# each block excluded), and then only correct trials are kept. Each
# subject's curve is from a linear regression of log response time on log
# ratio, shown on the seconds scale, the counterpart of the logistic
# regression behind the accuracy curves.

library(tidyverse)

here <- "reports/presentations/plymouth-october-2026"
out_dir <- file.path(here, "results")

rt_by_ratio <- function(file) {
  d <- read_csv(file, show_col_types = FALSE) |>
    filter(type == "dots", sb_trials != 1) |>
    mutate(accuracy = as.logical(accuracy),
           ratio = pmax(left_size, right_size) / pmin(left_size, right_size),
           log_ratio = log(ratio))
  # The grid spans the ratios of all trials, as for the accuracy curves.
  grid <- tibble(ratio = seq(min(d$ratio), max(d$ratio), length.out = 50))
  d <- d |> filter(accuracy, !is.na(rt))
  curves <- d |>
    group_by(subject) |>
    group_modify(function(d, key) {
      f <- lm(log(rt) ~ log_ratio, data = d)
      grid |> mutate(rt = exp(predict(f, tibble(log_ratio = log(ratio)))))
    }) |>
    ungroup()
  slopes <- d |>
    group_by(subject) |>
    summarise(slope = coef(lm(log(rt) ~ log_ratio))[2], n = n())
  list(curves = curves, slopes = slopes, n_trials = nrow(d))
}

saveRDS(list(adult = rt_by_ratio("data/main/combined_behaviour_data.csv"),
             child = rt_by_ratio("data/child/combined_behaviour_data.csv")),
        file.path(out_dir, "rt.rds"))
