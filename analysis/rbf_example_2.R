# Load rstan library
#library(rstan)
#library(cmdstanr)
#library(tidyverse)

data_df <- read_csv("analysis/s13_b2_t14.csv")

# Specify the data generated in the previous step
N <- nrow(data_df) # number of data points
x <- data_df$x # input data (x)
y <- data_df$y # observed output data (y)

# Specify the centers for the RBFs
centers <- seq(-250, 1000, by = 100) # manually specify centers for the RBFs
K <- length(centers) # number of RBFs

# ===========================================================================
# Define the RBF kernel function
rbf_kernel <- function(x1, x2, length_scale, sigma_f) {
  dist_sq <- sum((x1 - x2)^2)  # Squared Euclidean distance
  return(sigma_f^2 * exp(-0.5 * dist_sq / length_scale^2))
}

# Create the kernel matrix
create_kernel_matrix <- function(X, length_scale, sigma_f) {
  n <- length(X)
  K <- matrix(0, n, n)
  
  for (i in 1:n) {
    for (j in 1:n) {
      K[i, j] <- rbf_kernel(X[i], X[j], length_scale, sigma_f)
    }
  }
  
  K + diag(nrow(K)) * 1e-6
}
Sigma <- create_kernel_matrix(x, length_scale=10, sigma_f=1)
#plot(MASS::mvrnorm(mu = rep(0, length(x)), Sigma = Sigma))


# ===========================================================================
stan_data <- list(
  N = N, # Number of data points
  K = K, # Number of RBFs
  x = x, # Input data
  y = y, # Observed output data
  Sigma = Sigma,
  centers = centers # Manually specified centers
)

# Cmdstan -----------------------------------------------------------------
mod <- cmdstan_model('analysis/rbf_example_2.stan')

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



# Rstan -------------------------------------------------------------------


# Fit the Stan model using the data and the Stan model file
fit <- stan(
  file = "analysis/rbf_example_2a.stan", # Path to your Stan model file
  data = stan_data, # Data for Stan
  iter = 2000, # Number of iterations
  chains = 4, # Number of chains
  cores = 4,
  seed = 42 # Seed for reproducibility
)

# Print the results of the model fitting
summary(fit)$summary %>%
  as_tibble(rownames = "par") %>%
  filter(str_detect(par, "^w"))

# Plot the trace and diagnostics
traceplot(fit)

# Extract the posterior samples
#posterior_samples <- rstan::extract(fit)

# Get the predictions
y_pred <- posterior_samples$y_pred

# Plot the predictions (first chain, for example)
plot(x, y, pch = 19, col = "blue", main = "Observed vs Predicted", xlab = "x", ylab = "y")
lines(x, apply(y_pred, 2, mean), col = "red", type = "l", lwd = 2) # Posterior mean predictions
