#######################################################################
# Compile magic
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS magic
ARG MAGIC_REPO_URL="https://github.com/rtimothyedwards/magic.git"
ARG MAGIC_REPO_COMMIT="8.3.547"
ARG MAGIC_NAME="magic"
COPY images/magic/scripts/install.sh install.sh
USER 0:0
RUN --mount=type=bind,source=images/magic,target=/images/magic \
    bash /images/magic/scripts/install.sh
