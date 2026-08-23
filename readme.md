# Code and data for a project on the neural signatures of the approximate number system

## Overview

This project involves nonlinear regression modeling of ERP signals when people are performing an approximate number system task.

## Data and code provenance

The behavioural data is from a PsychoPy based approximate number system experiment available in the GitHub repo `mark-andrews/adak`, version `0.1-0-g7310f94` (i.e. tag 0.1; short commit hash 7310f94).
All the behavioural data files are the json files in `raw-data`.
The EEG data are the bdf files in `raw-data`.

The data analysis is R and Python based.
There are two separate ways of running that code, covered below: the reproducible batch pipeline, and interactive work.
They use two different container images for two different jobs, and that's deliberate, not an inconsistency: the pipeline's image (Apptainer) only needs to run a fixed, unattended sequence of steps once; the interactive image (Podman) needs to be a normal development environment, with an editor connected to it, a shell, and packages a batch job would never touch (`devtools`, for instance).

## Reproducible pipeline

The pre-processed EEG and behavioural raw data is created using Snakemake, running inside an Apptainer container, so it doesn't depend on the host's Python or R installation at all.

Build the image once (from the repo root, so the `%files` paths in `container/purple.def` resolve):

```bash
apptainer build --fakeroot container/purple.sif container/purple.def
```

This installs Python (`mne`, `mne-icalabel`, `autoreject`, `onnxruntime`, ...) and R (`tidyverse`, `arrow`, `purputils`, ...) into the image.
It takes a while, mostly spent compiling the R `arrow` package's C++ backend and the rest of `tidyverse` from source.
`container/purple.sif` is a large binary build artefact and isn't tracked in git; rebuild it locally with the command above whenever it's missing.

Then run the pipeline:

```bash
snakemake -j4 --sdm apptainer
```

Running time: around 2.5 hours (measured on 23 November, 2024; container overhead is minor).
The end product is `data/main/merged_eeg_behaviour_data.parquet`, one row per EEG timepoint per trial, joined against the behavioural covariates for that trial.

## Interactive development

Day-to-day interactive R and Python work (exploring the data, writing new analysis code, the nonlinear regression modelling) happens in [Positron](https://positron.posit.co/), connected to a container built from `.devcontainer/Dockerfile`, using [Podman](https://podman.io/) rather than Docker.
This is a separate image from the pipeline's `container/purple.sif`: same broad package set where it matters, built differently, and kept up to date for editing and exploring rather than for running once unattended.

This is the way this project is actually developed day to day, so it's documented here.
It isn't the only way to work with this code — plain Jupyter, RStudio, a host virtual environment, or anything else that can run R and Python will work fine too — but those paths aren't covered here, since only one person is working on this project at the moment.

### One-time setup

Install Podman and the Docker CLI shim, so tools that look for a `docker` binary find Podman instead (on Arch):

```bash
sudo pacman -S podman podman-docker
```

You don't need `podman-compose` (that's for multi-container setups via a compose file, not used here) or `podman-desktop` (a GUI; everything here goes through the CLI).

### Working in Positron

Open this repo's folder in Positron, then use the command palette to reopen the workspace in the dev container (the exact wording is along the lines of "Dev Containers: Reopen in Container").
Positron reads `.devcontainer/devcontainer.json`, builds `.devcontainer/Dockerfile` via Podman the first time (or whenever the Dockerfile changes), and opens the workspace inside it.

The first build takes a while, for the same reason the pipeline's image does: compiling `arrow` and the rest of `tidyverse` from source.
Later reopens reuse the build cache and are fast.

If the first build fails with an error about `pasta` or `/dev/net/tun`, rootless Podman couldn't set up its usual isolated network namespace for the build; add `--network=host` to the build (in Positron's dev container settings, or by building the image once yourself with `podman build --network=host -t purple-interactive -f .devcontainer/Dockerfile .` before reopening).

The container's active user is `root`, not a per-user account.
Rootless Podman's default UID mapping sends container UID 0 straight to the host user's real UID, so files edited inside the container keep normal host ownership on the bind-mounted workspace; any other in-container UID gets shifted into a subordinate range instead, which is why running as `root` here is what makes editing files feel ordinary from the host side, not a security-relevant choice.

If reopening in a container hangs, or repeatedly fails to start with the same error even after a Dockerfile or devcontainer.json change, Positron is likely retrying an already-created container rather than building fresh.
Find and remove it (`podman ps -a`, then `podman rm -f <name>`) and reopen; with nothing left to reattach to, Positron is forced to create one from the current config.

Once inside, both the R console and the Python console are the container's interpreters automatically, no per-language picker to fight with.
`purputils` is installed automatically on first creation (`devtools::install_local("rutils")`, run via `postCreateCommand`); after editing anything under `rutils/R/`, rerun that command, or use `devtools::load_all("rutils")` for changes to take effect without a full reinstall each time.

## Code layout

### R package

The R based code utilities are a real, installable R package named `purputils`, in `rutils/` (it has a `DESCRIPTION` and `NAMESPACE`, and is built with `R CMD INSTALL`).
Inside the interactive container this is installed automatically, as above; installed by hand it's:

```r
devtools::install_local("rutils") # install purputils package
```

### Python module

There's Python code shared across scripts too, in `pyutils/`.
This is a single module (`eegutils.py`), not an installable package: there's no `pyproject.toml` and nothing to `pip install`.
It's imported directly via a path lookup in the scripts that need it (see `scripts/preprocess_eeg.py`), which is why it doesn't appear in either container's package list.

### Scripts

The Python and R scripts are in `scripts/`.
