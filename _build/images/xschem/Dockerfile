#######################################################################
# Compile xschem
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS xschem
ARG XSCHEM_REPO_URL="https://github.com/StefanSchippers/xschem.git"
ARG XSCHEM_REPO_COMMIT="8fe82cf4ce11eac524b3990db225ce0d4f394012"
ARG XSCHEM_NAME="xschem"
USER 0:0
RUN --mount=type=bind,source=images/xschem,target=/images/xschem \
    bash /images/xschem/scripts/install.sh
