import mne
import numpy as np
from pandas import DataFrame, concat


def read_raw_bdf(bdf_path):
    "Return mne RawEDF object that contains the bdf data"
    return mne.io.read_raw_bdf(bdf_path, preload=True, verbose=False)


def get_triggers(edf_obj, channel="Status"):
    assert channel in edf_obj.info["ch_names"]
    return edf_obj.get_data(picks=channel).flatten().astype(dtype=np.int64)

def get_data(edf_obj):
    'Assumes the data channels are named A1 ... A32 and B1 ... B32'
    data_ch_names = [ch_name for ch_name in edf_obj.ch_names if ch_name.startswith('A') or ch_name.startswith('B')]
    return DataFrame(edf_obj.get_data(picks = data_ch_names).T,
                     columns=data_ch_names)


def get_events(edf_obj, skip=True):
    """
    Return a list of tuples giving the onset time of each new trigger code.
    If `skip`, then skip all occurrences of single tic trigger events, i.e.
    a trigger event that occurs for one timepoint only, which we are going to
    assume are all anomalies.
    """

    triggers = get_triggers(edf_obj)

    events = []
    j = 0
    for i, event in enumerate(triggers):
        j += 1
        if i == 0:
            events.append((i, event))
        if i > 0:
            if event != triggers[i - 1]:
                events.append((i, event))
                j = 0

    if skip:
        for i in range(len(events) - 1):
            event_tic, _ = events[i]

            next_event_tic, _ = events[i + 1]

            if event_tic == next_event_tic - 1:
                # next event is exactly one tic later
                # mark for skipping
                events[i] = events[i] + ("skip",)

    return DataFrame(
        list(
            filter(lambda event: not (len(event) == 3 and event[2] == "skip"), events)
        ),
        columns=["tic", "trigger"],
    )


def get_epoch_info(edf_obj, trigger_dict):

    events = get_events(edf_obj)

    INSIDE_BLOCK = False

    block_starts = []
    block_ends = []

    for i, event in events.iterrows():
        event_start_tic, event_code = event

        if not INSIDE_BLOCK and event_code == trigger_dict["start_block"]:
            INSIDE_BLOCK = True
            block_starts.append(i)

        if INSIDE_BLOCK and event_code == trigger_dict["end_block"]:
            INSIDE_BLOCK = False
            block_ends.append(i)

    # Checks:
    # We should be outside a block now that we are at the end of the events
    assert not INSIDE_BLOCK
    # We should have the same number of tics for block starts and block ends.
    assert len(block_starts) == len(block_ends)
    # The start tic should be before the end tic
    assert all([(start < end) for start, end in zip(block_starts, block_ends)])

    blocks = [
        events.iloc[start : (end + 1)].reset_index(drop=True)
        for start, end in zip(block_starts, block_ends)
    ]

    # convenience function:
    # return the trigger code corresponding to some labels
    trigger_codes = lambda S: [trigger_dict[s] for s in S]
    
    trials = []
    for j, block in enumerate(blocks):

        # Check if there is one and only one start block trigger
        assert sum(block["trigger"] == trigger_dict["start_block"]) == 1
        # and one and only one end block trigger
        assert sum(block["trigger"] == trigger_dict["end_block"]) == 1


        k = 0 # trial counter
        for i, event in block.iterrows():
            # Check: Trigger code should be either:
            #   start or end block
            #   start dot or blob
            #   left, right or no response
            assert event["trigger"] in trigger_codes(
                "start_block end_block start_dot_trial start_blob_trial left_response right_response no_response".split()
            )

            if event["trigger"] in trigger_codes(
                "start_dot_trial start_blob_trial".split()
            ):
                
                k += 1 # increment trial counter
                response_event = block.iloc[i + 1]
                
                # Check: If it is dot/blob start, the *very next* trial should be a response
                assert response_event["trigger"] in trigger_codes(
                    "left_response right_response no_response".split()
                )

                if event["trigger"] == trigger_dict["start_dot_trial"]:
                    stimulus = "dots"
                elif event["trigger"] == trigger_dict["start_blob_trial"]:
                    stimulus = "blobs"
                else:
                    # Should not happen
                    raise Exception("Unrecognized stimulus", event)
                stimulus_tic = event["tic"]

                
                if response_event["trigger"] == trigger_dict["left_response"]:
                    response = "left"
                elif response_event["trigger"] == trigger_dict["right_response"]:
                    response = "right"
                elif response_event["trigger"] == trigger_dict["no_response"]:
                    response = None
                else:
                    # Should not happen
                    raise Exception("Unrecognized response", response_event)
                response_tic = response_event["tic"]

                trials.append([j+1, k, stimulus, response, stimulus_tic, response_tic])
                          

    return DataFrame(trials, columns=["block", "trial", "stimulus", "response", "stimulus_tic", "response_tic"])


def get_epoch_data(edf_obj, epoch_info, ch_names, epoch_lock = 'stimulus_onset', epoch_interval = (-100, 1000), sampling_freq = 1024):

    tic_duration = 1/sampling_freq
    start_tic = round(sampling_freq / 1000 * epoch_interval[0])
    end_tic = round(sampling_freq / 1000 * epoch_interval[1])
    tic_offsets = np.array(range(start_tic, end_tic + 1))

    # we may eventually loop over multiple files
    # for bdf_pathname in bdf_pathnames:

    # maybe we will pass in the edf_obj instead in the future
    #edf_obj = read_raw_bdf(bdf_pathname)

    # and maybe we should pass the `trial_info` in too 
    #events = get_events(edf_obj)
    #trial_info = get_trial_info_from_events(events, trigger_dict)

    # ===== Pre-processing steps should go here ======
    # 
    # 
    # 
    # ================================================
    
    eeg_data = edf_obj.get_data(picks = ch_names)

    if epoch_lock == 'stimulus_onset':
        onsets = epoch_info.stimulus_tic
    elif epoch_lock == 'response_onset':
        onsets = epoch_info.response_tic

    tmp_df_list = []
    for tic_offset in tic_offsets:

        tmp_df = concat(
            [
                epoch_info.loc[:, ['block','trial','stimulus','response']],
                DataFrame(eeg_data[:, onsets + tic_offset].T, columns = ch_names)
            ],
            axis = 1
        )

        tmp_df['time'] = round(tic_offset * tic_duration * 1000) # tic in milliseconds
        tmp_df_list.append(tmp_df)

    tmp_df_stacked = concat(tmp_df_list, axis = 0)
    colnames = tmp_df_stacked.columns.tolist()
    colnames.remove('time')
    colnames.insert(2, 'time')

    return tmp_df_stacked[colnames]
