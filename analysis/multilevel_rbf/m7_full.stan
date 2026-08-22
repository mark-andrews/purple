// M7: full model. Multilevel RBF weights (subject, electrode, trial,
// crossed as in M5) plus stimulus covariates on the population mean
// function (as in M6). This is the target model for the abstract's
// "primary analysis": a random-function-effects generalisation of a
// varying-slopes-varying-intercepts mixed model, with numerosity and
// numerosity ratio entering as predictors of the population-level mean
// waveform.
//
// As in M5, `trial` is a globally unique trial id, not a within-subject
// trial number. As in M6, covariates are expected to be
// centered/standardized upstream of Stan.

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
  array[N] int<lower=1, upper=Tr> trial;
  vector[N] numerosity;
  vector[N] ratio;
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
  vector[K] g_numerosity;
  vector[K] g_ratio;

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
  g_numerosity ~ normal(0, 2);
  g_ratio ~ normal(0, 2);

  tau_subject ~ student_t(3, 0, 2);
  to_vector(z_subject) ~ std_normal();
  tau_electrode ~ student_t(3, 0, 2);
  to_vector(z_electrode) ~ std_normal();
  tau_trial ~ student_t(3, 0, 2);
  to_vector(z_trial) ~ std_normal();

  sigma ~ student_t(3, 0, 5);

  vector[N] mu;
  for (n in 1:N) {
    vector[K] w_n = w0
                    + numerosity[n] * g_numerosity
                    + ratio[n] * g_ratio
                    + dev_subject[, subject[n]]
                    + dev_electrode[, electrode[n]]
                    + dev_trial[, trial[n]];
    mu[n] = dot_product(Phi[n], w_n);
  }
  y ~ normal(mu, sigma);
}
