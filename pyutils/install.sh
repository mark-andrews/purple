#!/bin/bash

VENV=$HOME/var/venvirons/purple

if [ -d $VENV ]; then
	rm -rf $VENV
fi

virtualenv $VENV

source $VENV/bin/activate

pip install mne
pip install numpy
pip install scipy
pip install pandas
pip install jupyter
pip install jupytext
pip install pyarrow
