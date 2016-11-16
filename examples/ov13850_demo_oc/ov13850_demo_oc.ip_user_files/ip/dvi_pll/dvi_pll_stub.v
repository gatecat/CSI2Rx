// Copyright 1986-2016 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2016.3 (lin64) Build 1682563 Mon Oct 10 19:07:26 MDT 2016
// Date        : Tue Nov 15 17:05:27 2016
// Host        : david-desktop-arch running 64-bit unknown
// Command     : write_verilog -force -mode synth_stub
//               /home/dave/ip/examples/ov13850_demo/ov13850_demo.srcs/sources_1/ip/dvi_pll_1/dvi_pll_stub.v
// Design      : dvi_pll
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k325tffg900-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module dvi_pll(pixel_clock, dvi_bit_clock, sysclk)
/* synthesis syn_black_box black_box_pad_pin="pixel_clock,dvi_bit_clock,sysclk" */;
  output pixel_clock;
  output dvi_bit_clock;
  input sysclk;
endmodule
