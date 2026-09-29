# Numerical check of the sufficient-statistics likelihood in
# rbf_multilevel.stan. For a small random problem with subjects, items,
# trial-level predictors and AR(2) noise, compares
#   total_quad()     sum_n r_n' Sigma^-1 r_n from sufficient statistics
#   trial_log_det()  log|Sigma|
# with brute-force values from an explicitly built covariance matrix
# Sigma = Sigma_AR + B_c diag(tau^2) B_c'.
#
#   Rscript analysis/rbf_stan/check_suffstat.R [stan file]

library(cmdstanr)

args <- commandArgs(trailingOnly = TRUE)
stanfile <- if (length(args)) args[1] else "analysis/rbf_stan/rbf_multilevel.stan"
mod <- cmdstan_model(stanfile, compile = FALSE)
mod$compile(compile_standalone = TRUE, force_recompile = TRUE)
f <- mod$functions

set.seed(1)
T <- 24; Kr <- 3; J <- 3; I <- 4; N <- 40; Pt <- 2; p <- 2
time <- seq(-100, 500, length.out = T)
centres <- seq(-100, 500, length.out = Kr)
Bc <- sapply(centres, function(c) exp(-0.5 * ((time - c) / 150)^2))
tau <- c(1.5, 0.7, 2.0)
sigma <- 3
r <- c(0.6, -0.3)

# Levinson-Durbin, as in the Stan model.
a <- matrix(0, p, p); v <- numeric(p + 1); v[1] <- 1
for (k in 1:p) {
  a[k, k] <- r[k]
  if (k > 1) for (j in 1:(k - 1)) a[k, j] <- a[k - 1, j] - r[k] * a[k - 1, k - j]
  v[k + 1] <- v[k] * (1 - r[k]^2)
}
phi <- a[p, ]

# Brute force covariance.
acf <- ARMAacf(ar = phi, lag.max = T - 1)
psi <- ARMAtoMA(ar = phi, lag.max = 2000)
marg_var_unit <- 1 + sum(psi^2)
Sigma_AR <- sigma^2 * toeplitz(acf)
Sigma <- Sigma_AR + Bc %*% diag(tau^2) %*% t(Bc)
Sinv <- solve(Sigma)

subj <- sample(1:J, N, replace = TRUE)
item <- sample(1:I, N, replace = TRUE)
Y <- matrix(rnorm(T * N, 0, 4), T, N)
M <- matrix(rnorm(T * J), T, J)
D <- matrix(rnorm(T * Pt), T, Pt)
Fm <- matrix(rnorm(T * I), T, I)
X <- matrix(rnorm(N * Pt), N, Pt)

R <- Y - M[, subj] - D %*% t(X) - Fm[, item]
brute_quad <- sum(sapply(1:N, function(n) drop(t(R[, n]) %*% Sinv %*% R[, n])))
brute_logdet <- as.numeric(determinant(Sigma)$modulus)

# Sufficient statistics, as in transformed data.
S_all <- Y %*% t(Y)
s_subj <- sapply(1:J, function(j) rowSums(Y[, subj == j, drop = FALSE]))
n_subj <- as.numeric(table(factor(subj, levels = 1:J)))
SXm <- Y %*% X
X_subj <- t(sapply(1:J, function(j) colSums(X[subj == j, , drop = FALSE])))
X2m <- crossprod(X)
S_item <- sapply(1:I, function(i) rowSums(Y[, item == i, drop = FALSE]))
N_item <- as.numeric(table(factor(item, levels = 1:I)))
C <- table(factor(subj, levels = 1:J), factor(item, levels = 1:I))
C <- matrix(as.numeric(C), J, I)
X_item <- t(sapply(1:I, function(i) colSums(X[item == i, , drop = FALSE])))

pieces <- f$trial_pieces(Bc, tau, a, v, sigma, p)
Wt <- pieces[, 1:Kr]
WB <- pieces[, (Kr + 1):(2 * Kr)]

stan_quad <- f$total_quad(S_all, s_subj, n_subj, M, Wt, a, v, sigma, p,
                          1L, SXm, X_subj, X2m, D, I, Fm, S_item, N_item,
                          C, X_item)
stan_logdet <- f$trial_log_det(WB, tau, a, v, sigma, p)

cat(sprintf("quad:   brute %.8f  stan %.8f  rel diff %.2e\n",
            brute_quad, stan_quad, abs(brute_quad - stan_quad) / abs(brute_quad)))
cat(sprintf("logdet: brute %.8f  stan %.8f  diff %.2e\n",
            brute_logdet, stan_logdet, abs(brute_logdet - stan_logdet)))
stopifnot(abs(brute_quad - stan_quad) / abs(brute_quad) < 1e-8,
          abs(brute_logdet - stan_logdet) < 1e-8)
cat("PASS\n")
