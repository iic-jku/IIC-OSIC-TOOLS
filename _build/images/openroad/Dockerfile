#######################################################################
# Compile OpenROAD
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
FROM ${BASE_IMAGE_BUILD} AS openroad
ARG OPENROAD_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD.git"
ARG OPENROAD_REPO_COMMIT="b984a8d7e869745a923bf28037b373a3a6488a17"
ARG OPENROAD_NAME="openroad"
RUN --mount=type=bind,source=images/openroad,target=/images/openroad \
    bash /images/openroad/scripts/install.sh
