INPUT_DIR = "raw-data/main"
OUTPUT_DIR = "data/main"
TMP_DIR = "data/tmp"

eeg_input_files = glob_wildcards(INPUT_DIR + "/{filename}.bdf").filename
behaviour_input_files = glob_wildcards(INPUT_DIR + "/{filename}.json").filename

rule all:
    input:
        OUTPUT_DIR + "/merged_eeg_behaviour_data.feather"

rule process_behaviour_data:
  input:
    expand(INPUT_DIR + "/{filename}.json", filename=behaviour_input_files)
  output:
    OUTPUT_DIR + "/combined_behaviour_data.csv"
  script:
    "scripts/process_behaviour_raw_data.R"

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
    script:
        "scripts/combine_preprocessed_eeg.py"

rule merge_eeg_behaviour_data:
  input:
    OUTPUT_DIR + "/combined_behaviour_data.csv",
    OUTPUT_DIR + "/all_preprocessed_epochs.feather"
  output:
    OUTPUT_DIR + "/merged_eeg_behaviour_data.feather"
  shell:
    "Rscript scripts/merge_eeg_behaviour_data.R {input[0]} {input[1]} {output[0]}"

