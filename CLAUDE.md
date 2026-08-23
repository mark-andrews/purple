# Project context for Claude

This project analyses EEG data from an Approximate Number System (ANS) experiment.
Participants judge which of two dot arrays is more numerous, and the primary analysis fits a multilevel nonlinear regression to single-trial ERP waveforms.
See `logbook.md` for the current abstract and analysis status, and `readme.md` for data provenance and how to run things.

This is a research and data analysis project, not a software project.
There is no expectation of test suites, CI pipelines, or general-purpose library design.
Judge changes by whether the analysis is faithful to the data and the statistical model, and reproducible, not by typical software engineering conventions.
Don't propose adding testing infrastructure, CI, linting setups, or similar unless asked.

## Where things are documented

`readme.md` is the operational reference: data provenance, how to run the reproducible Snakemake/Apptainer pipeline, and how to work interactively in Positron via the Podman dev container.
Keep it current whenever the pipeline or the interactive setup changes in a way a future user, most likely the project's own author returning to it later, would need to know to actually run the project.

`logbook.md` is a running scientific narrative, most recent entry first: what analysis has been done, what's planned, and why.
It is not an implementation changelog.
Tooling and infrastructure work, container setup, dependency wrangling, IDE configuration, belongs in commit messages and code comments, not the logbook, unless it materially affected the science, for example a bug that changed results.
If unsure whether something rises to that level, ask rather than adding it.

## Code layout

- `rutils/`: the R package `purputils`, installable, has `DESCRIPTION`/`NAMESPACE`.
- `pyutils/`: shared Python code (`eegutils.py`), a plain module, not an installable package.
- `scripts/`: the Snakemake pipeline's R and Python scripts.
- `analysis/`: interactive and exploratory analysis scripts, not part of the reproducible pipeline.
- `container/`: the Apptainer definition for the reproducible batch pipeline.
- `.devcontainer/`: the Podman-based Dockerfile and devcontainer.json for interactive work in Positron.
  Deliberately a separate image from `container/`, see `readme.md` for why.
- `raw-data/`: source EEG (`.bdf`) and behavioural (`.json`) data, from `mark-andrews/adak`.
- `data/`: pipeline outputs, notably `data/main/merged_eeg_behaviour_data.parquet`.
