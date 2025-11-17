#######################################################################
# Compile xcircuit
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS xcircuit
ARG XCIRCUIT_REPO_URL="https://github.com/RTimothyEdwards/XCircuit.git"
ARG XCIRCUIT_REPO_COMMIT="8a0429250abbd2b70c4d3fbfe2e2c20b4c43be81"
ARG XCIRCUIT_NAME="xcircuit"
RUN --mount=type=bind,source=images/xcircuit,target=/images/xcircuit \
    bash /images/xcircuit/scripts/install.sh
