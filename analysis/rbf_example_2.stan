data {
  int<lower=1> N;               // Number of data points
  int<lower=1> K;               // Number of RBFs
  vector[N] x;                  // Input data
  vector[N] y;                  // Output (observed data)
  vector[K] centers;            // Manually specified centers of RBFs
}

parameters {
  real<lower=0> rho;            // Length-scale for the RBF
  vector[K] w;                  // Weights for each RBF
  real intercept;               // Intercept term
  real<lower=0> sigma;          // Noise standard deviation
  real<lower=0> ell;          // length-scale parameter for RBF
}

model {
  matrix[N, K] Phi;             // Design matrix (RBF evaluated at each data point)
  matrix[N, N] Sigma;         // covariance matrix
  
  // Build the design matrix using RBFs
  for (i in 1:N) {
    for (j in 1:K) {
      Phi[i, j] = exp(-0.5 * square(x[i] - centers[j]) / square(rho));
    }
  }
  
  for (i in 1:N) {
    for (j in 1:N) {
      Sigma[i, j] = square(sigma) * exp(-0.5 * square(x[i] - x[j]) / square(ell));
    }
  }
 
  // Priors
  w ~ normal(0, 10);             // Prior on weights
  rho ~ normal(0, 10);           // Prior on length-scale
  intercept ~ normal(0, 10);     // Prior on intercept
  sigma ~ student_t(3, 0, 10);         // Prior on observation noise
  ell ~ student_t(3, 0, 10);         // Prior for length-scale
  
  // Likelihood
  y ~ multi_normal(Phi * w + intercept, Sigma);
}

generated quantities {
  vector[N] y_pred;
  
  // Predictions for the latent function
  for (i in 1:N) {
    y_pred[i] = dot_product(w, exp(-0.5 * square(x[i] - centers) / square(rho))) + intercept;
  }
}
