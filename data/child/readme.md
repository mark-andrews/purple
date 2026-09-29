This directory contains the preprocessed child data, produced from the raw child data files (`child` in the raw data directory) by the Snakemake workflow.
It has the same files as `data/main`, which holds the adult data.
`combined_behaviour_data.csv` is the behavioural data from every session.
`merged_eeg_behaviour_data.parquet` is the preprocessed EEG epochs joined to the behavioural data, one row per timepoint per trial.
`merged_eeg_behaviour_data_masked.parquet` is the same with anomalous channel and trial combinations set to missing, by `scripts/mask_anomalous_trials.R`.
