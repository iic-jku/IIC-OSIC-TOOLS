# Copyright (c) 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# from: https://github.com/pulp-platform/croc/blob/main/sw/link.ld
#
# Authors:
# - Paul Scheffler <paulsc@iis.ee.ethz.ch>
# - Philippe Sauter <phsauter@iis.ee.ethz.ch>

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY 
{
   SRAM (rwxail) : ORIGIN = 0x10000000, LENGTH = 2K
}

SECTIONS
{
  /DISCARD/ : { *(.riscv.attributes) *(.comment) }

  .text._start 0x10000080 : { *(.text._start) } >SRAM
  .text : { *(.text) *(.text.*) } >SRAM
  .misc : { *(.sdata) *(.*) } >SRAM
  
  __global_pointer$ = ADDR(.misc); 
  __stack_pointer$  = ORIGIN(SRAM) + LENGTH(SRAM) -4;

  status  = 0x03000008;
}