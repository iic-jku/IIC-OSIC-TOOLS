#######################################################################
# Compile openems
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS openems
ARG OPENEMS_REPO_URL="https://github.com/thliebig/openEMS-Project.git"
ARG OPENEMS_REPO_COMMIT="9ba6e1b330c2152e7f8d13bba4e42d834c9a432b"
ARG OPENEMS_NAME="openems"
USER 0:0
RUN --mount=type=bind,source=images/openems,target=/images/openems \
    bash /images/openems/scripts/install.sh
