# Notes

This directory is the project's wiki, a knowledge base for everything to do with this research.
It holds technical documentation of methods (the EEG system, preprocessing, modelling and analysis) and the knowledge base of the literature.
Its documents are written to be reused, for example when writing the literature review and methods of a paper, rather than being drafts of any one paper.
None of it is run by the pipeline.

## Literature

`ans-cognitive-neuroscience-literature.qmd` summarises what the literature collected so far says about the cognitive neuroscience of the approximate number system, with emphasis on EEG and ERP signatures (P1, N1, P2p and later components), the paradigms used, the continuous-magnitudes debate, individual differences and development, and measuring acuity.
It ends with implications for this project and a list of important papers not yet in the collection.
It uses plain APA-style references rather than a BibTeX file.

## Methods and technical notes

`fixed-trial-sequence.md` records that the behavioural task used a single fixed pseudo-random sequence for all participants, repeated as each block, and sets out its benefits, its costs for analysing stimulus effects such as ratio, and how those costs are dealt with in the analysis and in reporting.

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
It dates from the October 2024 Gaussian process work, and the same equivalence is discussed in `analysis/rbf_stan/models.qmd`.
