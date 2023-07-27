FROM archlinux:base-20220731.0.71623

RUN sed -i 's/^\(NoExtract.*\)/#\1/g' /etc/pacman.conf

ENV TZ=Europe/London

# install the linux packages
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm \
       base-devel \
       vim \
       texlive-bin \
       texlive-core \
       texlive-bibtexextra \
       texlive-fontsextra \
       texlive-formatsextra \
       texlive-latexextra \
       texlive-pictures \
       texlive-science \
       texlive-publishers \
       texlive-pstricks \
       texlive-pictures \
       gcc-fortran \
       libgit2 \
       git \
       openblas \
       pandoc \
       pandoc-crossref \
       r \
       cmake \
       nlopt \
       tcl \
       tk 

# install extra latex fonts
RUN curl --remote-name https://www.tug.org/fonts/getnonfreefonts/install-getnonfreefonts \
    && texlua install-getnonfreefonts \
    && getnonfreefonts --sys --all

# install necessary R packages
ADD install_packages.R .
RUN Rscript ./install_packages.R

# install other packages, not recompiling tidyverse each time
ADD install_other_packages.R .
RUN Rscript ./install_other_packages.R

# install the isdsr package
ADD install_isdsr.R .
RUN Rscript ./install_isdsr.R

RUN mkdir /build
WORKDIR /build
