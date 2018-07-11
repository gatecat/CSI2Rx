# MIPI CSI-2 IP Cores

The _vhdl\_rx_ folder contains a tried-and-tested high performance CSI-2 receiver core in VHDL. This can handle 4k video at over 30fps (most likely 60fps with a suitable camera module). This has been tested with the OV13850 camera module with a Xilinx Kintex-7 FPGA. It is currently limited to a 4-lane and 10bpp without modification, other parameters such as timing can be modified at compile time. Also in this folder are an example project and some miscellaneous VHDL support IP such as an AXI-4 framebuffer controller.

The _verilog\_cores_ contains work-in-progress CSI-2 transmit and receive cores in Verilog. These are designed to be more flexible and run on a variety of platforms. The first target will be 640x480 video using a Raspberry Pi camera with an iCE40 FPGA.

All cores are licensed under the MIT License, see LICENSE for details.
