#!/bin/bash

VENV=$HOME/var/venvirons/purple

if [ -d "$VENV" ]; then
  rm -rf "$VENV"
fi

python -m venv "$VENV"

source "$VENV/bin/activate"

# upgrade pip
pip install -U pip
# deal with the gcc 14 problem with datrie
# https://github.com/pytries/datrie/issues/101
export CFLAGS="-Wno-error=incompatible-pointer-types"
export CXXFLAGS="-Wno-error=incompatible-pointer-types"
pip install datrie
pip install ipympl
pip install scikit-learn
pip install torch
pip install mne-icalabel
pip install seaborn
pip install spyder-vim
pip install autoreject
pip install -r requirements.txt


########################################################
############### Installing R packages ##################
########################################################


# this is complete re-initialization
Rscript -e 'renv::deactivate(clean = TRUE)' \
        -e 'renv::init()' \
        -e 'renv::install("./rutils")' \
        -e 'renv::snapshot()'


# We shouldn't have to do this rigmarole, but it
# worked in the past. Here, for reference for now.

# TODO: this is cruft. remove
# initialize renv
#Rscript -e 'renv::deactivate(clean = TRUE)'
#Rscript -e 'renv::activate()'
## install purputils
#Rscript -e "renv::install('devtools')"
#Rscript -e "devtools::install_local('rutils')"
#Rscript -e "renv::install()"
#Rscript -e "renv::snapshot()"
