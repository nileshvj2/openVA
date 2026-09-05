# openVA Docker Setup Guide

This guide sets up openVA in Docker so R, Java, `rJava`, and all R packages stay isolated from the host machine.

## 1. Host prerequisites

Install the following on the new machine:

1. [Git](https://git-scm.com/downloads)
2. [Docker Desktop](https://www.docker.com/products/docker-desktop/)
3. Visual Studio Code (optional)

On Windows, configure Docker Desktop to use the WSL 2 backend. Start Docker Desktop and wait until it displays **Engine running**.

You do **not** need to install R, RStudio, Java, `rJava`, or CRAN packages on the host. They are installed inside the Docker image.

Verify Docker from PowerShell:

```powershell
docker version
docker compose version
```

Both commands should display client and server/version information without an engine connection error.

## 2. Get the project

Open PowerShell and choose a parent directory:

```powershell
cd C:\path\to\projects
git clone https://github.com/verbal-autopsy-software/openVA.git
cd openVA
```

To recreate the Docker setup exactly as configured in this checkout, ensure these project files are present:

- `Dockerfile`
- `compose.yaml`
- `.dockerignore`
- `docker/smoke-test.R`

## 3. Build the Docker image

From the openVA repository directory, run:

```powershell
docker compose build
```

The first build can take several minutes. It downloads and installs:

- R 4.5.1
- A Java JDK
- Linux system libraries
- `rJava` without its unused JRI component
- openVA dependencies from CRAN
- openVA 1.2.0 from the checked-out source

CRAN is accessed from inside Docker. Nothing from CRAN is installed directly on Windows.

A successful build creates the image:

```text
openva-local:1.2.0
```

Verify that it exists:

```powershell
docker image inspect openva-local:1.2.0
```

## 4. Start an interactive R session

Run:

```powershell
docker compose run --rm openva
```

At the R prompt, load openVA:

```r
library(openVA)
```

Exit R when finished:

```r
q()
```

Choose `n` if R asks whether to save the workspace.

The `--rm` option removes the temporary container after it exits. It does not remove the Docker image or project files.

## 5. Start a container shell

For a Linux shell inside the openVA environment, run:

```powershell
docker compose run --rm openva bash
```

The project is available inside the container at:

```text
/workspace
```

Exit the shell with:

```bash
exit
```

## 6. Rebuild after project changes

The image contains an installed copy of the checked-out openVA source. Rebuild after changing package source or dependencies:

```powershell
docker compose build
```

Use a clean, uncached rebuild only when necessary:

```powershell
docker compose build --no-cache
```

## 7. Stop and clean up

Remove stopped Compose containers and the Compose network:

```powershell
docker compose down --remove-orphans
```

Also remove the locally built image when a complete reset is needed:

```powershell
docker compose down --rmi local --remove-orphans
```

Project files and output files remain on the host.

# Input formats for InSilicoVA and InterVA-5

`codeVA()` receives an R data frame or matrix. A CSV file is a convenient way to
provide that table:

```r
va_data <- read.csv(
	"input/my-data.csv",
	check.names = FALSE,
	stringsAsFactors = FALSE
)
```

For all binary formats:

- Each row represents one death.
- The first column contains a unique death ID.
- The remaining columns contain symptom indicators.
- Test and training data must use the same symptom columns.
- WHO column names must match the applicable WHO questionnaire schema. Arbitrary
	symptom names only work with labeled custom training data.

## Supported-format summary

| Input standard | InSilicoVA | InterVA-5 | Labeled training data |
| --- | --- | --- | --- |
| WHO 2016 | Yes | Yes | Not required |
| WHO 2012 | Yes | No | Not required |
| PHMRC | Yes | Not the standard InterVA-5 engine; uses trained InterVA | Required |
| Custom binary | Yes | Not the standard InterVA-5 engine; uses trained InterVA | Required |
| EAVA | No | No | Use `model = "EAVA"` instead |

In this guide, **InterVA-5** means `data.type = "WHO2016"`,
`model = "InterVA"`, and `version = "5"`. For PHMRC or custom data,
`model = "InterVA"` routes to openVA's `interVA_train()` implementation and
returns an `interVA` object, not an `interVA5` object.

## WHO 2016 format

WHO 2016 is the common input standard for both requested models.

| Meaning | Cell value |
| --- | --- |
| Symptom present | `y` |
| Symptom absent | `n` |
| Missing or unknown | `-` |

InterVA-5 also accepts `.` as missing and changes blank symptom cells to `n`.
Using explicit `y`, `n`, and `-` values is clearer and works for both models.

Example CSV shape:

```csv
ID,i004a,i004b,i019a
death001,y,n,-
death002,n,y,n
death003,-,n,y
```

The indicator names above only illustrate the shape. A real file must contain
the WHO 2016 indicator names expected by InterVA-5. The package's bundled
`RandomVA5` dataset is the reference example:

```r
library(openVA)
data(RandomVA5)
head(RandomVA5)
```

Run InSilicoVA:

```r
fit_insilico <- codeVA(
	data = va_data,
	data.type = "WHO2016",
	model = "InSilicoVA",
	Nsim = 10000,
	auto.length = FALSE
)
```

Run InterVA-5:

```r
fit_interva5 <- codeVA(
	data = va_data,
	data.type = "WHO2016",
	model = "InterVA",
	version = "5",
	HIV = "h",
	Malaria = "h",
	write = FALSE
)
```

`HIV` and `Malaria` accept `"h"` (high), `"l"` (low), or `"v"` (very
low). Choose values appropriate for the study population.

## WHO 2012 format

WHO 2012 input can be used directly with InSilicoVA, but not InterVA-5.

| Meaning | Cell value |
| --- | --- |
| Symptom present | `Y` |
| Symptom absent | blank |
| Missing or unknown | `.` |

```r
fit_insilico <- codeVA(
	data = va_data,
	data.type = "WHO2012",
	model = "InSilicoVA",
	Nsim = 10000,
	auto.length = FALSE
)
```

Do not combine `data.type = "WHO2012"` with InterVA `version = "5"`; openVA
rejects that combination. The bundled `RandomVA1` dataset is a WHO 2012 example.

## Convert Yes/No source data

Use `ConvertData()` when the source table has labels such as `Yes`, `No`, and
`Unknown`. The first column must still contain unique IDs, and the column names
must already match the target WHO questionnaire:

```r
raw_data <- read.csv(
	"input/my-data.csv",
	check.names = FALSE,
	stringsAsFactors = FALSE
)

va_data <- ConvertData(
	raw_data,
	yesLabel = "Yes",
	noLabel = "No",
	missLabel = c("Unknown", "Don't know", "Refused"),
	data.type = "WHO2016"
)
```

## PHMRC format

Set `data.type = "PHMRC"` for standard raw PHMRC adult, child, or neonate data.
Both test data and labeled training data are required. `causes.train` identifies
the cause-of-death column in the training table.

```r
test_data <- read.csv("input/phmrc-test.csv", check.names = FALSE)
train_data <- read.csv("input/phmrc-train.csv", check.names = FALSE)

fit_insilico <- codeVA(
	data = test_data,
	data.type = "PHMRC",
	data.train = train_data,
	causes.train = "va55",
	phmrc.type = "adult",
	model = "InSilicoVA",
	Nsim = 10000,
	auto.length = FALSE
)
```

Supported `phmrc.type` values exposed by the converter are `"adult"`,
`"child"`, and `"neonate"`. The current `codeVA()` documentation still warns
that neonate support is pending, so validate neonatal results carefully.

Using `model = "InterVA"` with PHMRC data is possible with the same training
arguments, but it uses trained InterVA rather than the standard InterVA-5 engine:

```r
fit_trained_interva <- codeVA(
	data = test_data,
	data.type = "PHMRC",
	data.train = train_data,
	causes.train = "va55",
	phmrc.type = "adult",
	model = "InterVA"
)
```

## Custom binary format

Custom input allows arbitrary symptom names but requires labeled training data.
The training table contains the same ID and symptom columns plus a cause column.

Accepted symptom values are case-insensitive when validated:

| Meaning | Cell value |
| --- | --- |
| Symptom present | `Y` |
| Symptom absent | blank or `N` |
| Missing or unknown | `.` or `-` |

Example test data:

```csv
ID,fever,cough,rash
death001,Y,N,.
death002,N,Y,Y
```

Example training data:

```csv
ID,fever,cough,rash,cause
train001,Y,N,.,Malaria
train002,N,Y,N,Pneumonia
train003,Y,N,Y,Measles
```

Run InSilicoVA with custom data:

```r
test_data <- read.csv("input/custom-test.csv", check.names = FALSE)
train_data <- read.csv("input/custom-train.csv", check.names = FALSE)

fit_insilico <- codeVA(
	data = test_data,
	data.type = "customize",
	data.train = train_data,
	causes.train = "cause",
	model = "InSilicoVA",
	Nsim = 10000,
	auto.length = FALSE
)
```

Use `model = "InterVA"` with the same training arguments for trained InterVA.
This is not the standard WHO 2016 InterVA-5 engine:

```r
fit_trained_interva <- codeVA(
	data = test_data,
	data.type = "customize",
	data.train = train_data,
	causes.train = "cause",
	model = "InterVA"
)
```

# Output examples

Both models return a fitted R object. Use openVA's extraction functions instead
of reading internal object fields directly.

## Most likely causes for each death

```r
top_causes <- getTopCOD(fit, n = 3, include.prob = TRUE)
head(top_causes)
```

InSilicoVA returns columns shaped like:

```text
ID        cause1       prob1  cause2       prob2  cause3    prob3
death001  Pneumonia    0.61   Tuberculosis 0.18   Malaria   0.07
```

InterVA-5 returns `lik1`, `lik2`, and `lik3` instead of `prob1`, `prob2`, and
`prob3`:

```text
ID        cause1       lik1  cause2       lik2  cause3       lik3
death001  Pneumonia    0.70  Tuberculosis 0.18  Undetermined NA
```

These rows illustrate the output columns only. Actual causes and values depend
on the input, prevalence settings, and model run.

## Population cause fractions

Cause-specific mortality fractions (CSMFs) estimate the share of deaths due to
each cause:

```r
csmf <- getCSMF(fit)
head(csmf)
```

Typical output is a named vector for InterVA-5 or a matrix with posterior
summary columns for InSilicoVA. An InSilicoVA summary may look like:

```text
Cause                              Mean  Std.Error  Lower  Median  Upper
Other and unspecified infections  0.16      0.02   0.11    0.16   0.20
Digestive neoplasms                0.15      0.02   0.12    0.15   0.20
```

For InSilicoVA, the default `CI = 0.95` includes a 95% credible interval:

```r
csmf <- getCSMF(fit_insilico, CI = 0.95)
```

## Individual cause distribution

```r
individual_probabilities <- getIndivProb(fit)
individual_probabilities[1:3, 1:5]
```

Rows identify deaths and columns identify possible causes. InSilicoVA values are
posterior cause probabilities. InterVA-5 values are its cause propensities;
`getTopCOD()` presents the selected values as likelihood indicators.

For InSilicoVA credible intervals, pass `CI`; this returns a list containing the
mean, lower, upper, and median individual estimates:

```r
individual_with_ci <- getIndivProb(fit_insilico, CI = 0.95)
```

## Save outputs as CSV

```r
dir.create("output", showWarnings = FALSE)

top_causes <- getTopCOD(fit, n = 3, include.prob = TRUE)
write.csv(top_causes, "output/top-causes.csv", row.names = FALSE)

csmf <- getCSMF(fit)
write.csv(as.data.frame(csmf), "output/csmf.csv", row.names = TRUE)

individual_probabilities <- getIndivProb(fit)
individual_output <- data.frame(
	ID = rownames(individual_probabilities),
	individual_probabilities,
	check.names = FALSE
)
write.csv(
	individual_output,
	"output/individual-probabilities.csv",
	row.names = FALSE
)
```

For an InSilicoVA result returned with `CI`, export each list component
separately, such as `individual_with_ci$indiv.prob.lower` and
`individual_with_ci$indiv.prob.upper`.

# Running input and checking output

## Run an R script

Save an R script within the repository, for example:

```text
scripts/my-analysis.R
```

Run it from PowerShell:

```powershell
docker compose run --rm openva Rscript scripts/my-analysis.R
```

## Use local input data

Place input files under a project directory such as:

```text
input/my-data.csv
```

Because the repository is mounted at `/workspace`, the script can read the file with a relative path:

```r
data <- read.csv("input/my-data.csv")
```

Alternatively, its full container path is:

```r
data <- read.csv("/workspace/input/my-data.csv")
```

## Save and inspect output

Write generated files under `output`:

```r
dir.create("output", showWarnings = FALSE)
write.csv(results, "output/results.csv", row.names = FALSE)
capture.output(summary(fit), file = "output/model-summary.txt")
```

Files written below `/workspace` are immediately available in the repository on the host. After execution:

1. Open the local `output` directory in VS Code or File Explorer.
2. Inspect text and CSV results directly.
3. Open PNG files to inspect plots.
4. Check the terminal process exit code. Exit code `0` indicates successful script execution.

Example command that runs a script and then lists its output:

```powershell
docker compose run --rm openva Rscript scripts/my-analysis.R
Get-ChildItem .\output
```

# Smoke test and validation

## Quick environment validation

Confirm that R, Java, `rJava`, and openVA load correctly:

```powershell
docker compose run --rm openva Rscript -e "library(rJava); library(openVA); cat('R=', R.version.string, '\nJava=', rJava::.jcall('java/lang/System','S','getProperty','java.version'), '\nopenVA=', as.character(packageVersion('openVA')), '\n', sep='')"
```

The validated setup reports:

- R 4.5.1
- Java 21.0.12
- openVA 1.2.0

## Full smoke test

Run the included test:

```powershell
docker compose run --rm openva Rscript docker/smoke-test.R
```

The test:

1. Loads `rJava` and openVA.
2. Loads the included `RandomVA5` dataset.
3. Processes 200 records with the InSilicoVA model.
4. Runs 1,000 model iterations.
5. Writes a model summary and plot.

Successful output ends with:

```text
Smoke test passed. Results are in /workspace/output.
```

Inspect the generated files:

- `output/smoke-test-summary.txt`
- `output/smoke-test-plot.png`

Warnings about missing symptoms in the synthetic dataset or the deprecated ggplot2 `size` aesthetic do not indicate smoke-test failure.

## Check for leftover containers

The test uses `--rm`, so it should not leave a container behind. Confirm with:

```powershell
docker compose ps --all
```

An empty service list after the test is expected.
