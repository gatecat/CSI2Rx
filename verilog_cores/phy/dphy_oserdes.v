/**
 * The MIT License
 * Copyright (c) 2018 David Shah
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

/**
 * MIPI D-PHY output SERDES
 * This is designed to generate 2 outputs per clock for an architecture specific
 * DDR primitive
 */

module dphy_oserdes(
	input sys_clk, // System byte clock
	input areset, // Active high async reset
  input [7:0] din, // Input from CSI-2 packetiser
	input dphy_clk, // Fast D-PHY DDR clock (4x sys_clk)
	output reg [1:0] dout // Output data, bit 1 should be the second bit transmitted
);

	parameter NUM_SYNCFFS = 2;

	reg [8:0] dclk_sclk_din[0:NUM_SYNCFFS-1];

	// Input
	integer i;
	always @(posedge dphy_clk, posedge areset)
		if (areset) begin
			for (i = 0; i < NUM_SYNCFFS; i = i + 1)
				dclk_sclk_din[i] <= 0;
		end else begin
			for (i = 1; i < NUM_SYNCFFS; i = i + 1)
				dclk_sclk_din[i] <= dclk_sclk_din[i-1];
			dclk_sclk_din[0] <= {sys_clk, din};
		end

	wire dclk_sclk = dclk_sclk_din[NUM_SYNCFFS-1][8];
	wire [7:0] dclk_din = dclk_sclk_din[NUM_SYNCFFS-1][7:0];
	reg last_sclk;

	reg [7:0] reg_word;

	always @(posedge dphy_clk, posedge areset)
		if (areset) begin
			last_sclk <= 1'b0;
			dout <= 2'b00;
			reg_word <= 0;
		end else begin
			last_sclk <= dclk_sclk;
			dout <= reg_word[1:0]; // LSB first
			if (dclk_sclk && !last_sclk) begin
				reg_word <= dclk_din;
			end else begin
				reg_word <= {reg_word[1:0], reg_word[7:2]};
			end
		end
endmodule
