ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base"
ARG TOOL_IMAGE_YOSYS="registry.iic.jku.at:5000/iic-osic-tools:tool-yosys-latest"
ARG TOOL_IMAGE_GHDL="registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-latest"


FROM ${TOOL_IMAGE_YOSYS} AS yosys
FROM ${TOOL_IMAGE_GHDL} AS ghdl

FROM ${BASE_IMAGE_BUILD} AS ghdl-yosys-plugin

ARG GHDL_YOSYS_PLUGIN_REPO_URL="https://github.com/ghdl/ghdl-yosys-plugin.git"
ARG GHDL_YOSYS_PLUGIN_REPO_COMMIT="1b97dc71377cea7e861be6625be4353c377a5fb5"
ARG GHDL_YOSYS_PLUGIN_NAME="ghdl-yosys-plugin"

COPY --from=yosys	${TOOLS}    ${TOOLS}
COPY --from=ghdl	${TOOLS}    ${TOOLS}

USER 0:0
RUN --mount=type=bind,source=images/ghdl-yosys-plugin,target=/images/ghdl-yosys-plugin \
    bash /images/ghdl-yosys-plugin/scripts/install.sh
