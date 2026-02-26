#######################################################################
# Compile pulp platform tools
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS pulp-tools
ARG PULP_NAME="pulp"
ARG BENDER_REPO_URL="https://github.com/pulp-platform/bender.git"
ARG BENDER_REPO_COMMIT="37ba98f7c234b72b6321b36db136c62018bfc2fc"
ARG SV2V_REPO_URL="https://github.com/zachjs/sv2v.git"
ARG SV2V_REPO_COMMIT="d3812098d8feb2d04cc4cb55e034a1f2338db02f"
ARG VERIBLE_VERSION="v0.0-3724-gdec56671"
RUN --mount=type=bind,source=images/pulp-tools,target=/images/pulp-tools \
    bash /images/pulp-tools/scripts/install.sh
