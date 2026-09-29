# Slides for Jessica's Plymouth talk, October 2026

This is a plain slide deck of results from this project on the approximate number system (ANS).
Jessica Diaz will take slides from it into her own, larger talk at the University of Plymouth on 14 October 2026, which also covers other projects, and will restyle them there.
So the deck has a working title, no styling, and more slides than she will use.
It shows the ANS signature in the adult EEG, and preliminary results on how it varies with individual acuity (accuracy) and with the difficulty of the comparison (numerical ratio), from the multilevel radial basis function model in `analysis/rbf_stan/` and from simpler checks.

## Rebuilding the deck

The deck is fully reproducible from the preprocessed data, in two stages.
Nothing is taken from earlier saved results.

First, `prepare_results.R` computes every result and writes small files to `results/` in this directory.
It runs in the devcontainer image, from the repository root:

```bash
podman run --rm --user root -v "$PWD":/w -w /w localhost/purple-interactive \
  Rscript reports/presentations/plymouth-october-2026/prepare_results.R
```

It needs `data/main/merged_eeg_behaviour_data_masked.parquet` and `data/main/combined_behaviour_data.csv` from the Snakemake pipeline.
It takes about five hours on 24 cores, almost all of it in the five model fits, which run in parallel.
Every random step is seeded, so a rerun with the same container image on the same hardware gives the same files.
The header of the script lists its options, including `test=1`, a quick check of the whole pipeline that writes to `results-test/`, and `stage=`, which runs only some stages.
`results/provenance.txt` records the commit and package versions a run used, and the fit logs are in `results/fits/`.

Second, render the slides from this directory:

```bash
quarto render slides.qmd
```

This takes seconds and writes `slides.pptx`.
It uses the host's R and needs only `tidyverse` and `scales`.
To render from the test run instead, set `PLYMOUTH_RESULTS=results-test`.

`results/`, `results-test/` and the rendered `.pptx` are not committed.

## Files

`prepare_results.R` computes the results, `slides.qmd` is the deck, and `figs/dots_example.png` is an example stimulus.
Background slides are adapted from the BPS Cognitive Section 2026 talk in `../bps-cog-2026/`.
