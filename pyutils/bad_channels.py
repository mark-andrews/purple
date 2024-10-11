# ---
# jupyter:
#   jupytext:
#     formats: py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.16.4
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# %%
import eegutils
import mne
import pyhere
import os
import numpy as np
import pandas
from autoreject import AutoReject

project_home = pyhere.here()

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

eeg_obj = eegutils.EEG(bdf_filepath = os.path.join(project_home, 'raw-data/main/FA_03_08_2024_10_29_31.bdf'),
             trigger_dict = trigger_dict)

eeg_obj.downsample(hz=1024)  # two sessions were recorded at 2048Hz
eeg_obj.remove_artifacts()
eeg_obj.filter(highpass=1.0, lowpass=40.0)

epochs_df = eeg_obj.get_epochs(
    lock="stimulus",
    offsets=(-200, 1000),
    re_reference=True,
    baseline_correct=True,
    test=True,
)

info = mne.create_info(
    ch_names=eeg_obj.raw.ch_names[:64], 
    ch_types = ['eeg'] * 64,
    sfreq=eeg_obj.raw.info['sfreq']
)

epochs_df_list = [epoch_df for _,epoch_df in epochs_df.groupby(['block','trial'])]

# %%
epochs_df_list_original = [epoch_df.copy() for _,epoch_df in epochs_df.groupby(['block','trial'])]

# %%
epochs_list = []
epochs_info = []
for epoch_df in epochs_df_list:
    epochs_info.append(epoch_df.loc[:,'block':'time'])
    epochs_list.append(epoch_df.loc[:,'Fp1':'O2'].values.T)

epochs = mne.EpochsArray(np.array(epochs_list), info)
epochs.set_montage('biosemi64')

ar = AutoReject()
epochs_clean, epochs_clean_log = ar.fit_transform(epochs, return_log = True) 

# %%
epochs_clean_data = epochs_clean.get_data()
kept_epochs = epochs_clean.events[:,0]
drop_epochs = epochs_clean_log.bad_epochs
dropped_epochs = np.where(drop_epochs)[0]

# drop_epochs is a boolean array with the same number of elements
# as the number of original epochs
assert len(drop_epochs) == len(epochs_df_list)

# those False elements of drop_epochs are those we keep
assert all(np.where(~drop_epochs)[0] == kept_epochs)

# we should have a list of N data frames
# and an array of length N that have their original epochs_df_list indices
assert len(epochs_clean_data) == len(kept_epochs)

# the union of dropped and kept epochs is 0, 1 ... number of original epochs
assert set(dropped_epochs).union(kept_epochs) == set(np.arange(len(epochs_df_list)))

for i,k in enumerate(kept_epochs):
    # insert the cleaned dataframe for epoch k
    # at position k of the epochs_df_list

    # the ith cleaned epoch
    cleaned_epoch_ith = pandas.DataFrame(epochs_clean_data[i].T, columns=epochs_clean.ch_names).reset_index(drop=True)  
    
    # this is the kth original epoch
    # so insert ith epoch into position k in the orignal list
    epochs_df_list[k].loc[:,epochs_clean.ch_names] = cleaned_epoch_ith.values

    # Add new column to indicate that this epoch is not dropped
    epochs_df_list[k]['drop'] = False

for k in dropped_epochs:
    epochs_df_list[k]['drop'] = True

# do some further checking
drops = []
keeps = []
for i, x in enumerate(epochs_df_list):    
    is_drop = x['drop'].drop_duplicates().values
    assert len(is_drop) == 1
    
    if is_drop[0]:
        drops.append(i)
    else:
        keeps.append(i)

assert set(kept_epochs.tolist()) == set(keeps)
assert set(dropped_epochs.tolist()) == set(drops)

# %%
R = []
for epoch_df_1, epoch_df_2 in zip(epochs_df_list, epochs_df_list_original):

    A = epoch_df_1.loc[:,'Fp1':'O2'].values.flatten() 
    B = epoch_df_2.loc[:,'Fp1':'O2'].values.flatten() 

    r = np.corrcoef(A,B)[0,1].item()
    R.append(r)

R = np.array(R)

# %%
R.sort()

# %%
R.round(2)

# %%
pandas.concat(epochs_df_list)

# %%
np.corrcoef(epochs_df.loc[:,'Fp1':'O2'].values.flatten(),pandas.concat(epochs_df_list).loc[:,'Fp1':'O2'].values.flatten())

# %%
epochs_df.shape == epochs_df.shape

# %%
