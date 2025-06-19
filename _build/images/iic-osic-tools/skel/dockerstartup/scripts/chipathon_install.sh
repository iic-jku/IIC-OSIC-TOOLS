#!/bin/bash
set -e  # Exit on error

# === Step 1: Basic environment setup ===
unset PYTHONPATH
unset LD_LIBRARY_PATH

# Define base directory for conda installation
BASE_DIR="$HOME/conda-env"
MINICONDA_DIR="$BASE_DIR/miniconda3"
ENV_NAME="GLdev"

export PATH="$MINICONDA_DIR/bin:$PATH"

# === Step 2: Check if environment is already set up ===
if [ -d "$MINICONDA_DIR/envs/$ENV_NAME" ]; then
    echo "Existing $ENV_NAME environment detected. Skipping setup."
else
    echo "$ENV_NAME environment not found. Starting setup..."

    # Create base directory
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR"

    # Download and install Miniconda
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-`uname -i`.sh -O miniconda.sh
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
    pip install glayout
    pip install "klayout>=0.28,<0.29"
    pip install svgutils

    echo "Setup complete!"

    chown -f -R 1000:1000 $BASE_DIR
    find $BASE_DIR -type f -exec chmod a+rw {} \; -o -type d -exec chmod a+rwx {} \;
    
fi
