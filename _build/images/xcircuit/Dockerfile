#######################################################################
# Compile xcircuit
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS xcircuit
ARG XCIRCUIT_REPO_URL="https://github.com/RTimothyEdwards/XCircuit.git"
ARG XCIRCUIT_REPO_COMMIT="b67fb820ac5506f9926ebc7f92c65c74c48e087d"
ARG XCIRCUIT_NAME="xcircuit"
RUN --mount=type=bind,source=images/xcircuit,target=/images/xcircuit \
    bash /images/xcircuit/scripts/install.sh
