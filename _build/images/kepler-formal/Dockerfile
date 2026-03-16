#######################################################################
# Compile kepler-formal
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
FROM ${BASE_IMAGE_BUILD} AS kepler-formal
ARG KEPLER_FORMAL_REPO_URL="https://github.com/keplertech/kepler-formal.git"
ARG KEPLER_FORMAL_REPO_COMMIT="cc11a2142a914c8b652a3034d3f045da5fccee0a"
ARG KEPLER_FORMAL_NAME="kepler-formal"
RUN --mount=type=bind,source=images/kepler-formal,target=/images/kepler-formal \
    bash /images/kepler-formal/scripts/install.sh
