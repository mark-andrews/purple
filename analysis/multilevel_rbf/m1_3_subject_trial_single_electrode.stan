// M1+M3, single electrode: RBF weights vary by subject and trial, crossed.
//
// Not part of the main M0-M7 ladder. That ladder treats electrode as a
// crossed grouping factor throughout (M2, M4, M5, M7); this model instead
// fits one electrode at a time, so there is no electrode term at all.
// Structurally it is M1 (subject) and M3 (trial) combined, additively, with
// no stimulus covariates. Used for the first preliminary fits at POz, Oz,
// and Pz ahead of the BPS conference presentation (see logbook, 26 August
// 2026). Same non-centered parameterization as the rest of the family.
//
// `trial` must be a globally unique trial id across subjects (as in M3,
// M5, M7), not a within-subject trial number, even though only one
// electrode is in play here.

data {
  int<lower=1> N;
  int<lower=1> K;
  int<lower=1> S;                          // number of subjects
  int<lower=1> Tr;                         // number of trials (globally unique ids)
  vector[N] time;
  vector[N] y;
  array[N] int<lower=1, upper=S> subject;  // subject index for each observation
  array[N] int<lower=1, upper=Tr> trial;   // trial index for each observation
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
  vector<lower=0>[K] tau_trial;     // sd of trial deviations, per basis function
  matrix[K, Tr] z_trial;
  real<lower=0> sigma;
}

transformed parameters {
  matrix[K, S] dev_subject = diag_pre_multiply(tau_subject, z_subject);
  matrix[K, Tr] dev_trial = diag_pre_multiply(tau_trial, z_trial);
}

model {
  w0 ~ normal(0, 5);
  tau_subject ~ student_t(3, 0, 2);
  to_vector(z_subject) ~ std_normal();
  tau_trial ~ student_t(3, 0, 2);
  to_vector(z_trial) ~ std_normal();
  sigma ~ student_t(3, 0, 5);

  vector[N] mu;
  for (n in 1:N)
    mu[n] = dot_product(Phi[n], w0 + dev_subject[, subject[n]] + dev_trial[, trial[n]]);
  y ~ normal(mu, sigma);
}
