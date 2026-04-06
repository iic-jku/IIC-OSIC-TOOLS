#######################################################################
# Compile GDS3D
#######################################################################
ARG TOOL_IMAGE_OPEN_PDKS="registry.iic.jku.at:5000/iic-osic-tools:tool-open_pdks-latest"
FROM ${TOOL_IMAGE_OPEN_PDKS} AS gds3d
ARG GDS3D_REPO_URL="https://github.com/trilomix/GDS3D.git"
ARG GDS3D_REPO_COMMIT="dc6d965225c9f5ed2a6faefb7ea30665429060fe"
ARG GDS3D_NAME="gds3d"
RUN --mount=type=bind,source=images/gds3d,target=/images/gds3d \
    bash /images/gds3d/scripts/install.sh
