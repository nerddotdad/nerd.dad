#! /bin/bash

python3 -m venv nerddadsiteenv
source nerddadsiteenv/bin/activate
pip install --upgrade pip
pip install -r docs/requirements.txt