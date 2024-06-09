# Code and data for a project on the neural signatures of the approximate number system.

(extremely very brief description for now) This project involves nonlinear regression modeling of ERP signals when people are performing an approximate number system task.

## Data analysis

The data analysis is a R and Python based.

### R package

The R based code utilities are in a bespoke project-specific R package named `rutils`, found in the `rutils/`.

This can be be installed as follows (assuming the working directory is this repo):

```bash
devtools::install_local("rutils") ' install purputils package
```

### Python package

There is a Python package too. It is in `pytutils/`.

### Reading in the behavioural data

All the behavioural data can be read into R as follows:
```r
library(purputils)
behav_df <- read_behavioural_data('behavioural_data_directory')
behav_df <- read_behavioural_data('behavioural_data_directory')
```