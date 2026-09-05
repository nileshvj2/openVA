FROM rocker/r-ver:4.5.1

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENVA_USER=openva
ARG OPENVA_UID=1000

ENV JAVA_HOME=/usr/lib/jvm/default-java \
    R_LIBS_USER=/home/openva/R/library

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    default-jdk \
    git \
    libcurl4-openssl-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    libssl-dev \
    libtiff-dev \
    libxml2-dev \
    && R CMD javareconf \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid "${OPENVA_UID}" --shell /bin/bash "${OPENVA_USER}" \
    && mkdir -p "${R_LIBS_USER}" /workspace \
    && chown -R "${OPENVA_USER}:${OPENVA_USER}" "/home/${OPENVA_USER}" /workspace

# Install dependencies separately so source changes do not invalidate this layer.
COPY DESCRIPTION /tmp/openVA/DESCRIPTION
RUN Rscript -e "install.packages('rJava', repos='https://cloud.r-project.org', configure.args='--disable-jri'); stopifnot(requireNamespace('rJava', quietly=TRUE))" \
    && Rscript -e "install.packages('remotes', repos='https://cloud.r-project.org'); stopifnot(requireNamespace('remotes', quietly=TRUE))" \
    && Rscript -e "remotes::install_deps('/tmp/openVA', dependencies=NA, upgrade='never', repos='https://cloud.r-project.org')"

# InSilicoVA is an openVA import but can be skipped by dependency discovery on
# some CRAN mirror/index combinations, so verify/install it explicitly.
RUN Rscript -e "if (!requireNamespace('InSilicoVA', quietly=TRUE)) install.packages('InSilicoVA', repos='https://cloud.r-project.org')" \
    && Rscript -e "stopifnot(requireNamespace('InSilicoVA', quietly=TRUE))"

# Install the checked-out package source. The bind mount used at runtime does not
# replace the package installed in the image.
COPY . /tmp/openVA
RUN R CMD INSTALL --no-multiarch /tmp/openVA \
    && rm -rf /tmp/openVA \
    && Rscript -e "stopifnot(requireNamespace('rJava', quietly=TRUE)); stopifnot(requireNamespace('openVA', quietly=TRUE)); cat('openVA ', as.character(packageVersion('openVA')), ' installed successfully\n', sep='')"

USER ${OPENVA_USER}
WORKDIR /workspace

CMD ["R", "--no-save", "--no-restore"]