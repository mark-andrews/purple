# Notes

Background and reference material on the EEG system, the preprocessing, and the modelling.
None of it is run by the pipeline.

`eeg_system_note.md` is a one-line record of the BioSemi cabling used, with a link to the manufacturer's pin electrode page.

`cap_map.jpeg` is a diagram of the physical 64-channel cap layout.
`Cap_coords_all.xls` gives the spherical and Cartesian coordinates of each electrode position, in sheet `64-chan`.
These coordinates are also what a future spatial model over the scalp would use.

`electrode-labels.md` explains the 64 channel labels for a reader without an EEG background.
It covers the difference between the BioSemi connector labels (`A1`-`A32`, `B1`-`B32`) and the 10-20 anatomical labels used in the merged data, the naming convention, and the scalp regions.
It confirms that the renaming in `pyutils/eegutils.py` and the coordinates in `Cap_coords_all.xls` both follow MNE's standard `biosemi64` montage.

`preprocessing-pipeline.qmd` is a methods-style description of the Snakemake pipeline, step by step, from the raw BDF and JSON files to `data/main/merged_eeg_behaviour_data.parquet`.
It was reconstructed from the code, and records the parameters actually used where they differ from the scripts' defaults.

`sanity-checks.md` sets out what to check in the merged data before trusting it for modelling, and what the results should look like if recording and preprocessing were correct.
It distinguishes a code-level channel-labelling bug, which would affect every participant identically, from a session-specific wiring or contact problem, which would affect one.

`rbf_to_gp_proof.md` shows that a radial basis function network with Gaussian weights becomes a Gaussian process as the number of basis functions goes to infinity.
It dates from the October 2024 Gaussian process work, and the same equivalence is discussed in `analysis/rbf_stan/README.md`.
