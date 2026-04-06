#######################################################################
# Compile qucs-s
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS qucs-s
ARG QUCS_S_REPO_URL="https://github.com/ra3xdh/qucs_s.git"
ARG QUCS_S_REPO_COMMIT="25.2.0"
ARG QUCS_S_NAME="qucs-s"
RUN --mount=type=bind,source=images/qucs-s,target=/images/qucs-s \
    bash /images/qucs-s/scripts/install.sh
