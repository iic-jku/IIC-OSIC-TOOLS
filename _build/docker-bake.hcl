target "base" {
  platforms = ["linux/amd64", "linux/arm64"]
  dockerfile = "images/base/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:base"]
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
}

# Individual tool targets for tools-level-1
target "magic" {
  inherits = ["base-tool"]
  dockerfile = "images/magic/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-magic-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-magic-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-magic-latest,mode=max,compression=zstd"]
}

target "openvaf" {
  inherits = ["base-tool"]
  dockerfile = "images/openvaf/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-openvaf-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-openvaf-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-openvaf-latest,mode=max,compression=zstd"]
}

target "osic-multitool" {
  inherits = ["base-tool"]
  dockerfile = "images/osic-multitool/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-osic-multitool-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-osic-multitool-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-osic-multitool-latest,mode=max,compression=zstd"]
}

target "xyce" {
  inherits = ["base-tool"]
  dockerfile = "images/xyce/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-xyce-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-xyce-latest,mode=max,compression=zstd"]
}

target "covered" {
  inherits = ["base-tool"]
  dockerfile = "images/covered/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-covered-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-covered-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-covered-latest,mode=max,compression=zstd"]
}

target "cvc_rv" {
  inherits = ["base-tool"]
  dockerfile = "images/cvc_rv/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-cvc_rv-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-cvc_rv-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-cvc_rv-latest,mode=max,compression=zstd"]
}

target "gaw3-xschem" {
  inherits = ["base-tool"]
  dockerfile = "images/gaw3-xschem/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-gaw3-xschem-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-gaw3-xschem-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-gaw3-xschem-latest,mode=max,compression=zstd"]
}

target "ghdl" {
  inherits = ["base-tool"]
  dockerfile = "images/ghdl/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-ghdl-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-ghdl-latest,mode=max,compression=zstd"]
}

target "gtkwave" {
  inherits = ["base-tool"]
  dockerfile = "images/gtkwave/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-gtkwave-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-gtkwave-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-gtkwave-latest,mode=max,compression=zstd"]
}

target "irsim" {
  inherits = ["base-tool"]
  dockerfile = "images/irsim/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-irsim-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-irsim-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-irsim-latest,mode=max,compression=zstd"]
}

target "iverilog" {
  inherits = ["base-tool"]
  dockerfile = "images/iverilog/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-iverilog-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-iverilog-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-iverilog-latest,mode=max,compression=zstd"]
}

target "kactus2" {
  inherits = ["base-tool"]
  dockerfile = "images/kactus2/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-kactus2-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-kactus2-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-kactus2-latest,mode=max,compression=zstd"]
}

target "klayout" {
  inherits = ["base-tool"]
  dockerfile = "images/klayout/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-klayout-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-klayout-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-klayout-latest,mode=max,compression=zstd"]
}

target "libman" {
  inherits = ["base-tool"]
  dockerfile = "images/libman/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-libman-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-libman-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-libman-latest,mode=max,compression=zstd"]
}

target "netgen" {
  inherits = ["base-tool"]
  dockerfile = "images/netgen/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-netgen-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-netgen-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-netgen-latest,mode=max,compression=zstd"]
}

target "ngspyce" {
  inherits = ["base-tool"]
  dockerfile = "images/ngspyce/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-ngspyce-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-ngspyce-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-ngspyce-latest,mode=max,compression=zstd"]
}

target "nvc" {
  inherits = ["base-tool"]
  dockerfile = "images/nvc/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-nvc-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-nvc-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-nvc-latest,mode=max,compression=zstd"]
}

target "openems" {
  inherits = ["base-tool"]
  dockerfile = "images/openems/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-openems-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-openems-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-openems-latest,mode=max,compression=zstd"]
}

target "openroad_app" {
  inherits = ["base-tool"]
  dockerfile = "images/openroad_app/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-openroad_app-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-openroad_app-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-openroad_app-latest,mode=max,compression=zstd"]
}

target "padring" {
  inherits = ["base-tool"]
  dockerfile = "images/padring/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-padring-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-padring-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-padring-latest,mode=max,compression=zstd"]
}

target "pulp-tools" {
  inherits = ["base-tool"]
  dockerfile = "images/pulp-tools/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-pulp-tools-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-pulp-tools-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-pulp-tools-latest,mode=max,compression=zstd"]
}

target "surelog" {
  inherits = ["base-tool"]
  dockerfile = "images/surelog/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-surelog-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-surelog-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-surelog-latest,mode=max,compression=zstd"]
}

target "surfer" {
  inherits = ["base-tool"]
  dockerfile = "images/surfer/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-surfer-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-surfer-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-surfer-latest,mode=max,compression=zstd"]
}

target "qflow" {
  inherits = ["base-tool"]
  dockerfile = "images/qflow/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-qflow-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-qflow-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-qflow-latest,mode=max,compression=zstd"]
}

