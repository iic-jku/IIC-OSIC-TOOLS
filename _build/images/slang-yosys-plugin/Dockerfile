#######################################################################
# Compile Slang Yosys plugin
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
ARG TOOL_IMAGE_YOSYS="registry.iic.jku.at:5000/iic-osic-tools:tool-yosys-latest"

FROM ${TOOL_IMAGE_YOSYS} AS yosys
FROM ${BASE_IMAGE_BUILD} AS slang-yosys-plugin

ARG SLANG_YOSYS_PLUGIN_REPO_URL="https://github.com/povik/yosys-slang.git"
ARG SLANG_YOSYS_PLUGIN_REPO_COMMIT="d4053e825408a25dc2c065cd430b4cc5e71b1b6c"
ARG SLANG_YOSYS_PLUGIN_NAME="slang-yosys-plugin"

COPY --from=yosys	${TOOLS}    ${TOOLS}

RUN --mount=type=bind,source=images/slang-yosys-plugin,target=/images/slang-yosys-plugin \
    bash /images/slang-yosys-plugin/scripts/install.sh
