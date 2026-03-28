#######################################################################
# Compile pulp platform tools
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS pulp-tools
ARG PULP_NAME="pulp"
ARG BENDER_REPO_URL="https://github.com/pulp-platform/bender.git"
ARG BENDER_REPO_COMMIT="59f72bcfdd631e563a56ff768cb098c6990845f3"
ARG SV2V_REPO_URL="https://github.com/zachjs/sv2v.git"
ARG SV2V_REPO_COMMIT="6662fa5da71f87797598060f17728b284b99a9fc"
ARG VERIBLE_VERSION="v0.0-3724-gdec56671"
RUN --mount=type=bind,source=images/pulp-tools,target=/images/pulp-tools \
    bash /images/pulp-tools/scripts/install.sh
