ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base"
ARG TOOL_IMAGE_YOSYS="registry.iic.jku.at:5000/iic-osic-tools:tool-yosys-latest"

FROM ${TOOL_IMAGE_YOSYS} AS yosys

FROM ${BASE_IMAGE_BUILD} AS slang-yosys-plugin

ARG SLANG_YOSYS_PLUGIN_REPO_URL="https://github.com/povik/yosys-slang.git"
ARG SLANG_YOSYS_PLUGIN_REPO_COMMIT="9d9ce7b767d2ea776e2dee0ef636a84512e6b229"
ARG SLANG_YOSYS_PLUGIN_NAME="slang-yosys-plugin"

COPY --from=yosys	${TOOLS}    ${TOOLS}
USER 0:0
RUN --mount=type=bind,source=images/slang-yosys-plugin,target=/images/slang-yosys-plugin \
    bash /images/slang-yosys-plugin/scripts/install.sh
