#######################################################################
# Compile xschem
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS xschem
ARG XSCHEM_REPO_URL="https://github.com/StefanSchippers/xschem.git"
ARG XSCHEM_REPO_COMMIT="1f52d630f53ba3cd0d2329f810da4847f775dc07"
ARG XSCHEM_NAME="xschem"
RUN --mount=type=bind,source=images/xschem,target=/images/xschem \
    bash /images/xschem/scripts/install.sh
