// M3: RBF weights vary by trial only.
//
// The third single-factor model: each trial gets its own deviation from
// a population-mean weight vector, e.g. all trials at one electrode for
// one subject. This is the case walked through informally first: trial
// is the grouping factor that plays the role of "varying slopes and
// intercepts across repeated measurements" in the ordinary linear mixed
// model analogy. No subject or electrode variation, no covariates.

data {
  int<lower=1> N;
  int<lower=1> K;
  int<lower=1> Tr;                      // number of trials
  vector[N] time;
  vector[N] y;
  array[N] int<lower=1, upper=Tr> trial; // trial index for each observation
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
  vector<lower=0>[K] tau_trial;
  matrix[K, Tr] z_trial;
  real<lower=0> sigma;
}

transformed parameters {
  matrix[K, Tr] dev_trial = diag_pre_multiply(tau_trial, z_trial);
}

model {
  w0 ~ normal(0, 5);
  tau_trial ~ student_t(3, 0, 2);
  to_vector(z_trial) ~ std_normal();
  sigma ~ student_t(3, 0, 5);

  vector[N] mu;
  for (n in 1:N)
    mu[n] = dot_product(Phi[n], w0 + dev_trial[, trial[n]]);
  y ~ normal(mu, sigma);
}
