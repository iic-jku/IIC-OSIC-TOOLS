#######################################################################
# Compile openroad
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base"
FROM ${BASE_IMAGE_BUILD} AS openroad_app
ARG OPENROAD_APP_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD.git"
ARG OPENROAD_APP_REPO_COMMIT="edf00dff99f6c40d67a30c0e22a8191c5d2ed9d6"
ARG OPENROAD_APP_NAME="openroad"
USER 0:0
RUN --mount=type=bind,source=images/openroad_app,target=/images/openroad_app \
    bash /images/openroad_app/scripts/install.sh
