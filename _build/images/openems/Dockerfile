#######################################################################
# Compile openems
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS openems
ARG OPENEMS_REPO_URL="https://github.com/thliebig/openEMS-Project.git"
ARG OPENEMS_REPO_COMMIT="a1e1be4e69234bcc65f5be60a049899029a4751c"
ARG OPENEMS_NAME="openems"
USER 0:0
RUN --mount=type=bind,source=images/openems,target=/images/openems \
    bash /images/openems/scripts/install.sh
