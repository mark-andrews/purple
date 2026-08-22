// M1: RBF weights vary by subject only.
//
// Adds the first source of multilevel variation to M0: each subject gets
// their own deviation from a population-mean weight vector. No electrode
// or trial variation yet, and no stimulus covariates. Non-centered
// parameterization throughout this model family for sampling efficiency.

data {
  int<lower=1> N;
  int<lower=1> K;
  int<lower=1> S;                          // number of subjects
  vector[N] time;
  vector[N] y;
  array[N] int<lower=1, upper=S> subject;  // subject index for each observation
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
  vector[K] w0;                     // population-level mean weights
  vector<lower=0>[K] tau_subject;   // sd of subject deviations, per basis function
  matrix[K, S] z_subject;           // raw N(0,1) deviations, non-centered
  real<lower=0> sigma;
}

transformed parameters {
  matrix[K, S] dev_subject = diag_pre_multiply(tau_subject, z_subject);
}

model {
  w0 ~ normal(0, 5);
  tau_subject ~ student_t(3, 0, 2);
  to_vector(z_subject) ~ std_normal();
  sigma ~ student_t(3, 0, 5);

  vector[N] mu;
  for (n in 1:N)
    mu[n] = dot_product(Phi[n], w0 + dev_subject[, subject[n]]);
  y ~ normal(mu, sigma);
}
