import os

container: "container/purple.sif"

configfile: "config.yaml"

# The raw data lives outside the repository (see config.yaml and the
# readme). Apptainer only sees it if it is bound into the container, with
# --apptainer-args "--bind <raw_data_dir>".
RAW_DATA_DIR = os.path.abspath(config["raw_data_dir"])
INPUT_DIR = RAW_DATA_DIR + "/main"
OUTPUT_DIR = "data/main"
TMP_DIR = "data/tmp"

eeg_input_files = glob_wildcards(INPUT_DIR + "/{filename}.bdf").filename
behaviour_input_files = glob_wildcards(INPUT_DIR + "/{filename}.json").filename

rule all:
    input:
        OUTPUT_DIR + "/merged_eeg_behaviour_data.parquet"

rule process_behaviour_data:
  input:
    expand(INPUT_DIR + "/{filename}.json", filename=behaviour_input_files)
  output:
    OUTPUT_DIR + "/combined_behaviour_data.csv"
  shell:
    "Rscript scripts/process_behaviour_raw_data.R --input {input} --output {output}"

rule process_raw_eeg_data:
    input:
        INPUT_DIR + "/{filename}.bdf"
    output:
        temp(TMP_DIR + "/{filename}_epochs.feather")
    params:
      highpass = 1,
      lowpass = 30,
      fix_bad = 'yes'
    shell:
        "python scripts/preprocess_eeg.py --input {input} --output {output} --fix-bad {params.fix_bad} --filter {params.highpass} {params.lowpass}"

rule combine_epoch_files:
    input:
        expand(TMP_DIR + "/{filename}_epochs.feather", filename=eeg_input_files)
    output:
        temp(OUTPUT_DIR + "/all_preprocessed_epochs.feather")
    shell:
        "python scripts/combine_preprocessed_eeg.py --input {input} --output {output}"

rule merge_eeg_behaviour_data:
  input:
    OUTPUT_DIR + "/combined_behaviour_data.csv",
    OUTPUT_DIR + "/all_preprocessed_epochs.feather"
  output:
    OUTPUT_DIR + "/merged_eeg_behaviour_data.parquet"
  shell:
    "Rscript scripts/merge_eeg_behaviour_data.R {input[0]} {input[1]} {output[0]}"

