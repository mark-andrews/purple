data {
  int<lower=1> N;               // Number of data points
  int<lower=1> K;               // Number of RBFs (for both fast and slow)
  vector[N] x;                  // Input data
  vector[N] y;                  // Output (observed data)
  vector[K] centers_slow;       // Manually specified centers for slow RBFs
  vector[K] centers_fast;       // Manually specified centers for fast RBFs
}

parameters {
  real<lower=0> rho_slow;       // Length-scale for the slow RBF
  real<lower=0> rho_fast;       // Length-scale for the fast RBF
  vector[K] w_slow;             // Weights for each slow RBF
  vector[K] w_fast;             // Weights for each fast RBF
  real intercept;               // Intercept term
  real<lower=0> sigma;          // Noise standard deviation
}

model {
  matrix[N, K] Phi_slow;        // Design matrix for slow RBFs
  matrix[N, K] Phi_fast;        // Design matrix for fast RBFs
  
  // Build the design matrix using slow RBFs
  for (i in 1:N) {
    for (j in 1:K) {
      Phi_slow[i, j] = exp(-0.5 * square(x[i] - centers_slow[j]) / square(rho_slow));
    }
  }
  
  // Build the design matrix using fast RBFs
  for (i in 1:N) {
    for (j in 1:K) {
      Phi_fast[i, j] = exp(-0.5 * square(x[i] - centers_fast[j]) / square(rho_fast));
    }
  }
  
  // Priors
  w_slow ~ normal(0, 10);       // Prior on weights for slow RBF
  w_fast ~ normal(0, 10);       // Prior on weights for fast RBF
  rho_slow ~ normal(0, 10);     // Prior on length-scale for slow RBF
  rho_fast ~ normal(0, 10);     // Prior on length-scale for fast RBF
  intercept ~ normal(0, 10);    // Prior on intercept
  sigma ~ student_t(3, 0, 10);  // Prior on observation noise
  
  // Likelihood: sum of slow and fast RBFs
  y ~ normal(Phi_slow * w_slow + Phi_fast * w_fast + intercept, sigma);
}

generated quantities {
  vector[N] y_pred;
  
  // Predictions for the latent function (sum of slow and fast components)
    for (i in 1:N) {
      real slow_component = dot_product(w_slow, exp(-0.5 * square(x[i] - centers_slow) / square(rho_slow)));
      real fast_component = dot_product(w_fast, exp(-0.5 * square(x[i] - centers_fast) / square(rho_fast)));
      y_pred[i] = slow_component + fast_component + intercept;
    }
}
