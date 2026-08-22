// M2: RBF weights vary by electrode only.
//
// Mirror image of M1: each electrode gets its own deviation from a
// population-mean weight vector. No subject or trial variation, no
// stimulus covariates. No spatial covariance is imposed between
// electrodes; they are treated as an ordinary, unstructured grouping
// factor.

data {
  int<lower=1> N;
  int<lower=1> K;
  int<lower=1> E;                           // number of electrodes
  vector[N] time;
  vector[N] y;
  array[N] int<lower=1, upper=E> electrode; // electrode index for each observation
  vector[K] centers;
  real<lower=0> width;
}

transformed data {
  matrix[N, K] Phi;
  for (n in 1:N)
    for (k in 1:K)
      Phi[n, k] = exp(-0.5 * square(time[n] - centers[k]) / square(width));
}

parameters {
  vector[K] w0;
  vector<lower=0>[K] tau_electrode;
  matrix[K, E] z_electrode;
  real<lower=0> sigma;
}

transformed parameters {
  matrix[K, E] dev_electrode = diag_pre_multiply(tau_electrode, z_electrode);
}

model {
  w0 ~ normal(0, 5);
  tau_electrode ~ student_t(3, 0, 2);
  to_vector(z_electrode) ~ std_normal();
  sigma ~ student_t(3, 0, 5);

  vector[N] mu;
  for (n in 1:N)
    mu[n] = dot_product(Phi[n], w0 + dev_electrode[, electrode[n]]);
  y ~ normal(mu, sigma);
}
