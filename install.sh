#!/bin/bash

VENV=$HOME/var/venvirons/purple

if [ -d "$VENV" ]; then
  rm -rf "$VENV"
fi

python -m venv "$VENV"

source "$VENV/bin/activate"

# upgrade pip 
pip install -U pip
pip install -r requirements.txt
