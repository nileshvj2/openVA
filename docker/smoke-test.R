suppressPackageStartupMessages({
  library(rJava)
  library(openVA)
})

cat("R version: ", R.version.string, "\n", sep = "")
cat("Java version: ", .jcall("java/lang/System", "S", "getProperty", "java.version"), "\n", sep = "")
cat("openVA version: ", as.character(packageVersion("openVA")), "\n", sep = "")

data(RandomVA5)
set.seed(2026)
fit <- codeVA(
  RandomVA5,
  data.type = "WHO2016",
  model = "InSilicoVA",
  Nsim = 1000,
  auto.length = FALSE
)

dir.create("output", showWarnings = FALSE)
capture.output(summary(fit), file = "output/smoke-test-summary.txt")
png("output/smoke-test-plot.png", width = 1200, height = 800, res = 120)
plotVA(fit)
dev.off()

cat("Smoke test passed. Results are in /workspace/output.\n")