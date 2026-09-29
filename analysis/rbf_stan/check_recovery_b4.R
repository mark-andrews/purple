# Recovery check for B4. Compares the effect curves estimated with and
# without known effects added to the data (fit_rbf_multilevel.R addeff=1
# and addeff=0, otherwise identical). Their difference should reproduce
# the added curves. Writes tmp/b4_recovery.png and prints a summary.
#
#   Rscript analysis/rbf_stan/check_recovery_b4.R <draws file addeff=0> <draws file addeff=1>

library(tidyverse)
library(posterior)

args <- commandArgs(trailingOnly = TRUE)
r0 <- readRDS(args[1])
r1 <- readRDS(args[2])
time <- r1$time
T <- length(time)
get <- function(r, v) as_draws_matrix(r$draws)[, str_c(v, "[", seq_len(T), "]")]

out <- map_dfr(c(subj = "effect_subj", trial = "effect_trial"), function(v) {
  # Posterior draws of the difference, pairing draws arbitrarily. The
  # two fits are independent, so this is the posterior of the difference.
  D <- get(r1, v) - get(r0, v)
  tibble(time = time,
         q5 = apply(D, 2, quantile, 0.05),
         q50 = apply(D, 2, median),
         q95 = apply(D, 2, quantile, 0.95))
}, .id = "effect") |>
  mutate(truth = c(r1$true_effect$subj, r1$true_effect$trial))

out |>
  summarise(max_abs_error = max(abs(q50 - truth)),
            peak_truth = truth[which.max(abs(truth))],
            peak_estimate = q50[which.max(abs(truth))],
            coverage_90 = mean(truth >= q5 & truth <= q95),
            .by = effect) |>
  print()

g <- ggplot(out, aes(x = time)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_ribbon(aes(ymin = q5, ymax = q95), fill = "steelblue", alpha = 0.3) +
  geom_line(aes(y = q50), colour = "steelblue") +
  geom_line(aes(y = truth), colour = "black", linetype = "dashed") +
  facet_wrap(~effect, ncol = 1, scales = "free_y",
             labeller = as_labeller(c(subj = "Subject-level (accuracy) effect",
                                      trial = "Trial-level (ratio) effect"))) +
  theme_minimal() +
  labs(x = "Time (ms)", y = "uV",
       title = "B4 recovery: estimated added effect (blue) against truth (dashed)")
ggsave("tmp/b4_recovery.png", g, width = 7, height = 6)
