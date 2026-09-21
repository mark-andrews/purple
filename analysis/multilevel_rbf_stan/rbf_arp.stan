// Basis-function regression for a single ERP waveform, with a
// stationary AR(p) residual process.
//
//   y = alpha + B w + eps,   eps ~ MVN(0, sigma^2 R(phi))
//
// where B is a fixed RBF design matrix supplied as data and R(phi) is
// the correlation matrix of a stationary AR(p) process.
//
// The AR(p) is parameterised by its PARTIAL autocorrelations
// r[1..p], each free in (-1, 1). The Levinson-Durbin recursion maps
// these to the AR coefficients phi, and the image of the open cube
// (-1,1)^p under that map is exactly the stationarity region. So the
// stationarity constraint is enforced by construction, with no
// rejection sampling and no discontinuity in the posterior geometry.
// This is the Barndorff-Nielsen and Schou (1973) transformation, the
// same device the Stan User's Guide recommends for stationary AR
// models.
//
// The likelihood is EXACT, not conditional. It uses the
// prediction-error decomposition, which the same Levinson-Durbin
// recursion supplies for free: at time t the best linear predictor of
// eps[t] from its t-1 predecessors uses the order-(t-1) coefficients,
// with prediction variance sigma^2 * prod_{i<=t-1}(1 - r[i]^2). For
// t > p the coefficients settle to phi and the variance to the
// innovation variance. Cost is O(T p), no matrix is ever formed or
// inverted, and there is no Cholesky.
//
// Setting p = 0 recovers iid Gaussian noise exactly, so the same file
// fits the baseline model.

data {
  int<lower=1> T;                    // number of timepoints
  int<lower=1> K;                    // number of basis functions
  int<lower=0> p;                    // AR order; p = 0 gives iid noise
  matrix[T, K] B;                    // RBF design matrix (no intercept column)
  vector[T] y;                       // observed voltage
  real<lower=0> prior_sd_w;          // prior sd for basis weights
  real<lower=0> prior_sd_sigma;      // prior scale for residual sd
}

parameters {
  real alpha;                        // intercept
  vector[K] w;                       // basis weights
  real<lower=0> sigma;               // MARGINAL sd of eps, not the
                                     // innovation sd (see below)
  vector<lower=-1, upper=1>[p] r;    // partial autocorrelations
}

transformed parameters {
  // Levinson-Durbin: partial autocorrelations -> AR coefficients at
  // every order up to p. a[k, 1:k] holds the order-k coefficients.
  matrix[p, p] a = rep_matrix(0, p, p);
  vector[p + 1] v;                   // v[k+1] = prod_{i<=k} (1 - r[i]^2)

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
  vector[T] eps = y - alpha - B * w;

  // Priors. Weak but proper. prior_sd_w should be set on the scale of
  // the data: the weights are voltages, and with overlapping RBFs they
  // can be considerably larger than the waveform itself.
  alpha ~ normal(0, prior_sd_w);
  w ~ normal(0, prior_sd_w);
  sigma ~ normal(0, prior_sd_sigma);         // half-normal via <lower=0>
  r ~ uniform(-1, 1);                        // flat on the stationarity region

  // Exact likelihood by prediction-error decomposition.
  for (t in 1 : T) {
    int k = min(t - 1, p);                   // order usable at this t
    real mu = 0;
    for (j in 1 : k) {
      mu += a[k, j] * eps[t - j];
    }
    target += normal_lpdf(eps[t] | mu, sigma * sqrt(v[k + 1]));
  }
}

generated quantities {
  vector[p] phi;                             // AR coefficients
  real sigma_innovation = sigma * sqrt(v[p + 1]);
  vector[T] mu_fitted = alpha + B * w;
  vector[T] log_lik;                         // for loo / PSIS-LOO
  real ar_frequency = not_a_number();        // Hz, if AR(2) oscillates

  for (j in 1 : p) {
    phi[j] = a[p, j];
  }

  {
    vector[T] eps = y - mu_fitted;
    for (t in 1 : T) {
      int k = min(t - 1, p);
      real mu = 0;
      for (j in 1 : k) {
        mu += a[k, j] * eps[t - j];
      }
      log_lik[t] = normal_lpdf(eps[t] | mu, sigma * sqrt(v[k + 1]));
    }
  }
}
