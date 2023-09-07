import eegutils
import os
import numpy as np
import pandas 
import importlib
import matplotlib.pyplot as plt

trigger_dict = dict(start_experiment = 20,
                    end_experiment = 24,
                    start_block = 4,
                    end_block = 5,
                    show_instructions = 6,
                    start_dot_trial = 8,
                    start_blob_trial = 10,
                    left_response = 12,
                    right_response = 14,
                    no_response = 18)

# +
RAW_DATA_DIR = '../raw-data/aug_sept_2023/'

basenames = '''TA__08_29_2023_14_16_18_results.bdf
ThA__08_24_2023_12_13_47_results.bdf
ThB__08_24_2023_14_08_22_results.bdf
WA__08_23_2023_09_39_23_results.bdf
WB__08_23_2023_12_39_15_results.bdf
WC__08_23_2023_14_48_19_results.bdf'''.split()

# +
bdf_filename = os.path.join(RAW_DATA_DIR, basenames[0])                           

edf_obj = eegutils.read_raw_bdf(bdf_filename)

# bandpass
#edf_obj.filter(1, 40, verbose = False)

# re-reference
#edf_obj = edf_obj.set_eeg_reference(ref_channels='average', verbose = False)
# -

# events = eegutils.get_events(edf_obj)
# trial_info = eegutils.get_trial_info_from_events(events, trigger_dict)
ch_names = edf_obj.ch_names[:64]
# eeg_data = edf_obj.get_data(picks = ch_names)
# I = trial_info.stimulus_tic.values
# xx = np.stack([eeg_data[:, I+i] for i in range(1024)], axis = 0)
# xxm = xx.mean(axis = 2)
# j = -1

# +
#importlib.reload(eegutils);
# -

tmp_df_list = []
for basename in basenames:
    
    bdf_filename = os.path.join(RAW_DATA_DIR, basename)
    edf_obj = eegutils.read_raw_bdf(bdf_filename)
    edf_obj.filter(1, 40, verbose = False)
    epoch_info = eegutils.get_epoch_info(edf_obj, trigger_dict)

    tmp_df = eegutils.get_epoch_data(edf_obj, epoch_info, ch_names)
    tmp_df['subject'] = basename.replace('_results.bdf', '')
    tmp_df_list.append(tmp_df)

x = pandas.concat(tmp_df_list, axis = 0)

x.to_feather('epochs_7_sept.feather')


