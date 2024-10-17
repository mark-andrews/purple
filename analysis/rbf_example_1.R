library(tidyverse)
# Set seed for reproducibility
set.seed(42)

# Number of data points
N <- 50

# Generate input data (x) evenly spaced between 0 and 10
x <- seq(0, 10, length.out = N)

# Specify centers for the RBFs
centers <- c(2, 5, 8)  # manually specified centers
K <- length(centers)  # number of RBFs

# Define RBF function (squared exponential)
rbf <- function(x, c, rho) {
  exp(-0.5 * ((x - c)^2) / rho^2)
}

# True weights for the RBFs
true_w <- c(3, -2, 1)

# Generate true underlying function using the RBFs
rho <- 1.0  # length scale for RBFs
y_true <- rep(0, N)
for (i in 1:K) {
  y_true <- y_true + true_w[i] * rbf(x, centers[i], rho)
}

# Add noise to the observations
sigma_noise <- 0.5
y_observed <- y_true + rnorm(N, mean = 0, sd = sigma_noise)

# Create a data frame for the generated data
data_df <- data.frame(x = x, y_observed = y_observed)

# Plot the generated data
plot(x, y_observed, pch = 19, col = "blue", main = "Generated RBF Data", 
     xlab = "x", ylab = "y_observed")
lines(x, y_true, col = "red", lwd = 2)  # Plot the true function (without noise)

# Prepare data ------------------------------------------------------------

# Create the list of data for Stan
stan_data <- list(
  N = nrow(data_df),            # Number of data points
  K = length(centers),            # Number of RBFs
  x = data_df$x,            # Input data
  y = data_df$y_observed,            # Observed output data
  centers = centers # Manually specified centers
)

# Call cmdstan ------------------------------------------------------------
library(cmdstanr)
mod <- cmdstan_model('analysis/rbf_example_1.stan')

fit_optim <- mod$optimize(data = stan_data, jacobian = TRUE)
fit_optim$summary() %>% 
  filter(str_detect(variable, '^w|rho|sigma|intercept') )

fit_laplace <- mod$laplace(data = stan_data, mode = fit_optim, draws = 2000)
fit_laplace$summary() %>% 
  filter(str_detect(variable, '^w|rho|sigma|intercept') )

fit_vb <- mod$variational(data = stan_data, seed = 10101)
fit_vb$summary() %>% 
  filter(str_detect(variable, '^w|rho|sigma|intercept') )

fit_pf <- mod$pathfinder(data = stan_data, seed = 123)
fit_pf$summary() %>% 
  filter(str_detect(variable, '^w|rho|sigma|intercept') )


# Call rstan --------------------------------------------------------------

# Load rstan library
library(rstan)

# Fit the Stan model using the data and the Stan model file
fit <- stan(
  file = "analysis/rbf_example_1.stan",  # Path to your Stan model file
  data = stan_data,         # Data for Stan
  iter = 2000,              # Number of iterations
  chains = 4,               # Number of chains
  seed = 42                 # Seed for reproducibility
)

summary(fit)$summary %>% 
  as_tibble(rownames = 'variable') %>% 
  filter(str_detect(variable, '^w|rho|sigma|intercept') )
