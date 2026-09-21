/* B1, B2 and B3. Multilevel Gaussian radial basis function regression of
 * single-curve EEG voltage on time, at one electrode.
 *
 * One file covers three models, selected by two data flags:
 *
 *   B1  use_subject = 1, use_trial = 0   curves are subject averages
 *   B2  use_subject = 0, use_trial = 1   curves are trials, one subject
 *   B3  use_subject = 1, use_trial = 1   curves are trials, all subjects
 *
 * The unit of data is a curve: one voltage waveform over the T timepoints
 * of the decimated epoch. Every curve shares the same time grid, so the
 * design matrix is built once and reused. The AR(p) residual runs within
 * a curve and never across curves.
 *
 * Population weights use all K basis functions. Subject and trial
 * deviations use only the first Kr, which must be the coarse block. That
 * restriction is the smoothness control at those levels, and it is
 * deliberate: the narrow basis functions are exactly the ones capable of
 * chasing single-trial noise.
 */

functions {
  /* Exact log density of a length-T mean-zero stationary AR(p) process.
   * See stan/rbf_b0_single_trial.stan for the full explanation. */
  real ar_loglik(vector eps, matrix a, vector v, real sigma, int p) {
    int T = num_elements(eps);
    int p_use = min(p, T);
    vector[T] mu = rep_vector(0, T);
    vector[T] sd_t;

    for (t in 1 : p_use) {
      int k = t - 1;
      sd_t[t] = sigma * sqrt(v[k + 1]);
      for (j in 1 : k) {
        mu[t] += a[k, j] * eps[t - j];
      }
    }

    if (p > 0 && T > p) {
      vector[p] arev;
      for (j in 1 : p) {
        arev[j] = a[p, p + 1 - j];
      }
      for (t in (p + 1) : T) {
        mu[t] = dot_product(arev, segment(eps, t - p, p));
        sd_t[t] = sigma * sqrt(v[p + 1]);
      }
    } else if (p == 0) {
      sd_t = rep_vector(sigma, T);
    }

    return normal_lpdf(eps | mu, sd_t);
  }
}

data {
  int<lower=1> T;                          // timepoints per curve
  int<lower=1> N;                          // curves
  int<lower=1> J;                          // subjects
  int<lower=1> K;                          // basis functions, population
  int<lower=1, upper=K> Kr;                // basis functions, group levels
  int<lower=0> p;                          // AR order; 0 gives iid noise

  int<lower=0, upper=1> use_subject;
  int<lower=0, upper=1> use_trial;

  vector[T] time;                          // ms, shared by every curve
  matrix[T, N] Y;                          // one curve per COLUMN
  array[N] int<lower=1, upper=J> subj;     // subject of each curve

  vector[K] centre;
  vector<lower=0>[K] width;

  int<lower=1> n_block;
  array[n_block] int<lower=1> block_start;
  array[n_block] int<lower=1> block_size;

  real<lower=0> prior_sd_alpha;
  real<lower=0> prior_sd_ridge;
  real<lower=0> prior_sd_curv;
  real<lower=0> prior_sd_tau_subj;
  real<lower=0> prior_sd_tau_trial;
  real<lower=0> prior_sd_sigma;
  real<lower=0> prior_sd_log_width;
}

transformed data {
  // Zero-sized containers switch a level off without a separate model
  // file. A matrix with zero rows contributes nothing anywhere.
  int Ks = use_subject ? Kr : 0;
  int Js = use_subject ? J : 0;
  int Kt = use_trial ? Kr : 0;
  int Nt = use_trial ? N : 0;
}

parameters {
  real alpha;
  vector[K] w;                              // population weights
  vector<lower=0>[n_block] tau_ridge;
  vector<lower=0>[n_block] tau_curv;
  real<lower=0> width_mult;

  // Non-centred. z is standard normal and the scale multiplies it, which
  // keeps the geometry clean when a variance component is weakly
  // identified. One scale per basis function, no covariance between basis
  // dimensions, matching the uncorrelated random slopes used in the lme4
  // smoke tests.
  matrix[Ks, Js] z_subj;
  vector<lower=0>[Ks] tau_subj;
  matrix[Kt, Nt] z_trial;
  vector<lower=0>[Kt] tau_trial;

  real<lower=0> sigma;                      // MARGINAL sd of eps
  vector<lower=-1, upper=1>[p] r;
}

