# xyz <- arrow::read_feather('data/main/all_preprocessed_epochs.feather')
# arrow_tbl <- arrow::arrow_table(xyz)

# arrow::write_parquet(arrow_tbl, sink='foo.parquet')


# Sys.setenv("NOT_CRAN" = "true")
# install.packages("arrow")

# Sys.setenv("LIBARROW_BINARY" = FALSE)
# Sys.setenv("LIBARROW_MINIMAL" = FALSE)
# Sys.setenv("ARROW_R_DEV" = TRUE)
# install.packages("arrow", repos = c("https://apache.r-universe.dev", "https://cloud.r-project.org"))
source("https://raw.githubusercontent.com/apache/arrow/main/r/R/install-arrow.R")
# install_arrow(verbose = TRUE)
create_package_with_all_dependencies("my_arrow_pkg.tar.gz")
install.packages(
  "my_arrow_pkg.tar.gz",
  dependencies = c("Depends", "Imports", "LinkingTo")
 )
