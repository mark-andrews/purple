library(tidyverse)
library(rstan)

# Generate some example data (replace this with your actual data)
N <- 100
x <- seq(0, 10, length.out = N)
y <- rnorm(N)  # Replace with observed data

# Centers for the slow and fast RBFs
centers_slow <- seq(0, 10, length.out = 10)
centers_fast <- seq(0, 10, length.out = 10)

# Prepare the data for Stan
stan_data <- list(
  N = N,
  K = length(centers_slow),  # Number of RBFs
  x = x,
  y = y,
  centers_slow = centers_slow,
  centers_fast = centers_fast
)

# Run the Stan model
fit <- stan(
  file = "analysis/rbf_example_4.stan",  # Path to your Stan model file
  data = stan_data,
  iter = 2000, chains = 4, cores=4, seed = 42
)

# Print and plot results
print(fit)
