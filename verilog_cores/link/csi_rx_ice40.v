/**
 * The MIT License
 * Copyright (c) 2016-2018 David Shah
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

/*
 * Example CSI-2 receiver for iCE40
*/

module csi_rx_ice40 #(
	parameter LANES = 2, // lane count
	parameter PAIRSWAP = 2'b10, // lane pair swap (inverts data for given  lane)

	parameter [1:0] VC = 2'b00, // MIPI CSI-2 "virtual channel"
	parameter [5:0] FS_DT = 6'h00, // Frame start data type
	parameter [5:0] FE_DT = 6'h01, // Frame end data type
	parameter [5:0] VIDEO_DT = 6'h2A, // Video payload data type (6'h2A = 8-bit raw, 6'h2B = 10-bit raw, 6'h2C = 12-bit raw)
	parameter [15:0] MAX_LEN = 8192 // Max expected packet len, used as timeout
)(
	input dphy_clk_lane,
	input [LANES-1:0] dphy_data_lane,
	input dphy_lp_sense,

	input areset,

	output word_clk,
	output [31:0] payload_data,
	output payload_enable,
	output payload_frame,

	output [2*LANES-1:0] dbg_raw_ddr,
	output [8*LANES-1:0] dbg_raw_deser,
	output [8*LANES-1:0] dbg_aligned,
	output [LANES-1:0] dbg_aligned_valid,
	output dbg_wait_sync,

	output vsync,
	output in_line,
	output in_frame
);

	wire dphy_clk;

	SB_IO #(
		.PIN_TYPE(6'b000001),
		.IO_STANDARD("SB_LVDS_INPUT")
	) clk_iobuf (
		.PACKAGE_PIN(dphy_clk_lane),
		.D_IN_0(dphy_clk)
	);

	wire dphy_lp;
	SB_IO #(
		.PIN_TYPE(6'b000001),
		.IO_STANDARD("SB_LVDS_INPUT")
	) lp_compare (
		.PACKAGE_PIN(dphy_lp_sense),
		.D_IN_0(dphy_lp)
	);

	reg [1:0] div;
	always @(posedge dphy_clk)
		div <= div + 1'b1;
	assign word_clk = div[1];

	reg sreset1, sreset2, sreset;
	always @(posedge word_clk) begin
		sreset1 <= areset;
		sreset2 <= sreset1;
		sreset <= sreset2;
	end

	wire byte_packet_done, wait_for_sync;
	wire [LANES*8-1:0] aligned_bytes;
	wire [LANES-1:0] aligned_bytes_valid;


	generate
	genvar ii;
	for (ii = 0; ii < LANES; ii++) begin
		wire [1:0] din_raw;
		SB_IO #(
			.PIN_TYPE(6'b000000),
			.IO_STANDARD("SB_LVDS_INPUT")
		) clk_iobuf (
			.PACKAGE_PIN(dphy_data_lane[ii]),
			.INPUT_CLK(dphy_clk),
			.D_IN_0(din_raw[0]),
			.D_IN_1(din_raw[1])
		);
		assign dbg_raw_ddr[2*ii+1:2*ii] = din_raw;

		wire [7:0] din_deser;
		dphy_iserdes #(
			.REG_INPUT(1'b1)
		) iserdes_i (
		   .dphy_clk(dphy_clk),
		   .din(din_raw),
		   .sys_clk(word_clk),
		   .areset(areset),
		   .dout(din_deser)
	    );

    	wire [7:0] din_deser_swap = PAIRSWAP[ii] ? ~din_deser : din_deser;
		assign dbg_raw_deser[8*ii+7:8*ii] = din_deser_swap;

		dphy_rx_byte_align baligner_i (
			.clock(word_clk),
			.reset(sreset),
			.enable(1'b1),
			.deser_byte(din_deser_swap),
			.wait_for_sync(wait_for_sync),
			.packet_done(byte_packet_done),
			.valid_data(aligned_bytes_valid[ii]),
			.data_out(aligned_bytes[8*ii+7:8*ii])
		);

	end
	endgenerate

	assign dbg_aligned = aligned_bytes;
	assign dbg_aligned_valid = aligned_bytes_valid;

	wire [31:0] comb_word;
	wire comb_word_en, comb_word_frame;
	wire word_packet_done;

	dphy_rx_word_combiner #(
		.LANES(LANES)
	) combiner_i (
		.clock(word_clk),
		.reset(sreset),
		.enable(1'b1),
		.bytes_in(aligned_bytes),
		.bytes_valid(aligned_bytes_valid),
		.wait_for_sync(wait_for_sync),
		.packet_done(word_packet_done),
		.byte_packet_done(byte_packet_done),

		.word_out(comb_word),
		.word_enable(comb_word_en),
		.word_frame(comb_word_frame)
	);

	assign dbg_wait_sync = wait_for_sync;

	csi_rx_packet_handler #(
		.VC(VC),
		.FS_DT(FS_DT),
		.FE_DT(FE_DT),
		.VIDEO_DT(VIDEO_DT),
		.MAX_LEN(MAX_LEN)
	) handler_i (
		.clock(word_clk),
		.reset(sreset),
		.enable(1'b1),

		.data(comb_word),
		.data_enable(comb_word_en),
		.data_frame(comb_word_frame),

		.lp_detect(!dphy_lp),

		.sync_wait(wait_for_sync),
		.packet_done(word_packet_done),

		.payload(payload_data),
	 	.payload_enable(payload_enable),
		.payload_frame(payload_frame),

		.vsync(vsync),
		.in_frame(in_frame),
		.in_line(in_line)
	);
endmodule
