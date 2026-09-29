# 29 September, 2026; 19:15

First look at the child data, in the course of setting up its preprocessing.

There are 53 children, aged 4 to 12.
Each did three blocks of the same task as the adults, with 30 dot trials and 30 blob trials per block, so 90 dot trials each against the adults' 200.
Mean accuracy on the dots is 68%, ranging from 48% to 84% between children, against 75% to 92% in the adults.

The children also saw a single fixed sequence, but a different one from the adults.
Every child saw the same 30 dot trials in the same order, repeated identically as each block.
The sequence has 29 distinct stimulus pairs, with ratios of larger to smaller from 1.02 to 1.45, and only 7 of those pairs are among the adults' 45.
So differences between children cannot come from the stimuli, but stimulus effects cannot be compared directly between children and adults, since the two stimulus sets barely overlap.
The first trial of every child block is again the same pair (47 against 59 dots), so the first-of-block effect found in the adults must be checked for here.
The details are added to `notes/fixed-trial-sequence.md`.

The recordings have the same format and trigger codes as the adults', and the existing preprocessing handles 51 of the 53 unchanged.
One recording (MA, 11 August 2025) was made with an extra, unconnected bank of 32 electrodes, which are dropped.
One (MA, 16 February 2026) began after the first block had started, so that block's 30 dot trials are lost and the other blocks are numbered correctly.
In the first recordings processed, AutoReject rejected anything from 3 to 112 of a child's 180 epochs, against a median of about 3% in the adults, so the number of usable trials will vary much more between children.
Preprocessing was paused in the evening to free the machine and completed just before midnight.
The merge with the behavioural data then needed one more fix, since the child json files put a date in the participant code (and in one session a different code from the file name), so behaviour is now matched to EEG by the session's date-time.
`data/child/` now has the same four files as `data/main/`.
At POz the median child has 85 of 87 usable dot trials after artefact rejection and masking, but two children have fewer than 20.
The child grand averages show a large posterior positivity near 155 ms and a negativity near 230 ms, possibly the P1 and N1, larger and later than in the adults, which is a first look only.

# 29 September, 2026; 14:40

Plan for the week to Saturday 3 October, agreed with Mark today, recorded so that it survives interruptions.
This entry may be deleted once the plan is carried out.

Step 1, the clean-up and squash merge of the RBF branch, is done (previous entry).

