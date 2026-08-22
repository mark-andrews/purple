# Code and data for a project on the neural signatures of the approximate number system

## Overview

This project involves nonlinear regression modeling of ERP signals when people are performing an approximate number system task.

## Code

The behavioural data is from a PsychoPy based approximate number system experiment available in the GitHub repo `mark-andrews/adak`, version `0.1-0-g7310f94` (i.e. tag 0.1; short commit hash 7310f94).
All the behavioural data files are the json files in `raw-data`.
The EEG data are the bdf files in `raw-data`.

## Utilities

The data analysis is a R and Python based.

### R package

The R based code utilities are in a bespoke project-specific R package named `purputils`, found in the `rutils/`.

This can be be installed as follows (assuming the working directory is this repo):

```bash
devtools::install_local("rutils") # install purputils package
```

### Python package

There is a Python package too. It is in `pyutils/`.

### Scripts

The Python and R scripts are in `scripts/`

### Snakemake

The pre-processed EEG and behavioural raw-data is created using snakemake.
The pipeline runs inside an Apptainer container, so it no longer depends on the host's Python or R installation.

First build the image (from the repo root, so the `%files` paths in the definition resolve):

```bash
apptainer build --fakeroot container/purple.sif container/purple.def
```

This installs Python (`mne`, `mne-icalabel`, `autoreject`, `onnxruntime`, ...) and R (`tidyverse`, `arrow`, `purputils`, ...) into the image.
It takes a while, mostly spent compiling the R `arrow` package's C++ backend and the rest of `tidyverse` from source.

Then run the pipeline with:

```bash
snakemake -j4 --sdm apptainer
```

Running time: around 2.5 hours (measured on 23 November, 2024; container overhead is minor).

The image itself (`container/purple.sif`) is a large binary build artefact and is not tracked in git; rebuild it locally with the command above whenever it is missing.
