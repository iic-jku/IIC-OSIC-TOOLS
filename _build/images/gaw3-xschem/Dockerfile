#######################################################################
# Compile gaw3-xschem
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS gaw3-xschem
ARG GAW3_XSCHEM_REPO_URL="https://github.com/StefanSchippers/xschem-gaw.git"
ARG GAW3_XSCHEM_REPO_COMMIT="6b8fa4ab007e88b3129381e0479737ae014a8b51"
ARG GAW3_XSCHEM_NAME="gaw3-xschem"
USER 0:0
RUN --mount=type=bind,source=images/gaw3-xschem,target=/images/gaw3-xschem \
    bash /images/gaw3-xschem/scripts/install.sh
