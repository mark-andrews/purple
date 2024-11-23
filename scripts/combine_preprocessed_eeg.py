import argparse
import pandas
from pathlib import Path

def main():

    parser = argparse.ArgumentParser(description="Combine all preprocessed files.")

    parser.add_argument(
        "--input",
        nargs="+",  # Accept one or more inputs
        required=True,
        help="Input feather file(s) (space-separated if multiple).",
    )

    parser.add_argument(
        "--output",
        required=True,
        help="Output file of the combined data.",
    )

    args = parser.parse_args()

    # Extract input and output
    fnames = args.input
    output_fname = args.output

    # Main logic
    EPOCH_DF = []

    for fname in fnames:
        tmp_df = pandas.read_feather(fname)
        tmp_df.insert(0, "participant", Path(fname).stem.replace("_epochs", ""))

        EPOCH_DF.append(tmp_df)

    EPOCHS = pandas.concat(EPOCH_DF)

    EPOCHS.reset_index(drop=True).to_feather(output_fname)

if __name__ == "__main__":
    main()
