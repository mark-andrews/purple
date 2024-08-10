# Code and data for a project on the neural signatures of the approximate number system.

## Overview

This project involves nonlinear regression modeling of ERP signals when people are performing an approximate number system task.

## Raw data

The behavioural data is from a PsychoPy based approximate number system experiment available in the GitHub repo `mark-andrews/adak`, version `0.1-0-g7310f94` (i.e. tage 0.1; short commit hash 7310f94).
All the behavioural data files are the json files in `raw-data`.

The EEG data are also in `raw-data`.

More information about the data to follow.

## Data analysis

The data analysis is a R and Python based.

### R package

The R based code utilities are in a bespoke project-specific R package named `rutils`, found in the `rutils/`.

This can be be installed as follows (assuming the working directory is this repo):

```bash
devtools::install_local("rutils") # install purputils package
```

### Python package

There is a Python package too. It is in `pytutils/`.

### Reading in the behavioural data

All the behavioural data can be read into R as follows:
```r
library(purputils)
behav_df <- read_behavioural_data('behavioural_data_directory')
```
