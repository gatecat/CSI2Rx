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

/**
 * MIPI CSI-2 receive packet handler
 *
 * This controls wait_for_sync and packet_done handshaking with
 * byte/word aligners; keeps track of whether in frame
 * by detecting FS/FE; and extracts video payload from long packets
 */

module csi_rx_packet_handler #(
	parameter [1:0] VC = 2'b00, // MIPI CSI-2 "virtual channel"
	parameter [5:0] FS_DT = 6'h00, // Frame start data type
	parameter [5:0] FE_DT = 6'h01, // Frame end data type
	parameter [5:0] VIDEO_DT = 6'h2A, // Video payload data type (6'h2A = 8-bit raw, 6'h2B = 10-bit raw, 6'h2C = 12-bit raw)
	parameter [15:0] MAX_LEN = 8192 // Max expected packet len, used as timeout
) (
	input clock, // byte/word clock
	input reset, // active high sync reset
	input enable, // active high clock enable

	input [31:0] data, // data from word aligner
	input data_enable, // data enable for less than 4-lane links
	input data_frame, // data framing from word combiner

	input lp_detect, // D-PHY LP mode detection, forces EoP

	output sync_wait, // sync wait output to byte/word handlers
	output packet_done, // packet done output to word combiner

	output reg [31:0] payload, // payload output
	output reg payload_enable, // payload data enable
	output reg payload_frame, // payload framing

	output reg vsync, // quasi-vsync for FS signal
	output reg in_frame,
	output reg in_line
);

	wire [1:0] hdr_vc;
	wire [5:0] hdr_dt;
	wire [15:0] hdr_packet_len;
	wire [7:0] hdr_ecc, expected_ecc;
	wire long_packet, valid_packet;
	wire is_hdr;

	reg [15:0] packet_len;
	reg [2:0] state;
	reg [15:0] bytes_read;

	always @(posedge clock)
	begin
		if (reset) begin
			state <= 3'b000;

			packet_len <= 0;
			bytes_read <= 0;

			payload <= 0;
			payload_enable <= 0;
			payload_frame <= 0;

			vsync <= 0;
			in_frame <= 0;
			in_line <= 0;
		end else if (enable) begin

			if (lp_detect) begin
				state <= 3'b000;
			end else begin
				case (state)
					3'b000: state <= 3'b001; // init

					3'b001: begin // wait for start
						bytes_read <= 0;
						if (data_enable) begin
							packet_len <= hdr_packet_len;
							if (long_packet && valid_packet)
								state <= 3'b010;
							else
								state <= 3'b011;
						end
					end

					3'b010: begin // rx long packet
						if (data_enable) begin
							if ((bytes_read < (packet_len - 4)) && (bytes_read < MAX_LEN))
								bytes_read <= bytes_read + 4;
							else
								state <= 3'b011;
						end
					end

					3'b011: state <= 3'b100; // end of packet, assert packet_done
					3'b100: state <= 3'b001; // wait one cycle and reset

					default: state <= 3'b000;
				endcase
			end

			if (is_hdr && hdr_dt == FS_DT && valid_packet)
				in_frame <= 1'b1;
			else if (is_hdr && hdr_dt == FE_DT && valid_packet)
				in_frame <= 1'b0;

			if (is_hdr && hdr_dt == VIDEO_DT && valid_packet)
				in_line <= 1'b1;
			else if (state != 3'b010 && state != 3'b001)
				in_line <= 1'b0;

			vsync <= (is_hdr && hdr_dt == FS_DT && valid_packet);

			payload <= data;
			payload_frame <= (state == 3'b010);
			payload_enable <= (state == 3'b010) && data_enable;
		end
	end

	assign hdr_vc = data[7:6];
	assign hdr_dt = data[5:0];
	assign hdr_packet_len = data[23:8];
	assign hdr_ecc = data[31:24];

	csi_header_ecc ecc_i (
		.data(data[23:0]),
		.ecc(expected_ecc)
	);

	assign long_packet = hdr_dt > 6'h0F;
	assign valid_packet = (hdr_vc == VC)
							&& (hdr_dt == FS_DT || hdr_dt == FE_DT || hdr_dt == VIDEO_DT)
							&& (hdr_ecc == expected_ecc);

	assign is_hdr = data_enable && (state == 3'b001);

	assign sync_wait = (state == 3'b001);
	assign packet_done = (state == 3'b011) || lp_detect;
endmodule
