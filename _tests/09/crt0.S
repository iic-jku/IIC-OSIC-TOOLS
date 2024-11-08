# Copyright (c) 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# from: https://github.com/pulp-platform/croc/blob/main/sw/crt0.S
#
# Authors:
# - Paul Scheffler <paulsc@iis.ee.ethz.ch>
# - Philippe Sauter <phsauter@iis.ee.ethz.ch>

.globl _start
.section .text._start
_start:
  # Global pointer
  .option push
  .option norelax
  la      x3, __global_pointer$
  .option pop
  # Stack pointer
  la      x2, __stack_pointer$
  # Reset vector
  li      x1, 0
  li      x4, 0
  li      x5, 0
  li      x6, 0
  li      x7, 0
  li      x8, 0
  li      x9, 0
  li      x10, 0
  li      x11, 0
  li      x12, 0
  li      x13, 0
  li      x14, 0
  li      x15, 0
  call main
_eoc:
  la      t0, status
  sw      a0, 0(t0)
  wfi