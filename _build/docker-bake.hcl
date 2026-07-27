# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Build definition for the IIC-OSIC-TOOLS container.
#
# Every inter-image dependency is declared as a named build context bound to a
# bake target (see DEPS_FROM_TARGETS below). BuildKit therefore knows the real
# dependency graph and schedules the whole build as one DAG: a target starts as
# soon as *its own* dependencies are ready instead of waiting for an entire
# "level" to finish. A single `docker buildx bake all` builds everything.
#
# The Dockerfiles are unchanged: each one already pins its parent image behind
# an ARG (BASE_IMAGE_BUILD / TOOL_IMAGE_*), and the args below simply point that
# ARG at a named context instead of at a registry tag.

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "REGISTRY" {
  default = "registry.iic.jku.at:5000"
}

variable "IMAGE" {
  default = "iic-osic-tools"
}

# "1" (default) resolves inter-image dependencies to bake targets, so bake
# builds the full dependency DAG in a single solve.
# "0" resolves them to the images already pushed to REGISTRY, which is the
# pre-DAG behaviour: useful to re-assemble the final image from tool images
# that were built earlier without rebuilding or re-checking any of them.
variable "DEPS_FROM_TARGETS" {
  default = "1"
}

# "1" (default) exports a dedicated mode=max registry cache per target, which
# also covers intermediate stages and RUN --mount=type=cache mounts.
# Set to "0" when building without write access to the cache registry.
variable "CACHE_EXPORT" {
  default = "1"
}

