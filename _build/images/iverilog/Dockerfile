#######################################################################
# Compile iverilog
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS iverilog
ARG IVERILOG_REPO_URL="https://github.com/steveicarus/iverilog.git"
ARG IVERILOG_REPO_COMMIT="f82c6c7b3ada873015348f728aa3087cdb6661a6"
ARG IVERILOG_NAME="iverilog"
USER 0:0
RUN --mount=type=bind,source=images/iverilog,target=/images/iverilog \
    bash /images/iverilog/scripts/install.sh
