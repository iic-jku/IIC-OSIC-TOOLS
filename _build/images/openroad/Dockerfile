#######################################################################
# Compile OpenROAD
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
FROM ${BASE_IMAGE_BUILD} AS openroad
ARG OPENROAD_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD.git"
ARG OPENROAD_REPO_COMMIT="566951d2b635e9bb4162282826362a3c7f5d4c8a"
ARG OPENROAD_NAME="openroad"
RUN --mount=type=bind,source=images/openroad,target=/images/openroad \
    bash /images/openroad/scripts/install.sh
