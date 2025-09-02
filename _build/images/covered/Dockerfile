#######################################################################
# Compile covered 
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS covered
ARG COVERED_REPO_URL="https://github.com/hpretl/verilog-covered.git"
ARG COVERED_REPO_COMMIT="19d30fc942642b14dc24e95331cd4777c8dcbad9"
ARG COVERED_NAME="covered"
RUN --mount=type=bind,source=images/covered,target=/images/covered \
    bash /images/covered/scripts/install.sh
