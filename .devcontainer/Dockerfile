FROM debian:trixie-slim

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

RUN set -e && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        locales \
        wget \
        git \
        curl \
        sudo \
        pkg-config \
        build-essential \
        gfortran \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libuv1-dev \
        libfontconfig-dev \
        libfreetype-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libpng-dev \
        libtiff-dev \
        libjpeg-dev \
        python3 \
        python3-pip \
        python-is-python3 && \
    # Add the CRAN apt repository so we get a current R release rather than
    # Debian's older packaged one (per cran.r-project.org/bin/linux/debian/),
    # matching container/purple.def.
    gpg --keyserver keyserver.ubuntu.com \
        --recv-key '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7' && \
    gpg --armor --export '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7' \
        > /etc/apt/trusted.gpg.d/cran_debian_key.asc && \
    printf '%s\n' \
        'Types: deb' \
        'URIs: https://cloud.r-project.org/bin/linux/debian/' \
        'Suites: trixie-cran46/' \
        'Components:' \
        'Signed-By: /etc/apt/trusted.gpg.d/cran_debian_key.asc' \
        > /etc/apt/sources.list.d/cran.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends r-base r-base-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Positron forwards the client's LANG (en_US.UTF-8 here) into the R
    # session, but that locale isn't compiled into a slim base image, so R
    # falls back to C with a warning per category. Generate the locales
    # actually in use and set en_US.UTF-8 as the container default.
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
           -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8

# Python packages for interactive ANS/EEG analysis work.
RUN pip3 install --no-cache-dir --break-system-packages \
        mne \
        mne-icalabel \
        autoreject \
        scikit-learn \
        onnxruntime \
        numpy \
        scipy \
        pandas \
        pyarrow \
        pyhere \
        ipykernel

# R packages, same set as container/purple.def, plus devtools for
# interactive package development (load_all/install_local on rutils/).
# remotes is listed explicitly because devtools::install_local() delegates
# to remotes::install_local(), but remotes is only a Suggests of devtools
# (checked lazily via check_installed()), not a hard Imports dependency, so
# plain devtools installation wouldn't pull it in.
RUN Rscript -e 'install.packages(c("tidyverse", "argparse", "arrow", "rjson", "fs", "lubridate", "devtools", "remotes"), repos = "https://cloud.r-project.org")'

# To avoid a slow rebuild of the image every time we need a new package, we will put extra package installs here
RUN Rscript -e 'install.packages("moments", repos = "https://cloud.r-project.org")'

# TODO: dead weight, remove. This was meant to give bind-mounted files
# editable ownership without permission friction, matching the host UID,
# but rootless Podman's default UID mapping doesn't work that way (see
# devcontainer.json's remoteUser comment): only container UID 0 maps
# straight to the host user, any other UID including this one shifts into
# the subuid range instead. devcontainer.json now sets remoteUser to root,
# so this user, its sudoers entry, and the site-library chown below are all
# unused. Low priority, not broken, just clutter.
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chown -R ${USERNAME}:${USERNAME} /usr/local/lib/R/site-library && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

ENV TZ=Europe/London
USER ${USERNAME}
