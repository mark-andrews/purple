# Electrode labels: what they mean

This is a plain-language guide to the 64 scalp electrode labels used throughout the merged dataset (`Fp1`, `AFz`, `F3`, and so on), for someone who is doing the statistical analysis but did not run the experiment and does not have an EEG background.
It is not a list of all 64 positions.
For that, see `analysis/cap_map.jpeg` (the physical cap layout) and `analysis/Cap_coords_all.xls`, sheet `64-chan` (the spherical and Cartesian coordinates of each named position).

## Two different naming schemes, and how they relate

There are two label systems in play, and it matters that they are not the same thing.

The physical cap and its cabling use connector labels: `A1`...`A32` on one cable bundle, `B1`...`B32` on the other.
These identify a physical wire and amplifier input channel.
They say nothing on their own about scalp location.

The scientific convention uses anatomical labels: `Fp1`, `AFz`, `F3`, `Cz`, and so on.
These identify a position on the scalp, defined relative to skull landmarks, independent of any particular cap or cable.
This is what the code, the merged data, and this note are actually about.
The mapping from one to the other, `A1` -> `Fp1`, `A2` -> `AF7`, and so on, is fixed by BioSemi for their 64-channel cap and is applied automatically in `pyutils/eegutils.py` via MNE's built-in `biosemi64` standard montage, not something invented for this study.
The coordinates in `Cap_coords_all.xls` are consistent with that same standard mapping, which is a useful independent cross-check that the mapping used in the code is the conventional one, not a local error.

## The anatomical naming convention (extended 10-20 system)

The anatomical labels come from the "10-20 system" (later extended to finer spacing, sometimes called the 10-10 system), a standard from clinical EEG for describing scalp position without reference to any particular cap or manufacturer.
Each label has two parts: a letter or letters for the region, and a number or `z` for the position within that region.

The region letters run from front to back of the head:

- `Fp`, frontopolar, the very front, just above the eyebrows.
- `AF`, anterior frontal, between frontopolar and frontal.
- `F`, frontal.
- `FC`, fronto-central.
- `C`, central, over the vertex, roughly above the ears.
- `CP`, centro-parietal.
- `P`, parietal.
- `PO`, parieto-occipital.
- `O`, occipital, the very back, over the visual cortex.

Two further letters mark the sides of the head, roughly level with the ears, running front to back rather than the sequence above: `FT` (fronto-temporal), `T` (temporal), `TP` (temporo-parietal).
`Iz` (inion) sits at the very back of the skull, at the bony ridge you can feel at the base of the head.

The number tells you how far from the midline, and on which side.
Odd numbers are the left side, even numbers are the right side, and the number increases with distance from the midline (`F1`, `F3`, `F5`, `F7` moves from near the midline out towards the left ear).
`z` (for "zero") marks the midline itself, directly along the front-to-back centre line of the head: `Fz`, `Cz`, `Pz`, `Oz`.

So `FC3` is fronto-central, moderately left of the midline.
`PO8` is parieto-occipital, further right of the midline than `PO4`.
`Cz`, dead centre at the top of the head, is the point EEG systems conventionally use as the geometric reference for the whole layout, which is why it sits at inclination zero in the coordinate sheet.

### A rough map of the 64 positions

This is a text approximation of `analysis/cap_map.jpeg`, a top-down view of the head with the nose at the top, for looking up roughly where a label sits without opening the image.
Left-right spacing within each row is scaled from the actual coordinates in `Cap_coords_all.xls`, so it is closer to the real layout than an evenly-spaced grid would be, but it is still a flattened approximation, not the diagram itself.
For exact positions, use the JPEG or the coordinate sheet.

```
                                                  front / nose
                                           Fp1         Fpz         Fp2
                                AF7       AF3          AFz          AF4       AF8
                        F7     F5      F3      F1      Fz      F2      F4      F6     F8
                  FT7      FC5      FC3       FC1      FCz      FC2       FC4      FC6      FT8
  left ear ->   T7        C5        C3       C1        Cz        C2       C4        C6        T8 <- right ear
                  TP7      CP5      CP3       CP1      CPz      CP2       CP4      CP6      TP8
                P9      P7     P5      P3      P1      Pz      P2      P4      P6     P8      P10
                                PO7       PO3          POz          PO4       PO8
                                           O1          Oz          O2
                                                       Iz
                                              back of head / inion
```

Odd numbers (left of centre) and even numbers (right of centre) mirror each other, as the naming convention above describes.
`P9`, `P10`, and `Iz` sit lower on the head, towards the mastoid bone and the inion, than their row placement here suggests, since this is a top-down flattening and those three sit somewhat below the main scalp surface it is projecting.

## Regions in practical terms

Roughly, and only roughly, since scalp position is not the same as the underlying cortex it sits above:

- Frontal and frontopolar channels (`Fp`, `AF`, `F`) sit above the eyes and forehead. These are also the channels most affected by eye movements and blinks, which produce large voltage deflections that are treated as an artefact to be removed, not neural signal, in the preprocessing pipeline.
- Central channels (`C`, `FC`, `CP`) sit over the sensorimotor strip, roughly ear to ear across the top of the head.
- Parietal and occipital channels (`P`, `PO`, `O`) sit towards the back of the head, with occipital electrodes directly over primary visual cortex. For a task presented visually, as this one is, these are the channels most likely to show an early, reliable stimulus-locked response.
- Temporal channels (`FT`, `T`, `TP`) sit low, near the ears, and are prone to muscle artefact from jaw and neck.

That is the level of detail needed to read the column names in the merged data and know roughly where on the head, and how far forward, back, left or right, each one sits.
