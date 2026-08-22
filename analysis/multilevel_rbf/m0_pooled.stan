// M0: pooled radial basis function regression.
//
// The bottom of the ladder. A single global weight vector for the RBF
// expansion, fit to all rows of data pooled together: no variation across
// subjects, electrodes, or trials, and no stimulus covariates. This is
// the "plain nonlinear regression, nothing multilevel" baseline.

data {
  int<lower=1> N;             // number of observations (pooled over trials/electrodes/subjects)
  int<lower=1> K;             // number of RBF basis functions
  vector[N] time;             // time of each observation, in ms
  vector[N] y;                // observed voltage, in microvolts
  vector[K] centers;          // fixed centers of the RBFs, in ms
  real<lower=0> width;        // fixed width (length-scale) of the RBFs, in ms
}

transformed data {
  matrix[N, K] Phi;
  for (n in 1:N)
    for (k in 1:K)
      Phi[n, k] = exp(-0.5 * square(time[n] - centers[k]) / square(width));
}

parameters {
  vector[K] w;                // RBF weights
  real<lower=0> sigma;        // observation noise sd
}

model {
  w ~ normal(0, 5);
  sigma ~ student_t(3, 0, 5);
  y ~ normal(Phi * w, sigma);
}

generated quantities {
  vector[N] y_rep = to_vector(normal_rng(Phi * w, sigma));
}
