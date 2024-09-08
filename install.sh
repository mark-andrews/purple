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
pip install -r requirements.txt
