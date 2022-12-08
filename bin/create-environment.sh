#!/bin/sh

echo "Specify the environment name, or type ENTER to use xasp"
read name
if [ -z "$name" ]; then
    name="xasp"
fi

conda create --yes --name "$name" python=3.10

conda install --yes --name "$name" -c conda-forge poetry
conda install --yes --name "$name" -c conda-forge chardet
conda install --yes --name "$name" -c potassco clingo
conda update --all --yes --name "$name"
poetry install
