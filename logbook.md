# 27 August, 2026; 00:18

Started adding EEG results to today's BPS conference talk (`presentations/bps-cog-2026`), grand-average ERPs across a representative subset of electrodes, not all 64: anterior (AF3, AFz, AF4), central (C3, Cz, C4), and parieto-occipital (PO7, POz, PO8, P7, Pz, P8), following the same collapse-over-subject-and-trial approach as `analysis/aug26_1.R`'s Figure x.3 (fixed y-scale, per-channel facet).
Central included specifically because it's expected to show little, the sensorimotor strip rather than a visual-response site; anterior included because it's expected to broadly mirror the posterior sites; posterior is where P1/N1/P2p actually live.

The slide deck cannot read the merged EEG parquet directly, at several gigabytes it's far too slow to re-read on every Quarto render, and Quarto's own chunk caching was deliberately ruled out as more trouble than it's worth here.
So the presentation instead reads a small precomputed file, `tmp/grand_average_erp.rds`, grand-average voltage per channel per timepoint, all 64 channels, dots task only, written once by a new standalone script, `analysis/prepare_presentation_data.R`, run by hand inside the devcontainer.
That file is not committed and not durable, `tmp/` is gitignored and gets cleared; if it's missing, re-run `analysis/prepare_presentation_data.R` (needs `arrow`, devcontainer only) to regenerate it, a few seconds' work once the parquet is read.
This is a deliberate, acknowledged shortcut for getting today's talk finished, not a long-term data-management decision: the repository already has real clutter building up (`smoke_test_lmer.R` deleted earlier tonight for exactly this reason) and putting more thought into how presentation-derived data should be prepared and stored is follow-up work, not something to solve mid-talk-prep.
The `M0`/`M1`/`M2` `.rds` files saved earlier tonight to `tmp/` (see above) are the same kind of thing, ephemeral, session-local, and will need the same eventual tidying-up.

Ran a step-by-step sequence of `lme4` smoke tests, `analysis/multilevel_rbf/smoke_test_lmer0.R`, `smoke_test_lmer1.R`, `smoke_test_lmer2.R`, at POz, to validate the basis-function multilevel model's structure and data preparation cheaply before committing to Stan.
Total model-fitting time across all three, start to finish, was under two hours.
None of the three results are polished, but all three are informative, which is the actual point of a smoke test.

**M0** (`smoke_test_lmer0.R`): subject variability only, all subjects, trials pre-averaged away first.
The cheapest possible version of this model, meant to check subject-level random effects in isolation before adding anything else.
Its first attempt, still inside the old combined draft at the time, tried this on a small 8-subject subset for speed and failed with a degenerate Hessian, a genuine optimizer failure, not just a warning: 8 subjects is too few groups to estimate 9 independent variance components (8 basis-function slopes plus an intercept).
Fixed by using all 47 subjects instead, which costs nothing once trials are pre-averaged, so there was never a real reason to subset subjects here.
With only the original 8 coarse basis functions (spanning the whole ~1200ms epoch, each about 170ms wide), the population fit visibly underfit, flattening the main peak's amplitude and missing the sharp early P1-like structure entirely, since nothing that coarse can represent a ~50-100ms component.
Fixed by adding a second, denser tier of 8 basis functions confined to 0-300ms, where P1, N1, and P2p all sit, on top of the original 8, not instead of them, giving 16 basis functions total.
Re-run with all 47 subjects and 16 basis functions: 240 seconds, converged cleanly, and the population fit now tracked the grand average closely across the whole epoch.
Subject-level fits showed real, substantial between-subject variability, peak amplitudes from near zero to over 20µV across subjects, without obvious overfitting.

