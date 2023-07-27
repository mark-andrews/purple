import mne
import numpy as np
from pandas import DataFrame

def read_raw_bdf(bdf_path):
    'Return mne RawEDF object that contains the bdf data'
    return mne.io.read_raw_bdf(bdf_path, preload=True, verbose = False)


def get_triggers(edf_obj, channel='Status'):
    assert channel in edf_obj.info['ch_names']
    return edf_obj.get_data(picks = channel).flatten().astype(dtype=np.int64)


def get_events(edf_obj, skip=True):
    '''
    Return a list of tuples giving the onset time of each new trigger code.
    If `skip`, then skip all occurrences of single tic trigger events, i.e.
    a trigger event that occurs for one timepoint only, which we are going to 
    assume are all anomalies. 
    '''

    triggers = get_triggers(edf_obj)

    events = []
    j = 0
    for i, event in enumerate(triggers):
        j += 1
        if i == 0:
            events.append((i, event))
        if i > 0:
            if event != triggers[i-1]:
                events.append((i, event))
                j = 0

    if skip:
        for i in range(len(events) - 1):
            event_tic, _ = events[i]

            next_event_tic, _ = events[i+1]

            if event_tic == next_event_tic - 1:
                # next event is exactly one tic later
                # mark for skipping
                events[i] = events[i] + ('skip',)

    return list(
        filter(lambda event: not (len(event) == 3 and event[2] == 'skip'), events)
    )


def get_trial_info_from_events(events):
    
    trials = []
    start_block = False
    block_number = 0
    for i, tic_event in enumerate(events):

        tic, event = tic_event

        if event == 0:
            start_block = True
            block_number += 1
        elif event == 10:
            start_block = False

        # if a block has started, code 2 and code 8 should be followed by code 4 or 6
        # make a big fuss otherwise
        if i + 1 < len(events) and start_block and event in (2, 8):
            assert events[i+1][1] in (4, 6), (event[i], events[i+1])

            if event == 2:
                stimulus = 'dots'
            elif event == 8:
                stimulus = 'blobs'
            else:
                stimulus = None

            if events[i+1][1] == 4:
                response = 'left'
            elif events[i+1][1] == 6:
                response = 'right'
            else:
                response = None

            trials.append([block_number,
             stimulus,
             response,
             events[i][0],
             events[i+1][0]])
            
    return DataFrame(trials, 
                     columns = ['block', 'stimulus', 'response', 'start_tic', 'stop_tic'])
        

