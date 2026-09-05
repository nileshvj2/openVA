# Running openVA in Docker

This setup keeps R, Java, `rJava`, openVA, and all R package dependencies inside
the container. The Windows host only needs Docker Desktop with its WSL2 engine.
CRAN is contacted from inside the image during the build.

## 1. Start Docker Desktop

Open Docker Desktop and wait until it reports that the engine is running. Docker
Compose is included with Docker Desktop.

## 2. Build the environment

From this repository directory:

```powershell
docker compose build
```

The first build downloads the Rocker R image, a Java JDK, system libraries, and R
packages. Later builds reuse Docker's cache unless dependency files change.

## 3. Validate the installation

Run the automated package example:

```powershell
docker compose run --rm openva Rscript docker/smoke-test.R
```

The test loads `rJava` and `openVA`, runs InSilicoVA against `RandomVA5`, and
writes its summary and plot to the local `output` directory.

For a faster installation-only check:

```powershell
docker compose run --rm openva Rscript -e "library(rJava); library(openVA); packageVersion('openVA')"
```

## 4. Use openVA

Start an interactive R console:

```powershell
docker compose run --rm openva
```

Start a shell instead:

```powershell
docker compose run --rm openva bash
```

The repository is mounted at `/workspace`. Files saved there, including files in
`output`, persist on Windows after the container exits.

Run a local script with:

```powershell
docker compose run --rm openva Rscript path/to/script.R
```

## 5. Rebuild after source changes

The image contains a source installation of the current checkout. Rebuild it
after changing package code:

```powershell
docker compose build
```

For a completely uncached rebuild:

```powershell
docker compose build --no-cache
```

## 6. Stop and clean up

Remove stopped Compose containers and the network:

```powershell
docker compose down --remove-orphans
```

Also remove the locally built image:

```powershell
docker compose down --rmi local --remove-orphans
```

No host installation of R, RStudio, Java, or CRAN packages is required.