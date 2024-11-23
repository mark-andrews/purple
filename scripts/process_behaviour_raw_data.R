
library(argparse)

# Create ArgumentParser object
parser <- ArgumentParser(description = "Convert the json behavioural data files to single csv file.")

# Add arguments
parser$add_argument("--input",
                    nargs = "+",   # Accept one or more values; each one is a file
                    required = TRUE,
                    help = "adak json files")
parser$add_argument("--output",
                    required = TRUE,
                    help = "Output csv file")

# Parse arguments
args <- parser$parse_args()

# read in, process, and combine json files
behaviour_df <- purputils::read_behavioural_results(args$input)

# write to a csv file
readr::write_csv(behaviour_df, file = args$output)