Step 2 is a fully reproducible slide deck for Jessica, in `reports/presentations/plymouth-october-2026/`, rebuilt from the data rather than from any saved result.
It is a two-stage pipeline.
A heavy script, `prepare_results.R`, does everything that takes more than seconds and writes small result files to a git-ignored results directory.
The Quarto document, rendered to PowerPoint, only reads those files and may contain any R code that runs in seconds.
Every step that involves randomness takes a fixed seed, so that rerunning gives the same files, exactly so with the same container image on the same hardware.
The heavy script builds the decimated trial cache, fits the corrected B4 (first trials excluded, previous trial's ratio, fixed effect scales) at POz, Oz, Pz, PO7 and PO8 in parallel, runs the item-level crossed mixed-model analysis of ratio, and computes behaviour by ratio, grand averages and the raw difference waves.
B3 is not refitted for the slides.
The run should take about five hours and must take less than twelve.
The existing results in `tmp/` are kept until the new run is compared with them, since the new estimates should agree within Monte Carlo error, and a disagreement would be a problem in itself.
The deck is plain, at most 20 slides, with a working title, taking background and method from the BPS Cog 2026 deck and adding the new results.
The ratio result is presented from the item-level analysis, as preliminary.
A readme in the directory says what the deck is for (Jessica's talk at Plymouth on 14 October 2026) and how to rebuild it.

Step 3 is preprocessing the child data (53 subjects, in `../purple-raw-data/data/child`).
The Snakefile gains rules that write `data/child/` with the same four files as `data/main/`, namely the combined behaviour CSV, the merged EEG and behaviour parquet, the masked parquet and a readme.
The masking step, `scripts/mask_anomalous_trials.R`, becomes a Snakefile rule for both samples, since at present it is run by hand.
`scripts/preprocess_eeg.py` is left untouched.
A copy, `scripts/preprocess_eeg_child.py`, takes whatever changes the child data needs, and likewise for the behavioural script if the child JSON differs.
Merging the adult and child scripts into one general script is later work, after the child data is processed.
The first task is to compare a few child recordings with an adult one (channels, sampling rate, trigger codes, recording length), since that is where the unknowns lie.
Then the child grand-average ERPs at every electrode are plotted, as was done for the adults in August (`reports/presentations/bps-cog-2026/prepare_presentation_data.R`), and one or two slides comparing them with the adults are added to the deck.
If the EEG preprocessing is not working by Friday, the child behavioural results go in instead.

Schedule.
Tuesday, step 1, then the results script, tested on a subset and launched in full overnight.
Wednesday, check the new results against the old and build the deck, and begin inspecting the child data.
Thursday and Friday, the child pipeline and child ERPs.
Saturday, send the deck to Jessica.
The branch `get-rbf-stan-models-working-23-sept-2026` and the tag `rbf-stan-branch-final` are kept for a few days before the branch is deleted.
Nothing is pushed to GitHub until Mark says so.

# 29 September, 2026; 14:20

The branch `get-rbf-stan-models-working-23-sept-2026` (23 to 29 September) has been squash-merged into main.
It produced a working Bayesian multilevel radial basis function model of single-trial ERPs, fitted at POz, Oz, Pz, PO7 and PO8 to all adult trials, without predictors (B3) and with subject accuracy and trial ratio as predictors (B4).
It also found that the stimulus sequence of the experiment was not randomised, which changes how any stimulus effect must be analysed.
The branch's running log has been condensed into this entry.
The branch tip before its clean-up is tagged `rbf-stan-branch-final`, and `purge.md` lists what was removed.

## Agenda and deadline

Jessica presents this project at a department in Plymouth on 14 October 2026.
About 15 to 20 minutes of her talk concern it, mostly background on the approximate number system and its neural signatures, with five to ten minutes of results.
The audience is not mathematical, so results are presented without technical detail on priors and the like.
The results are work in progress, in the spirit of the BPS Cog 2026 talk, honest and neither overstated nor undersold.
The message is that multilevel nonlinear regression with basis functions is a new and general method for ERP analysis, that it works on this data, and that it already gives preliminary answers to real questions.

The deliverable is a Quarto deck rendered to PowerPoint, at most 20 slides, from which Jessica takes what she needs into her own deck.
It is due to her by Saturday 3 October.
The priorities are, in order, the adult modelling of three questions (corroborating the P1/N1 and P2/P2p signature at posterior electrodes, its variation with individual ANS acuity, and its variation with numerical ratio), then preprocessing the child data so that child ERPs can be shown, then behavioural results for adults and children.
The plan for the rest of the week is in the next entry.

The RBF model is to be completed for this phase and then succeeded by a Gaussian process version, which will probably be the model from then on.
The RBF model's structure (basis placement, two density tiers, which basis functions each level may use, the subject-level prior) had to be repaired case by case as the data exposed problems.
A Gaussian process states the same assumptions as one covariance function per level.
The computational machinery built here (exact integration over subject and trial deviations, sufficient statistics, AR whitening) carries over to it.

## The model

The complete specification is the first section of `analysis/rbf_stan/models.qmd`, and the procedure is in `analysis/rbf_stan/readme.md`.
At one electrode, each trial's waveform, decimated to 128 Hz, is a population waveform, plus its subject's deviation, plus its own deviation, plus AR(2) noise with parameters shared across all trials.
Waveforms are built from Gaussian basis functions, 8 coarse ones over the whole epoch and 31 dense ones every 20 ms from 0 to 600 ms.
The population weights have a ridge-plus-curvature prior with estimated scales, the penalised prior of a generalised additive model.
Subject deviations use the full basis, with independent scales on the coarse block and the ridge-plus-curvature prior on the dense block.
Trial deviations use the coarse block only.
The width multipliers of the two blocks were estimated once per electrode from subject-averaged curves (B1) and are fixed thereafter.
Trial and subject deviations are integrated out analytically, and the likelihood is computed from sufficient statistics, so the cost does not depend on the number of trials and the sampler sees about 30 to 65 parameters.

B3 is this model without predictors.
B4 adds effect curves over time for standardised log-odds accuracy (a subject-level predictor) and standardised log(larger/smaller) ratio (a trial-level predictor, larger meaning easier), plus the previous trial's ratio as a covariate.
The effect curves use the full basis with the ridge-plus-curvature prior at fixed scales (ridge 5, curvature 10), like a fixed smoothing penalty.
The first trial of each block is excluded (see below).
Accuracy is the acuity measure rather than the Weber fraction, because every subject saw the same ratios, so the two carry essentially the same information and accuracy needs no explanation.

Several parts of this design were forced by problems, and the reasons matter for the Gaussian process version.
The ridge-plus-curvature prior must be stated as a single Gaussian with precision I/tau_r^2 + D'D/tau_c^2.
Stated as two sampling statements it has the wrong normalising constant, which makes the posterior improper at zero scale when the scales are estimated, and this is why the original single-trial model collapsed to a flat line.
The basis is strongly collinear, so NUTS needs a dense mass matrix.
AR noise parameters cannot be estimated from the same single trial as the waveform, since in simulation the noise then absorbed most of the signal.
Sharing them across trials, as the multilevel model does, identifies the time-locked waveform.
With 8 dense functions to 300 ms the model underestimated P2p, and 31 to 600 ms fitted the mean of subject averages to within about 0.2 uV.
With subject deviations on the coarse block only, individual N1 and P2p differences could not be represented.
With independent scales on the full subject basis, the shared P1 moved out of the population waveform into the subject deviations, hence the hybrid subject prior.
With estimated effect-curve scales, B4 shrank the ratio effect 2 to 8 times below the raw within-subject slope and let the subject deviations absorb the accuracy effect.
The model's own subject waveforms had the right accuracy slope, but the effect curve was near zero.
Fixed scales removed both problems, and realistic planted effects (1.5 uV per sd for accuracy, 0.3 uV per sd for ratio) were then recovered almost exactly.
Leave-one-subject-out PSIS-LOO proved unusable for comparing designs (p_loo about 300 for 46 curves), so designs were judged against the mean of subject averages.

## B3, the neural signature

B3 fits took 2.3 to 2.6 hours per electrode, five in parallel, and all converged (R-hat at most 1.006, bulk ESS at least 1398, at most one divergence).
The population waveform matches the mean of subject averages to within 0.3 to 0.6 uV from 0 to 600 ms and captures P1, N1, P2p and the late positivity at every electrode.
The fitted subject waveforms follow each subject's average through every component and smooth over its noise.
At POz the between-subject sd of the waveform is near zero before stimulus onset, peaks at about 6 uV near 170 ms (N1) and about 5 uV near 270 ms (P2p), and falls to about 1.5 uV by 1000 ms.
So individual differences are largest at the components of interest.
The Plymouth slides use B4 only, whose population waveform is the signature for an average subject on an average trial.
B3 may be returned to, for example to show total between-subject variability rather than what remains after accuracy.

## The stimulus sequence

Every subject saw one fixed sequence of 50 trials, repeated identically as each of the four blocks, with 45 distinct stimulus pairs.
The full account of its benefits, costs and remedies is in `notes/fixed-trial-sequence.md`.
Two consequences were found in the data.
The first trial of every block is the same hard pair (47 against 51 dots), and its ERP differs greatly from other trials (at POz at 253 ms, -2.2 against 5.9 uV), presumably because it follows a break.
That alone manufactured an apparent ratio effect at the P2p latency, which disappears when first trials are excluded.
Consecutive trials' ratios are also correlated (about 0.16), which carries activity from the previous trial into apparent ratio effects before stimulus onset.
So every analysis excludes first trials and controls for the previous trial's ratio.
Ratio is confounded with item identity and each item's fixed context, and its effective sample size is about 44 items, not 8300 trials, so ratio effects must be judged against variation between items, with pairs as a random factor crossed with subjects.
The accuracy and population results are unaffected, since every subject saw identical stimuli.
The experiment code (`mark-andrews/adak`) must be checked for a fixed seed and corrected before further data collection, and it must be established whether the child data used the same sequence.

## B4 results

The corrected B4 fits (first trials excluded, previous ratio, fixed effect scales) took 4.3 to 5.2 hours per electrode and all converged (R-hat at most 1.007, bulk ESS at least 1364, 0 to 4 divergences).

Accuracy, reportable as preliminary.
Higher-accuracy subjects have a more positive waveform at about 260 to 325 ms at POz and Oz, the P2p window, and at about 145 to 175 ms at PO7 and PO8, the N1 window, by about 1.3 to 1.7 uV per sd of accuracy at 300 ms at POz and Oz.
These agree with the raw slopes of subject averages on accuracy.
The bands are pointwise, and a pre-stimulus window at Pz shows that isolated false windows occur.
The raw difference of 3 to 6 uV at about 165 ms between the higher-accuracy and lower-accuracy halves of subjects is not a reliable linear accuracy effect.

Behaviour.
The ratio manipulation works strongly, with accuracy rising from 0.60 in the hardest fifth of trials to 0.98 in the easiest, median RT falling from 0.90 to 0.70 s, and a positive slope of accuracy on log ratio in every one of 47 subjects.

Ratio, preliminary.
B4 treats trials as independent evidence about ratio, so its bands are too narrow.
An item-level analysis, with single-trial mixed models at each timepoint having crossed random intercepts for subjects and the 44 pairs, finds easier trials more positive at about 350 to 375 ms at all five electrodes, by about 0.3 uV per sd of log ratio, with a later positivity at about 540 to 610 ms at POz and 420 to 610 ms at Pz, and a reversal after about 850 ms that overlaps the responses.
B4 finds the same windows.
The timing resembles the P3-range distance effect of Libertus and colleagues (2007) more than a P2p effect.

The literature (`notes/ans-cognitive-neuroscience-literature.qmd`) does not lead us to expect large effects here.
Published ERP ratio effects mostly compare one array with a reference held in memory, contrast ratios much further apart than ours (1.02 to 1.39, all hard), and differ in direction between studies.
The individual-differences evidence (Pinhas and colleagues 2023, Paulsen and colleagues 2010) is mainly an acuity by ratio interaction, which B4 does not yet include.

## Open

Pairs as a random factor inside the RBF model is implemented (`items=1`) and its likelihood is checked against a brute-force computation, but it does not sample well.
A 20-trial test hit the maximum tree depth on 98 per cent of transitions with R-hat up to 2.2, and the full runs launched on 28 September did not complete.
The likely cause is that ratio is a property of each pair, so the ratio effect curve and the item deviations compete for the same variation, with the non-centred item deviations making it worse.
Also open are an acuity by ratio interaction, the AR order (AR(2) throughout so far, with no settled criterion for choosing it), modelling electrodes jointly, updating `ppc_b4.R` for the current options, and the Gaussian process version.
Posterior predictive checks and recovery tests with realistic effects are standing requirements for every model.

# 23 September, 2026; 21:22

Renamed the two basis-function modelling directories.
`analysis/multilevel_rbf_stan/` is now `analysis/rbf_stan/`, and `analysis/multilevel_rbf/` is now `analysis/rbf_lme4/`.
The old names hid the one real difference between them, which is Stan versus `lme4`, and "multilevel" misdescribed B0, a single-trial model.
Earlier entries and `purge.md` use the old names and have deliberately been left as they were.

The Stan directory was also consolidated.
The first-generation single-trial AR(p) model and its document were superseded by B0 and deleted, and the three overlapping documents were merged into `models.qmd`.
Details are in `purge.md` and the directory's `README.md`, which now sets out the step-by-step procedure.
The single-trial CSV that the B0 scripts read had never been kept anywhere.
`extract_b0_trial.R` now regenerates it, and it recovers the original trial (s17, block 1, trial 53), confirmed by reproducing the residual autocorrelations quoted in the documents.

The substantive finding is that B0 does not work as written.
Fitted end to end on that trial with iid, AR(2) and AR(4) noise, it shrank the waveform to a flat line in every case and let the noise term absorb the signal.
The weight-scale parameters fell to about 1e-6, and the chains did not converge (R-hat 1.7 to 3.3, about 5 effective draws).
The gls fit of the same trial finds clear structure, so the fault is in the model or its parameterisation, not the data.
The likely cause is the sampler becoming stuck as the weight scales approach zero.
Non-centring the weights, or a prior that keeps those scales away from zero, are the first things to try.
B1 to B3 share the same weight prior, so B0 has to be fixed before any of them is fitted.

# 21 September, 2026; 22:32

Did first-pass on how to clean up the directory, since `analysis/` in particular has accumulated undifferentiated clutter and the project layout no longer distinguishes raw-data preparation, preprocessing-adjacent work, and current interactive analysis from one another.
Nothing has been moved or deleted yet.
This entry records the recommendation as given, to be returned to and acted on once priorities are settled.

Organising principle proposed: `analysis/` should hold only current interactive exploration, matching its own stated purpose in `CLAUDE.md`.
A dead line of work should be archived rather than left mixed in among live files, so the directory doesn't require archaeology every time it's opened.
Raw-data preparation scripts, `prepare_child_raw_data_files.py` and `rename_raw_data_files.py`, stay where they are only until the raw-data move described in the 12 September entry below actually happens.

Files judged confidently obsolete, candidates for outright deletion.
`analysis/get_unprocessed_erp.R` reads `data/main/epochs_8_sept_2024.feather`, which no longer exists, and predates the entire current preprocessing pipeline, AutoReject, anomalous-trial masking, the parquet merge, none of which existed yet when it was written in September 2023.
`analysis/compare_behav_and_eeginfo.R` reads from `data/pilots/pilot_26July2023/`, a directory no longer present anywhere in the tree, a one-off July 2023 pilot sanity check.
`analysis/rbf_example_1.R` through `rbf_example_5.R`, their matching `.stan` files, and three compiled Stan binaries, `rbf_example_1`, `rbf_example_2`, `rbf_example_2a`, roughly 8.6MB total, checked into git as build artefacts, which they should never have been.
These come from the Gaussian process dead end recorded in the 17 October 2024 entry below, and the commit that added them was itself titled "Add lots of crufty scripts to do rbfs and gps".
`analysis/s13_b2_t14.csv`, added in that same commit and apparently scratch input for those scripts, is the exact file already flagged by eye as not belonging in the directory at all.
Both `__pycache__` directories, under `analysis/` and under `pyutils/`, are untracked Python bytecode caches with no history to lose.

One genuine judgment call, the two `multilevel_rbf` directories.
`analysis/multilevel_rbf/` holds an eight-model Stan ladder, `m0_pooled.stan` through `m7_full.stan`, written 22 August, and its own `readme.md` says plainly that none of them have been fitted yet.
`analysis/multilevel_rbf_stan/`, written 21 September, describes itself in its own `README.md` as "the Bayesian replacement for the `lme4` smoke tests in `analysis/multilevel_rbf/`".
So the `m0`-`m7` files and `model_specification.qmd` are superseded and never fitted, reasonable to archive.
But `smoke_test_lmer0.R`, `smoke_test_lmer1.R`, `smoke_test_lmer2.R`, and `m1_3_subject_trial_single_electrode.stan`, all in that same `multilevel_rbf/` directory, are still live: the newer README's own B0-B3 comparison table names them directly as the `lme4` counterparts each Stan rung is checked against.
The directory needs splitting on that basis, not deleting wholesale.

Other points raised, none acted on.
`reports/papers/`, `reports/presentations/`, and `reports/misc/` each contain nothing but a placeholder readme saying "so far, empty", while the actual conference presentation, `presentations/bps-cog-2026/`, lives in a separate top-level `presentations/` directory outside that structure entirely.
Worth deciding whether `reports/` is an intended structure that presentations should move into, or whether it should be dropped.
`notes/rbf_to_gp_proof.md` is from the same October 2024 Gaussian-process dead end as the deleted rbf examples above, but its content, the RBF/GP equivalence, is still cited conceptually in the new `multilevel_rbf_stan/README.md`, so recommended to keep rather than archive.
`analysis/exploratory_analysis_behavioural_data.R` and its `.Rmd` counterpart, `analysis/sample_size_determination.R`, and `analysis/rename_raw_data_files.py` are all old, 2023 to 2024, but document real prior decisions and preliminary checks rather than throwaway scratch work, so recommended to leave alone for now.
`analysis/check_erp_plots.R` is explicitly called "hacky", "ropey", "interactive scratch code" in the 23 August entry below, and its functionality has likely been superseded by the later grand-average work in `aug26_1.R`, a candidate for archiving, though it may still be wanted as a reference.

# 12 September, 2026; 21:55

To-dos accumulated over the last two days, previously spread across three separate entries (11 September and two from earlier today), gathered into one for easier reading later. What actually got done in that time is recorded in the entry below this one, unchanged.

Code layout.
This project needs a serious tidy-up of where the steps before preprocessing live.
Right now some of that work sits inside `analysis/`, which is meant for interactive, non-pipeline exploration, not for steps that logically belong before `scripts/preprocess_eeg.py` runs.
The distinction between raw-data preparation, preprocessing, and downstream analysis is not currently reflected in the code layout.
That needs sorting out properly at some point, not solved in passing here.

Raw data and Git LFS, a bigger and more concrete version of the point above.
All the raw data (`raw-data/main` and `raw-data/child`) is going to move out of this repository entirely, into a separate, non-version-controlled project.
Reason is Git LFS.
It has been paid for and has still hit its limits after only a handful of clones, pushes, and pulls, and these files don't justify that cost or that fragility, they're set once and never change again after the one renaming pass each directory gets.
The eventual home is a public neuroimaging data repository, not decided yet which one, staying local in the meantime.
Once that move happens, `analysis/prepare_child_raw_data_files.py` (and whatever the equivalent for `raw-data/main` turns out to be), along with each directory's `readme.md`, `checksums.txt`, and `raw_data_integrity_check.py`, all move with the data, into that other project, not this one, since none of it is pipeline pre-processing or analysis.
Until the move happens, `prepare_child_raw_data_files.py`'s docstring has been rewritten to spell out what it does step by step and to make explicit that it's meant to be run interactively, from inside the directory holding the original, pre-renaming files, so that whoever eventually has only the originals (from a backup, or from wherever this data ends up living) can reproduce exactly the same renamed, skipped, and deleted files already produced here.
The script's hard-coded paths will need updating to point at wherever the data actually lives once it moves, that's a mechanical change, not attempted yet.

`raw-data/main`'s `ThB_03_21_2024_12_10_57`, unrelated to the above.
It has a json but no matching bdf, 47 bdf files against 48 json files (see that directory's own `raw_data_integrity_check.py`).
The reason isn't recorded anywhere found so far, whether the EEG was never recorded for that session or was recorded and later judged unusable and removed.
Worth tracking down, and if it turns out to be the latter, the json should probably be removed too for consistency, but not resolved here.

# 12 September, 2026; 21:38

Finished the raw-data/child renaming started on 11 September.
Working from `analysis/check_child_raw_data_filenames2.py`, paired every bdf with its json, resolved the ambiguous cases where possible, and renamed everything to the raw-data/main scheme.
Two sessions, SuA on 1 June 2025 and FA on 29 August 2025, were dropped rather than resolved.
Each had more than one json against a single bdf, and the bdf's own header start time didn't line up with an ordinary single session for either candidate.
Most likely explanation is that the EEG kept recording across more than one aborted or restarted behavioural attempt, so which json corresponds to the actual recording isn't known without checking trial by trial against the EEG triggers.
One more json, the 15:13:09 attempt for MC on 16 February 2026, was dropped because it was truncated, 565 lines against 1669 for every other json in the directory.
Three further files had no counterpart at all and were dropped for that reason alone, `FB_29August2025.bdf`, `SuB_1June2025.bdf`, and the json for `SA_12July2025`.
A stray `.fif` file, `MA_11August2025cleaned.fif`, a processed file that had ended up in raw-data/child for no known reason, was deleted too.
Final count came to 53 subjects, 53 bdf files and 53 json files, each pair sharing a basename and differing only in extension, matching what was expected for this sample.
Added `raw-data/child/readme.md`, `checksums.txt`, and `raw_data_integrity_check.py`, the same approach already used in raw-data/main.

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
