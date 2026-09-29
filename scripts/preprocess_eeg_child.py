import sys
import os
import pyhere
import argparse

# We need to add pyutils to path in order to import eegutils
import mne
import re
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


class ChildEEG(eegutils.EEG):
    """
    eegutils.EEG with two changes needed by some child recordings.

    First, one recording (MA_08_11_2025_15_42_15) was made with a 96-channel
    configuration, adding a third, unconnected bank of electrodes, C1 to
    C32 (flat, about 1.5 uV sd against about 150 uV on A and B). Renaming
    A1 to B32 to the 10-20 labels would then clash with the raw names C1
    to C6. Any EEG channel outside the A and B banks is dropped before
    renaming.

    Second, one recording (MA_02_16_2026_10_41_10) started after the first
    block had begun, so the first block has an end-block trigger but no
    start-block trigger. eegutils numbers blocks by counting start-block
    triggers, which would label the second and third blocks of the
    behavioural data as the first and second. Blocks are therefore
    renumbered, adding the number of end-block triggers that precede the
    first start-block trigger. The trials of the partial block are
    dropped, since which trials they are cannot be read from the triggers
    alone.
    """

    def __init__(self, bdf_filepath: str, trigger_dict: dict):
        # As eegutils.EEG.__init__, except for dropping the extra banks
        # before renaming.
        self.raw = mne.io.read_raw_bdf(bdf_filepath, preload=True, verbose=False)
        extra = [ch for ch in self.raw.ch_names if re.fullmatch(r"[C-H][0-9]+", ch)]
        if extra:
            print(f"------ Dropping {len(extra)} channels outside banks A and B ------")
            self.raw.drop_channels(extra)

        def mknames(prefix="A", K=32):
            return [prefix + str(k + 1) for k in range(K)]

        original_channel_names = mknames("A", 32) + mknames("B", 32)
        self.montage = mne.channels.make_standard_montage("biosemi64")
        self.raw.rename_channels(
            mapping=dict(zip(original_channel_names, self.montage.ch_names))
        )
        self.raw.set_montage("biosemi64", on_missing="ignore")
        self.ch_names = self.montage.ch_names
        self.trigger_dict = trigger_dict
        self.trigger_channel = "Status"

    def get_epoch_tics(self):
        events = self.get_events()
        codes = events["trigger"].tolist()
        start, end = self.trigger_dict["start_block"], self.trigger_dict["end_block"]
        first_start = codes.index(start)
        offset = sum(1 for c in codes[:first_start] if c == end)
        epoch_tics = super().get_epoch_tics()
        if offset:
            print(f"------ Recording began inside a block: blocks renumbered by +{offset} ------")
            epoch_tics["block"] = epoch_tics["block"] + offset
        return epoch_tics


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

    eeg_obj = ChildEEG(bdf_filepath=args.input, trigger_dict=trigger_dict)

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
