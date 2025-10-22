#######################################################################
# Compile OpenROAD for LibreLane
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
FROM ${BASE_IMAGE_BUILD} AS openroad-librelane
ARG OPENROAD_LL_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD.git"
ARG OPENROAD_LL_REPO_COMMIT="edf00dff99f6c40d67a30c0e22a8191c5d2ed9d6"
ARG OPENROAD_LL_NAME="openroad-librelane"
RUN --mount=type=bind,source=images/openroad-librelane,target=/images/openroad-librelane \
    bash /images/openroad-librelane/scripts/install.sh
