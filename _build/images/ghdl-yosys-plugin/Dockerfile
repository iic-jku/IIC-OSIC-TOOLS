#######################################################################
# Compile Yosys GHDL plugin
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
ARG TOOL_IMAGE_YOSYS="registry.iic.jku.at:5000/iic-osic-tools:tool-yosys-latest"
ARG TOOL_IMAGE_GHDL="registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-latest"
FROM ${TOOL_IMAGE_YOSYS} AS yosys
FROM ${TOOL_IMAGE_GHDL} AS ghdl
FROM ${BASE_IMAGE_BUILD} AS ghdl-yosys-plugin
ARG GHDL_YOSYS_PLUGIN_REPO_URL="https://github.com/ghdl/ghdl-yosys-plugin.git"
ARG GHDL_YOSYS_PLUGIN_REPO_COMMIT="356b6f5fb7af02b0fde346520a37938744f7d58f"
ARG GHDL_YOSYS_PLUGIN_NAME="ghdl-yosys-plugin"
COPY --from=yosys	${TOOLS}    ${TOOLS}
COPY --from=ghdl	${TOOLS}    ${TOOLS}
RUN --mount=type=bind,source=images/ghdl-yosys-plugin,target=/images/ghdl-yosys-plugin \
    bash /images/ghdl-yosys-plugin/scripts/install.sh
