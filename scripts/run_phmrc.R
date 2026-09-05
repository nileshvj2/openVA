suppressPackageStartupMessages(library(openVA))

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 5 || length(args) > 7) {
  stop(paste(
    "Usage: Rscript scripts/run_phmrc.R <test.csv> <train.csv>",
    "<cause-column> <adult|child|neonate> <insilico|interva>",
    "[output-prefix] [Nsim]"
  ))
}

test_file <- args[[1]]
train_file <- args[[2]]
cause_column <- args[[3]]
phmrc_type <- tolower(args[[4]])
model <- tolower(args[[5]])
output_prefix <- if (length(args) >= 6) args[[6]] else paste0("output/phmrc-", model)
nsim <- if (length(args) >= 7) as.integer(args[[7]]) else 10000L

if (!file.exists(test_file)) {
  stop("Test file does not exist: ", test_file)
}
if (!file.exists(train_file)) {
  stop("Training file does not exist: ", train_file)
}
if (!phmrc_type %in% c("adult", "child", "neonate")) {
  stop("PHMRC type must be 'adult', 'child', or 'neonate'.")
}
if (!model %in% c("insilico", "interva")) {
  stop("Model must be 'insilico' or 'interva'.")
}
if (is.na(nsim) || nsim < 100) {
  stop("Nsim must be an integer of at least 100.")
}

test_data <- read.csv(
  test_file,
  check.names = FALSE,
  stringsAsFactors = FALSE
)
train_data <- read.csv(
  train_file,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

if (!cause_column %in% colnames(train_data)) {
  stop("Cause column was not found in the training data: ", cause_column)
}

if (model == "insilico") {
  set.seed(2026)
  fit <- codeVA(
    test_data,
    data.type = "PHMRC",
    data.train = train_data,
    causes.train = cause_column,
    phmrc.type = phmrc_type,
    model = "InSilicoVA",
    Nsim = nsim,
    auto.length = FALSE
  )
} else {
  message("PHMRC uses openVA's trained InterVA method, not standard InterVA-5.")
  fit <- codeVA(
    test_data,
    data.type = "PHMRC",
    data.train = train_data,
    causes.train = cause_column,
    phmrc.type = phmrc_type,
    model = "InterVA"
  )
}

output_directory <- dirname(output_prefix)
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)

top_causes <- getTopCOD(fit, n = 3, include.prob = TRUE)
write.csv(top_causes, paste0(output_prefix, "-top-causes.csv"), row.names = FALSE)

csmf <- getCSMF(fit)
write.csv(as.data.frame(csmf), paste0(output_prefix, "-csmf.csv"), row.names = TRUE)

individual <- getIndivProb(fit)
individual_output <- data.frame(
  ID = rownames(individual),
  individual,
  check.names = FALSE
)
write.csv(
  individual_output,
  paste0(output_prefix, "-individual.csv"),
  row.names = FALSE
)

cat("Analysis complete. Output prefix: ", output_prefix, "\n", sep = "")