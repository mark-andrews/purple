//
//
//
//

functions {
  // Partial sum function for the multivariate normal log-likelihood
  real partial_sum_likelihood(int[] y_slice_idx, int start, int end, 
                              vector x, vector y, vector centers, 
                              vector w, real rho, real intercept, real sigma, real ell) {
    int N = end - start + 1;      // number of data points in this slice
    int K = num_elements(w);
    matrix[N, K] Phi;             // Design matrix (RBF evaluated at each data point)
    matrix[N, N] Sigma;           // covariance matrix
    vector[N] y_slice;
    vector[N] mu_slice;

    // Get the slice of the data
    for (i in 1:N) {
      y_slice[i] = y[y_slice_idx[start + i - 1]];
    }

    // Build the design matrix for the slice using RBFs
    for (i in 1:N) {
      for (j in 1:K) {
        Phi[i, j] = exp(-0.5 * square(x[y_slice_idx[start + i - 1]] - centers[j]) / square(rho));
      }
    }
    
    // Build covariance matrix for the slice
    for (i in 1:N) {
      for (j in 1:N) {
        Sigma[i, j] = square(sigma) * exp(-0.5 * square(x[y_slice_idx[start + i - 1]] - x[y_slice_idx[start + j - 1]]) / square(ell));
      }
    }
    
    // Mean vector for the slice
    mu_slice = Phi * w + intercept;

    // Return the log-likelihood contribution from this slice
    return multi_normal_lpdf(y_slice | mu_slice, Sigma);
  }
}

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
  real<lower=0> ell;            // Length-scale parameter for RBF kernel
}

model {
  int grainsize = 1;            // You can adjust the grainsize as needed

  // Priors
  w ~ normal(0, 10);             // Prior on weights
  rho ~ normal(0, 10);           // Prior on length-scale for RBFs
  intercept ~ normal(0, 10);     // Prior on intercept
  sigma ~ student_t(3, 0, 10);   // Prior on observation noise
  ell ~ student_t(3, 0, 10);     // Prior for RBF kernel length-scale
  
  // Use reduce_sum to parallelize the likelihood computation
  target += reduce_sum(partial_sum_likelihood, y, grainsize, x, y, centers, w, rho, intercept, sigma, ell);
}

generated quantities {
  vector[N] y_pred;
  
  // Predictions for the latent function
  for (i in 1:N) {
    y_pred[i] = dot_product(w, exp(-0.5 * square(x[i] - centers) / square(rho))) + intercept;
  }
}
