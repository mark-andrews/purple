behaviour_df <- purputils::read_behavioural_results(snakemake@input)
readr::write_csv(behaviour_df, file=snakemake@output[[1]])

