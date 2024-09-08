import pandas
from pathlib import Path
from snakemake.script import snakemake

fnames = snakemake.input
output_fname = snakemake.output[0]

EPOCH_DF = []

for fname in fnames:
    tmp_df = pandas.read_feather(fname)
    tmp_df.insert(0, "participant", Path(fname).stem.replace("_epochs", ""))

    EPOCH_DF.append(tmp_df)

EPOCHS = pandas.concat(EPOCH_DF)

EPOCHS.reset_index(drop=True).to_feather(output_fname)
