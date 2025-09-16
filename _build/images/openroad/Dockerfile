#######################################################################
# Compile OpenROAD
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base"
FROM ${BASE_IMAGE_BUILD} AS openroad
ARG OPENROAD_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD.git"
ARG OPENROAD_REPO_COMMIT="1f974c324029b6065cb86713064091f69cd66987"
ARG OPENROAD_NAME="openroad"
RUN --mount=type=bind,source=images/openroad,target=/images/openroad \
    bash /images/openroad/scripts/install.sh
