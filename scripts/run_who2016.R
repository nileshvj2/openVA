suppressPackageStartupMessages(library(openVA))

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2 || length(args) > 6) {
  stop(paste(
    "Usage: Rscript scripts/run_who2016.R <input.csv>",
    "<insilico|interva5> [output-prefix] [HIV] [Malaria] [Nsim]"
  ))
}

input_file <- args[[1]]
model <- tolower(args[[2]])
output_prefix <- if (length(args) >= 3) args[[3]] else paste0("output/who2016-", model)
hiv <- if (length(args) >= 4) args[[4]] else "h"
malaria <- if (length(args) >= 5) args[[5]] else "h"
nsim <- if (length(args) >= 6) as.integer(args[[6]]) else 10000L

if (!file.exists(input_file)) {
  stop("Input file does not exist: ", input_file)
}
if (!model %in% c("insilico", "interva5")) {
  stop("Model must be 'insilico' or 'interva5'.")
}
if (!hiv %in% c("h", "l", "v") || !malaria %in% c("h", "l", "v")) {
  stop("HIV and Malaria must be 'h', 'l', or 'v'.")
}
if (is.na(nsim) || nsim < 100) {
  stop("Nsim must be an integer of at least 100.")
}

data <- read.csv(
  input_file,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

if (model == "insilico") {
  set.seed(2026)
  fit <- codeVA(
    data,
    data.type = "WHO2016",
    model = "InSilicoVA",
    Nsim = nsim,
    auto.length = FALSE
  )
} else {
  fit <- codeVA(
    data,
    data.type = "WHO2016",
    model = "InterVA",
    version = "5",
    HIV = hiv,
    Malaria = malaria,
    write = FALSE
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