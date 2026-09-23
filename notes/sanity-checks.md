# Sanity checks on the preprocessed EEG data

This note describes what to check in `data/main/merged_eeg_behaviour_data.parquet` before trusting it as input to the nonlinear regression modelling, and roughly what the result should look like if the upstream recording and preprocessing (see `notes/preprocessing-pipeline.qmd`) were done correctly.
It assumes no prior EEG experience, in line with the electrode background in `notes/electrode-labels.md`.

## What "is this electrode really where it claims to be" actually means

The question behind this whole exercise, whether a column labelled `FP1` really is the electrode that was sitting on the scalp position called Fp1, cannot be answered by inspecting the numbers directly, in the way an obviously-wrong reaction time can be spotted on sight.
Nothing in the merged data records where the electrodes physically were.
That would need something recorded at the time, photographs of the cap, digitised electrode positions from a 3D scanner, or an impedance-check log, none of which exist here.
What can be checked is whether the data *behaves* the way it should if the labelling is correct, using the fact that different scalp regions are known to respond differently to known things: eye movements, visual stimulation, and so on.
That is indirect evidence, not proof, but it is the standard the field itself works to, and a clear failure of it is a real finding, not a false alarm.

It is worth separating two different failure modes, because they show up differently and need different checks:

- A **labelling bug in the code**. The `A1`...`A32`, `B1`...`B32` to anatomical-label renaming in `pyutils/eegutils.py` is fixed, deterministic code, applied identically to every participant's file. If that mapping were wrong, every single participant would show the same, consistent, systematic distortion. This is checkable once, from a topography averaged over all participants, and if the group-level topography looks right, this failure mode is effectively ruled out.
- A **wiring error on a specific session**. Someone plugging the connector strip into the amplifier in the wrong physical orientation, or a poorly-seated electrode, is a per-participant event, not a code bug. This would show up as one participant's data looking anomalous relative to everyone else, not as a group-level distortion, so it needs a per-participant check, not just a group-average one.

The checks below are organised roughly from cheapest and most mechanical (pure bookkeeping, no EEG knowledge needed) to those that need the electrode/region background from `notes/electrode-labels.md`.

## 1. Bookkeeping checks

These confirm the data is structurally what it claims to be, and several of them are already partly enforced by assertions inside the pipeline itself (see `notes/preprocessing-pipeline.qmd`, steps 7, 8, 9, 11); re-checking them here in the final merged file is a cheap way to confirm nothing was lost or reshuffled after those checks ran.

- Row and column counts match expectation: 64 EEG channel columns (`Fp1` through `O2`), the identifying and behavioural columns, and `drop`.
- Every participant has a `time` axis running from -200 to 1000 ms in fixed steps of about 0.977 ms (1000/1024 Hz), with no gaps or duplicated timepoints within a trial.
- The number of trials per participant, per block, matches what the behavioural log for that participant says it should be.
- `drop == TRUE` rate: the proportion of trials AutoReject flagged as unrecoverable. A small, fairly uniform proportion across participants is expected. A participant with almost all trials dropped, or one channel dropped on almost every trial, points at a bad session (poor electrode contact throughout) rather than an occasional bad trial, and probably needs a decision about whether to exclude that participant rather than rely on the trial-level flag.
- Left-right trial counts and stimulus-type counts (`dots` vs `blobs`) per participant are balanced in the way the experiment design intends.

## 2. Amplitude and scale checks

These do not need any knowledge of what a "real" ERP looks like, only what a plausible voltage looks like.

