#######################################################################
# Compile vacask
#######################################################################
ARG TOOL_IMAGE_OPENVAF="registry.iic.jku.at:5000/iic-osic-tools:tool-openvaf-latest"
FROM ${TOOL_IMAGE_OPENVAF} AS vacask
ARG VACASK_REPO_URL="https://codeberg.org/arpadbuermen/VACASK.git"
ARG VACASK_REPO_COMMIT="884cc3a0c1bff88910468ac253db6dcce7a85f41"
ARG VACASK_NAME="vacask"
RUN --mount=type=bind,source=images/vacask,target=/images/vacask \
    bash /images/vacask/scripts/install.sh
