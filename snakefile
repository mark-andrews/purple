import os

container: "container/purple.sif"

configfile: "config.yaml"

# The raw data lives outside the repository (see config.yaml and the
# readme), with one subdirectory per sample: main (the adults) and child.
# Apptainer only sees it if it is bound into the container, with
# --apptainer-args "--bind <raw_data_dir>".
RAW_DATA_DIR = os.path.abspath(config["raw_data_dir"])
SAMPLES = ["main", "child"]
TMP_DIR = "data/tmp"

# The behaviour, EEG preprocessing and merge scripts for each sample. The child script began as
# a copy of the adult one, so that the adult pipeline, which is known to
# work, is left untouched while the child data is got working. The two
# are to be merged into one script later.
EEG_SCRIPT = {
    "main": "scripts/preprocess_eeg.py",
    "child": "scripts/preprocess_eeg_child.py",
}
BEHAVIOUR_SCRIPT = {
    "main": "scripts/process_behaviour_raw_data.R",
    "child": "scripts/process_behaviour_raw_data_child.R",
}
MERGE_SCRIPT = {
    "main": "scripts/merge_eeg_behaviour_data.R",
    "child": "scripts/merge_eeg_behaviour_data_child.R",
}

wildcard_constraints:
    sample = "|".join(SAMPLES)

def raw_files(sample, extension):
    return glob_wildcards(f"{RAW_DATA_DIR}/{sample}/{{filename}}.{extension}").filename

rule all:
    input:
        expand("data/{sample}/merged_eeg_behaviour_data_masked.parquet", sample=SAMPLES)

rule process_behaviour_data:
    input:
        lambda wc: expand(f"{RAW_DATA_DIR}/{wc.sample}/{{filename}}.json",
                          filename=raw_files(wc.sample, "json"))
    output:
        "data/{sample}/combined_behaviour_data.csv"
    params:
        script = lambda wc: BEHAVIOUR_SCRIPT[wc.sample]
    shell:
        "Rscript {params.script} --input {input} --output {output}"

rule process_raw_eeg_data:
    input:
        RAW_DATA_DIR + "/{sample}/{filename}.bdf"
    output:
        temp(TMP_DIR + "/{sample}/{filename}_epochs.feather")
    params:
        script = lambda wc: EEG_SCRIPT[wc.sample],
        highpass = 1,
        lowpass = 30,
        fix_bad = 'yes'
    shell:
        "python {params.script} --input {input} --output {output} --fix-bad {params.fix_bad} --filter {params.highpass} {params.lowpass}"

rule combine_epoch_files:
    input:
        lambda wc: expand(TMP_DIR + f"/{wc.sample}/{{filename}}_epochs.feather",
                          filename=raw_files(wc.sample, "bdf"))
    output:
        temp("data/{sample}/all_preprocessed_epochs.feather")
    shell:
        "python scripts/combine_preprocessed_eeg.py --input {input} --output {output}"

rule merge_eeg_behaviour_data:
    input:
        "data/{sample}/combined_behaviour_data.csv",
        "data/{sample}/all_preprocessed_epochs.feather"
    output:
        "data/{sample}/merged_eeg_behaviour_data.parquet"
    params:
        script = lambda wc: MERGE_SCRIPT[wc.sample]
    shell:
        "Rscript {params.script} {input[0]} {input[1]} {output[0]}"

rule mask_anomalous_trials:
    input:
        "data/{sample}/merged_eeg_behaviour_data.parquet"
    output:
        "data/{sample}/merged_eeg_behaviour_data_masked.parquet"
    shell:
        "Rscript scripts/mask_anomalous_trials.R {input} {output}"
