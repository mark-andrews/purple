import sys
import os
import pyhere
import argparse

# We need to add pyutils to path in order to import eegutils
project_home = pyhere.here()
sys.path.insert(0, os.path.abspath(os.path.join(project_home, "pyutils")))

import eegutils
# from snakemake.script import snakemake

# bdf_filepath = snakemake.input[0]
# output_filepath = snakemake.output[0]
# +
trigger_dict = dict(
    start_experiment=20,
    end_experiment=24,
    start_block=4,
    end_block=5,
    show_instructions=6,
    start_dot_trial=8,
    start_blob_trial=10,
    left_response=12,
    right_response=14,
    no_response=18,
)


def main():
    def str_to_bool(v):
        if v.lower() in ("yes", "y"):
            return True
        elif v.lower() in ("no", "n"):
            return False
        else:
            raise argparse.ArgumentTypeError(
                "Yes/y or No/n expected (case insensitive)"
            )

    parser = argparse.ArgumentParser(description="Preprocess EEG data.")

    parser.add_argument(
        "--input", type=str, required=True, help="Path to the bdf input file"
    )
    parser.add_argument(
        "--output",
        type=str,
        required=True,
        help="Path to the preprocessed epochs output file",
    )
    parser.add_argument(
        "--fix-bad",
        type=str_to_bool,
        dest="fix_bad",
        required=True,
        help="Fix bad channels (yes or no)",
    )
    parser.add_argument(
        "--filter",
        nargs=2,
        type=int,
        default=(1, 40),
        help="Highpass and lowpass filter thresholds as two integers (default: 1 40)",
    )

    args = parser.parse_args()

    eeg_obj = eegutils.EEG(bdf_filepath=args.input, trigger_dict=trigger_dict)

    eeg_obj.downsample(hz=1024)  # two sessions were recorded at 2048Hz
    eeg_obj.remove_artifacts()
    eeg_obj.filter(highpass=args.filter[0], lowpass=args.filter[1])

    epochs_df = eeg_obj.get_epochs(
        lock="stimulus",
        offsets=(-200, 1000),
        re_reference=True,
        baseline_correct=True,
        test=True,
    )

    if args.fix_bad:
        print("------ Attempting to fix bad channels ------")
        epochs_df = eeg_obj.fix_bad_channels(epochs_df)

    epochs_df.to_feather(args.output)


if __name__ == "__main__":
    main()
