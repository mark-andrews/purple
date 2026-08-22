// M4: RBF weights vary by subject and by electrode, crossed.
//
// Combines M1 and M2: population mean plus an additive subject deviation
// plus an additive electrode deviation, no interaction between them and
// no trial variation yet. Still no stimulus covariates. This is the
// first genuinely crossed-random-effects model in the ladder.

data {
  int<lower=1> N;
  int<lower=1> K;
  int<lower=1> S;
  int<lower=1> E;
  vector[N] time;
  vector[N] y;
  array[N] int<lower=1, upper=S> subject;
  array[N] int<lower=1, upper=E> electrode;
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
  vector<lower=0>[K] tau_subject;
  matrix[K, S] z_subject;
  vector<lower=0>[K] tau_electrode;
  matrix[K, E] z_electrode;
  real<lower=0> sigma;
}

transformed parameters {
  matrix[K, S] dev_subject = diag_pre_multiply(tau_subject, z_subject);
  matrix[K, E] dev_electrode = diag_pre_multiply(tau_electrode, z_electrode);
}

model {
  w0 ~ normal(0, 5);
  tau_subject ~ student_t(3, 0, 2);
  to_vector(z_subject) ~ std_normal();
  tau_electrode ~ student_t(3, 0, 2);
  to_vector(z_electrode) ~ std_normal();
  sigma ~ student_t(3, 0, 5);

  vector[N] mu;
  for (n in 1:N)
    mu[n] = dot_product(Phi[n], w0 + dev_subject[, subject[n]] + dev_electrode[, electrode[n]]);
  y ~ normal(mu, sigma);
}
