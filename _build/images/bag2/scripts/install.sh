#! /bin/bash

set -e

# shorten real git commit hashes, but don't mess with tag or branch names
REPO_COMMIT_SHORT=$(git rev-parse --quiet --short "$BAG2_REPO_COMMIT" || echo "$BAG2_REPO_COMMIT")

BAG2_INSTALL_DIR="$TOOLS/$BAG2_NAME/$REPO_COMMIT_SHORT"

mkdir -p "$TOOLS"
git clone --filter=blob:none "$BAG2_REPO_URL" "$BAG2_INSTALL_DIR"
cd "$BAG2_INSTALL_DIR" || exit 1
git checkout "$BAG2_REPO_COMMIT"

./init_submodules.sh
./pip3userinstall.sh

# create a file to be sourced in the final .bashrc
cat <<EOF > "$TOOLS/$BAG2_NAME/sourceme.sh"
export BAG_SRC_DIR="$BAG2_INSTALL_DIR"
export BAG_GENERATOR_ROOT=/foss/designs/bag2
export BAG_RUN_DIR=/foss/designs/bag2/BAG2_run_dir

source \$BAG_SRC_DIR/sourceme.sh
EOF
