// M6: stimulus covariates on the mean function, no multilevel structure.
//
// Orthogonal to M1-M5: instead of adding random deviations, the
// population-level weight vector is now itself a linear function of
// trial-level stimulus covariates (numerosity, numerosity ratio), so the
// mean ERP waveform shape can change with task difficulty. All rows are
// still pooled with no subject/electrode/trial variation, so this
// isolates the covariate-on-the-mean-function mechanism before it is
// combined with the multilevel structure in M7.
//
// Covariates are expected to be centered/standardized upstream of Stan.

data {
  int<lower=1> N;
  int<lower=1> K;
  vector[N] time;
  vector[N] y;
  vector[N] numerosity;    // standardized numerosity (e.g. mean of left/right count)
  vector[N] ratio;         // standardized numerosity ratio (smaller/larger)
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
  vector[K] w0;               // weights for the population mean function
  vector[K] g_numerosity;     // how the weights shift per unit of numerosity
  vector[K] g_ratio;          // how the weights shift per unit of ratio
  real<lower=0> sigma;
}

model {
  w0 ~ normal(0, 5);
  g_numerosity ~ normal(0, 2);
  g_ratio ~ normal(0, 2);
  sigma ~ student_t(3, 0, 5);

  vector[N] mu = Phi * w0 + numerosity .* (Phi * g_numerosity) + ratio .* (Phi * g_ratio);
  y ~ normal(mu, sigma);
}