**M1** (`smoke_test_lmer1.R`): trial variability only, one subject (chosen at random, came out as s47), full trial-level resolution, no averaging.
The next cheapest test, trial-level random effects instead of subject-level, still avoiding the cost of combining both.
First run, same 16 basis functions used for the random effect as for the fixed effect: 745 seconds, and severe single-trial overfitting, individual trial fits visibly tracking what looks like single-trial noise rather than genuine signal, worst in the 8 dense, narrow 0-300ms basis functions, exactly the ones capable of representing that kind of fine structure.
Fixed by restricting the trial random effect to the 8 coarse basis functions only, leaving the fixed effect at all 16: the first case in this sequence of the fixed-effect and random-effect design matrices deliberately not matching.
Re-run: converged, visibly less jagged trial-level fits, confirmed by a direct before/after comparison on the same 12 sampled trials, not just a different random draw looking better by chance.
A follow-up check of whether the remaining trial-level roughness related to how many trials a subject had, as a proxy for a noisier average, found no relationship (Spearman's rho about 0.03), but the check itself was flawed, the roughness metric used was confounded with response amplitude rather than a valid test of the hypothesis, so this specific question remains genuinely open, not resolved either way.

**M2** (`smoke_test_lmer2.R`): subject and trial together, both random effects at once, the actual target structure this whole sequence was building toward.
The full dataset (47 subjects x ~180 trials x ~1230 timepoints, on the order of 10 million rows) was never attempted, far too slow for two crossed random effects.
First attempt cut both subjects (to 15) and trials (to 20 per subject) for speed, with the subject random effect reduced to a 4-term basis, and failed the same way M0's first attempt did, a degenerate Hessian, 15 subjects too few for 5 variance components.
Second attempt cut the subject basis further to 2 terms; converged without a warning this time, but produced numerically unstable nonsense, near-straight-line "fits" per subject reaching into the tens or hundreds of microvolts.
Cause: with only 2 centers, `seq()` places them at the two ends of the epoch, and the width convention used throughout this basis (width = spacing) then forces the width to the entire ~1200ms range, making the two basis functions nearly collinear, so the model can't separate their two weights and amplifies noise into large, arbitrary trends instead.
Third attempt reduced the subject random effect all the way to a plain random intercept, no basis-function slopes at all; converged cleanly and confirmed a subject-level effect is estimable at 15 subjects, but produced, correctly, uselessly rigid fits, an intercept can only shift the shared curve up or down, never reshape it, so every subject's "fit" was just the population curve translated vertically.
That's not a bad result, it's exactly what an intercept alone can ever produce, and it settled the point that 15 subjects was survivable in principle, just not with any real subject-level shape flexibility.
Diagnosis at that point: subject count was the wrong dimension to have cut in the first place.
M0 had already shown 47 subjects comfortably supports an 8-term coarse subject-level random effect; trial count is the safe dimension to cut instead, since the number of trial groups, subjects times trials-per-subject, stays large regardless of how many trials per subject are kept.
Final version: all 47 subjects, 20 trials per subject (about 1.4 million rows), both random effects at the same 8-term coarse basis already validated separately in M0 and M1, nothing reduced to an intercept.
Took 71 minutes (4272 seconds wall clock, timed with `system.time()`), by a wide margin the slowest fit this session.
Result: by far the best population-level fit of the whole session, closely tracking the grand average across the full epoch, including the sharp early structure and the main P2p-like peak.
Subject-level fits were sensible, broad shape captured per subject, sharp idiosyncratic spikes appropriately smoothed over given the coarse-only basis, no sign of subject-level overfitting.
Trial-level fits still show substantial, possibly excessive spread, particularly right at the two edges of the time window, before stimulus onset and at the end of the epoch, which looks like it could be a basis-function boundary artefact, the least-constrained coefficients sit at the edge of the fitted range, rather than a genuine finding about trial-to-trial neural variability.
Not resolved; flagged for whenever this specific question is worth returning to.
All three fitted model objects, `M0`, `M1`, `M2`, are now saved via `saveRDS()` to `tmp/smoke_test_lmer{0,1,2}_{M0,M1,M2}.rds` at the end of their respective scripts, so none needs refitting to look at again this session; `tmp/` only, not a durable save, and `M0`/`M1` need re-running once to actually produce their `.rds` files since the save lines were added after those two had already been run.

Decision: `lme4` has done its job for this exploratory pass, cheap enough to iterate on, and every failure mode hit along the way, the degenerate Hessian, the collinear basis, the forced choice between a rigid intercept and cutting flexibility, traces back to the same cause, REML is a point-estimation method with no way to gracefully shrink a weakly-identified variance component toward zero the way a prior can.
Moving to Stan for further work on this, not `brms`, hand-written models via `cmdstanr`, so the exact basis-function random-effects structure stays fully under control rather than going through `brms`'s formula-to-Stan translation.
Plan, in order: first re-implement these exact same models, M0, M1, M2's structure, directly in Stan, one at a time, in the same order, to get a like-for-like comparison against what `lme4` already gave before adding any new complexity.
Given `lme4` alone already took 71 minutes for M2, and Stan will likely be slower still for a comparable model under full HMC sampling, start with fast approximate inference instead, optimization (MAP), Laplace approximation, Pathfinder, ADVI, all supported by `cmdstanr`, rather than full sampling, to iterate quickly, and move to HMC only once a model is settled enough to be worth the wait.
After matching the `lme4` baseline, build up complexity slowly and deliberately, one change at a time, checking results before moving to the next, specifically to address the underfitting/overfitting tension this session's diagnostics kept surfacing, rather than reproducing it in a more expensive tool.
Keep logging each step here as it happens, the way this session's `lme4` work was.
Some of this work will also be referenced in today's BPS Cognitive Section conference talk; see `presentations/bps-cog-2026`.

# 26 August, 2026; 15:00

Starting the first preliminary multilevel nonlinear model fits, for the conference presentation.
This entry will be updated through the rest of today as that work proceeds.

Scope, deliberately narrowed: subject and trial as crossed random effects, no electrode grouping and no spatial model over the scalp.
Electrodes are not exchangeable the way subjects and trials are, they sit at fixed points with a real geometry, and a plain unstructured random intercept per electrode would throw that away.
Handling that properly (a generalised additive model over the scalp coordinates in `analysis/Cap_coords_all.xls`) is real, separate work for another day, already flagged as a known gap in `analysis/multilevel_rbf/model_specification.qmd`'s "What is deliberately left out" section, not something to fold into this pass.
Instead, fitting one electrode at a time.

Electrodes for this pass: `POz` and `Oz` at minimum, adding `Pz` for a fuller check.
All three are midline (the `z` suffix means zero distance left or right of centre), not "central" in the anatomical sense, `C` is a separate, different electrode row (the vertex/sensorimotor strip) that has already shown up flat and uninformative for this task in the 25 August grand-average work.
`POz` is midline parieto-occipital, `Oz` midline occipital, `Pz` midline parietal.
Chosen because this is where the literature on numerosity ERPs consistently locates the relevant components, and because it's also where this project's own grand-average ERPs (`analysis/aug26_1.R`, figures x2/x3) show the largest, cleanest responses of any of the 64 channels.

Wrote `analysis/multilevel_rbf/m1_3_subject_trial_single_electrode.stan` for this pass.
None of the M0-M7 ladder models fit, since that ladder treats electrode as a crossed grouping factor from M2 onward and this pass fits one electrode at a time instead.
Structurally the new model is M1 (subject) and M3 (trial) combined, additively, no electrode term, no stimulus covariates.
Documented in the ladder's `readme.md` and `model_specification.qmd` alongside the numbered models, so the spec still matches the code exactly for every model in the directory, not just the numbered ones.

Before fitting that in Stan, wrote `analysis/multilevel_rbf/smoke_test_lmer.R`, the same subject+trial structure fit in `lme4` instead, as a faster check that the model structure and data prep are sound.
With RBF centers and width fixed rather than estimated, the basis-function expansion is linear in its weights, so this is literally a linear mixed model, fixed-effect and uncorrelated random-slope terms on the K basis-function values, `(b1 + ... + bK || subject)`, the same trick as the spline example in `gam_script2.R`.
Used `||`, uncorrelated random slopes, rather than `|`, because the target Stan model gives each basis function an independent variance with no covariance between basis dimensions, so `||` is the closer analog and also much likelier to converge with two crossed grouping factors than a full covariance matrix would be.
Dry-ran the formula-construction and model-fitting logic on synthetic data (not this project's real data, the host has no `arrow`) to confirm the crossed `(... || subject) + (... || trial_id)` specification is valid and fits without error: `nloptwrap` converged, code 0.
`smoke_test_lmer.R` itself not yet run against the real merged data, that needs the devcontainer.

Restructured into a step-by-step sequence of separate scripts, since the combined draft above was jumping between the full model and its two decompositions out of order.
`analysis/multilevel_rbf/smoke_test_lmer0.R` is the first: subject variability only, subject-averaged data, exactly the M1_3_0 model above, plus diagnostic plots (population fit vs grand average, all-subjects overlay, per-subject facets).
Ran cleanly against the real data on all subjects, no convergence warnings, confirming the earlier diagnosis that the degenerate Hessian was a too-few-groups problem, not a general `lme4` fragility.

The diagnostic plots showed real underfitting, not a false alarm.
The population fit and the per-subject fits both smooth straight through the early P1/N1 structure and flatten peak amplitude throughout, an expected consequence of 8 Gaussian basis functions spaced evenly across the whole -200 to 1000ms epoch, each about 170ms wide, far too coarse for components living in a roughly 80-250ms window.
Between-subject variability itself came through clearly, several subjects' fitted curves peak past 15µV and others stay near zero, so the random-effect structure is doing its job; the resolution problem is specifically in the shared basis, not the multilevel part.

Fixed by adding, not replacing: the original 8 coarse centers spanning the full epoch stay, and a second set of 8 narrower centers, confined to 0-300ms (spacing and width both about 43ms, versus 171ms for the coarse set), is added alongside them, 16 basis functions total.
Centers and widths remain fixed, not estimated, in both sets, so this is still ordinary linear regression on a richer set of fixed predictors, not a step toward overfitting via adaptive basis placement.
Not run against the real data yet with the new basis; that's the next thing to check.

Three components are the target, all standard in the numerosity-ERP literature specifically, not general ERP nomenclature:

- P1, ~80-150 ms, posterior positivity.
Tracks the physical stimulus rather than the perceived one.
Grasso et al. (2022; see below) found P1 amplitude modulated by real differences in dot count between conditions, but unaffected by a numerosity-adaptation illusion that changed what participants perceived without changing the physical stimulus, "suggesting that this variation was mostly unrelated to changes in perceived numerical estimates" (p. 7).

- N1, ~150-200 ms, posterior, a negative-going deflection or inflection between P1 and P2p.
Two things are known about it, and they point the same way.
Hyde and Spelke (2009, see below) found N1 amplitude modulated by absolute number specifically for small arrays (1-3 items), not large ones, and interpreted this as reflecting "a location-specific and attentional-dependent processing... crucial for the elaboration of very low numerical ranges", i.e. tracking individual objects and their locations (an object-tracking/individuation system) rather than an abstract sense of quantity.
Separately, in Grasso et al.'s own data, where every stimulus was already above the subitizing range (22-41 dots), N1 was still modulated by physical numerosity differences, but, like P1 and unlike P2p, was not modulated by the perceptual illusion: N1 waveforms for Baseline, Adaptation and Neutral conditions "were virtually overlapped" (p. 7).
So N1 looks like an earlier, more stimulus-driven stage of processing than P2p, tied to attending to and individuating the array itself, not (on the evidence so far) to the subjective numerical estimate.

- P2p, ~200-250 ms, posterior/parietal, "P2, parietal" to distinguish it from the unrelated centro-frontal P2/P200 component.
This is the component treated as the actual candidate signature of ANS processing, specifically because it is the one shown to track the perceived rather than the physical numerosity.
Grasso et al.'s central result is that P2p shrank under the same adaptation illusion that left P1 and N1 unchanged, and that the size of that shrinkage correlated with each participant's behavioural underestimation (Spearman r(23) = 0.43, p = 0.03).
More generally, mid-latency components like P2p are described in this literature as indexing "abstract, location-invariant numerical information", a genuine representation of quantity rather than a response to a particular low-level visual feature, and one "mostly evident within relatively large numerical ranges" (Grasso et al., 2022, p. 9), i.e. the regime this project's own ANS task uses throughout, unlike the small-number range where N1's distinct role was established.

Papers behind the above, given in full since author-year alone is easy to lose track of later:

- Grasso, P. A., Petrizzo, I., Caponi, C., Anobile, G., & Arrighi, R. (2022). Visual P2p component responds to perceived numerosity. Frontiers in Human Neuroscience, 16:1014703. The paper worked through in detail today; source of the P1/N1/P2p functional contrast above and the electrode cluster (P3, P4, P7, P8, PO3, PO4, PO7, PO8, O1, O2) this project's choice of `POz`/`Oz`/`Pz` is consistent with.
- Hyde, D. C., & Spelke, E. S. (2009). All numbers are not equal: An electrophysiological investigation of small and large number representations. Journal of Cognitive Neuroscience, 21(6), 1039-1053. Source of the N1 (small-number) versus P2p (large-number, ratio-sensitive) dissociation, and, along with Libertus et al. (2007) below, one of the papers credited with establishing P2p as a named component in this literature.
- Libertus, M. E., Woldorff, M. G., & Brannon, E. M. (2007). Electrophysiological evidence for notation independence in numerical processing. Behavioral and Brain Functions, 3:1. Earliest of these to report P2p modulated by numerical distance over relatively large numerical ranges.
- Park, J., DeWind, N. K., Woldorff, M. G., & Brannon, E. M. (2016). Rapid and direct encoding of numerosity in the visual stream. Cerebral Cortex, 26(2), 748-763. Reports an even earlier (~75 ms) component, in addition to P2p, that scales with dot count.
- Fornaciai, M., & Park, J. (2017). Distinct neural signatures for very small and very large numerosities. Frontiers in Human Neuroscience, 11:21. Further evidence for the subitizing-range/large-range distinction underlying the N1/P2p functional split.

# 26 August, 2026; 14:08

To do, not done today: check whether a handful of subjects show a genuine late-epoch drift at the posterior midline channels, rather than ordinary between-subject variability, before trusting the multilevel model's subject-level random effects to absorb it.

The concern: while looking at grand-average and per-subject ERPs at `POz`, `Oz` and `Pz` (`analysis/aug26_1.R`, figures x4 and x5), several subjects' average waveforms stay well away from zero in the 500-1000ms window, well after the grand average has settled back near baseline.
The existing trial-level mask (`scripts/mask_anomalous_trials.R`, see 25 August entry) cannot catch this even in principle: it flags a trial by its IPR, the spread of voltage within that one trial around its own mean, which says nothing about where that mean sits.
A trial that drifts smoothly away from zero, for instance from a slow skin-potential shift or a change in electrode impedance over the session, keeps a normal-looking spread around its own drifted level and is never flagged.
If that drift is consistent in direction across a subject's trials, rather than random trial to trial, it survives averaging over ~200 trials and shows up as exactly this kind of late-epoch offset in the subject mean.
A second, unrelated possibility for the same symptom is a small effective sample size, a subject-channel combination with many trials already masked out has a noisier late-epoch average for that reason alone, no drift required.

Wrote `analysis/check_subject_channel_drift.R` to check this.
For each subject and channel, it computes the subject-average ERP's peak absolute amplitude in the 500-1000ms window, alongside the number of trials that average was built from, and flags outliers using the same per-channel MAD-based z-score convention as `mask_anomalous_trials.R` (z >= 5).
Only the channels actually being checked are pivoted to long format before summarising, not all 64, since a naive `pivot_longer` over the full unfiltered table is the same mistake that used over 90GB of RAM and crashed the machine on 25 August, and this script hit that exact crash on first attempt before being restricted to a handful of channels.
It has to be run inside the Podman devcontainer (or equivalent), not on the host, since the host has no `arrow` installation.

First pass, on `POz`, `Oz`, `Pz`: nothing reaches the z >= 5 bar used for trial-level masking, so nothing here is anomalous by that existing standard.
Below that bar, four subjects (s34, s19, s38, and to a lesser extent s17) show a moderate, consistent elevation (z roughly 2 to 4.5) across all three channels simultaneously, which is more suggestive of a session-wide issue for those subjects than three unrelated coincidences would be.
Checked this isn't just explained by low trial counts: those four subjects have 179-200 surviving trials each, right at the healthy end, while the subjects with genuinely low counts (s18, s6: 67-68 trials; s27: 55 at `Oz`; s31: 93) are a different set and are not the ones showing elevated late-epoch amplitude.
Also checked this isn't just re-finding the two subjects (s13, s23) already flagged as broadly noisy on 25 August: s13 is only moderately elevated here (z = 2.16 at `POz`) and s23 barely registers, so this is catching something different from the earlier trial-level screen, not the same problem twice.
Four subject-channel combinations (s4-Pz, s10-POz, s13-Pz, s23-Oz) are fully masked, every trial flagged, consistent with an ordinary single bad electrode contact for that subject rather than a session-wide problem, since each subject's other channels checked here are fine; not itself a concern.

What still needs doing, later: eyeball s34, s19 and s38 specifically, using `plot_subject()` from `mask_anomalous_trials.R` or `plot_channel_subject_grid()` from `aug26_1.R`, to judge by eye whether the late-epoch elevation looks like genuine drift or artifact worth masking or excluding, or is simply what a more electrically active individual's ERP looks like.
Not blocking the modelling work meanwhile, since nothing here clears the threshold already used to justify masking, but better resolved by eye now than discovered as an unexplained subject-level outlier in a posterior predictive check later.

# 25 August, 2026; 17:07

Ran sanity checks on `data/main/merged_eeg_behaviour_data.parquet`, beyond what AutoReject already does during preprocessing.
Per-subject, per-channel descriptive statistics (variance, MAD, skewness, kurtosis) showed that AutoReject's trial-level rejection was not catching everything, a small number of subjects and channels still contained implausible voltage excursions, into the hundreds of microvolts, concentrated in specific subject-channel combinations rather than spread evenly across the sample.
Two subjects stood out in particular, one (s13) with spread elevated fairly uniformly across nearly all 64 channels, consistent with a session that was noisier throughout, the other (s23) with a close-to-normal spread but far fatter tails on about 50 of its 64 channels, consistent with more frequent moderate excursions rather than a few extreme ones.
Neither was explained by AutoReject's own trial-drop rate, which was unremarkable for both.
Waveform plots of every trial for every channel, across all 47 subjects, confirmed the pattern by eye: not every channel or every subject is affected, both isolated bad trials and whole-channel problems for one subject occur, and the affected electrodes recur non-randomly (central sites, the posterior/inferior edge of the montage, frontopolar sites) and are often physically clustered within a subject, more consistent with session-specific contact problems than with a channel-labelling bug.

Decided AutoReject needed a second pass after it, at the level of individual channel-trial combinations rather than whole subjects or channels.
For each subject, channel and trial, computed the "voltage IPR", the range containing the central 99% of that trial's amplitude, a robust measure of a single trial's spread.
A channel on a trial is flagged if its IPR is more than 5 robust (MAD-based) standard deviations above that channel's own median IPR, computed per channel since channels genuinely differ in typical amplitude and a pooled threshold would just flag naturally wider channels rather than genuinely anomalous trials.
The threshold of 5, rather than the conventional 3.5, was chosen because 3.5 removed close to 5% of all data with no visible benefit over 5 on the cases checked, and 8 was rejected on the assumption that the nonlinear regression's residual error model won't itself be robust to occasional extreme trials, worth confirming once that model is specified.

The rule is now applied, not just computed: flagged cells are set to `NA` in place, rather than whole trials being dropped, so the masked data have exactly the same rows and columns as the input.
A naive `pivot_longer` over the full merged table, to join the per-trial flags against the per-timepoint data, used over 90GB of RAM and crashed the machine, so the join instead goes the other way, the small per-trial flag table is pivoted to wide (one flag column per channel) and joined onto the merged data by subject, block and trial only, which adds columns rather than multiplying rows.
Checked exhaustively, not by spot sample, that every flagged (subject, block, trial, channel) combination is `NA` in every timepoint and every unflagged one is `NA` in none, with no partial masking within a trial/channel.

This, and the `plot_subject()` function to verify what the threshold does to any subject's waveforms with or without it applied, are in `scripts/mask_anomalous_trials.R`, the definitive record of this piece of work.
Writes `data/main/merged_eeg_behaviour_data_masked.parquet`.
Ran it as `Rscript scripts/mask_anomalous_trials.R` from the repository root and confirmed by MD5 checksum that it reproduces the masked parquet file exactly on a repeat run.
Still needs to be wired into the Snakemake pipeline as its last step, not yet done, that's the next piece of work on this.

# 23 August, 2026; 23:11

Added three background notes in `notes/`, written before starting the actual sanity checks on the merged EEG data, since I have no EEG background myself and needed the groundwork written down first.

- `notes/electrode-labels.md`: plain-language explanation of the 64 channel labels (`Fp1`, `AFz`, and so on).
Covers the difference between the physical connector labels (`A1`-`A32`, `B1`-`B32`) and the anatomical 10-20/10-10 labels actually used in the merged data, the naming convention (region letters front to back, odd/even/`z` for left/right/midline), and what the main regions (frontal, central, parietal, occipital, temporal) correspond to on the scalp.
Confirmed the coordinates in `analysis/Cap_coords_all.xls` (sheet `64-chan`) and the renaming done in `pyutils/eegutils.py` both follow MNE's standard `biosemi64` montage, in the same channel order, so the mapping used in the code is a standard, off-the-shelf convention, not something bespoke to this study.
- `notes/preprocessing-pipeline.qmd`: a Quarto methods-style writeup of the full pipeline, numbered step by step, from the raw BDF file through channel renaming, downsampling, ICA/ICLabel artefact removal, filtering, trigger decoding, trial extraction, epoching with baseline correction, AutoReject, participant concatenation, and the final merge with behavioural data.
Reconstructed by reading the Snakefile, `scripts/preprocess_eeg.py`, `pyutils/eegutils.py`, `scripts/combine_preprocessed_eeg.py`, and `scripts/merge_eeg_behaviour_data.R`.
Notes where the Snakefile's actual parameters (1-30 Hz filter, `fix_bad = yes`) differ from the Python script's own coded defaults, since it's the Snakefile's values that describe what was actually run.
- `notes/sanity-checks.md`: what to check in the merged data before trusting it, and what it should look like if preprocessing was done correctly.
Separates two distinct failure modes that need different checks: a code-level channel-labelling bug, which would corrupt every participant identically and is caught by a group-averaged topography check, versus a session-specific wiring error, which shows up as one participant looking anomalous relative to the rest.
Gives concrete checks: amplitude scale, baseline-near-zero, average-reference-sums-to-zero, the expected frontal eye-blink signature, the expected posterior visual response in the first 100-250 ms post-stimulus, left-right symmetry, and per-channel variance screening.

Next step, to be done tomorrow morning (24 August, 2026): actually run the sanity checks described in `notes/sanity-checks.md` against `data/main/merged_eeg_behaviour_data.parquet`.
`analysis/check_erp_plots.R` (a hacky, interactive script, not part of the pipeline) already has a first pass at some of this, grand-average ERP traces per channel and a per-trial per-channel variance screen, and was modified again tonight.
Not committed as part of this entry, still ropey, interactive scratch code.
Not yet decided whether to keep extending that script tomorrow or start fresh; either is fine.

# 22 August, 2026; 22:07

Removed the host renv/venv bootstrap now that the container covers reproducibility.
Deleted `.Renviron`, `.Rprofile`, `renv/`, `renv.lock` (renv, superseded by the container for the pipeline), `arrow_install.R` (a scratch file of failed host attempts at getting R's `arrow` package to build, the exact problem the container now solves), and `install.sh`, `.envrc`, `requirements.txt` (the host Python venv bootstrap and its direnv auto-activation, confirmed no longer wanted, not just for the pipeline but for interactive work too).
`readme.md` never referenced any of these, so no changes needed there.

# 22 August, 2026; 21:08

Fixed the `snakemake -j4` failure from earlier today (host venv broken by the Arch Python 3.13 to 3.14 upgrade, leaving `mne_icalabel`'s ICLabel step without a working backend).
Rather than patch the venv again, containerised the whole pipeline with Apptainer instead of repairing host Python/R state.
Decisions: Apptainer, not Docker.
`onnxruntime`, not `torch`, as the ICLabel backend, since nothing else in the repo uses either.
No `renv` for R, the image itself is the reproducibility mechanism, packages installed straight from CRAN at build time.
Full pipeline ran to completion under the container: `data/main/merged_eeg_behaviour_data.parquet` now exists (23,124,000 rows, 85 columns).
Renamed from `.feather` to `.parquet`: the file is written with `arrow::write_parquet()`, not `arrow::write_feather()`, so `.feather` was always the wrong extension.
Updated the Snakefile's output path and `analysis/check_erp_plots.R`'s (commented-out) read call to match.

Two real bugs turned up along the way, both fixed:

- `fs`, `systemfonts`, `ragg` and friends need `libuv1-dev`, `libfontconfig-dev`, `libfreetype-dev`, `libharfbuzz-dev`, `libfribidi-dev`, `libpng-dev`, `libtiff-dev`, `libjpeg-dev` to build from source on Debian trixie, not just the curl/ssl/xml dev packages that cover `arrow`.
- `process_behaviour_data` failed deterministically with "evaluation nested too deeply: infinite recursion" whenever Snakemake ran it under Apptainer.
Cause: Snakemake's apptainer integration passes `--home <cwd>`, so `$HOME` equals the project directory.
The repo's own `.Rprofile` sources `renv/activate.R`, and renv 1.1.4's activate script re-sources itself repeatedly when `$HOME` and the project directory coincide, blowing R's expression-nesting limit.
Setting `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` was not sufficient, it stops renv from switching library paths but not the repeated re-sourcing.
Fixed by setting `R_PROFILE_USER=/dev/null` in the container image, so `.Rprofile` is never sourced by R processes running inside it at all.
This is specific to Apptainer's `--home` behaviour and would not show up running R normally on the host.

`container/purple.def` has the full build recipe.
`*.sif` is gitignored, rebuild locally with `apptainer build --fakeroot container/purple.sif container/purple.def`.
`readme.md` updated with build/run instructions.

Priority now is completing as much as possible of the analysis described in the abstract below for the presentation at the BPS Cognitive Section Annual Conference, which is held in Liverpool from 26 to 28 August, 2026.

Time, date, location: Oral presentation at 11:10am in Room i3B114 in Liverpool Hope University, Day 2, 27 August 2026.

Title: Identifying the Neural Signature of the Approximate Number System via Multilevel Nonlinear Regression of Single-Trial EEG
Author: Dr Jessica Ann Diaz (Birmingham City University), & Dr Mark Andrews (Nottingham Trent University)

Abstract: The Approximate Number System (ANS) underlies our ability to estimate numerical quantities without counting. Performance on the ANS task correlates with mathematical ability across the lifespan, making its neural basis relevant to conditions such as dyscalculia. We present data from approximately 100 participants, comprising 50 children aged 4 to 12 years and 50 adults, who completed a 64-channel EEG experiment. Each participant performed a standard ANS task, judging which of two dot arrays was more numerous, and a control task requiring size judgments of blob pairs, matched in visual complexity but without  numerosity demands. Our primary analysis applies a novel multilevel nonlinear regression framework to the single-trial ERP data. We model the voltage waveform at each electrode as a smooth nonlinear function of time, represented via basis function expansion. This function is treated as a random quantity that varies probabilistically across trials and participants, yielding random-function effects that generalise random slopes and intercepts in linear mixed models to the nonlinear domain. Stimulus covariates, including dot numerosity, numerosity ratio, and array density, enter as predictors of the population-level mean function, allowing the model to characterise how the ERP varies systematically with task difficulty and stimulus properties. Comparing estimated waveform functions between the numerosity and control conditions aims to isolate those ERP components that constitute the neural signature of ANS processing specifically. Results will assess how well this method identifies the neural signature of ANS processing, how it develops from childhood to adulthood, and what this implies for conditions such as dyscalculia.

# 17 October, 2024; 07:49

Starting doing nonlinear regression. Started with one trial for one subject and with one channel.
Looked at rbf and gp models.
The two main problems faced so far are:

- GPs are extremely slow; though it looks like optimization and/or variational Bayes etc might be possible with cmdstanr
- There is high frequency correlated noise, which looks like it needs a separate GP, which is fine in principle, but I have not exactly got it working yet.

Next steps:

- Get a GP model of slow (which is the main focus) and fast (essentially noise) working
- Get the optimization and/or VB methods working
- Look at downsampling; maybe that will solve it
- Look at the GAM models in neurokit

# 15 October, 2024; 18:11

Add a new preprocessing step using autoreject.

# 21 September, 2024; 21:55

Remove an ThB_03_21_2024_12_10_57.bdf because this was a copy of ThA on that same date.
The original version of ThB is incomplete or not saved properly and it was incorrectly assumed that the ThA on that date was the correct version.
See commit 9498264537196746c2c3fc3bccdf50fb57b552e4 (main) for more details.

# 20 September, 2024; 22:25

- Change the participant id inside the json file of MB*11_13_2023_13_56_39 to \_MB* from *WB*

# 19 September, 2024; 20:13

- Two EEG sessions were recorded at 2048HZ, not 1024HZ. These are downsampled to 1024hz. The sessions can be identified by their file size.
  - raw-data/main/WA_11_22_2023_13_54_06.bdf
  - raw-data/main/MA_11_20_2023_11_46_10.bdf

# 11 September, 2023; 08:08

- As a very preliminary analysis, plot the ERPs for each channel for each of the two tasks. For this, we will average over all subjects and all trials. This required reading in the EEG data and changing some code to do and then writing new code to plot ERPs etc.
- The principal relevant files are, so far,
  - pyutils/get_epochs_from_bdfs.py to read in the raw EEG data and create a feather data frame for exporting
  - analysis/get_unprocessed_erp.R

What I need to do now is do all the preprocessing. Which is?

- Filtering
- Re-referencing to average
- ICA for artefact rejection
- Epoching
- Bad channel detection?
- Baseline correction

# 10 August, 2024; 22:58

- Rename the raw-data files to use a standard basename for each of the N = 48 bdf and N = 48 json files.
- Add Python script to check if the raw-data is complete and correct.

# 10 August, 2024; 15:00

- At around 1pm today, added all the raw EEG data files, using their original filenames.
- Pushed them to GitHub. Upload took around 2 hours.

# 9 June, 2024; 21:48

- Did a preliminary exploratory analysis of the behavioural data.
- With that, all looks fine thus far: as task difficulty decreases, accuracy increases and reaction time decreases, both for the dots and the blobs.
- There is quite a lot of intersubject variability in those effects.
- I also updated the R package to sort subjects by s1, s2 ... and not s1, s11, s12 ...

# 9 June, 2024; 19:43

- I have added the behavioural data files of all subjects thus far, which is 48 subjects.
- Data from 6 of these subjects already had been added.
- I have not added the EEG data files yet due to some trouble downloading them from OneDrive, which I did not persist with due to the fact that I don't need to do any EEG analysis immediately.
- I have updated the R utilities package, renamed purputils, to include a function to read in all behavioural data json files from a single directory in one command, amongst some other changes (see Git repo log).
- I have updated the top level readme to provide a bit more guidance of how to set things up and start doing analysis.
