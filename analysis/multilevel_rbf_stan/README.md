# Multilevel basis-function models for single-trial ERPs

This directory holds the Bayesian replacement for the `lme4` smoke tests
in `analysis/multilevel_rbf/`. It is a deliberately short ladder of four
models, fitted in Stan via `cmdstanr`, building up to a multilevel
nonlinear regression of single-trial EEG waveforms.

## What problem this is solving

The scientific questions concern the neural signature of the approximate
number system, which in posterior EEG appears as a sequence of three
components: P1 at roughly 80 to 150 ms, N1 at 150 to 200 ms, and P2p at
200 to 250 ms. P2p is the candidate ANS signature specifically, because it
tracks perceived rather than physical numerosity.

The questions we want to answer are about variability and about continuous
relationships. How much do these components vary from trial to trial and
from person to person? How does the waveform change as numerical ratio or
array density varies? Does the signature differ with a participant's
behavioural ANS acuity, or with age?

The standard ERP pipeline cannot answer any of these, because it discards
the relevant information before modelling begins. Averaging over trials
removes trial-to-trial variability. Peak-picking or window-averaging
reduces a waveform to one number per condition, which removes
subject-level differences in waveform *shape* as opposed to amplitude.
Binning a continuous stimulus property into conditions removes the
continuous relationship.

The alternative is to model the single-trial waveform directly, as a
smooth random function of time that varies systematically with stimulus
and subject properties and probabilistically across trials and
participants. That is what these models do.

## The modelling approach in one page

The waveform is written as a weighted sum of fixed Gaussian bumps in time,

    y(t) = alpha + sum_k w_k * phi_k(t) + noise

where each `phi_k` is a Gaussian centred at latency `mu_k` with width
`ell_k`. Because the centres and widths are fixed, the model is linear in
the weights `w_k`, so it is an ordinary linear model with basis-function
values as predictors. This is the same device as polynomial or spline
regression.

The multilevel part follows immediately. Give every weight a subject
deviation and a trial deviation,

    w_k(subject, trial) = w_k + u_{k,subject} + v_{k,trial}

and each subject and each trial acquires its own random *function*, a
whole waveform shape deviating from the population waveform, not merely an
amplitude offset. Covariates enter the same way, as a `K`-vector of
coefficients rather than a scalar, so a change in numerical ratio can
change the waveform at one latency without changing it elsewhere.

Two things make this harder than an ordinary mixed model, and both are
handled explicitly.

**The noise is not iid.** The data are band-pass filtered at 1 to 30 Hz
and sampled at 1024 Hz, so consecutive samples are strongly dependent by
construction, quite apart from the fact that ongoing EEG is a rhythmic,
autocorrelated process. Treating them as independent does not bias the
fit, but it understates the uncertainty on the fitted waveform by roughly
50%. The residual is therefore modelled as a stationary AR(2) process,
which at posterior electrodes recovers a rhythm near 11 Hz without being
asked to.

**The prior on the weights does the work that `K` cannot.** Overlapping
Gaussian bumps are collinear, so an unpenalised fit produces large weights
with heavy cancellation between neighbours. The weights get a
ridge-plus-curvature prior with estimated scales, which is a penalised
spline penalty written as a prior. The consequence is that the effective
complexity of the fitted curve is controlled by four estimated parameters
rather than by the number and spacing of the basis functions, so the
number of basis functions stops being a delicate choice.

## Why radial basis functions and not something else

A Gaussian process with a squared exponential kernel is the limit of this
model as the number of basis functions goes to infinity. The two are the
same class of model, and a GP is the more general and more elegant version
of it. We are using the finite expansion anyway, for three reasons.

The multilevel structure above is immediate for a finite expansion and
considerably less transparent for a GP. A subject-level random function is
just `K` more coefficients, handled by machinery identical to random
slopes.

Everything known about linear regression applies unchanged, including the
reading of the priors as penalties.

It can be explained to a psychology audience.

Similarly, a penalised spline in `mgcv` would give much of this, and the
curvature prior above is exactly `mgcv`'s penalty. We are not using
`mgcv`, partly because `s()` cannot express the multilevel structure we
need, and partly because the whole point is to understand and control what
is being fitted rather than to hand it to a black box.

## The four models

Each adds one thing to the previous one. The order is not negotiable: the
full model has enough moving parts that a failure could not be attributed
to any one of them, and each rung has a frequentist counterpart already
fitted in `lme4` to be checked against.

| | Data | Random effects | `lme4` counterpart |
|---|---|---|---|
| **B0** | one subject, one trial | none | `gls` in `rbf_correlated_noise.R` |
| **B1** | all subjects, trials averaged | subject | `smoke_test_lmer0.R` (M0) |
| **B2** | one subject, all trials | trial | `smoke_test_lmer1.R` (M1) |
| **B3** | all subjects, subset of trials | subject and trial | `smoke_test_lmer2.R` (M2) |

B0 is new and is the most useful of the four to get right, because it is
where the basis, the decimation, the prior and the noise model can each be
checked in isolation.

Stimulus and subject covariates are B4 and are deliberately not in this
ladder. That is the first rung that answers a scientific question rather
than checking machinery, and it is structurally identical to the
group-level terms already present, so it should be cheap to add once B3
runs.

## Files

    models.qmd                       the four models written out, with
                                     the reasoning for every choice
    technical-appendix.qmd           the parts that would clutter the
                                     specification: decimation, the
                                     penalty algebra, the AR
                                     parameterisation, scaling to the
                                     full trial count
    stan/rbf_b0_single_trial.stan    B0
    stan/rbf_multilevel.stan         B1, B2 and B3, selected by two data
                                     flags
    R/rbf_common.R                   decimation, basis construction,
                                     prior scales, curve reconstruction
    R/fit_b0.R                       driver for B0
    R/fit_multilevel.R               driver for B1, B2, B3

Read `models.qmd` first. The Stan files are commented on the assumption
that it has been read.

## How to run this

In order, and do not move on until the current model is understood.

1. Read `models.qmd`.
2. Run the prior predictive check at the top of `R/fit_b0.R` and look at
   the output before fitting anything. If the curves drawn from the prior
   alone run to hundreds of microvolts, the prior scales are wrong and
   nothing downstream will rescue that.
3. Fit B0 at `p = 0`, `p = 2` and `p = 4`. Check the list of things to
   look at in the driver. The one that matters most is whether the
   reported amplitude at 240 ms is stable across AR order.
4. Fit B1, then B2, then B3, from `R/fit_multilevel.R`.
5. At every rung, run Pathfinder before HMC. It costs seconds, it catches
   gross specification errors, and its draws are good initial values for
   HMC. At B3, run Laplace as well and compare all three against HMC on
   the fitted curve.
6. Check diagnostics before estimates, every time.

Expected cost. B0 is seconds. B1 and B2 are minutes. B3 is hours under
HMC, and should be iterated on with Pathfinder and Laplace instead.

## Two standing rules

**Report functions of the fitted curve, never individual weights.** The
basis functions overlap heavily, so the individual weights are not
separately interpretable and their marginals are unstable. This is not a
defect in the fit and it does not affect prediction or inference about the
curve. It does mean that anything reported must be something like the
fitted amplitude at 240 ms, the height of the fitted P2p peak, or the
difference between two fitted curves at a latency.

**The basis functions are not ERP components.** There is no expectation of
a one-to-one correspondence between a basis function and P1, N1 or P2p.
Components are individuated by scalp topography and functional
dissociation, and the waveform at one electrode is a superposition of
temporally overlapping sources. The components are properties of the
fitted curve, and they emerge from the sum.
