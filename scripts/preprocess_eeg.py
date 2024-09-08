import sys
import os
import pyhere

# We need to add pyutils to path in order to import eegutils
project_home = pyhere.here()
sys.path.insert(0, os.path.abspath(os.path.join(project_home, "pyutils")))

import eegutils
from snakemake.script import snakemake

bdf_filepath = snakemake.input[0]
output_filepath = snakemake.output[0]
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

eeg_obj = eegutils.EEG(bdf_filepath=bdf_filepath, trigger_dict=trigger_dict)

eeg_obj.downsample(hz=1024)  # two sessions were recorded at 2048Hz
eeg_obj.remove_artifacts()
eeg_obj.filter(highpass=1.0, lowpass=40.0)
eeg_obj.re_reference()

epochs_df = eeg_obj.get_epochs(
    lock="stimulus", offsets=(-200, 1000), baseline_correct=True, test=True
)

epochs_df.to_feather(output_filepath)