transformed parameters {
  matrix[T, K] B;
  matrix[p, p] a = rep_matrix(0, p, p);
  vector[p + 1] v;

  for (k in 1 : K) {
    B[, k] = exp(-0.5 * square((time - centre[k]) / (width_mult * width[k])));
  }

  v[1] = 1;
  for (k in 1 : p) {
    a[k, k] = r[k];
    for (j in 1 : (k - 1)) {
      a[k, j] = a[k - 1, j] - r[k] * a[k - 1, k - j];
    }
    v[k + 1] = v[k] * (1 - square(r[k]));
  }
}

model {
  vector[T] pop = alpha + B * w;

  // Each subject's and each curve's deviation waveform, all at once.
  // block(B, 1, 1, T, Kr) is the coarse part of the design matrix.
  matrix[T, Js] dev_subj;
  matrix[T, Nt] dev_trial;

  if (use_subject) {
    dev_subj = block(B, 1, 1, T, Kr)
               * diag_pre_multiply(tau_subj, z_subj);
  }
  if (use_trial) {
    dev_trial = block(B, 1, 1, T, Kr)
                * diag_pre_multiply(tau_trial, z_trial);
  }

  alpha ~ normal(0, prior_sd_alpha);

  for (b in 1 : n_block) {
    segment(w, block_start[b], block_size[b]) ~ normal(0, tau_ridge[b]);
  }

  for (b in 1 : n_block) {
    int s = block_start[b];
    int n = block_size[b];
    if (n >= 3) {
      vector[n - 2] d2 = segment(w, s + 2, n - 2)
                         - 2 * segment(w, s + 1, n - 2)
                         + segment(w, s, n - 2);
      d2 ~ normal(0, tau_curv[b]);
    }
  }

  tau_ridge ~ normal(0, prior_sd_ridge);
  tau_curv ~ normal(0, prior_sd_curv);
  width_mult ~ lognormal(0, prior_sd_log_width);
  sigma ~ normal(0, prior_sd_sigma);

  to_vector(z_subj) ~ std_normal();
  to_vector(z_trial) ~ std_normal();
  tau_subj ~ normal(0, prior_sd_tau_subj);
  tau_trial ~ normal(0, prior_sd_tau_trial);

  for (n in 1 : N) {
    vector[T] mu = pop;
    if (use_subject) {
      mu += dev_subj[, subj[n]];
    }
    if (use_trial) {
      mu += dev_trial[, n];
    }
    target += ar_loglik(Y[, n] - mu, a, v, sigma, p);
  }
}

generated quantities {
  vector[p] phi;
  real sigma_innovation = sigma * sqrt(v[p + 1]);
  vector[T] mu_pop = alpha + B * w;

  /* One log-likelihood value per curve, not per timepoint. Leaving out one
   * timepoint from an autocorrelated series is nearly free and tells you
   * almost nothing, so the honest cross-validation unit here is the whole
   * curve. This makes loo() on these draws leave-one-trial-out. */
  vector[N] log_lik;

  for (j in 1 : p) {
    phi[j] = a[p, j];
  }

  {
    matrix[T, Js] dev_subj;
    matrix[T, Nt] dev_trial;

    if (use_subject) {
      dev_subj = block(B, 1, 1, T, Kr)
                 * diag_pre_multiply(tau_subj, z_subj);
    }
    if (use_trial) {
      dev_trial = block(B, 1, 1, T, Kr)
                  * diag_pre_multiply(tau_trial, z_trial);
    }

    for (n in 1 : N) {
      vector[T] mu = mu_pop;
      if (use_subject) {
        mu += dev_subj[, subj[n]];
      }
      if (use_trial) {
        mu += dev_trial[, n];
      }
      log_lik[n] = ar_loglik(Y[, n] - mu, a, v, sigma, p);
    }
  }
}