- Units are microvolts (MNE's `to_data_frame`, used in the pipeline, returns data in µV). Preprocessed, filtered, average-referenced single-trial EEG is typically in the tens of µV, with occasional trial-level excursions into the low hundreds. Values consistently in the thousands, or consistently well under 1 µV, would indicate a unit or scaling problem rather than genuine signal.
- The pre-stimulus baseline period (`time <= 0`) should have close to zero mean per trial per channel, by construction (this is asserted inside the pipeline at preprocessing time, step 8; re-confirming it here is a check that nothing corrupted the values between preprocessing and the final merge, not a check on the preprocessing logic itself).
- Summing all 64 channels at a single timepoint should be close to zero, since the data was re-referenced to the average of all channels (step 8). A channel that is a wild outlier will show up as breaking this near-zero sum for every trial it appears in.
- Per-participant, per-channel variance is a good screen for a single bad channel across a whole session: a channel with implausibly high variance (loose contact, intermittent noise) or implausibly low, near-flat variance (poor contact, effectively disconnected) relative to the same channel in other participants, or relative to other channels in the same participant, is worth flagging for exclusion rather than trusting as-is.

## 3. Topography and known-response checks

These use the region background from `notes/electrode-labels.md` and are the main defence against a systematic labelling problem.

- **Eye-blink signature.** Blinks and eye movements produce large, slow deflections that should be concentrated at the frontal and frontopolar channels (`Fp1`, `Fp2`, `AFz`, `AF3`, `AF4`, and neighbours) and fall off quickly moving back towards central and posterior channels. If ICA/ICLabel (preprocessing step 4) has done its job, most of this should already be removed, but any that remains, or the residual pattern of what was removed, should still be front-heavy. If the largest, most eye-movement-like deflections turn out to be concentrated at an occipital or parietal label instead, that is a strong sign the frontal and posterior labels have been swapped somewhere upstream, which would point straight at the channel-renaming step.
- **Visual evoked response.** The stimuli (dot and blob arrays) are presented visually, so a clear, early, stimulus-locked response is expected at occipital and parieto-occipital channels (`O1`, `O2`, `Oz`, `PO7`, `PO8`, `POz`), roughly in the first 100-250 ms after stimulus onset (a positive-going deflection around 70-130 ms, often followed by a larger negative-going deflection around 150-200 ms, is the typical shape, though exact timing varies with age and stimulus). This is the single most useful grand-average plot to look at first: average over all trials and all participants, plot voltage against time for the posterior channels, and check that *something* systematic and time-locked to stimulus onset is visible there, well above the noise level seen in the pre-stimulus baseline.
- **Left-right symmetry.** Channel pairs on opposite sides of the midline (`F3`/`F4`, `C3`/`C4`, `P3`/`P4`, `O1`/`O2`, and so on) should look broadly similar in amplitude and variance, since nothing in the task design should produce a strong overall left-right asymmetry. A systematic, group-level imbalance between corresponding left and right channels is more likely to reflect a reference, grounding, or channel-order problem than genuine neural lateralisation.
- **A later, more central positivity** (around the `Cz`/`CPz`/`Pz` midline, several hundred milliseconds post-stimulus) is plausible for a two-alternative numerical judgement task, since components of that kind are often associated with decision or categorisation processes. This one should be treated as a hypothesis the main modelling is trying to test, not a known ground truth to check the data against; do not be alarmed if it is not obviously visible in a simple grand average, since that is exactly the kind of trial-to-trial and participant-to-participant variability the multilevel nonlinear model is designed to handle.

## 4. What would specifically indicate a labelling or wiring problem

To make the framing in the introduction concrete, this is the pattern to look for, and what it would imply.

- If the blink signature or the visual response above look anatomically sensible (frontal for blinks, posterior for the visual response) when averaged across **all** participants, a systematic, code-level mislabelling of the 64 channels is effectively ruled out, since such a bug would corrupt every participant identically.
- If those same checks look sensible for most participants individually, but one participant's topography looks rotated or mirrored relative to everyone else, for instance their apparent "blink channels" sit at the back of the head instead of the front, that points at a session-specific wiring error for that one participant, not a code bug, and is grounds to consider excluding that participant rather than treating it as a modelling nuisance.
- The two failure modes are not resolved by the same plot. The group-average check answers the "is the code's mapping right" question. The per-participant check answers the "was this specific session wired correctly" question. Both are needed; neither substitutes for the other.

## 5. Practical starting point

`analysis/check_erp_plots.R`, since deleted (see `purge.md`), contained a first pass at several of these, grand-average ERP traces per channel split by stimulus type, and a per-trial, per-channel variance screen for flagging outlier channels.
Extending that script to produce the grand-average posterior-channel plot and the blink-topography check described above, both averaged across all participants first, then repeated per participant, is a reasonable next concrete step, and does not need any tooling beyond what that script already uses.
