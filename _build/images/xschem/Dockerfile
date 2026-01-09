#######################################################################
# Compile xschem
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS xschem
ARG XSCHEM_REPO_URL="https://github.com/StefanSchippers/xschem.git"
ARG XSCHEM_REPO_COMMIT="2a242cb80a7ebd893cfe76647b5ad202629e3f21"
ARG XSCHEM_NAME="xschem"
RUN --mount=type=bind,source=images/xschem,target=/images/xschem \
    bash /images/xschem/scripts/install.sh
