// M5: RBF weights vary by subject, electrode, and trial, all crossed.
//
// The full random-effects structure with no covariates yet: population
// mean plus additive deviations for subject, electrode, and trial. Trial
// and electrode are crossed within subject (every trial is observed at
// every electrode); trial is in turn specific to a subject. To keep the
// indexing flat and avoid an explicit nesting statement, `trial` here is
// assumed to be a globally unique trial id assigned at data-prep time
// (e.g. subject and within-subject trial number combined), not a
// within-subject trial number reused across subjects.

data {
  int<lower=1> N;
  int<lower=1> K;
  int<lower=1> S;
  int<lower=1> E;
  int<lower=1> Tr;
  vector[N] time;
  vector[N] y;
  array[N] int<lower=1, upper=S> subject;
  array[N] int<lower=1, upper=E> electrode;
  array[N] int<lower=1, upper=Tr> trial;   // globally unique trial id
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
  vector<lower=0>[K] tau_trial;
  matrix[K, Tr] z_trial;
  real<lower=0> sigma;
}

transformed parameters {
  matrix[K, S] dev_subject = diag_pre_multiply(tau_subject, z_subject);
  matrix[K, E] dev_electrode = diag_pre_multiply(tau_electrode, z_electrode);
  matrix[K, Tr] dev_trial = diag_pre_multiply(tau_trial, z_trial);
}

model {
  w0 ~ normal(0, 5);
  tau_subject ~ student_t(3, 0, 2);
  to_vector(z_subject) ~ std_normal();
  tau_electrode ~ student_t(3, 0, 2);
  to_vector(z_electrode) ~ std_normal();
  tau_trial ~ student_t(3, 0, 2);
  to_vector(z_trial) ~ std_normal();
  sigma ~ student_t(3, 0, 5);

  vector[N] mu;
  for (n in 1:N)
    mu[n] = dot_product(Phi[n], w0
                                 + dev_subject[, subject[n]]
                                 + dev_electrode[, electrode[n]]
                                 + dev_trial[, trial[n]]);
  y ~ normal(mu, sigma);
}