variable "PLATFORMS" {
  default = "linux/amd64,linux/arm64"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function "img" {
  params = [tag]
  result = "${REGISTRY}/${IMAGE}:${tag}"
}

# Dependency on one of the base images.
function "basedep" {
  params = [name]
  result = DEPS_FROM_TARGETS == "1" ? "target:${name}" : "docker-image://${REGISTRY}/${IMAGE}:${name}"
}

# Dependency on a tool image.
function "tooldep" {
  params = [name]
  result = DEPS_FROM_TARGETS == "1" ? "target:${name}" : "docker-image://${REGISTRY}/${IMAGE}:tool-${name}-latest"
}

# Cache import: the dedicated cache manifest first, with the image's own inline
# cache as a fallback so the first build after switching over is not a full
# rebuild (and so a target stays warm even if its cache manifest is GCed).
function "cache_from" {
  params = [key, legacy]
  result = [
    "type=registry,ref=${REGISTRY}/${IMAGE}:cache-${key}",
    "type=registry,ref=${REGISTRY}/${IMAGE}:${legacy}",
  ]
}

function "tool_cache_from" {
  params = [name]
  result = cache_from(name, "tool-${name}-latest")
}

# Cache export: inline (cheap, travels with the image) plus a mode=max registry
# manifest. ignore-error keeps a read-only or unreachable registry from failing
# an otherwise successful build.
function "cache_to" {
  params = [key]
  result = CACHE_EXPORT == "1" ? [
    "type=inline",
    "type=registry,ref=${REGISTRY}/${IMAGE}:cache-${key},mode=max,compression=zstd,ignore-error=true",
  ] : ["type=inline"]
}

# ---------------------------------------------------------------------------
# Base images
# ---------------------------------------------------------------------------

target "base" {
  platforms  = split(",", PLATFORMS)
  dockerfile = "images/base/Dockerfile"
  tags       = [img("base")]
  cache-from = cache_from("base", "base")
  cache-to   = cache_to("base")
}

target "base-dev" {
  platforms  = split(",", PLATFORMS)
  dockerfile = "images/base-dev/Dockerfile"
  tags       = [img("base-dev")]
  contexts = {
    "ctx-base" = basedep("base")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base"
  }
  cache-from = cache_from("base-dev", "base-dev")
  cache-to   = cache_to("base-dev")
}

# ---------------------------------------------------------------------------
# Tool images
# ---------------------------------------------------------------------------

# Common settings for every tool target.
target "base-tool" {
  platforms = split(",", PLATFORMS)
}

# --- Tools built directly on base-dev -----------------------------------------

target "covered" {
  inherits   = ["base-tool"]
  dockerfile = "images/covered/Dockerfile"
  tags       = [img("tool-covered-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("covered")
  cache-to   = cache_to("covered")
}

target "cvc_rv" {
  inherits   = ["base-tool"]
  dockerfile = "images/cvc_rv/Dockerfile"
  tags       = [img("tool-cvc_rv-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("cvc_rv")
  cache-to   = cache_to("cvc_rv")
}

target "fpga" {
  inherits   = ["base-tool"]
  dockerfile = "images/fpga-tools/Dockerfile"
  tags       = [img("tool-fpga-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("fpga")
  cache-to   = cache_to("fpga")
}

target "gaw3-xschem" {
  inherits   = ["base-tool"]
  dockerfile = "images/gaw3-xschem/Dockerfile"
  tags       = [img("tool-gaw3-xschem-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("gaw3-xschem")
  cache-to   = cache_to("gaw3-xschem")
}

target "ghdl" {
  inherits   = ["base-tool"]
  dockerfile = "images/ghdl/Dockerfile"
  tags       = [img("tool-ghdl-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("ghdl")
  cache-to   = cache_to("ghdl")
}

target "gtkwave" {
  inherits   = ["base-tool"]
  dockerfile = "images/gtkwave/Dockerfile"
  tags       = [img("tool-gtkwave-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("gtkwave")
  cache-to   = cache_to("gtkwave")
}

target "irsim" {
  inherits   = ["base-tool"]
  dockerfile = "images/irsim/Dockerfile"
  tags       = [img("tool-irsim-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("irsim")
  cache-to   = cache_to("irsim")
}

target "iverilog" {
  inherits   = ["base-tool"]
  dockerfile = "images/iverilog/Dockerfile"
  tags       = [img("tool-iverilog-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("iverilog")
  cache-to   = cache_to("iverilog")
}

target "kactus2" {
  inherits   = ["base-tool"]
  dockerfile = "images/kactus2/Dockerfile"
  tags       = [img("tool-kactus2-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("kactus2")
  cache-to   = cache_to("kactus2")
}

target "kepler-formal" {
  inherits   = ["base-tool"]
  dockerfile = "images/kepler-formal/Dockerfile"
  tags       = [img("tool-kepler-formal-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("kepler-formal")
  cache-to   = cache_to("kepler-formal")
}

target "klayout" {
  inherits   = ["base-tool"]
  dockerfile = "images/klayout/Dockerfile"
  tags       = [img("tool-klayout-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("klayout")
  cache-to   = cache_to("klayout")
}

target "libman" {
  inherits   = ["base-tool"]
  dockerfile = "images/libman/Dockerfile"
  tags       = [img("tool-libman-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("libman")
  cache-to   = cache_to("libman")
}

target "magic" {
  inherits   = ["base-tool"]
  dockerfile = "images/magic/Dockerfile"
  tags       = [img("tool-magic-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("magic")
  cache-to   = cache_to("magic")
}

target "netgen" {
  inherits   = ["base-tool"]
  dockerfile = "images/netgen/Dockerfile"
  tags       = [img("tool-netgen-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("netgen")
  cache-to   = cache_to("netgen")
}

target "ngspyce" {
  inherits   = ["base-tool"]
  dockerfile = "images/ngspyce/Dockerfile"
  tags       = [img("tool-ngspyce-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("ngspyce")
  cache-to   = cache_to("ngspyce")
}

target "nvc" {
  inherits   = ["base-tool"]
  dockerfile = "images/nvc/Dockerfile"
  tags       = [img("tool-nvc-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("nvc")
  cache-to   = cache_to("nvc")
}

target "openems" {
  inherits   = ["base-tool"]
  dockerfile = "images/openems/Dockerfile"
  tags       = [img("tool-openems-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("openems")
  cache-to   = cache_to("openems")
}

target "openroad" {
  inherits   = ["base-tool"]
  dockerfile = "images/openroad/Dockerfile"
  tags       = [img("tool-openroad-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("openroad")
  cache-to   = cache_to("openroad")
}

target "openroad-librelane" {
  inherits   = ["base-tool"]
  dockerfile = "images/openroad-librelane/Dockerfile"
  tags       = [img("tool-openroad-librelane-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("openroad-librelane")
  cache-to   = cache_to("openroad-librelane")
}

target "openvaf" {
  inherits   = ["base-tool"]
  dockerfile = "images/openvaf/Dockerfile"
  tags       = [img("tool-openvaf-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("openvaf")
  cache-to   = cache_to("openvaf")
}

target "osic-multitool" {
  inherits   = ["base-tool"]
  dockerfile = "images/osic-multitool/Dockerfile"
  tags       = [img("tool-osic-multitool-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("osic-multitool")
  cache-to   = cache_to("osic-multitool")
}

target "padring" {
  inherits   = ["base-tool"]
  dockerfile = "images/padring/Dockerfile"
  tags       = [img("tool-padring-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("padring")
  cache-to   = cache_to("padring")
}

target "pulp-tools" {
  inherits   = ["base-tool"]
  dockerfile = "images/pulp-tools/Dockerfile"
  tags       = [img("tool-pulp-tools-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("pulp-tools")
  cache-to   = cache_to("pulp-tools")
}

target "pyopus" {
  inherits   = ["base-tool"]
  dockerfile = "images/pyopus/Dockerfile"
  tags       = [img("tool-pyopus-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("pyopus")
  cache-to   = cache_to("pyopus")
}

target "qflow" {
  inherits   = ["base-tool"]
  dockerfile = "images/qflow/Dockerfile"
  tags       = [img("tool-qflow-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("qflow")
  cache-to   = cache_to("qflow")
}

target "qucs-s" {
  inherits   = ["base-tool"]
  dockerfile = "images/qucs-s/Dockerfile"
  tags       = [img("tool-qucs-s-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("qucs-s")
  cache-to   = cache_to("qucs-s")
}

target "rftoolkit" {
  inherits   = ["base-tool"]
  dockerfile = "images/rftoolkit/Dockerfile"
  tags       = [img("tool-rftoolkit-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("rftoolkit")
  cache-to   = cache_to("rftoolkit")
}

target "riscv-gnu-toolchain" {
  inherits   = ["base-tool"]
  dockerfile = "images/riscv-gnu-toolchain/Dockerfile"
  tags       = [img("tool-riscv-gnu-toolchain-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("riscv-gnu-toolchain")
  cache-to   = cache_to("riscv-gnu-toolchain")
}

target "slang" {
  inherits   = ["base-tool"]
  dockerfile = "images/slang/Dockerfile"
  tags       = [img("tool-slang-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("slang")
  cache-to   = cache_to("slang")
}

target "surelog" {
  inherits   = ["base-tool"]
  dockerfile = "images/surelog/Dockerfile"
  tags       = [img("tool-surelog-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("surelog")
  cache-to   = cache_to("surelog")
}

target "surfer" {
  inherits   = ["base-tool"]
  dockerfile = "images/surfer/Dockerfile"
  tags       = [img("tool-surfer-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("surfer")
  cache-to   = cache_to("surfer")
}

target "svck" {
  inherits   = ["base-tool"]
  dockerfile = "images/svck/Dockerfile"
  tags       = [img("tool-svck-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("svck")
  cache-to   = cache_to("svck")
}

target "uv" {
  inherits   = ["base-tool"]
  dockerfile = "images/uv/Dockerfile"
  tags       = [img("tool-uv-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("uv")
  cache-to   = cache_to("uv")
}

target "verible" {
  inherits   = ["base-tool"]
  dockerfile = "images/verible/Dockerfile"
  tags       = [img("tool-verible-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("verible")
  cache-to   = cache_to("verible")
}

target "verilator" {
  inherits   = ["base-tool"]
  dockerfile = "images/verilator/Dockerfile"
  tags       = [img("tool-verilator-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("verilator")
  cache-to   = cache_to("verilator")
}

target "veryl" {
  inherits   = ["base-tool"]
  dockerfile = "images/veryl/Dockerfile"
  tags       = [img("tool-veryl-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("veryl")
  cache-to   = cache_to("veryl")
}

target "xcircuit" {
  inherits   = ["base-tool"]
  dockerfile = "images/xcircuit/Dockerfile"
  tags       = [img("tool-xcircuit-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("xcircuit")
  cache-to   = cache_to("xcircuit")
}

target "xschem" {
  inherits   = ["base-tool"]
  dockerfile = "images/xschem/Dockerfile"
  tags       = [img("tool-xschem-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("xschem")
  cache-to   = cache_to("xschem")
}

target "xyce" {
  inherits   = ["base-tool"]
  dockerfile = "images/xyce/Dockerfile"
  tags       = [img("tool-xyce-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("xyce")
  cache-to   = cache_to("xyce")
}

target "yosys" {
  inherits   = ["base-tool"]
  dockerfile = "images/yosys/Dockerfile"
  tags       = [img("tool-yosys-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
  }
  cache-from = tool_cache_from("yosys")
  cache-to   = cache_to("yosys")
}

# --- Tools that depend on other tool images -----------------------------------

target "gds3d" {
  inherits   = ["base-tool"]
  dockerfile = "images/gds3d/Dockerfile"
  tags       = [img("tool-gds3d-latest")]
  contexts = {
    "ctx-open_pdks"  = tooldep("open_pdks")
  }
  args = {
    TOOL_IMAGE_OPEN_PDKS = "ctx-open_pdks"
  }
  cache-from = tool_cache_from("gds3d")
  cache-to   = cache_to("gds3d")
}

target "ghdl-yosys-plugin" {
  inherits   = ["base-tool"]
  dockerfile = "images/ghdl-yosys-plugin/Dockerfile"
  tags       = [img("tool-ghdl-yosys-plugin-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
    "ctx-yosys"     = tooldep("yosys")
    "ctx-ghdl"      = tooldep("ghdl")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
    TOOL_IMAGE_YOSYS = "ctx-yosys"
    TOOL_IMAGE_GHDL  = "ctx-ghdl"
  }
  cache-from = tool_cache_from("ghdl-yosys-plugin")
  cache-to   = cache_to("ghdl-yosys-plugin")
}

target "ngspice" {
  inherits   = ["base-tool"]
  dockerfile = "images/ngspice/Dockerfile"
  tags       = [img("tool-ngspice-latest")]
  contexts = {
    "ctx-open_pdks"  = tooldep("open_pdks")
  }
  args = {
    TOOL_IMAGE_OPEN_PDKS = "ctx-open_pdks"
  }
  cache-from = tool_cache_from("ngspice")
  cache-to   = cache_to("ngspice")
}

target "open_pdks" {
  inherits   = ["base-tool"]
  dockerfile = "images/open_pdks/Dockerfile"
  tags       = [img("tool-open_pdks-latest")]
  contexts = {
    "ctx-osic-multitool"  = tooldep("osic-multitool")
    "ctx-openvaf"         = tooldep("openvaf")
    "ctx-xyce"            = tooldep("xyce")
  }
  args = {
    TOOL_IMAGE_OSIC_MULTITOOL = "ctx-osic-multitool"
    TOOL_IMAGE_OPENVAF        = "ctx-openvaf"
    TOOL_IMAGE_XYCE           = "ctx-xyce"
  }
  cache-from = tool_cache_from("open_pdks")
  cache-to   = cache_to("open_pdks")
}

target "palace" {
  inherits   = ["base-tool"]
  dockerfile = "images/palace/Dockerfile"
  tags       = [img("tool-palace-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
  }
  args = {
    TOOL_IMAGE_PALACE = "ctx-base-dev"
  }
  cache-from = tool_cache_from("palace")
  cache-to   = cache_to("palace")
}

target "slang-yosys-plugin" {
  inherits   = ["base-tool"]
  dockerfile = "images/slang-yosys-plugin/Dockerfile"
  tags       = [img("tool-slang-yosys-plugin-latest")]
  contexts = {
    "ctx-base-dev"  = basedep("base-dev")
    "ctx-yosys"     = tooldep("yosys")
  }
  args = {
    BASE_IMAGE_BUILD = "ctx-base-dev"
    TOOL_IMAGE_YOSYS = "ctx-yosys"
  }
  cache-from = tool_cache_from("slang-yosys-plugin")
  cache-to   = cache_to("slang-yosys-plugin")
}

target "spicebind" {
  inherits   = ["base-tool"]
  dockerfile = "images/spicebind/Dockerfile"
  tags       = [img("tool-spicebind-latest")]
  contexts = {
    "ctx-ngspice"  = tooldep("ngspice")
  }
  args = {
    TOOL_IMAGE_NGSPICE = "ctx-ngspice"
  }
  cache-from = tool_cache_from("spicebind")
  cache-to   = cache_to("spicebind")
}

target "spike" {
  inherits   = ["base-tool"]
  dockerfile = "images/spike/Dockerfile"
  tags       = [img("tool-spike-latest")]
  contexts = {
    "ctx-riscv-gnu-toolchain"  = tooldep("riscv-gnu-toolchain")
  }
  args = {
    TOOL_IMAGE_RISCV_GNU_TOOLCHAIN = "ctx-riscv-gnu-toolchain"
  }
  cache-from = tool_cache_from("spike")
  cache-to   = cache_to("spike")
}

target "vacask" {
  inherits   = ["base-tool"]
  dockerfile = "images/vacask/Dockerfile"
  tags       = [img("tool-vacask-latest")]
  contexts = {
    "ctx-openvaf"  = tooldep("openvaf")
  }
  args = {
    TOOL_IMAGE_OPENVAF = "ctx-openvaf"
  }
  cache-from = tool_cache_from("vacask")
  cache-to   = cache_to("vacask")
}

# ---------------------------------------------------------------------------
# Final image
# ---------------------------------------------------------------------------

target "image-full" {
  platforms  = split(",", PLATFORMS)
  dockerfile = "images/iic-osic-tools/Dockerfile"
  # No default tag: the tags are set by the build scripts.
  contexts = {
    "ctx-base"                 = basedep("base")
    "ctx-covered"              = tooldep("covered")
    "ctx-cvc_rv"               = tooldep("cvc_rv")
    "ctx-fpga"                 = tooldep("fpga")
    "ctx-gaw3-xschem"          = tooldep("gaw3-xschem")
    "ctx-gds3d"                = tooldep("gds3d")
    "ctx-ghdl"                 = tooldep("ghdl")
    "ctx-ghdl-yosys-plugin"    = tooldep("ghdl-yosys-plugin")
    "ctx-gtkwave"              = tooldep("gtkwave")
    "ctx-irsim"                = tooldep("irsim")
    "ctx-iverilog"             = tooldep("iverilog")
    "ctx-kactus2"              = tooldep("kactus2")
    "ctx-kepler-formal"        = tooldep("kepler-formal")
    "ctx-klayout"              = tooldep("klayout")
    "ctx-libman"               = tooldep("libman")
    "ctx-magic"                = tooldep("magic")
    "ctx-netgen"               = tooldep("netgen")
    "ctx-ngspice"              = tooldep("ngspice")
    "ctx-ngspyce"              = tooldep("ngspyce")
    "ctx-nvc"                  = tooldep("nvc")
    "ctx-open_pdks"            = tooldep("open_pdks")
    "ctx-openems"              = tooldep("openems")
    "ctx-openroad"             = tooldep("openroad")
    "ctx-openroad-librelane"   = tooldep("openroad-librelane")
    "ctx-openvaf"              = tooldep("openvaf")
    "ctx-osic-multitool"       = tooldep("osic-multitool")
    "ctx-padring"              = tooldep("padring")
    "ctx-palace"               = tooldep("palace")
    "ctx-pulp-tools"           = tooldep("pulp-tools")
    "ctx-pyopus"               = tooldep("pyopus")
    "ctx-qflow"                = tooldep("qflow")
    "ctx-qucs-s"               = tooldep("qucs-s")
    "ctx-rftoolkit"            = tooldep("rftoolkit")
    "ctx-riscv-gnu-toolchain"  = tooldep("riscv-gnu-toolchain")
    "ctx-slang"                = tooldep("slang")
    "ctx-slang-yosys-plugin"   = tooldep("slang-yosys-plugin")
    "ctx-spicebind"            = tooldep("spicebind")
    "ctx-spike"                = tooldep("spike")
    "ctx-surelog"              = tooldep("surelog")
    "ctx-surfer"               = tooldep("surfer")
    "ctx-svck"                 = tooldep("svck")
    "ctx-uv"                   = tooldep("uv")
    "ctx-vacask"               = tooldep("vacask")
    "ctx-verible"              = tooldep("verible")
    "ctx-verilator"            = tooldep("verilator")
    "ctx-veryl"                = tooldep("veryl")
    "ctx-xcircuit"             = tooldep("xcircuit")
    "ctx-xschem"               = tooldep("xschem")
    "ctx-xyce"                 = tooldep("xyce")
    "ctx-yosys"                = tooldep("yosys")
  }
  args = {
    BASE_IMAGE                     = "ctx-base"
    TOOL_IMAGE_COVERED             = "ctx-covered"
    TOOL_IMAGE_CVC_RV              = "ctx-cvc_rv"
    TOOL_IMAGE_FPGA                = "ctx-fpga"
    TOOL_IMAGE_GAW3_XSCHEM         = "ctx-gaw3-xschem"
    TOOL_IMAGE_GDS3D               = "ctx-gds3d"
    TOOL_IMAGE_GHDL                = "ctx-ghdl"
    TOOL_IMAGE_GHDL_YOSYS_PLUGIN   = "ctx-ghdl-yosys-plugin"
    TOOL_IMAGE_GTKWAVE             = "ctx-gtkwave"
    TOOL_IMAGE_IRSIM               = "ctx-irsim"
    TOOL_IMAGE_IVERILOG            = "ctx-iverilog"
    TOOL_IMAGE_KACTUS2             = "ctx-kactus2"
    TOOL_IMAGE_KEPLER_FORMAL       = "ctx-kepler-formal"
    TOOL_IMAGE_KLAYOUT             = "ctx-klayout"
    TOOL_IMAGE_LIBMAN              = "ctx-libman"
    TOOL_IMAGE_MAGIC               = "ctx-magic"
    TOOL_IMAGE_NETGEN              = "ctx-netgen"
    TOOL_IMAGE_NGSPICE             = "ctx-ngspice"
    TOOL_IMAGE_NGSPYCE             = "ctx-ngspyce"
    TOOL_IMAGE_NVC                 = "ctx-nvc"
    TOOL_IMAGE_OPEN_PDKS           = "ctx-open_pdks"
    TOOL_IMAGE_OPENEMS             = "ctx-openems"
    TOOL_IMAGE_OPENROAD            = "ctx-openroad"
    TOOL_IMAGE_OPENROAD_LIBRELANE  = "ctx-openroad-librelane"
    TOOL_IMAGE_OPENVAF             = "ctx-openvaf"
    TOOL_IMAGE_OSIC_MULTITOOL      = "ctx-osic-multitool"
    TOOL_IMAGE_PADRING             = "ctx-padring"
    TOOL_IMAGE_PALACE              = "ctx-palace"
    TOOL_IMAGE_PULP_TOOLS          = "ctx-pulp-tools"
    TOOL_IMAGE_PYOPUS              = "ctx-pyopus"
    TOOL_IMAGE_QFLOW               = "ctx-qflow"
    TOOL_IMAGE_QUCS_S              = "ctx-qucs-s"
    TOOL_IMAGE_RFTOOLKIT           = "ctx-rftoolkit"
    TOOL_IMAGE_RISCV_GNU_TOOLCHAIN = "ctx-riscv-gnu-toolchain"
    TOOL_IMAGE_SLANG               = "ctx-slang"
    TOOL_IMAGE_SLANG_YOSYS_PLUGIN  = "ctx-slang-yosys-plugin"
    TOOL_IMAGE_SPICEBIND           = "ctx-spicebind"
    TOOL_IMAGE_SPIKE               = "ctx-spike"
    TOOL_IMAGE_SURELOG             = "ctx-surelog"
    TOOL_IMAGE_SURFER              = "ctx-surfer"
    TOOL_IMAGE_SVCK                = "ctx-svck"
    TOOL_IMAGE_UV                  = "ctx-uv"
    TOOL_IMAGE_VACASK              = "ctx-vacask"
    TOOL_IMAGE_VERIBLE             = "ctx-verible"
    TOOL_IMAGE_VERILATOR           = "ctx-verilator"
    TOOL_IMAGE_VERYL               = "ctx-veryl"
    TOOL_IMAGE_XCIRCUIT            = "ctx-xcircuit"
    TOOL_IMAGE_XSCHEM              = "ctx-xschem"
    TOOL_IMAGE_XYCE                = "ctx-xyce"
    TOOL_IMAGE_YOSYS               = "ctx-yosys"
  }
  cache-from = cache_from("image-full", "latest")
  cache-to   = cache_to("image-full")
}

# ---------------------------------------------------------------------------
# Groups
# ---------------------------------------------------------------------------

# Everything, as one dependency-ordered DAG. This is the normal entry point.
group "all" {
  targets = ["base", "base-dev", "tools", "image-full"]
}

group "images" {
  targets = ["image-full"]
}

group "tools" {
  targets = [
    "covered",
    "cvc_rv",
    "fpga",
    "gaw3-xschem",
    "gds3d",
    "ghdl",
    "ghdl-yosys-plugin",
    "gtkwave",
    "irsim",
    "iverilog",
    "kactus2",
    "kepler-formal",
    "klayout",
    "libman",
    "magic",
    "netgen",
    "ngspice",
    "ngspyce",
    "nvc",
    "open_pdks",
    "openems",
    "openroad",
    "openroad-librelane",
    "openvaf",
    "osic-multitool",
    "padring",
    "palace",
    "pulp-tools",
    "pyopus",
    "qflow",
    "qucs-s",
    "rftoolkit",
    "riscv-gnu-toolchain",
    "slang",
    "slang-yosys-plugin",
    "spicebind",
    "spike",
    "surelog",
    "surfer",
    "svck",
    "uv",
    "vacask",
    "verible",
    "verilator",
    "veryl",
    "xcircuit",
    "xschem",
    "xyce",
    "yosys",
  ]
}

# The historical dependency levels. They are no longer needed for correct
# ordering -- bake derives that from the contexts above -- but are kept so that
# existing scripts and a staged build (e.g. to bound peak disk usage) keep
# working. Note that vacask and spicebind now sit at the level their Dockerfiles
# actually require.
group "tools-level-1" {
  targets = [
    "covered",
    "cvc_rv",
    "fpga",
    "gaw3-xschem",
    "ghdl",
    "gtkwave",
    "irsim",
    "iverilog",
    "kactus2",
    "kepler-formal",
    "klayout",
    "libman",
    "magic",
    "netgen",
    "ngspyce",
    "nvc",
    "openems",
    "openroad",
    "openroad-librelane",
    "openvaf",
    "osic-multitool",
    "padring",
    "palace",
    "pulp-tools",
    "pyopus",
    "qflow",
    "qucs-s",
    "rftoolkit",
    "riscv-gnu-toolchain",
    "slang",
    "surelog",
    "surfer",
    "svck",
    "uv",
    "verible",
    "verilator",
    "veryl",
    "xcircuit",
    "xschem",
    "xyce",
    "yosys",
  ]
}

group "tools-level-2" {
  targets = ["ghdl-yosys-plugin", "open_pdks", "slang-yosys-plugin", "spike", "vacask"]
}

group "tools-level-3" {
  targets = ["gds3d", "ngspice"]
}

group "tools-level-4" {
  targets = ["spicebind"]
}
