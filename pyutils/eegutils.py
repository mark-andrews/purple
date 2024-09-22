import mne
import numpy as np
from mne.preprocessing import ICA
from mne_icalabel import label_components
from pandas import DataFrame, concat, merge


class EEG:
    def __init__(self, bdf_filepath: str, trigger_dict: dict):
        """
        Initialize a new EDF object instance.

        Args:
            bdf_filepath (str): path to the bdf file
            trigger_dict (dict): a dictionary of trigger labels
        """
        self.raw = mne.io.read_raw_bdf(bdf_filepath, preload=True, verbose=False)

        # The channels originally are named A1, A2 ... A32, B1,
        # B2 ... B32. Rename to 10/20 system: Fp1, AF7, etc.

        def mknames(prefix="A", K=32):
            return [prefix + str(k + 1) for k in range(K)]

        # Here, we are assuming the EEG channels will always be
        # A1, A2, ... A32, B1, B2 ... B32
        original_channel_names = mknames("A", 32) + mknames("B", 32)

        self.montage = mne.channels.make_standard_montage("biosemi64")

        self.raw.rename_channels(
            mapping=dict(zip(original_channel_names, self.montage.ch_names))
        )
        # having renamed channels, set montage
        self.raw.set_montage("biosemi64", on_missing="ignore")

        # the names of the EEG channels using new naming scheme
        self.ch_names = self.montage.ch_names

        self.trigger_dict = trigger_dict

        self.trigger_channel = "Status"

    @property
    def sampling_freq(self):
        return int(self.raw.info["sfreq"])

    @property
    def tic_duration(self):
        """
        Return the duration of an EEG sample (tic) in milliseconds?
        """
        return 1000 / self.sampling_freq

    def downsample(self, hz=1024):
        "If sampling freq is > `hz`, then downsample to hz"
        if self.sampling_freq > hz:
            self.raw.resample(sfreq=hz, npad="auto")

    def milliseconds_to_samples(self, ms):
        """
        Return the number of EEG samples in a specified number of milliseconds.
        """
        return int(np.ceil(ms * self.sampling_freq / 1000))

    def get_trigger_array(self):
        "Return trigger channel as a one-dimensional numpy integer array"
        assert self.trigger_channel in self.raw.info["ch_names"]

        return (
            self.raw.get_data(picks=self.trigger_channel)
            .flatten()
            .astype(dtype=np.int64)
        )

    def get_events(self):
        """
        Return a list of tuples giving the onset time of each new trigger code.

        We set `skip` to True. Then we skip all occurrences of single tic trigger events, i.e.
        a trigger event that occurs for one timepoint only, which we are going to
        assume are all anomalies.
        """

        trigger_array = self.get_trigger_array()

        skip = True  # could be added as an object initialization argument

        events = []
        j = 0
        for i, event in enumerate(trigger_array):
            j += 1
            if i == 0:
                events.append((i, event))
            if i > 0:
                if event != trigger_array[i - 1]:
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
                filter(
                    lambda event: not (len(event) == 3 and event[2] == "skip"), events
                )
            ),
            columns=["tic", "trigger"],
        )

    # should this be renamed `get_epoch_info`?
    def get_epoch_tics(self):
        """
        For each trial in each block, give the tic of each stimulus
        onset and each response.
        """

        events = self.get_events()

        INSIDE_BLOCK = False

        block_starts = []
        block_ends = []

        for i, event in events.iterrows():
            event_start_tic, event_code = event

            if not INSIDE_BLOCK and event_code == self.trigger_dict["start_block"]:
                INSIDE_BLOCK = True
                block_starts.append(i)

            if INSIDE_BLOCK and event_code == self.trigger_dict["end_block"]:
                INSIDE_BLOCK = False
                block_ends.append(i)

        # Checks:
        # We should be outside a block now that we are at the end of the events
        assert not INSIDE_BLOCK
        # We should have the same number of tics for block starts and block ends.
        assert len(block_starts) == len(block_ends)
        # The start tic should be before the end tic
        assert all([(start < end) for start, end in zip(block_starts, block_ends)])

        # a list of data frames, each one corresponding to an experiment block
        blocks = [
            events.iloc[start : (end + 1)].reset_index(drop=True)
            for start, end in zip(block_starts, block_ends)
        ]

        # convenience function:
        # return the trigger code corresponding to some labels
        def trigger_codes(S):
            return [self.trigger_dict[s] for s in S]

        trials = []
        for j, block in enumerate(blocks):
            # Check if there is one and only one start block trigger
            assert sum(block["trigger"] == self.trigger_dict["start_block"]) == 1
            # and one and only one end block trigger
            assert sum(block["trigger"] == self.trigger_dict["end_block"]) == 1

            k = 0  # trial counter
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
                    k += 1  # increment trial counter
                    response_event = block.iloc[i + 1]

                    # Check: If it is dot/blob start, the *very next* trial should be a response
                    assert response_event["trigger"] in trigger_codes(
                        "left_response right_response no_response".split()
                    )

                    if event["trigger"] == self.trigger_dict["start_dot_trial"]:
                        stimulus = "dots"
                    elif event["trigger"] == self.trigger_dict["start_blob_trial"]:
                        stimulus = "blobs"
                    else:
                        # Should not happen
                        raise Exception("Unrecognized stimulus", event)
                    stimulus_tic = event["tic"]

                    if response_event["trigger"] == self.trigger_dict["left_response"]:
                        response = "left"
                    elif (
                        response_event["trigger"] == self.trigger_dict["right_response"]
                    ):
                        response = "right"
                    elif response_event["trigger"] == self.trigger_dict["no_response"]:
                        response = None
                    else:
                        # Should not happen
                        raise Exception("Unrecognized response", response_event)
                    response_tic = response_event["tic"]

                    trials.append(
                        [j + 1, k, stimulus, response, stimulus_tic, response_tic]
                    )

        return DataFrame(
            trials,
            columns=[
                "block",
                "trial",
                "stimulus",
                "response",
                "stimulus_tic",
                "response_tic",
            ],
        )

    def get_epochs(
        self,
        lock="stimulus",
        offsets=(-200, 1000),
        re_reference=True,
        baseline_correct=True,
        test=False,
    ):
        """
        Note that here, because we are using are to_data_frame, we get
        back the EEG voltage data in microvolts.
        """

        # ========================== local utilities ======================================

        def apply_baseline_correction(X):
            channel_baseline_averages = (
                X.query("time <= 0")
                .drop(["stimulus", "response", "time", "uindex", "utime"], axis=1)
                .groupby(["block", "trial"])
                .mean()
                .reset_index()
                .melt(
                    id_vars=["block", "trial"],
                    var_name="channel",
                    value_name="baseline_average",
                )
            )

            X_pivot = X.melt(
                id_vars=[
                    "block",
                    "trial",
                    "time",
                    "stimulus",
                    "response",
                    "uindex",
                    "utime",
                ],
                var_name="channel",
                value_name="value",
            )

            y = (
                merge(
                    X_pivot,
                    channel_baseline_averages,
                    how="inner",
                    on=["block", "trial", "channel"],
                )
                .assign(value=lambda _: _["value"] - _["baseline_average"])
                .drop(["baseline_average"], axis=1)
            )

            z = y.pivot(
                index=[
                    "block",
                    "trial",
                    "time",
                    "stimulus",
                    "response",
                    "uindex",
                    "utime",
                ],
                columns="channel",
                values="value",
            ).reset_index()

            # reorder
            return z[X.columns]

        def bind_xy(X, Y):
            """
            This function is just to make the code below more readable.
            It binds X, a series, with Y a data frame.
            It drops some elements from X and then recycles it.
            """

            # X is a series
            # drop some variables
            X = X.drop(["stimulus_tic", "response_tic"])

            k = len(Y)

            # create a data frame with k rows with that series as each row
            # remove the index too
            X = DataFrame([X] * k).reset_index(drop=True)

            # reset the index of Y and rename it
            Y = Y.reset_index().rename(columns={"index": "uindex"})

            return concat((X, Y), axis=1)

        def test_get_epochs(epoch_df, eeg_df, epoch_info):
            """
            This tests whether the epoch data is correct.
            It is relatively time-consuming.
            """

            # Test 1:
            # -------
            # In the epoch data, there is a 'uindex'.
            # If we use this to select rows in the EEG data frame, the two data frames should be indentical.
            eeg_df_indexed = eeg_df.iloc[epoch_df.uindex, :]
            # for comparison purposes with eeg_df rename utime as time
            # this requires dropping the original `time`
            # and select cols `time` to `O2`
            epoch_df2 = (
                epoch_df.drop("time", axis=1)
                .rename(columns={"utime": "time"})
                .loc[:, "time":"O2"]
            )

            assert eeg_df_indexed.reset_index(drop=True).equals(
                epoch_df2.reset_index(drop=True)
            )

            # Test 2:
            # -------
            # in the epoch_df data, for each trial in each block, there should be a perfect
            # correlation between `time` and `utime`
            assert (
                epoch_df.groupby(["block", "trial"])
                .apply(lambda x: x["utime"].corr(x["time"]), include_groups=False)
                .reset_index(name="correlation")["correlation"]
                .values.all()
            )

            # Test 3:
            # -------
            # in the epoch_df data, for each trial and block, the difference between utime in milliseconds
            # and time should be a constant
            assert (
                epoch_df.groupby(["block", "trial"])
                .apply(
                    lambda x: len(np.unique(x["utime"] * 1000 - x["time"])) == 1,
                    include_groups=False,
                )
                .reset_index(name="len")["len"]
                .values.all()
            )

            # Test 4:
            # -------
            # and that constant (above test) should be exactly the value of utime when
            # time is zero
            y = (
                epoch_df.groupby(["block", "trial"])
                .apply(
                    lambda x: np.unique(x["utime"] * 1000 - x["time"])[0],
                    include_groups=False,
                )
                .values
            )

            assert all((epoch_df.query("time == 0")["utime"] * 1000).values == y)

            # Test 5:
            # -------
            # Epoch time at zero is the stimulus onset time
            # the row indices of the EEG data when the stimulus occurred is
            # as follows:
            zero_idx = epoch_info["stimulus_tic"].values

            # the time in EEG data, which is utime in epoch data,
            # when those stimuli onset should be the constant `x`
            # above, which is the onset time (utime) of the stimulus
            assert all(
                (epoch_df.query("time == 0")["utime"] * 1000).values
                == 1000 * eeg_df.iloc[zero_idx, :]["time"].values
            )

            print("Epoch dataframe tests passed.")

        def test_baseline_correction(corrected_epoch_df, uncorrected_epoch_df):
            """
            Test whether the baseline corrected epochs are correct.
            """

            def is_correlated(df_1, df_2):
                """
                For all the columns in df_2 that are in df_1, are they
                perfectly correlated.
                """
                correlations = []

                for col in df_1.columns:
                    if col in df_2.columns:
                        correlations.append(
                            df_1[col]
                            .reset_index(drop=True)
                            .corr(df_2[col].reset_index(drop=True))
                        )

                return np.allclose(1, correlations)

            def is_baseline_zero(df):
                """
                Is each column in each sub-df, after df is grouped, zero mean?
                """
                return (
                    (
                        df.query("time <= 0")
                        .drop(
                            ["stimulus", "response", "time", "uindex", "utime"], axis=1
                        )
                        .groupby(["block", "trial"])
                        .agg(lambda x: np.isclose(0, np.mean(x)))
                        .reset_index()
                        .loc[:, "Fp1":"O2"]
                    )
                    .all()
                    .all()
                )

            def groupby_block_trial_list(df):
                """
                Group the epochs by block and trial.
                Return as list of data frames, selecting only EEG channels
                """
                return [
                    sub_df.loc[:, "Fp1":"O2"]
                    for _, sub_df in (
                        df.drop(
                            ["stimulus", "response", "time", "uindex", "utime"], axis=1
                        ).groupby(["block", "trial"])
                    )
                ]

            # Test 1
            # ------
            # The corrected epoch df should have zero mean for times below zero
            assert is_baseline_zero(corrected_epoch_df)

            # Test 2
            # ------
            # For each sub dataframe in the by block+trial nested epoch dfs,
            # is there a perfect correlation between the baseline corrected
            # and uncorrected epoch df?
            assert all(
                [
                    is_correlated(sub_df1, sub_df2)
                    for sub_df1, sub_df2 in zip(
                        groupby_block_trial_list(corrected_epoch_df),
                        groupby_block_trial_list(uncorrected_epoch_df),
                    )
                ]
            )

            print("Baseline correction tests passed.")

        # =============================================================================

        epoch_info = self.get_epoch_tics()
        EEG_df = self.raw.to_data_frame(picks=self.ch_names)

        if re_reference:
            # subtract rowwise average of EEG channels from all channels
            channel_cols = self.ch_names
            rowwise_average = EEG_df[channel_cols].mean(axis=1)
            EEG_df[channel_cols] = EEG_df[channel_cols].sub(rowwise_average, axis=0)

            if test:
                assert np.allclose(0, EEG_df[channel_cols].mean(axis=1))
                print("Re-reference to average test passed.")

        Epochs = []
        for _, epoch_info_row in epoch_info.iterrows():
            if lock == "response":
                raise NotImplementedError()

            # lock == 'stimulus' is assumed
            start_tic = epoch_info_row["stimulus_tic"]
            start_time = EEG_df["time"][start_tic]

            i, j = (
                start_tic + self.milliseconds_to_samples(offset) for offset in offsets
            )

            # utime is the time, in seconds, since the beginning of the experiment
            # u for universal
            # time is epoch time in milliseconds
            EEG_epoch_df = (
                EEG_df.iloc[(i - 1) : (j + 1), :]
                .rename(columns={"time": "utime"})
                .assign(time=lambda _: 1000 * (_["utime"] - start_time))
            )

            # this is how to `relocate` in pandas
            time_var = EEG_epoch_df.pop("time")
            EEG_epoch_df.insert(1, time_var.name, time_var)

            Epochs.append(bind_xy(epoch_info_row, EEG_epoch_df))

        epoch_df = concat(Epochs, axis=0)

        if test:
            # these test will fail if lock == 'response'
            test_get_epochs(epoch_df, EEG_df, epoch_info)

        if not baseline_correct:
            return epoch_df
        else:
            epoch_df_corrected = apply_baseline_correction(epoch_df)
            if test:
                test_baseline_correction(epoch_df_corrected, epoch_df)

            return epoch_df_corrected

    def remove_artifacts(self, K=20):
        # copy the raw data, filter it
        filt_raw = self.raw.copy().filter(l_freq=1.0, h_freq=100.0, verbose=False)

        # re-reference the copy to average
        # TODO: Do we trust this?
        filt_raw = filt_raw.set_eeg_reference("average", verbose=False)

        ica = ICA(
            n_components=None,
            method="infomax",
            max_iter="auto",
            fit_params=dict(extended=True),
        )
        ica.fit(filt_raw, picks=self.ch_names)

        # Use Iclabel

        # Pion-Tonachini, L., Kreutz-Delgado, K., & Makeig, S. (2019).
        # ICLabel: An automated electroencephalographic independent component classifier, dataset, and website.
        # NeuroImage, 198, 181–197.
        # https://doi.org/10.1016/j.neuroimage.2019.05.026

        # See https://mne.tools/mne-icalabel/dev/generated/examples/00_iclabel.html

        ica_labels = label_components(filt_raw, ica, method="iclabel")

        exclude_idx = [
            idx
            for idx, label in enumerate(ica_labels["labels"])
            if label not in ["brain", "other"]
        ]
        exclu_labels = [ica_labels["labels"][i] for i in exclude_idx]
        print(
            f"Excluding ICA components {exclude_idx}, with these labels {exclu_labels}."
        )

        # reconstruct self raw data from ICA, excluding excluded channels
        ica.apply(self.raw, exclude=exclude_idx)

        return None

    def filter(self, highpass=1.0, lowpass=40.0):
        self.raw.filter(l_freq=highpass, h_freq=lowpass)
