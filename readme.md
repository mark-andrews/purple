# Code and data for a project on the neural signatures of the approximate number system

## Overview

This project is code-named Purple.
It is an EEG study of the approximate number system (ANS), using multilevel nonlinear regression of single-trial ERP waveforms recorded while people perform an ANS task.
Adults and children judged which of two dot arrays was the more numerous.

## Planned papers

This one research project is planned to lead to three separate papers.
Each has a code name, used throughout the project in place of phrases like "the adult paper", which become ambiguous when several adult or child EEG papers are in circulation.

| Code name | Paper | Order |
|---|---|---|
| Meredith | The adult paper | First |
| Bolton | The child and development paper | Second |
| Hayden | The methodological paper | Third |

The papers are written in that order, one after another and not at the same time.
The names stand unless different names turn out to have been assigned elsewhere already, in which case this section is revised.

### Meredith, the adult paper

Meredith uses the adult data only and does not mention the children's data.
Its question is what the neural signatures of the approximate number system are.
Every research question under that heading is addressed with multilevel nonlinear regression.
The method is a major strength of the paper and is presented in full detail, but it is the method and not the subject.
A paper that uses linear mixed-effects models is not a paper about linear mixed-effects models, and the same holds here.

The research questions come from the open questions in the BPS Cognitive Section 2026 talk (`reports/presentations/bps-cog-2026/slides.qmd`, the "Open Questions" slide).

- What is the pattern, and where is it?
  Is there a P1, N1 and P2p complex, as others have reported, can it be established with hard, independent evidence, and at which scalp electrodes is it concentrated?
- How much does it vary?
  A pattern in an average may be an artefact of averaging, and averaging may also conceal patterns that are present.
  The paper should show that the signatures occur trial by trial, and how they vary across trials, stimuli and individuals.
  This is why the model must be multilevel and nonlinear.
- Individual differences.
  How do individual differences in the whole waveform, not only P2p amplitude, relate to behavioural ANS acuity?
- Stimulus properties.
  How does the waveform vary with stimulus properties, numerical ratio or difficulty above all, but others too?

The last two open questions on that slide, on developmental trajectory and atypical numerical development, are not addressed in Meredith.
Further questions will arise as the work proceeds.
A working title is "The Neural Signatures of Numerical Processing: An Investigation Using Multilevel Non-Linear Regression", or something along those lines.

### Bolton, the child and development paper

Bolton asks the same questions as Meredith of the children's data, and also compares children with adults.
The comparison is one statistical analysis of both datasets together, not a child analysis and an adult analysis set side by side.
So the paper is both a replication of the adult analysis in children and a developmental comparison.
Age as a continuum would be ideal, but there is probably too little data for that.
At the least, younger children can be compared with adults, and possibly younger children, older children and adults.
That is not yet known.
It uses multilevel nonlinear regression throughout.

### Hayden, the methodological paper

Hayden is a purely methodological paper on how to analyse ERPs with multilevel nonlinear regression, which we expect to mean multilevel Gaussian processes.
Multilevel Gaussian processes are rare in psychology and neuroscience, and rarer still for ERPs, which is the point of the paper.

The motivation is as follows.
An ERP waveform is plainly a nonlinear function of time.
It varies between trials and between subjects, and it changes with stimulus properties and individual characteristics.
The noise is not independent normal noise around a line, since it is autocorrelated in time.
Given both facts, the question is how to do the equivalent of multilevel linear regression, which everyone knows, for data of this kind.
The answer is multilevel Gaussian processes.

The method has so far been developed with finite radial basis functions (`analysis/rbf_stan/`).
That works, but it has become overly complicated, and a Gaussian process version should be simpler to work with in practice and do a better job.

The paper illustrates the method on one to three datasets.
These should have well-established and uncontroversial research questions and ERP responses, so that attention stays on the method and not on the validity of a paradigm.
Open data are strongly preferred.
Which datasets is not yet decided.
The current inclination is not to use the Purple dots data in Hayden at all, so that the paper is not distracted by the specifics of the ANS task.
Hayden is nevertheless a product of this project, of its methods and not of its findings.

## Data and code provenance

The behavioural data is from a PsychoPy based approximate number system experiment available in the GitHub repo `mark-andrews/adak`, version `0.1-0-g7310f94` (i.e. tag 0.1; short commit hash 7310f94).
The raw data are the EEG recordings (`.bdf` files) and the behavioural data (`.json` files), one pair per session.
They are not in this repository, because they are too large for it.
They are kept in a separate directory with one subdirectory per sample, `main` for the adults and `child` for the children.
For now that directory is local, in a sibling project, `../purple-raw-data/data`.
It will eventually be released through a public data repository.
The pipeline finds it through `raw_data_dir` in `config.yaml`, so anyone reproducing the analysis downloads the raw data, puts it anywhere, and sets that one path.

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

Set `raw_data_dir` in `config.yaml` to the location of the raw data (see above), then run the pipeline:

```bash
snakemake -j4 --sdm apptainer --apptainer-args "--bind /path/to/raw/data"
```

The bind is needed because Apptainer only sees the working directory and the home directory by default, and the raw data is outside both.
The path can also be given on the command line, with `--config raw_data_dir=/path/to/raw/data`.
Snakemake itself runs on the host, not in the container, and can be installed with `pipx install snakemake`.

Running time for the adult data: around 2.5 hours (measured on 23 November, 2024; container overhead is minor).
The pipeline processes two samples, the adults (`main`) and the children (`child`), each into its own directory, `data/main` and `data/child`.
Each gets the combined behavioural data (`combined_behaviour_data.csv`), the EEG epochs joined to it, one row per EEG timepoint per trial (`merged_eeg_behaviour_data.parquet`), and the same with anomalous channel and trial combinations masked (`merged_eeg_behaviour_data_masked.parquet`), which is what the analyses read.
One sample can be built on its own by naming its target, for example `snakemake ... data/child/merged_eeg_behaviour_data_masked.parquet`.
The child data uses its own copies of the EEG preprocessing and merge scripts (`scripts/*_child.*`), for now.

The rules were rewritten in September 2026, after the adult data had been built, so Snakemake would rebuild the adult data because the rule code changed.
Adding `--rerun-triggers=mtime` (with the `=`, or the option takes the targets that follow as its values) makes it judge only by file times, and then the existing adult files count as up to date.

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
