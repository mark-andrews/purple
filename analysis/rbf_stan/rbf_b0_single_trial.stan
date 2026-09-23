/* B0. One subject, one trial, one electrode.
 *
 * A Gaussian radial basis function regression of voltage on time, with a
 * stationary AR(p) residual process and a ridge-plus-curvature prior on
 * the basis weights. Setting p = 0 recovers iid Gaussian noise exactly,
 * so this one file fits both the naive and the correlated-noise model.
 *
 * This is the base case of the ladder. Every model above it adds group
 * structure to the weights and changes nothing else.
 */

functions {
  /* Exact log density of a length-T mean-zero stationary AR(p) process,
   * by the prediction-error decomposition.
   *
   * `a` holds the AR coefficients at every order up to p, with row k
   * giving the order-k coefficients in columns 1:k. `v[k+1]` is
   * prod_{i<=k} (1 - r_i^2), the ratio of the order-k prediction variance
   * to the marginal variance. Both come from the Levinson-Durbin
   * recursion in transformed parameters. `sigma` is the MARGINAL standard
   * deviation of eps, not the innovation standard deviation.
   *
   * No T x T matrix is formed and no Cholesky is taken. The cost is
   * O(T p).
   */
  real ar_loglik(vector eps, matrix a, vector v, real sigma, int p) {
    int T = num_elements(eps);
    int p_use = min(p, T);
    vector[T] mu = rep_vector(0, T);
    vector[T] sd_t;

    /* The first p observations each have fewer than p predecessors, so
     * each uses a different row of `a` and a different prediction
     * variance. Handling them this way, rather than conditioning on them,
     * is what makes the likelihood exact. */
    for (t in 1 : p_use) {
      int k = t - 1;
      sd_t[t] = sigma * sqrt(v[k + 1]);
      for (j in 1 : k) {
        mu[t] += a[k, j] * eps[t - j];
      }
    }

    /* Every remaining observation uses the full order p with the same
     * coefficients, so the weighted sum is a single dot product. `arev`
     * is row p of `a` reversed, which lines it up with
     * eps[t-p], ..., eps[t-1] in increasing index order. */
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
  int<lower=1> T;                          // timepoints, after decimation
  int<lower=1> K;                          // basis functions
  int<lower=0> p;                          // AR order; 0 gives iid noise
  vector[T] time;                          // ms, relative to stimulus onset
  vector[T] y;                             // voltage, uV

  // Basis: centres and nominal widths, fixed as data, not estimated.
  vector[K] centre;
  vector<lower=0>[K] width;

  /* Density blocks. The curvature prior needs the weights it differences
   * to sit on an ordered grid, and the basis is a concatenation of two
   * grids of different spacing, so the prior is applied within each block
   * separately. Block b occupies weights block_start[b] : block_start[b]
   * + block_size[b] - 1. */
  int<lower=1> n_block;
  array[n_block] int<lower=1> block_start;
  array[n_block] int<lower=1> block_size;

  // Prior scales, supplied as data so they can be varied without editing
  // the model. See the driver script for the values used and why.
  real<lower=0> prior_sd_alpha;
  real<lower=0> prior_sd_ridge;
  real<lower=0> prior_sd_curv;
  real<lower=0> prior_sd_sigma;
  real<lower=0> prior_sd_log_width;        // set very small to fix widths
}

parameters {
  real alpha;                              // intercept
  vector[K] w;                             // basis weights
  vector<lower=0>[n_block] tau_ridge;       // shrinkage of w towards zero
  vector<lower=0>[n_block] tau_curv;        // shrinkage of w towards smooth
  real<lower=0> width_mult;                 // global multiplier on `width`
  real<lower=0> sigma;                      // MARGINAL sd of eps
  vector<lower=-1, upper=1>[p] r;           // partial autocorrelations
}

transformed parameters {
  matrix[T, K] B;                           // design matrix
  matrix[p, p] a = rep_matrix(0, p, p);
  vector[p + 1] v;

  for (k in 1 : K) {
    B[, k] = exp(-0.5 * square((time - centre[k]) / (width_mult * width[k])));
  }

  /* Levinson-Durbin. The image of the open cube (-1, 1)^p under this map
   * is exactly the stationarity region, so stationarity is enforced by
   * construction rather than by rejection. */
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
  alpha ~ normal(0, prior_sd_alpha);

  // Ridge component. Penalises amplitude, and covers the linear-in-k
  // directions that the curvature component leaves unpenalised.
  for (b in 1 : n_block) {
    segment(w, block_start[b], block_size[b]) ~ normal(0, tau_ridge[b]);
  }

  // Curvature component. Second differences of the weight sequence within
  // a block approximate the second derivative of the fitted curve, so this
  // is the discrete roughness penalty of a penalised spline, written as a
  // prior. Large excursions are unpenalised provided they are smooth.
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

  tau_ridge ~ normal(0, prior_sd_ridge);    // half-normal via <lower=0>
  tau_curv ~ normal(0, prior_sd_curv);
  width_mult ~ lognormal(0, prior_sd_log_width);
  sigma ~ normal(0, prior_sd_sigma);
  // r is implicitly uniform on (-1, 1)^p, which is flat on the
  // stationarity region.

  target += ar_loglik(y - alpha - B * w, a, v, sigma, p);
}

generated quantities {
  vector[p] phi;                            // AR coefficients at order p
  real sigma_innovation = sigma * sqrt(v[p + 1]);
  vector[T] mu_fitted = alpha + B * w;
  real log_lik;                             // one value: the whole trial

  for (j in 1 : p) {
    phi[j] = a[p, j];
  }

  log_lik = ar_loglik(y - mu_fitted, a, v, sigma, p);
}
