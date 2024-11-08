// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

`ifdef ERROR
`timescale 1ns / 1ps
`endif

module top (
    input  logic       clk_i,
    input  logic       rst_ni,

    input  logic       clear_i,
    input  logic       en_i,
    input  logic       load_i,
    input  logic       down_i,
    input  logic [7:0] delta_i,
    input  logic [7:0] d_i,
    output logic [7:0] q_o,
    output logic [7:0] max_o,

    input  logic       pop_i,
    output logic       full_o
);
    logic [7:0] data;

    max_counter #(
        .WIDTH(8)
    ) i_max (
        .clk_i,
        .rst_ni,
        .clear_i, 
        .clear_max_i ( 1'b0 ),
        .en_i,
        .load_i,
        .down_i,
        .delta_i,
        .d_i,
        .q_o ( data ),
        .max_o,
        .overflow_o     ( ),
        .overflow_max_o ( )
    );

    fifo_v3 #(
        .FALL_THROUGH ( 1'b0 ),
        .DATA_WIDTH   ( 8 ),
        .DEPTH        ( 4 )
    ) i_fifo (
        .clk_i,
        .rst_ni,
        .flush_i    ( clear_i ),
        .testmode_i (  1'b0   ),
        .full_o,
        .empty_o ( ),
        .usage_o ( ),
        .data_i  ( data ),
        .push_i  ( en_i ),
        .data_o  ( q_o ),
        .pop_i
    );
endmodule