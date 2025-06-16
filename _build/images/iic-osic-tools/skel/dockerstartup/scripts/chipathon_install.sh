#!/bin/bash
set -e  # Exit on error

# === Step 1: Basic environment setup ===
unset PYTHONPATH
unset LD_LIBRARY_PATH

# Define base directory for conda installation
BASE_DIR=$(realpath /foss/chipathon/conda-env)
MINICONDA_DIR="$BASE_DIR/miniconda3"
ENV_NAME="GLdev"

export PATH="$MINICONDA_DIR/bin:$PATH"

echo "$ENV_NAME setup..."

# Create base directory
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# Download and install Miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
bash miniconda.sh -b -p "$MINICONDA_DIR"

# Source Conda
source "$MINICONDA_DIR/etc/profile.d/conda.sh"

# Create the environment
conda create -y -n "$ENV_NAME" python=3.10

# Activate the environment
conda activate "$ENV_NAME"

# Install packages
conda install -y jupyter jupyterlab notebook nbclassic \
    jupyter_server_ydoc jupyter_server_fileid \
    numpy=1.24 matplotlib magic netgen ngspice pip \
    -c litex-hub -c conda-forge -c anaconda

# Register the kernel
python -m ipykernel install --user --name="$ENV_NAME"

# Pip packages
pip install glayout==0.0.9
pip install "klayout>=0.28,<0.29"
pip install svgutils


echo "Setup of conda env complete!"

# Patching GF180 to work with klayout.
cd /tmp
git clone https://github.com/mabrains/globalfoundries-pdk-libs-gf180mcu_fd_pr.git /tmp/globalfoundries-pdk-libs-gf180mcu_fd_pr
cp -R /tmp/globalfoundries-pdk-libs-gf180mcu_fd_pr/rules/klayout/macros/ /foss/pdks/gf180mcuD/libs.tech/klayout
chmod -R 777 /foss/pdks/gf180mcuD/libs.tech/klayout/macros
rm -rf /tmp/globalfoundries-pdk-libs-gf180mcu_fd_pr

echo "GF180 klayout libs installed"
