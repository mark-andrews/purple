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
   * See the technical appendix of models.qmd (the AR parameterisation). */
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

  /* The same log density for every column of E at once, each column an
   * independent curve with the same AR parameters. Row t of the
   * prediction errors is formed for all curves together, so the cost is
   * T * p vector operations of length N rather than N separate calls,
   * which matters for automatic differentiation when N is in the
   * thousands. */
  real ar_loglik_matrix(matrix E, matrix a, vector v, real sigma, int p) {
    int T = rows(E);
    real lp = 0;
    for (t in 1 : T) {
      int k = min(t - 1, p);
      row_vector[cols(E)] e = E[t];
      for (j in 1 : k) {
        e -= a[k, j] * E[t - j];
      }
      lp += normal_lpdf(e | 0, sigma * sqrt(v[k + 1]));
    }
    return lp;
  }

  /* Apply the AR(p) whitening filter to every column of M: row t becomes
   * the one-step prediction error given the rows before it, divided by its
   * prediction sd. W'W is the inverse of the AR covariance, and the first
   * p rows use the lower-order predictors, so this is exact. */
  matrix ar_whiten(matrix M, matrix a, vector v, real sigma, int p) {
    int T = rows(M);
    matrix[T, cols(M)] out;
    for (t in 1 : T) {
      int k = min(t - 1, p);
      row_vector[cols(M)] e = M[t];
      for (j in 1 : k) {
        e -= a[k, j] * M[t - j];
      }
      out[t] = e / (sigma * sqrt(v[k + 1]));
    }
    return out;
  }

  /* W' U, for W the whitening operator applied by ar_whiten. */
  matrix ar_whiten_t(matrix U, matrix a, vector v, real sigma, int p) {
    int T = rows(U);
    matrix[T, cols(U)] out = rep_matrix(0, T, cols(U));
    for (t in 1 : T) {
      int k = min(t - 1, p);
      row_vector[cols(U)] u = U[t] / (sigma * sqrt(v[k + 1]));
      out[t] += u;
      for (j in 1 : k) {
        out[t - j] -= a[k, j] * u;
      }
    }
    return out;
  }

  /* trace(W S W') for symmetric S, using the band structure of W. */
  real ar_trace_band(matrix S, matrix a, vector v, real sigma, int p) {
    int T = rows(S);
    real tr = 0;
    for (t in 1 : T) {
      int k = min(t - 1, p);
      vector[k + 1] c;
      c[k + 1] = 1;
      for (j in 1 : k) {
        c[k + 1 - j] = -a[k, j];
      }
      tr += quad_form(S[(t - k) : t, (t - k) : t], c)
            / (square(sigma) * v[k + 1]);
    }
    return tr;
  }

  /* Log density of every column of E, each an independent curve
   * E_n = Bc u_n + eps_n with u_n ~ N(0, diag(tau^2)) and eps_n AR(p),
   * with u_n integrated out. By the Woodbury identity, using the scaled
   * matrix A = I + D W'W D with D = diag(tau), which stays well
   * conditioned as any tau goes to zero. Returns one value per column. */
  vector ar_trial_marginal(matrix E, matrix Bc, vector tau, matrix a,
                           vector v, real sigma, int p) {
    int T = rows(E);
    int N = cols(E);
    int Kr = cols(Bc);
    matrix[T, N] WE = ar_whiten(E, a, v, sigma, p);
    matrix[T, Kr] WBD = diag_post_multiply(ar_whiten(Bc, a, v, sigma, p), tau);
    matrix[Kr, Kr] L = cholesky_decompose(add_diag(crossprod(WBD), 1.0));
    matrix[Kr, N] C = mdivide_left_tri_low(L, WBD' * WE);
    real log_det = 2 * sum(log(diagonal(L)));
    for (t in 1 : T) {
      int k = min(t - 1, p);
      log_det += 2 * log(sigma) + log(v[k + 1]);
    }
    return -0.5 * (T * log(2 * pi()) + log_det
                   + (columns_dot_self(WE) - columns_dot_self(C))');
  }

  /* Pieces shared by the sufficient-statistics likelihood. Given the
   * trial-level scales and the AR parameters, returns [Wt, W B_c], where
   * Wt = W' W B_c D L^-T with D = diag(tau_trial) and L L' = I + D B_c' W'W
   * B_c D. The marginal precision of one curve about its mean is then
   * Omega = W'W - Wt Wt'. */
  matrix trial_pieces(matrix Bc, vector tau_trial, matrix a, vector v,
                      real sigma, int p) {
    int T = rows(Bc);
    int Kr = cols(Bc);
    matrix[T, Kr] WB = ar_whiten(Bc, a, v, sigma, p);
    matrix[T, Kr] WBD = diag_post_multiply(WB, tau_trial);
    matrix[Kr, Kr] L = cholesky_decompose(add_diag(crossprod(WBD), 1.0));
    matrix[T, Kr] Wt = ar_whiten_t(mdivide_left_tri_low(L, WBD')',
                                   a, v, sigma, p);
    return append_col(Wt, WB);
  }

  /* Log determinant of the marginal covariance of one curve,
   * log|Sigma_AR| + log|I + D B_c' W'W B_c D|. */
  real trial_log_det(matrix WB, vector tau_trial, matrix a, vector v,
                     real sigma, int p) {
    matrix[rows(WB), cols(WB)] WBD = diag_post_multiply(WB, tau_trial);
    real ld = 2 * sum(log(diagonal(
      cholesky_decompose(add_diag(crossprod(WBD), 1.0)))));
    for (t in 1 : rows(WB)) {
      int k = min(t - 1, p);
      ld += 2 * log(sigma) + log(v[k + 1]);
    }
    return ld;
  }

  /* sum_n (Y_n - M_j)' Omega (Y_n - M_j) over all curves, where curve n
   * belongs to subject j, from the sufficient statistics. */
  real suffstat_quad(matrix S_all, matrix s_subj, vector n_subj, matrix M,
                     matrix Wt, matrix a, vector v, real sigma, int p) {
    matrix[rows(M), cols(M)] WM = ar_whiten(M, a, v, sigma, p);
    matrix[rows(M), cols(M)] Ws = ar_whiten(s_subj, a, v, sigma, p);
    matrix[cols(Wt), cols(M)] Ps = Wt' * s_subj;
    matrix[cols(Wt), cols(M)] Pm = Wt' * M;
    real term1 = ar_trace_band(S_all, a, v, sigma, p)
                 - 2 * sum(Ws .* WM)
                 + dot_product(n_subj, columns_dot_self(WM)');
    real term2 = trace_quad_form(S_all, Wt)
                 - 2 * sum(Ps .* Pm)
                 + dot_product(n_subj, columns_dot_self(Pm)');
    return term1 - term2;
  }

  /* The whole sum of quadratic forms sum_n r_n' Sigma^-1 r_n over curves,
   * r_n = y_n - M[, j] - D x_n - F[, i], from sufficient statistics.
   * M holds each subject's fixed mean (T x J), D the trial-level effect
   * curves (T x Pt) with predictors x_n, and F the stimulus-pair (item)
   * deviations (T x I), each curve belonging to subject j and item i.
   * Sigma^-1 = W'W - Wt Wt'. Checked numerically against a brute-force
   * computation with an explicit covariance matrix (check_suffstat.R). */
  real total_quad(matrix S_all, matrix s_subj, vector n_subj, matrix M,
                  matrix Wt, matrix a, vector v, real sigma, int p,
                  int use_pred, matrix SXm, matrix X_subj, matrix X2m,
                  matrix D, int I, matrix F, matrix S_item, vector N_item,
                  matrix C, matrix Xitem) {
    real quad = suffstat_quad(S_all, s_subj, n_subj, M, Wt, a, v, sigma, p);
    if (use_pred) {
      matrix[rows(D), cols(D)] SD = ar_whiten_t(ar_whiten(D, a, v, sigma, p),
                                                a, v, sigma, p)
                                    - Wt * (Wt' * D);
      quad += -2 * sum((SXm - M * X_subj) .* SD) + sum(X2m .* (D' * SD));
    }
    if (I > 0) {
      matrix[rows(F), cols(F)] SF = ar_whiten_t(ar_whiten(F, a, v, sigma, p),
                                                a, v, sigma, p)
                                    - Wt * (Wt' * F);
      quad += -2 * (sum(S_item .* SF) - sum((M' * SF) .* C)
                    - sum((D' * SF) .* Xitem'))
              + dot_product(N_item, columns_dot_product(F, SF)');
    }
    return quad;
  }

  /* Subject deviations u_j ~ N(0, diag(tau_subj^2)) on the coarse basis,
   * integrated out. With G = B_c' Omega B_c and h_j = B_c' Omega (s_j -
   * n_j pop), subject j contributes -0.5 log|Q_j| + 0.5 ||L_j^-1 Ds h_j||^2,
   * where Q_j = I + n_j Ds G Ds = L_j L_j' and Ds = diag(tau_subj). The
   * scaled form stays well conditioned as any tau_subj goes to zero. */
  matrix subject_GH(matrix Bs, matrix Wt, matrix St, matrix a, vector v,
                    real sigma, int p) {
    // Bs is the subject-level basis, which need not be the trial-level
    // (coarse) basis that Wt was built from. Column j of St is the sum over
    // subject j's curves of (curve - its fixed mean), that is
    // s_j - N_j m_j - X_j d when there are predictors.
    int J = cols(St);
    int Ks = cols(Bs);
    matrix[rows(Bs), Ks] WBs = ar_whiten(Bs, a, v, sigma, p);
    matrix[cols(Wt), Ks] WtB = Wt' * Bs;
    matrix[Ks, Ks] G = crossprod(WBs) - crossprod(WtB);
    matrix[Ks, J] H = WBs' * ar_whiten(St, a, v, sigma, p) - WtB' * (Wt' * St);
    return append_col(G, H);
  }

  /* Subject deviations u_j ~ N(0, S_u), integrated out, where S_u = Lu Lu'
   * is the ridge-plus-curvature prior covariance (Lu any square root).
   * Subject j contributes -0.5 log|Q_j| + 0.5 ||L_j^-1 Lu' h_j||^2, with
   * Q_j = I + n_j Lu' G Lu = L_j L_j'. */
  real subject_marginal(matrix GH, vector n_subj, matrix Lu) {
    int Ks = rows(GH);
    int J = cols(GH) - Ks;
    matrix[Ks, Ks] LGL = quad_form(GH[, 1 : Ks], Lu);
    real lp = 0;
    for (j in 1 : J) {
      matrix[Ks, Ks] Lj = cholesky_decompose(add_diag(n_subj[j] * LGL, 1.0));
      vector[Ks] c = mdivide_left_tri_low(Lj, Lu' * GH[, Ks + j]);
      lp += -sum(log(diagonal(Lj))) + 0.5 * dot_self(c);
    }
    return lp;
  }

  /* One draw of every subject's deviation weights from its Gaussian
   * conditional posterior, u_j = Lu Q_j^-1 (Lu' h_j + L_j z). */
  matrix subject_draw_rng(matrix GH, vector n_subj, matrix Lu) {
    int Ks = rows(GH);
    int J = cols(GH) - Ks;
    matrix[Ks, Ks] LGL = quad_form(GH[, 1 : Ks], Lu);
    matrix[Ks, J] U;
    for (j in 1 : J) {
      matrix[Ks, Ks] Lj = cholesky_decompose(add_diag(n_subj[j] * LGL, 1.0));
      vector[Ks] c = mdivide_left_tri_low(Lj, Lu' * GH[, Ks + j]);
      vector[Ks] z;
      for (i in 1 : Ks) {
        z[i] = std_normal_rng();
      }
      U[, j] = Lu * mdivide_right_tri_low((c + z)', Lj)';
    }
    return U;
  }

  /* Precision of the ridge-plus-curvature prior on one block of n
   * weights, I / tau_r^2 + D'D / tau_c^2, with D the (n - 2) x n second
   * difference matrix. The prior must be stated as one multivariate
   * normal with this precision. Stating it as two separate sampling
   * statements, on w and on D w, adds the wrong normalising terms, which
   * with estimated scales makes the posterior improper at tau = 0. See
   * the specification section of models.qmd. */
  matrix prior_precision(int n, real tau_r, real tau_c) {
    matrix[n, n] Q = diag_matrix(rep_vector(1 / square(tau_r), n));
    if (n >= 3) {
      matrix[n - 2, n] D = rep_matrix(0, n - 2, n);
      for (i in 1 : (n - 2)) {
        D[i, i] = 1;
        D[i, i + 1] = -2;
        D[i, i + 2] = 1;
      }
      Q += crossprod(D) / square(tau_c);
    }
    return Q;
  }

  /* A square root of the ridge-plus-curvature prior covariance on every
   * block, block diagonal. Used to non-centre the effect-curve weights:
   * with z standard normal, P z has the prior. */
  matrix prior_sqrt_blocks(int K, int nb, array[] int bstart,
                           array[] int bsize, vector tr, vector tc) {
    matrix[K, K] P = rep_matrix(0, K, K);
    for (b in 1 : nb) {
      int s = bstart[b];
      int n = bsize[b];
      matrix[n, n] R = cholesky_decompose(prior_precision(n, tr[b], tc[b]));
      P[s : (s + n - 1), s : (s + n - 1)]
        = mdivide_left_tri_low(R, diag_matrix(rep_vector(1, n)))';
    }
    return P;
  }

  /* A square root of the prior covariance of the subject deviations,
   * block diagonal over the first nb basis blocks. The coarse block (block
   * 1) has one independent scale per basis function, tau1. Every later
   * block has the ridge-plus-curvature prior with its own two scales,
   * tr[b - 1] and tc[b - 1]. With Q = R R' (R lower triangular), R^-T is a
   * square root of Q^-1, which avoids inverting Q.
   *
   * Why the mixture. With the ridge-plus-curvature prior on the coarse
   * block too, its one ridge scale had to cover the pre-stimulus functions,
   * which barely vary between subjects because the data are baseline
   * corrected, and the late functions, which do. It was pulled to about
   * 0.16 and the late subject waveforms were flattened. Independent
   * scales suit the coarse block, which has few wide functions, and the
   * curvature prior is needed in the dense block to stop the subject level
   * absorbing shared sharp structure such as P1. */
  matrix subject_prior_sqrt(int Ks, int nb, array[] int bstart,
                            array[] int bsize, vector tau1, vector tr,
                            vector tc) {
    matrix[Ks, Ks] Lu = rep_matrix(0, Ks, Ks);
    Lu[1 : bsize[1], 1 : bsize[1]] = diag_matrix(tau1);
    for (b in 2 : nb) {
      int s = bstart[b];
      int n = bsize[b];
      matrix[n, n] R = cholesky_decompose(prior_precision(n, tr[b - 1],
                                                          tc[b - 1]));
      Lu[s : (s + n - 1), s : (s + n - 1)]
        = mdivide_left_tri_low(R, diag_matrix(rep_vector(1, n)))';
    }
    return Lu;
  }
}

data {
  int<lower=1> T;                          // timepoints per curve
  int<lower=1> N;                          // curves
  int<lower=1> J;                          // subjects
  int<lower=1> K;                          // basis functions, population
  int<lower=1, upper=K> Kr;                // basis functions, trial level
  /* Basis functions for subject deviations, the first Ks_basis. Using
   * only the coarse block here, as at the trial level, left individual
   * P1, N1 and P2p differences unrepresentable, which is exactly what the
   * subject level is for. Ks_basis = K gives subjects the full basis. */
  int<lower=1, upper=K> Ks_basis;
  int<lower=0> p;                          // AR order; 0 gives iid noise

  int<lower=0, upper=1> use_subject;
  int<lower=0, upper=1> use_trial;

  /* If estimate_width = 0, the widths are used exactly as supplied. On
   * single trials, estimating the two block multipliers made the
   * posterior multimodal (in B2 one chain found a mode with a very narrow
   * coarse block and a very wide dense block), so they are estimated from
   * subject averages in B1 and then fixed. */
  int<lower=0, upper=1> estimate_width;

  /* If marginal_trial = 1, the trial deviations are integrated out
   * analytically instead of sampled. The model is unchanged, but the N * Kr
   * trial-level parameters disappear from the sampler, which is what makes
   * fits to thousands of trials practical. Trial deviations are then not
   * available in the output.
   *
   * marginal_trial = 2 computes exactly the same marginal likelihood from
   * sufficient statistics: the T x T second-moment matrix of all curves,
   * and the sum of the curves within each subject. Every term of the
   * marginal log density is quadratic in the data, so summing over curves
   * needs nothing else, and the cost per iteration no longer depends on N.
   *
   * compute_log_lik = 0 skips the per-curve log_lik in generated
   * quantities, which is the only remaining cost that grows with N. */
  int<lower=0, upper=2> marginal_trial;
  int<lower=0, upper=1> compute_log_lik;

  /* If marginal_subject = 1 (requires marginal_trial = 2 and
   * use_subject = 1), the subject deviations are integrated out as well,
   * and each subject's waveform is drawn from its exact conditional
   * posterior in generated quantities. The sampler then sees only the
   * population weights, the scales and the noise parameters. */
  int<lower=0, upper=1> marginal_subject;

  /* Predictors (B4). a_subj is a subject-level predictor (standardised log
   * odds accuracy) and x_trial a trial-level predictor (standardised log
   * ratio). Each has an effect curve over time, B gamma and B delta, with
   * the same ridge-plus-curvature prior as the population weights and its
   * own scales. Subject j's fixed mean is alpha + B w + a_j B gamma, and
   * trial n's is that plus x_n B delta. Requires marginal_trial = 2 and
   * compute_log_lik = 0. */
  int<lower=0, upper=1> use_pred;
  vector[J] a_subj;
  vector[N] x_trial;

  /* If fix_effect_scales = 1, the effect curves' ridge and curvature
   * scales are fixed at effect_tau_ridge and effect_tau_curv (the same for
   * every block) instead of being estimated. Estimated from a single curve
   * each, they came out at about 0.1 to 0.2, which shrank the ratio effect
   * two- to eight-fold relative to the raw data and pushed the accuracy
   * effect into the subject deviations. Fixed values on the uV scale act
   * like a fixed smoothing penalty in a GAM. */
  int<lower=0, upper=1> fix_effect_scales;
  real<lower=0> effect_tau_ridge;
  real<lower=0> effect_tau_curv;

  /* Further trial-level predictors, P2 of them, each with its own effect
   * curve under the same prior as the x_trial effect (for example the
   * previous trial's log ratio, since consecutive ratios are correlated).
   * Requires use_pred = 1. */
  int<lower=0> P2;
  matrix[N, P2] x_extra;

  /* Stimulus pairs (items) as a random factor crossed with subjects. With
   * I > 0, each curve belongs to item item[n], and each item has its own
   * random deviation waveform on the coarse basis, B_c diag(tau_item)
   * z_item, sampled non-centred. Every participant saw the same fixed
   * sequence of items (notes/fixed-trial-sequence.md), so stimulus effects
   * such as ratio must be judged against variation between items.
   * Requires marginal_trial = 2. */
  int<lower=0> I;
  array[N] int<lower=0, upper=I> item;

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
  int Ks = use_subject ? Ks_basis : 0;
  // Basis blocks covered by the subject deviations: all of them, or only
  // the coarse block when Ks_basis = Kr.
  int nbs = use_subject ? (Ks_basis == K ? n_block : 1) : 0;
  if (use_subject && Ks_basis != K && Ks_basis != block_size[1]) {
    reject("Ks_basis must be K or the size of the first (coarse) block");
  }
  int Js = use_subject ? J : 0;
  int Kt = use_trial ? Kr : 0;
  int Nt = use_trial && !marginal_trial ? N : 0;
  int Jz = use_subject && !marginal_subject ? J : 0;  // sampled subject z
  if (marginal_subject && !(use_subject && use_trial && marginal_trial == 2)) {
    reject("marginal_subject = 1 needs use_subject = 1, use_trial = 1 and ",
           "marginal_trial = 2");
  }

  if (use_pred && (marginal_trial != 2 || compute_log_lik)) {
    reject("use_pred = 1 needs marginal_trial = 2 and compute_log_lik = 0");
  }
  int Kp = use_pred ? K : 0;
  int nbp = use_pred ? n_block : 0;
  int nbp_est = use_pred && !fix_effect_scales ? n_block : 0;

  if (P2 > 0 && !use_pred) {
    reject("P2 > 0 needs use_pred = 1");
  }
  int P2p = use_pred ? P2 : 0;

  // Sufficient statistics for the trial-level predictors, all Pt = 1 + P2
  // of them together (x_trial first): sum_n y_n x_n' (T x Pt), the
  // per-subject sums of x_n (J x Pt), and sum_n x_n x_n' (Pt x Pt).
  matrix[N, 1 + P2] Xt = append_col(x_trial, x_extra);
  matrix[T, 1 + P2] SXm = Y * Xt;
  matrix[J, 1 + P2] X_subj = rep_matrix(0, J, 1 + P2);
  for (n in 1 : N) {
    X_subj[subj[n]] += Xt[n];
  }
  matrix[1 + P2, 1 + P2] X2m = crossprod(Xt);

  // Sufficient statistics for the items: per-item sums of the curves,
  // per-item counts, subject-by-item counts, and per-item sums of the
  // trial-level predictors.
  if (I > 0 && marginal_trial != 2) {
    reject("I > 0 needs marginal_trial = 2");
  }
  int Ki = I > 0 ? Kr : 0;
  matrix[T, I] S_item = rep_matrix(0, T, I);
  vector[I] N_item = rep_vector(0, I);
  matrix[J, I] C_item = rep_matrix(0, J, I);
  matrix[I, 1 + P2] X_item = rep_matrix(0, I, 1 + P2);
  for (n in 1 : N) {
    if (I > 0) {
      S_item[, item[n]] += Y[, n];
      N_item[item[n]] += 1;
      C_item[subj[n], item[n]] += 1;
      X_item[item[n]] += Xt[n];
    }
  }

  // Sufficient statistics for marginal_trial = 2.
  matrix[T, T] S_all = tcrossprod(Y);
  matrix[T, J] s_subj = rep_matrix(0, T, J);
  vector[J] n_subj = rep_vector(0, J);
  for (n in 1 : N) {
    s_subj[, subj[n]] += Y[, n];
    n_subj[subj[n]] += 1;
  }

  // Which block each basis function belongs to, for the per-block width
  // multipliers.
  array[K] int block_of;
  for (b in 1 : n_block) {
    for (k in block_start[b] : (block_start[b] + block_size[b] - 1)) {
      block_of[k] = b;
    }
  }
}

parameters {
  real alpha;
  vector[K] w;                              // population weights
  vector<lower=0>[n_block] tau_ridge;
  vector<lower=0>[n_block] tau_curv;
  // One multiplier per block. A single multiplier shared by the coarse and
  // dense blocks was pulled to about 0.34 by the dense block in B1, which
  // left the coarse Gaussians too narrow to overlap smoothly.
  vector<lower=0>[estimate_width ? n_block : 0] width_mult_est;

  // Non-centred where sampled. z is standard normal and the scale
  // multiplies it. One scale per basis function, no covariance between
  // basis dimensions, matching the uncorrelated random slopes used in the
  // lme4 smoke tests.
  matrix[Ks, Jz] z_subj;
  // Subject deviations have the same ridge-plus-curvature prior as the
  // population weights, with their own scales per block. Independent scales
  // per basis function, with no smoothness, let the subject level absorb
  // shared sharp structure such as P1 that belongs in the population
  // waveform.
  vector<lower=0>[use_subject ? block_size[1] : 0] tau_subj_coarse;
  vector<lower=0>[max(nbs - 1, 0)] tau_subj_ridge;
  vector<lower=0>[max(nbs - 1, 0)] tau_subj_curv;
  matrix[Kt, Nt] z_trial;
  vector<lower=0>[Kt] tau_trial;

  real<lower=0> sigma;                      // MARGINAL sd of eps
  vector<lower=-1, upper=1>[p] r;

  // Effect curves' weights, subject-level (gamma) and trial-level (delta),
  // non-centred. When an effect is weak its prior scales approach zero,
  // and with the weights sampled directly that made a funnel (hundreds of
  // divergences, bulk ESS about 30 on the scales).
  vector[Kp] z_gamma;
  vector[Kp] z_delta;
  matrix[Kp, P2p] z_delta_extra;
  matrix[Ki, I] z_item;
  vector<lower=0>[Ki] tau_item;
  vector<lower=0>[nbp_est] tau_g_ridge;
  vector<lower=0>[nbp_est] tau_g_curv;
  vector<lower=0>[nbp_est] tau_d_ridge;
  vector<lower=0>[nbp_est] tau_d_curv;
}

transformed parameters {
  vector[nbp] g_r = fix_effect_scales ? rep_vector(effect_tau_ridge, nbp)
                                       : tau_g_ridge;
  vector[nbp] g_c = fix_effect_scales ? rep_vector(effect_tau_curv, nbp)
                                       : tau_g_curv;
  vector[nbp] d_r = fix_effect_scales ? rep_vector(effect_tau_ridge, nbp)
                                       : tau_d_ridge;
  vector[nbp] d_c = fix_effect_scales ? rep_vector(effect_tau_curv, nbp)
                                       : tau_d_curv;
  vector[Kp] gamma = prior_sqrt_blocks(Kp, nbp, block_start, block_size,
                                       g_r, g_c) * z_gamma;
  vector[Kp] delta = prior_sqrt_blocks(Kp, nbp, block_start, block_size,
                                       d_r, d_c) * z_delta;
  matrix[Kp, P2p] delta_extra = prior_sqrt_blocks(Kp, nbp, block_start,
                                                  block_size, d_r, d_c)
                                * z_delta_extra;
  vector[n_block] width_mult = estimate_width ? width_mult_est
                                              : rep_vector(1, n_block);
  matrix[p, p] a = rep_matrix(0, p, p);
  vector[p + 1] v;

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
  // The basis is local rather than a transformed parameter, so that its
  // T x K entries are not written out with every draw.
  matrix[T, K] B;
  for (k in 1 : K) {
    B[, k] = exp(-0.5 * square((time - centre[k])
                               / (width_mult[block_of[k]] * width[k])));
  }
  vector[T] pop = alpha + B * w;
  matrix[T, Kr] Bc = block(B, 1, 1, T, Kr);  // coarse part of the basis
  matrix[T, Ks_basis] Bs = block(B, 1, 1, T, Ks_basis);  // subject basis
  matrix[Ks, Ks] Lu = subject_prior_sqrt(Ks, nbs, block_start, block_size,
                                         tau_subj_coarse, tau_subj_ridge,
                                         tau_subj_curv);

  alpha ~ normal(0, prior_sd_alpha);

  // Ridge-plus-curvature prior, one multivariate normal per block. The
  // ridge term penalises amplitude and the curvature term, on second
  // differences of the weights, penalises roughness.
  for (b in 1 : n_block) {
    int n = block_size[b];
    segment(w, block_start[b], n) ~ multi_normal_prec(
      rep_vector(0, n), prior_precision(n, tau_ridge[b], tau_curv[b]));
  }

  tau_ridge ~ normal(0, prior_sd_ridge);
  tau_curv ~ normal(0, prior_sd_curv);
  width_mult_est ~ lognormal(0, prior_sd_log_width);
  sigma ~ normal(0, prior_sd_sigma);

  to_vector(z_subj) ~ std_normal();
  to_vector(z_trial) ~ std_normal();
  tau_subj_coarse ~ normal(0, prior_sd_tau_subj);
  tau_subj_ridge ~ normal(0, prior_sd_tau_subj);
  tau_subj_curv ~ normal(0, prior_sd_tau_subj);
  tau_trial ~ normal(0, prior_sd_tau_trial);

  z_gamma ~ std_normal();
  z_delta ~ std_normal();
  to_vector(z_delta_extra) ~ std_normal();
  to_vector(z_item) ~ std_normal();
  tau_item ~ normal(0, prior_sd_tau_trial);
  tau_g_ridge ~ normal(0, prior_sd_ridge);
  tau_g_curv ~ normal(0, prior_sd_curv);
  tau_d_ridge ~ normal(0, prior_sd_ridge);
  tau_d_curv ~ normal(0, prior_sd_curv);

  if (use_trial && marginal_trial == 2) {
    // Sufficient statistics. Nothing here has a dimension of N.
    matrix[T, 2 * Kr] pieces = trial_pieces(Bc, tau_trial, a, v, sigma, p);
    matrix[T, Kr] Wt = pieces[, 1 : Kr];
    matrix[T, Kr] WB = pieces[, (Kr + 1) : (2 * Kr)];
    matrix[T, J] M = rep_matrix(pop, J);
    // One effect curve per trial-level predictor, x_trial's first.
    matrix[T, 1 + P2] D = rep_matrix(0, T, 1 + P2);
    if (use_pred) {
      M += (B * gamma) * a_subj';
      D[, 1] = B * delta;
      if (P2 > 0) {
        D[, 2 : (1 + P2)] = B * delta_extra;
      }
    }
    if (use_subject && !marginal_subject) {
      M += Bs * (Lu * z_subj);
    }
    // Item deviation waveforms.
    matrix[T, I] F = rep_matrix(0, T, I);
    if (I > 0) {
      F = Bc * diag_pre_multiply(tau_item, z_item);
    }
    real quad = total_quad(S_all, s_subj, n_subj, M, Wt, a, v, sigma, p,
                           use_pred, SXm, X_subj, X2m, D, I, F, S_item,
                           N_item, C_item, X_item);
    target += -0.5 * (N * T * log(2 * pi())
                      + N * trial_log_det(WB, tau_trial, a, v, sigma, p)
                      + quad);
    if (marginal_subject) {
      matrix[T, J] St = s_subj - M .* rep_matrix(n_subj', T) - D * X_subj'
                        - F * C_item';
      target += subject_marginal(subject_GH(Bs, Wt, St, a, v, sigma, p),
                                 n_subj, Lu);
    }
  } else {
    matrix[T, N] E = Y - rep_matrix(pop, N);
    if (use_subject) {
      E -= (Bs * (Lu * z_subj))[, subj];
    }
    if (use_trial && marginal_trial == 1) {
      target += sum(ar_trial_marginal(E, Bc, tau_trial, a, v, sigma, p));
    } else {
      if (use_trial) {
        E -= Bc * diag_pre_multiply(tau_trial, z_trial);
      }
      target += ar_loglik_matrix(E, a, v, sigma, p);
    }
  }
}

generated quantities {
  vector[p] phi;
  real sigma_innovation = sigma * sqrt(v[p + 1]);
  vector[T] mu_pop;
  matrix[T, Js] mu_subj;                    // each subject's mean waveform
  vector[use_pred ? T : 0] effect_subj;     // change per unit of a_subj
  vector[use_pred ? T : 0] effect_trial;    // change per unit of x_trial
  matrix[T, P2p] effect_extra;              // change per unit of each x_extra

  /* One log-likelihood value per curve, not per timepoint. Leaving out one
   * timepoint from an autocorrelated series is nearly free and tells you
   * almost nothing, so the honest cross-validation unit here is the whole
   * curve. This makes loo() on these draws leave-one-trial-out. */
  vector[compute_log_lik ? N : 0] log_lik;

  for (j in 1 : p) {
    phi[j] = a[p, j];
  }

  {
    matrix[T, K] B;
    for (k in 1 : K) {
      B[, k] = exp(-0.5 * square((time - centre[k])
                                 / (width_mult[block_of[k]] * width[k])));
    }
    matrix[T, Kr] Bc = block(B, 1, 1, T, Kr);
    matrix[T, Ks_basis] Bs = block(B, 1, 1, T, Ks_basis);
    matrix[Ks, Ks] Lu = subject_prior_sqrt(Ks, nbs, block_start, block_size,
                                           tau_subj_coarse, tau_subj_ridge,
                                           tau_subj_curv);
    mu_pop = alpha + B * w;
    matrix[T, J] M = rep_matrix(mu_pop, J);
    matrix[T, 1 + P2] D = rep_matrix(0, T, 1 + P2);
    if (use_pred) {
      effect_subj = B * gamma;
      effect_trial = B * delta;
      effect_extra = B * delta_extra;
      M += effect_subj * a_subj';
      D[, 1] = effect_trial;
      if (P2 > 0) {
        D[, 2 : (1 + P2)] = effect_extra;
      }
    }

    if (use_subject) {
      if (marginal_subject) {
        matrix[T, 2 * Kr] pieces = trial_pieces(Bc, tau_trial, a, v, sigma, p);
        matrix[T, J] St = s_subj - M .* rep_matrix(n_subj', T) - D * X_subj';
        if (I > 0) {
          St -= Bc * diag_pre_multiply(tau_item, z_item) * C_item';
        }
        // Subject j's mean waveform at the average trial (x = 0).
        mu_subj = M + Bs * subject_draw_rng(
                        subject_GH(Bs, pieces[, 1 : Kr], St, a, v, sigma, p),
                        n_subj, Lu);
      } else {
        mu_subj = M + Bs * (Lu * z_subj);
      }
    }

    if (compute_log_lik) {
      matrix[T, N] E = Y - (use_subject ? mu_subj[, subj]
                                        : rep_matrix(mu_pop, N));
      if (use_trial && marginal_trial > 0) {
        // Marginal over the trial deviations, which is the better quantity
        // for leave-one-trial-out in any case. With marginal_subject = 1
        // it is conditional on this draw of the subject waveforms.
        log_lik = ar_trial_marginal(E, Bc, tau_trial, a, v, sigma, p);
      } else {
        if (use_trial) {
          E -= Bc * diag_pre_multiply(tau_trial, z_trial);
        }
        for (n in 1 : N) {
          log_lik[n] = ar_loglik(E[, n], a, v, sigma, p);
        }
      }
    }
  }
}
