target "base" {
  platforms = ["linux/amd64", "linux/arm64"]
  dockerfile = "images/base/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:base"]
}

target "base-dev" {
  platforms = ["linux/amd64", "linux/arm64"]
  dockerfile = "images/base-dev/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:base-dev"]
}

group "tools" {
  targets = ["tools-level-1", "tools-level-2", "tools-level-3"]
}

target "image-full" {
  platforms = ["linux/amd64", "linux/arm64"]
  dockerfile = "images/iic-osic-tools/Dockerfile"
  #tags = ["registry.iic.jku.at:5000/iic-osic-tools:latest"] # Do not set a default tag for now, so it can be handled in the build command.
}

#target "image-analog" {
#  platforms = ["linux/amd64", "linux/arm64"]
#  dockerfile = "images/iic-osic-tools/Dockerfile.full"
#  tags = ["registry.iic.jku.at:5000/iic-osic-tools:latest-analog"]
#}

#target "image-digital" {
#  platforms = ["linux/amd64", "linux/arm64"]
#  dockerfile = "images/iic-osic-tools/Dockerfile.digital"
#  tags = ["registry.iic.jku.at:5000/iic-osic-tools:latest-digital"]
#}

#target "image-riscv" {
#  platforms = ["linux/amd64", "linux/arm64"]
#  dockerfile = "images/iic-osic-tools/Dockerfile.riscv"
#  tags = ["registry.iic.jku.at:5000/iic-osic-tools:latest"]
#}

group "images" {
  targets = ["image-full"]
}


# Base target for common settings
target "base-tool" {
  platforms = ["linux/amd64", "linux/arm64"]
  cache-to = ["type=inline"]
}

# Individual tool targets for tools-level-1
target "magic" {
  inherits = ["base-tool"]
  dockerfile = "images/magic/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-magic-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-magic-latest"]
}

target "openvaf" {
  inherits = ["base-tool"]
  dockerfile = "images/openvaf/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-openvaf-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-openvaf-latest"]
}

target "osic-multitool" {
  inherits = ["base-tool"]
  dockerfile = "images/osic-multitool/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-osic-multitool-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-osic-multitool-latest"]
}

target "xyce" {
  inherits = ["base-tool"]
  dockerfile = "images/xyce/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-latest"]
}

target "covered" {
  inherits = ["base-tool"]
  dockerfile = "images/covered/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-covered-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-covered-latest"]
}

target "cvc_rv" {
  inherits = ["base-tool"]
  dockerfile = "images/cvc_rv/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-cvc_rv-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-cvc_rv-latest"]
}

target "fpga" {
  inherits = ["base-tool"]
  dockerfile = "images/fpga-tools/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-fpga-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-fpga-latest"]
}

target "gaw3-xschem" {
  inherits = ["base-tool"]
  dockerfile = "images/gaw3-xschem/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-gaw3-xschem-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-gaw3-xschem-latest"]
}

target "ghdl" {
  inherits = ["base-tool"]
  dockerfile = "images/ghdl/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-latest"]
}

target "gtkwave" {
  inherits = ["base-tool"]
  dockerfile = "images/gtkwave/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-gtkwave-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-gtkwave-latest"]
}

target "irsim" {
  inherits = ["base-tool"]
  dockerfile = "images/irsim/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-irsim-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-irsim-latest"]
}

target "iverilog" {
  inherits = ["base-tool"]
  dockerfile = "images/iverilog/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-iverilog-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-iverilog-latest"]
}

target "kactus2" {
  inherits = ["base-tool"]
  dockerfile = "images/kactus2/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-kactus2-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-kactus2-latest"]
}

target "klayout" {
  inherits = ["base-tool"]
  dockerfile = "images/klayout/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-klayout-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-klayout-latest"]
}

target "libman" {
  inherits = ["base-tool"]
  dockerfile = "images/libman/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-libman-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-libman-latest"]
}

target "netgen" {
  inherits = ["base-tool"]
  dockerfile = "images/netgen/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-netgen-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-netgen-latest"]
}

target "ngspyce" {
  inherits = ["base-tool"]
  dockerfile = "images/ngspyce/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-ngspyce-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-ngspyce-latest"]
}

target "nvc" {
  inherits = ["base-tool"]
  dockerfile = "images/nvc/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-nvc-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-nvc-latest"]
}

target "openems" {
  inherits = ["base-tool"]
  dockerfile = "images/openems/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-openems-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-openems-latest"]
}

target "openroad" {
  inherits = ["base-tool"]
  dockerfile = "images/openroad/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-openroad-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-openroad-latest"]
}

