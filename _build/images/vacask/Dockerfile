#######################################################################
# Compile vacask
#######################################################################
ARG TOOL_IMAGE_OPENVAF="registry.iic.jku.at:5000/iic-osic-tools:tool-openvaf-latest"
FROM ${TOOL_IMAGE_OPENVAF} AS vacask
ARG VACASK_REPO_URL="https://codeberg.org/arpadbuermen/VACASK.git"
ARG VACASK_REPO_COMMIT="ca9debc467961bd9f781bf10fe28c9867f5ccec5"
ARG VACASK_NAME="vacask"
RUN --mount=type=bind,source=images/vacask,target=/images/vacask \
    bash /images/vacask/scripts/install.sh
