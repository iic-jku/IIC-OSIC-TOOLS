ARG TOOL_IMAGE_XYCE="registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-latest"

FROM ${TOOL_IMAGE_XYCE} AS xyce-xdm
ARG XYCE_XDM_REPO_URL="https://github.com/Xyce/XDM.git"
ARG XYCE_XDM_REPO_COMMIT="Release-2.7.0"
ARG XYCE_XDM_NAME="xyce-xdm"
#FIXME XDM has build fails in 24.04 LTS, not sure why; remove it for the
#      time being
#RUN --mount=type=bind,source=images/xyce-xdm,target=/images/xyce-xdm \
#    bash /images/xyce-xdm/scripts/install.sh