target "padring" {
  inherits = ["base-tool"]
  dockerfile = "images/padring/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-padring-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-padring-latest"]
}

target "palace" {
  inherits = ["base-tool"]
  dockerfile = "images/palace/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-palace-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-palace-latest"]
}

target "pulp-tools" {
  inherits = ["base-tool"]
  dockerfile = "images/pulp-tools/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-pulp-tools-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-pulp-tools-latest"]
}

target "surelog" {
  inherits = ["base-tool"]
  dockerfile = "images/surelog/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-surelog-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-surelog-latest"]
}

target "surfer" {
  inherits = ["base-tool"]
  dockerfile = "images/surfer/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-surfer-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-surfer-latest"]
}

target "qflow" {
  inherits = ["base-tool"]
  dockerfile = "images/qflow/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-qflow-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-qflow-latest"]
}

target "qucs-s" {
  inherits = ["base-tool"]
  dockerfile = "images/qucs-s/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-qucs-s-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-qucs-s-latest"]
}

target "riscv-gnu-toolchain" {
  inherits = ["base-tool"]
  dockerfile = "images/riscv-gnu-toolchain/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"]
}

target "slang" {
  inherits = ["base-tool"]
  dockerfile = "images/slang/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-slang-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-slang-latest"]
}

target "verilator" {
  inherits = ["base-tool"]
  dockerfile = "images/verilator/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-verilator-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-verilator-latest"]
}

target "veryl" {
  inherits = ["base-tool"]
  dockerfile = "images/veryl/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-veryl-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-veryl-latest"]
}

target "xcircuit" {
  inherits = ["base-tool"]
  dockerfile = "images/xcircuit/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-xcircuit-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-xcircuit-latest"]
}

target "xschem" {
  inherits = ["base-tool"]
  dockerfile = "images/xschem/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-xschem-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-xschem-latest"]
}

target "yosys" {
  inherits = ["base-tool"]
  dockerfile = "images/yosys/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-yosys-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-yosys-latest"]
}

target "rftoolkit" {
  inherits = ["base-tool"]
  dockerfile = "images/rftoolkit/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-rftoolkit-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-rftoolkit-latest"]
}

# Individual tool targets for tools-level-2
target "xyce-xdm" {
  inherits = ["base-tool"]
  dockerfile = "images/xyce-xdm/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-xdm-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-xdm-latest"]
}

target "open_pdks" {
  inherits = ["base-tool"]
  dockerfile = "images/open_pdks/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-open_pdks-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-open_pdks-latest"]
}

target "vacask" {
  inherits = ["base-tool"]
  dockerfile = "images/vacask/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-vacask-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-vacask-latest"]
}

target "ghdl-yosys-plugin" {
  inherits = ["base-tool"]
  dockerfile = "images/ghdl-yosys-plugin/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-yosys-plugin-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-yosys-plugin-latest"]
}

target "slang-yosys-plugin" {
  inherits = ["base-tool"]
  dockerfile = "images/slang-yosys-plugin/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-slang-yosys-plugin-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-slang-yosys-plugin-latest"]
}

target "spike" {
  inherits = ["base-tool"]
  dockerfile = "images/spike/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-spike-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-spike-latest"]
}

# Individual tool targets for tools-level-3
target "gds3d" {
  inherits = ["base-tool"]
  dockerfile = "images/gds3d/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-gds3d-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-gds3d-latest"]
}

target "ngspice" {
  inherits = ["base-tool"]
  dockerfile = "images/ngspice/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-ngspice-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools:tool-ngspice-latest"]
}

# Group targets for tools-level-1
group "tools-level-1" {
  targets = [
    "magic", "openvaf", "osic-multitool", "xyce", "covered", "cvc_rv", "fpga", "gaw3-xschem", "ghdl", "gtkwave", "irsim", "iverilog", "kactus2", "klayout", "libman", "netgen", "ngspyce", "nvc", "openems", "padring", "palace", "pulp-tools", "surelog", "surfer", "qflow", "qucs-s", "riscv-gnu-toolchain", "slang", "verilator", "veryl", "xcircuit", "xschem", "yosys", "rftoolkit", "openroad"
  ]
}

# Group targets for tools-level-2
group "tools-level-2" {
  targets = [
    "open_pdks", "vacask", "ghdl-yosys-plugin", "slang-yosys-plugin", "spike"
  ]
  # "xyce-xdm" disabled
}

# Group targets for tools-level-3
group "tools-level-3" {
  targets = [
    "gds3d", "ngspice"
  ]
}