target "qucs-s" {
  inherits = ["base-tool"]
  dockerfile = "images/qucs-s/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-qucs-s-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-qucs-s-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-qucs-s-latest,mode=max,compression=zstd"]
}

target "riscv-gnu-toolchain" {
  inherits = ["base-tool"]
  dockerfile = "images/riscv-gnu-toolchain/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-riscv-gnu-toolchain-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-riscv-gnu-toolchain-latest,mode=max,compression=zstd"]
}

target "slang" {
  inherits = ["base-tool"]
  dockerfile = "images/slang/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-slang-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-slang-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-slang-latest,mode=max,compression=zstd"]
}

target "verilator" {
  inherits = ["base-tool"]
  dockerfile = "images/verilator/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-verilator-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-verilator-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-verilator-latest,mode=max,compression=zstd"]
}

target "veryl" {
  inherits = ["base-tool"]
  dockerfile = "images/veryl/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-veryl-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-veryl-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-veryl-latest,mode=max,compression=zstd"]
}

target "xcircuit" {
  inherits = ["base-tool"]
  dockerfile = "images/xcircuit/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-xcircuit-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-xcircuit-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-xcircuit-latest,mode=max,compression=zstd"]
}

target "xschem" {
  inherits = ["base-tool"]
  dockerfile = "images/xschem/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-xschem-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-xschem-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-xschem-latest,mode=max,compression=zstd"]
}

target "yosys" {
  inherits = ["base-tool"]
  dockerfile = "images/yosys/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-yosys-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-yosys-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-yosys-latest,mode=max,compression=zstd"]
}

target "rftoolkit" {
  inherits = ["base-tool"]
  dockerfile = "images/rftoolkit/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-rftoolkit-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-rftoolkit-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-rftoolkit-latest,mode=max,compression=zstd"]
}

# Individual tool targets for tools-level-2
target "xyce-xdm" {
  inherits = ["base-tool"]
  dockerfile = "images/xyce-xdm/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-xdm-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-xyce-xdm-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-xyce-xdm-latest,mode=max,compression=zstd"]
}

target "open_pdks" {
  inherits = ["base-tool"]
  dockerfile = "images/open_pdks/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-open_pdks-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-open_pdks-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-open_pdks-latest,mode=max,compression=zstd"]
}

target "riscv-pk" {
  inherits = ["base-tool"]
  dockerfile = "images/riscv-pk/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-pk-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-riscv-pk-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-riscv-pk-latest,mode=max,compression=zstd"]
}

target "vacask" {
  inherits = ["base-tool"]
  dockerfile = "images/vacask/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-vacask-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-vacask-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-vacask-latest,mode=max,compression=zstd"]
}

target "ghdl-yosys-plugin" {
  inherits = ["base-tool"]
  dockerfile = "images/ghdl-yosys-plugin/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-yosys-plugin-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-ghdl-yosys-plugin-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-ghdl-yosys-plugin-latest,mode=max,compression=zstd"]
}

target "slang-yosys-plugin" {
  inherits = ["base-tool"]
  dockerfile = "images/slang-yosys-plugin/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-slang-yosys-plugin-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-slang-yosys-plugin-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-slang-yosys-plugin-latest,mode=max,compression=zstd"]
}

target "spike" {
  inherits = ["base-tool"]
  dockerfile = "images/spike/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-spike-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-spike-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-spike-latest,mode=max,compression=zstd"]
}

# Individual tool targets for tools-level-3
target "gds3d" {
  inherits = ["base-tool"]
  dockerfile = "images/gds3d/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-gds3d-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-gds3d-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-gds3d-latest,mode=max,compression=zstd"]
}

target "ngspice" {
  inherits = ["base-tool"]
  dockerfile = "images/ngspice/Dockerfile"
  tags = ["registry.iic.jku.at:5000/iic-osic-tools:tool-ngspice-latest"]
  cache-from = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-ngspice-latest"]
  cache-to = ["type=registry,ref=registry.iic.jku.at:5000/iic-osic-tools-cache:tool-ngspice-latest,mode=max,compression=zstd"]
}

# Group targets for tools-level-1
  # Disabled: openroad_app
group "tools-level-1" {
  targets = [
    "magic", "openvaf", "osic-multitool", "xyce", "covered", "cvc_rv", "gaw3-xschem", "ghdl", "gtkwave", "irsim", "iverilog", "kactus2", "klayout", "libman", "netgen", "ngspyce", "nvc", "openems", "padring", "pulp-tools", "surelog", "surfer", "qflow", "qucs-s", "riscv-gnu-toolchain", "slang", "verilator", "veryl", "xcircuit", "xschem", "yosys", "rftoolkit"
  ]
}

# Group targets for tools-level-2
group "tools-level-2" {
  targets = [
    "open_pdks", "riscv-pk", "vacask", "ghdl-yosys-plugin", "slang-yosys-plugin", "spike"
  ]
  # "xyce-xdm" disabled
}

# Group targets for tools-level-3
group "tools-level-3" {
  targets = [
    "gds3d", "ngspice"
  ]
}
