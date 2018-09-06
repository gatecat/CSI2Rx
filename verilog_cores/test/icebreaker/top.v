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

module top(input mpsse_sda, mpsse_scl, inout cam_sda, cam_scl, output cam_enable,
		   input dphy_clk, input [1:0] dphy_data, input dphy_lp,
		   output LEDR_N, LEDG_N, LED1, LED2, LED3, LED4, LED5,
		   input BTN_N, BTN1, BTN2, BTN3);

	wire areset = !BTN_N;
	assign cam_scl = mpsse_scl ? 1'bz : 1'b0;
    assign cam_sda = mpsse_sda ? 1'bz : 1'b0;
	assign cam_enable = 1'b1;
	wire sys_clk;
	wire in_line, in_frame;
	wire [31:0] payload_data;
	wire payload_valid;
	wire [15:0] raw_deser;
	wire [15:0] aligned_deser;
	wire [3:0] raw_ddr;
	wire [1:0] aligned_valid;
	wire wait_sync;

	csi_rx_ice40 #(
		.LANES(2), // lane count
		.PAIRSWAP(2'b10), // lane pair swap (inverts data for given  lane)

		.VC(2'b00), // MIPI CSI-2 "virtual channel"
		.FS_DT(6'h00), // Frame start data type
		.FE_DT(6'h01), // Frame end data type
		.VIDEO_DT(6'h2A), // Video payload data type (6'h2A = 8-bit raw, 6'h2B = 10-bit raw, 6'h2C = 12-bit raw)
		.MAX_LEN(8192) // Max expected packet len, used as timeout
	) csi_rx_i (
		.dphy_clk_lane(dphy_clk),
		.dphy_data_lane(dphy_data),
		.dphy_lp_sense(dphy_lp),

		.areset(areset),

		.word_clk(sys_clk),
		.payload_data(payload_data),
		.payload_enable(payload_valid),
		.payload_frame(),

		.vsync(),
		.in_line(in_line),
		.in_frame(in_frame),

		.dbg_aligned_valid(aligned_valid),
		.dbg_raw_deser(raw_deser),
		.dbg_raw_ddr(raw_ddr),
		.dbg_wait_sync(wait_sync)
	);


	reg [22:0] sclk_div;
	always @(posedge sys_clk)
		sclk_div <= sclk_div + 1'b1;

	assign {LEDR_N, LEDG_N} = ~(sclk_div[22:21]);
	assign LED1 = in_frame;
	assign LED2 = !in_frame;
	assign {LED5, LED4, LED3} = payload_valid ? payload_data[7:5] : 3'b000;
	//assign {LED5, LED4, LED3} = raw_deser[2:0];
	//assign {LED5, LED4, LED3} = {wait_sync, aligned_valid};
endmodule
