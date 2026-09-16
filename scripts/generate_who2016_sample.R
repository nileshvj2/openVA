suppressPackageStartupMessages(library(openVA))

sample_data <- new.env()
data("RandomVA5", package = "InterVA5", envir = sample_data)

# RandomVA5 uses "." for missing; export the standard WHO 2016 "-" encoding.
data <- ConvertData(
  sample_data$RandomVA5,
  yesLabel = "y",
  noLabel = "n",
  missLabel = ".",
  data.type = "WHO2016"
)
data[[1]] <- as.character(data[[1]])

stopifnot(
  identical(names(data), names(sample_data$RandomVA5)),
  identical(data[[1]], as.character(sample_data$RandomVA5[[1]])),
  !anyNA(data),
  !anyDuplicated(data[[1]]),
  all(unlist(data[-1], use.names = FALSE) %in% c("y", "n", "-"))
)

dir.create("input", showWarnings = FALSE)
write.csv(data, "input/who2016.csv", row.names = FALSE)

saved <- read.csv(
  "input/who2016.csv",
  check.names = FALSE,
  stringsAsFactors = FALSE,
  colClasses = "character"
)
stopifnot(identical(saved, data))

cat(
  "Created input/who2016.csv: ", nrow(data), " records, ", ncol(data),
  " columns, from InterVA5 ", as.character(packageVersion("InterVA5")),
  " RandomVA5.\n", sep = ""
)
