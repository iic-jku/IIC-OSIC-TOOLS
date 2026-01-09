#######################################################################
# Compile palace
#######################################################################
ARG TOOL_IMAGE_PALACE=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${TOOL_IMAGE_PALACE} AS palace
ARG PALACE_REPO_URL="https://github.com/awslabs/palace"
ARG PALACE_REPO_COMMIT="2bbc5096b25afaff8894e23af5bab9cea3234d0c"
ARG PALACE_NAME="palace"
RUN --mount=type=bind,source=images/palace,target=/images/palace \
    bash /images/palace/scripts/install.sh
