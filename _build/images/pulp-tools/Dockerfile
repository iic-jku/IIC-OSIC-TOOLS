#######################################################################
# Compile pulp platform tools
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS pulp-tools
ARG PULP_NAME="pulp"
RUN --mount=type=bind,source=images/pulp-tools,target=/images/pulp-tools \
    bash /images/pulp-tools/scripts/install.sh
