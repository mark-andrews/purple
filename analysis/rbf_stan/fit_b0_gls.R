# B0's frequentist counterpart. Single trial, single electrode: RBF
# basis-function regression with a correlated residual process, fitted
# with nlme::gls.
#
# Run from the repository root, after extract_b0_trial.R. Needs nlme and
# signal, but not arrow or cmdstanr.
#
# The point of this script is the *noise* model, not the mean model. The
# mean is exactly the RBF expansion from smoke_test_lmer0.R, unchanged.
# What changes is that the residual is no longer assumed iid.
#
# gls() is the right tool here: it is lm() with a `correlation` argument.
# The mean model is specified identically. Everything you would do with
# lm() (coef, vcov, predict, AIC, anova) works the same way.

library(tidyverse)
library(nlme)

source("analysis/rbf_stan/rbf_common.R")

# Data ---------------------------------------------------------------------

eeg_df0_trial <- read_csv("tmp/b0_trial_POz.csv", show_col_types = FALSE)

# Decimate 1024 -> 128 Hz, with the same anti-aliased decimation as B0,
# so that both fit exactly the same data. See rbf_common.R.
trial_df <- eeg_df0_trial |>
  mutate(curve = 1L) |>
  decimate_curves(curve, by = 8L) |>
  select(-curve) |>
  mutate(idx = row_number()) # consecutive integer index for corAR1/corARMA

# Basis functions ----------------------------------------------------------
# Identical construction to smoke_test_lmer0.R.

rbf_design_matrix <- function(x, centers, width) {
  mapply(function(ctr, w) exp(-0.5 * (x - ctr)^2 / w^2), centers, width)
}

K_coarse <- 8
K_dense <- 8
dense_window <- c(0, 300)

centers_coarse <- seq(
  min(trial_df$time),
  max(trial_df$time),
  length.out = K_coarse
)
width_coarse <- diff(centers_coarse)[1]

centers_dense <- seq(dense_window[1], dense_window[2], length.out = K_dense)
width_dense <- diff(centers_dense)[1]

centers <- c(centers_coarse, centers_dense)
width <- c(rep(width_coarse, K_coarse), rep(width_dense, K_dense))
K <- length(centers)

trial_df <- trial_df |>
  bind_cols(
    rbf_design_matrix(trial_df$time, centers, width) |>
      as.data.frame() |>
      rename_with(~ str_c("b", seq_along(.)))
  )

basis_terms <- str_c("b", 1:K)
model_formula <- as.formula(
  str_c("voltage ~ ", str_c(basis_terms, collapse = " + "))
)

# Models -------------------------------------------------------------------

# The baseline: iid Gaussian noise. Numerically identical to lm().
M_iid <- gls(model_formula, data = trial_df)

# AR(1): each residual is phi times the previous one plus a fresh shock.
# One extra parameter.
M_ar1 <- gls(
  model_formula,
  data = trial_df,
  correlation = corAR1(form = ~idx)
)

# AR(2): two extra parameters. Unlike AR(1), can represent an
# oscillatory residual, which matters if alpha is present.
M_ar2 <- gls(
  model_formula,
  data = trial_df,
  correlation = corARMA(form = ~idx, p = 2)
)

print(AIC(M_iid, M_ar1, M_ar2))

# Diagnostics --------------------------------------------------------------

# 1. Is the iid assumption violated at all? If the residual
# autocorrelation at short lags is far from zero, yes.
acf(residuals(M_iid), lag.max = 30, main = "Residual ACF under iid model")

# 2. How much were the standard errors understated?
se_table <- tibble(
  term = names(coef(M_iid)),
  estimate = coef(M_iid),
  se_iid = sqrt(diag(vcov(M_iid))),
  se_ar1 = sqrt(diag(vcov(M_ar1))),
  se_ar2 = sqrt(diag(vcov(M_ar2)))
) |>
  mutate(inflation_ar2 = se_ar2 / se_iid)
print(se_table, n = Inf)

# 3. What frequency, if any, is the AR(2) residual oscillating at?
# Complex roots mean an oscillation; the implied frequency should be
# recognisable as a real EEG rhythm if the model is capturing something
# physiological rather than an artefact.
ar2_frequency <- function(m, fs = 128) {
  p <- coef(m$modelStruct$corStruct, unconstrained = FALSE)
  if (p[1]^2 + 4 * p[2] >= 0) {
    return(NA_real_) # real roots, no oscillation
  }
  acos(p[1] / (2 * sqrt(-p[2]))) / (2 * pi) * fs
}
cat("AR(2) implied residual frequency:", round(ar2_frequency(M_ar2), 2), "Hz\n")

# 4. Fitted curves. The point estimates should barely move. It is the
# uncertainty that changes.
trial_df |>
  mutate(fit_iid = fitted(M_iid), fit_ar2 = fitted(M_ar2)) |>
  ggplot(aes(x = time)) +
  geom_line(aes(y = voltage), colour = "grey70") +
  geom_line(aes(y = fit_iid), colour = "black") +
  geom_line(aes(y = fit_ar2), colour = "red", linetype = "dashed") +
  theme_minimal() +
  labs(
    x = "Time from stimulus onset (ms)",
    y = "Voltage (uV)",
    title = "Grey: data. Black: iid fit. Red dashed: AR(2) fit."
  )
