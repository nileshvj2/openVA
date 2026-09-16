# How to invoke openVA from outside Docker

Run the direct Docker commands from the openVA repository directory.
For the Python notebook, start in the executor folder and follow
[Python configuration](#python-configuration); it selects the openVA repository
through its local `.env` file. The Docker Compose setup
mounts the repository at `/workspace`, so files placed in `input/` are visible to
R inside the container and files written to `output/` are visible on the host.

The `--rm` option removes the temporary container when processing finishes. It
does not remove the Docker image, input files, or output files.

## Supported combinations

`codeVA()` recognizes five input standards. Their compatibility with
InSilicoVA and the standard InterVA-5 engine is:

| Input standard | InSilicoVA | Standard InterVA-5 | Other openVA route |
| --- | --- | --- | --- |
| WHO 2016 | Supported directly | Supported directly with `version = "5"` | Not needed |
| WHO 2012 | Supported directly | Not supported | InterVA-4 with `version = "4.03"` |
| PHMRC | Supported with labeled training data | Not supported directly | Trained InterVA with labeled training data |
| Custom binary | Supported with labeled training data | Not supported directly | Trained InterVA with labeled training data |
| EAVA | Not supported | Not supported | EAVA model with `model = "EAVA"` |

Important distinctions:

- WHO 2016 is the only input standard that invokes the standard InterVA-5
    engine.
- WHO 2012 uses `Y` for present, a blank cell for absent, and `.` for missing.
- WHO 2016 uses `y` for present, `n` for absent, and `-` for missing.
- PHMRC and custom binary data require a labeled training dataset and a
    `causes.train` column name.
- PHMRC or custom data with `model = "InterVA"` use openVA's trained InterVA
    implementation, not the standard WHO 2016 InterVA-5 engine.
- EAVA input belongs to the EAVA model and cannot be passed to InSilicoVA or
    InterVA-5 through `codeVA()`.

The worked examples below remain limited to WHO 2016 and PHMRC.

## Before running

1. Start Docker Desktop and wait for **Engine running**.
2. Place input files in the repository's `input/` directory.
3. For direct Docker commands, use the repository root, where `compose.yaml`
   is located. For the notebook, use the executor folder as described below.

Create the output directory if it does not exist:

```powershell
New-Item -ItemType Directory -Force output
```

## Reusable R scripts

The reusable scripts are located in the repository's `scripts` directory:

| Input format | Script |
| --- | --- |
| WHO 2016 | `scripts/run_who2016.R` |
| PHMRC | `scripts/run_phmrc.R` |

Each script writes three CSV files using the selected output prefix:

- `<prefix>-top-causes.csv`
- `<prefix>-csmf.csv`
- `<prefix>-individual.csv`

### Run WHO 2016

The sample file [`input/who2016.csv`](../input/who2016.csv) is ready to use with
both algorithms. It contains all 200 synthetic records from
`InterVA5::RandomVA5`, with 354 columns: one unique death ID and 353 indicators.
Original IDs and column order are preserved. Values are `y` (yes), `n` (no),
and `-` (missing); the packaged sample's `.` missing markers were converted
to `-`.

To regenerate the sample from the installed InterVA5 package (overwrites the CSV):

```powershell
docker compose run --rm openva Rscript scripts/generate_who2016_sample.R
```

With InSilicoVA using the default 10,000 iterations:

```powershell
docker compose run --rm openva Rscript scripts/run_who2016.R input/who2016.csv insilico output/who2016-insilico
```

For a quick InSilicoVA smoke test using 1,000 iterations:

```powershell
docker compose run --rm openva Rscript scripts/run_who2016.R input/who2016.csv insilico output/who2016-insilico h h 1000
```

With InterVA-5:

```powershell
docker compose run --rm openva Rscript scripts/run_who2016.R input/who2016.csv interva5 output/who2016-interva5 h h
```

Both algorithms were verified to process all 200 sample records and write the
three output CSVs listed above. The 1,000-iteration InSilicoVA run reported
fully missing indicators in the source sample and non-convergence. Treat it
as a smoke test only, not a validated analysis or diagnostic-accuracy benchmark.

The optional arguments after the output prefix are HIV prevalence, malaria
prevalence, and InSilicoVA iteration count. Their defaults are `h`, `h`, and
`10000`.

Full argument order:

```text
run_who2016.R <input.csv> <insilico|interva5> [output-prefix] [HIV] [Malaria] [Nsim]
```

### Run PHMRC

With InSilicoVA:

```powershell
docker compose run --rm openva Rscript scripts/run_phmrc.R input/phmrc-test.csv input/phmrc-train.csv va55 adult insilico output/phmrc-insilico
```

With trained InterVA:

```powershell
docker compose run --rm openva Rscript scripts/run_phmrc.R input/phmrc-test.csv input/phmrc-train.csv va55 adult interva output/phmrc-trained-interva
```

The PHMRC InterVA option uses trained InterVA, not the standard InterVA-5
engine. Replace `va55` with the actual cause column and `adult` with the
appropriate PHMRC age group.

Full argument order:

```text
run_phmrc.R <test.csv> <train.csv> <cause-column> <adult|child|neonate> <insilico|interva> [output-prefix] [Nsim]
```

### Call a reusable script from Python

First complete the [Python configuration](#python-configuration) below in the
same Python session.

```python
command = [
    "docker", "compose", "run", "--rm", "openva",
    "Rscript", "scripts/run_who2016.R",
    "input/who2016.csv", "interva5", "output/who2016-interva5",
    "h", "h",
]

result = subprocess.run(
    command,
    cwd=project_directory,
    capture_output=True,
    text=True,
    check=True,
)
print(result.stdout)
```

## Invoke from PowerShell

### WHO 2016 with InSilicoVA

Expected input: WHO 2016 indicators with a unique death ID in the first column
and symptom values encoded as `y`, `n`, or `-`.

```powershell
docker compose run --rm openva Rscript -e 'library(openVA); d <- read.csv("input/who2016.csv", check.names=FALSE); fit <- codeVA(d, data.type="WHO2016", model="InSilicoVA", Nsim=10000, auto.length=FALSE); write.csv(getTopCOD(fit, n=3, include.prob=TRUE), "output/who2016-insilico.csv", row.names=FALSE)'
```

Output:

```text
output/who2016-insilico.csv
```

### WHO 2016 with InterVA-5

Choose `HIV` and `Malaria` prevalence values appropriate for the population:
`"h"` for high, `"l"` for low, or `"v"` for very low.

```powershell
docker compose run --rm openva Rscript -e 'library(openVA); d <- read.csv("input/who2016.csv", check.names=FALSE); fit <- codeVA(d, data.type="WHO2016", model="InterVA", version="5", HIV="h", Malaria="h", write=FALSE); write.csv(getTopCOD(fit, n=3, include.prob=TRUE), "output/who2016-interva5.csv", row.names=FALSE)'
```

Output:

```text
output/who2016-interva5.csv
```

### PHMRC with InSilicoVA

PHMRC processing requires:

- A test dataset
- A labeled training dataset
- The name of the cause-of-death column in the training dataset
- A `phmrc.type` of `"adult"`, `"child"`, or `"neonate"`

This example assumes the cause column is `va55` and the data is adult data:

```powershell
docker compose run --rm openva Rscript -e 'library(openVA); test <- read.csv("input/phmrc-test.csv", check.names=FALSE); train <- read.csv("input/phmrc-train.csv", check.names=FALSE); fit <- codeVA(test, data.type="PHMRC", data.train=train, causes.train="va55", phmrc.type="adult", model="InSilicoVA", Nsim=10000, auto.length=FALSE); write.csv(getTopCOD(fit, n=3, include.prob=TRUE), "output/phmrc-insilico.csv", row.names=FALSE)'
```

Output:

```text
output/phmrc-insilico.csv
```

Change `va55` to the actual cause column and `adult` to the appropriate PHMRC
age group.

### PHMRC with trained InterVA

This is available for PHMRC input but is **not the standard InterVA-5 engine**:

```powershell
docker compose run --rm openva Rscript -e 'library(openVA); test <- read.csv("input/phmrc-test.csv", check.names=FALSE); train <- read.csv("input/phmrc-train.csv", check.names=FALSE); fit <- codeVA(test, data.type="PHMRC", data.train=train, causes.train="va55", phmrc.type="adult", model="InterVA"); write.csv(getTopCOD(fit, n=3, include.prob=TRUE), "output/phmrc-trained-interva.csv", row.names=FALSE)'
```

Output:

```text
output/phmrc-trained-interva.csv
```

## Invoke from Python

Python can start the same temporary Docker container with `subprocess`. Python
does not need direct access to R, Java, or the openVA library.

### Python configuration

All Python executor configuration lives alongside the notebook in this folder:
`.env`, `.env.example`, and `requirements.txt`. The executor folder
can be moved independently; it does not assume the openVA repository is its
parent. It still requires Docker and the separate openVA repository containing
`compose.yaml`, the R scripts, and input/output directories.

Open the executor folder as your VS Code workspace and select your notebook's
Python environment. From this folder, install the executor dependency into
that same environment:

```powershell
python -m pip install -r requirements.txt
```

Copy [`.env.example`](.env.example) to `.env` in this executor folder if you
do not already have one. Replace its placeholder `OPENVA_PROJECT_DIRECTORY`
with the absolute path to your openVA repository.
The repository-root `.gitignore` excludes `.env` files at any depth.
If you move this folder to another repository, add `.env` to that repository's
ignore rules. It is also excluded from this project's Docker and R package builds.

Start Python or the notebook kernel with this executor folder as its working
directory. Configuration is read only from this folder, not from parent folders.
The notebook's first code cell loads this configuration. For standalone Python
examples, run this setup first:

```python
from pathlib import Path
import subprocess
from dotenv import dotenv_values

directory = dotenv_values(".env").get("OPENVA_PROJECT_DIRECTORY")
if not directory:
    raise ValueError("Set OPENVA_PROJECT_DIRECTORY in the executor's .env file.")

project_directory = Path(directory)
print(f"openVA project directory: {project_directory}")
```

### WHO 2016 and InterVA-5 example

After running the Python configuration above:

```python
r_code = """
library(openVA)

data <- read.csv(
    "input/who2016.csv",
    check.names = FALSE,
    stringsAsFactors = FALSE
)

fit <- codeVA(
    data,
    data.type = "WHO2016",
    model = "InterVA",
    version = "5",
    HIV = "h",
    Malaria = "h",
    write = FALSE
)

write.csv(
    getTopCOD(fit, n = 3, include.prob = TRUE),
    "output/who2016-interva5.csv",
    row.names = FALSE
)
"""

result = subprocess.run(
    [
        "docker",
        "compose",
        "run",
        "--rm",
        "openva",
        "Rscript",
        "-e",
        r_code,
    ],
    cwd=project_directory,
    capture_output=True,
    text=True,
    check=True,
)

print(result.stdout)
```

Read the output from Python:

```python
import pandas as pd

results = pd.read_csv(
    project_directory / "output" / "who2016-interva5.csv"
)
print(results.head())
```

### Changing the Python call to InSilicoVA

Replace the `codeVA()` call in `r_code` with:

```r
fit <- codeVA(
    data,
    data.type = "WHO2016",
    model = "InSilicoVA",
    Nsim = 10000,
    auto.length = FALSE
)
```

Change the output filename to avoid overwriting InterVA-5 results:

```r
"output/who2016-insilico.csv"
```

For PHMRC, read both test and training files in `r_code` and use the PHMRC
`codeVA()` arguments shown in the PowerShell example.

## Export other result types

The examples above export the three most likely causes for each death. Other
useful output types are available.

### Cause-specific mortality fractions

```r
csmf <- getCSMF(fit)
write.csv(as.data.frame(csmf), "output/csmf.csv", row.names = TRUE)
```

### Individual cause probabilities or propensities

```r
individual <- getIndivProb(fit)
individual_output <- data.frame(
    ID = rownames(individual),
    individual,
    check.names = FALSE
)
write.csv(
    individual_output,
    "output/individual-probabilities.csv",
    row.names = FALSE
)
```

## Check results and failures

List generated output from PowerShell:

```powershell
Get-ChildItem .\output
```

A successful Docker command returns exit code `0`. When Python uses
`check=True`, a failed Docker or R command raises
`subprocess.CalledProcessError`. Capture `stdout` and `stderr` to inspect R
warnings and errors:

```python
try:
    result = subprocess.run(command, check=True, capture_output=True, text=True)
except subprocess.CalledProcessError as error:
    print(error.stdout)
    print(error.stderr)
    raise
```

For occasional manual analysis, use the PowerShell commands. For integration
with a larger Python workflow, use the `subprocess` approach while continuing to
exchange input and output through the mounted repository directories.
