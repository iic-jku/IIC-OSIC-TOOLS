#######################################################################
# Compile OpenROAD
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base"
FROM ${BASE_IMAGE_BUILD} AS openroad
ARG OPENROAD_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD.git"
ARG OPENROAD_REPO_COMMIT="341650e72dad0dc8571822ff8c5d9c5e365327f7"
ARG OPENROAD_NAME="openroad"
RUN --mount=type=bind,source=images/openroad,target=/images/openroad \
    bash /images/openroad/scripts/install.sh
