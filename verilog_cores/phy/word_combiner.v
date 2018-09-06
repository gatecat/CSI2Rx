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
 * MIPI D-PHY word combiner
 * This receives aligned bytes from the byte aligner(s), controls the byte aligner(s)
 * and assembles the data stream back into 32-bit words for consistency across different
 * widths
 *
 */

module dphy_rx_word_combiner #(
	parameter LANES = 2
) (
	input clock, // byte clock
	input reset, // active high sync reset
	input enable, // active high clock enable
	input [8*LANES-1:0] bytes_in, // input bytes from lane byte aligners
	input [LANES-1:0] bytes_valid, // valid signals from lane byte aligners
	input wait_for_sync, // input from packet handler
	input packet_done, // packet done input from packet handler
	output byte_packet_done, // packet done output to byte aligners

	output reg [31:0] word_out, //fixed width 32-bit data out
	output reg word_enable, // word enable used when in less than 4-lane mode
	output reg word_frame // valid output high during valid packet even if word enable low
);
	wire triggered = |bytes_valid;
	wire all_valid = &bytes_valid;
	wire invalid_start = triggered && !all_valid;

	reg valid;

	reg [31:0] word_int;
	reg [1:0] byte_cnt;

	always @(posedge clock)
	begin
		if (reset) begin
			valid <= 0;
			word_int <= 0;
			byte_cnt <= 0;

			word_out <= 0;
			word_enable <= 0;
			word_frame <= 0;
		end else if (enable) begin
			if (all_valid && !valid && wait_for_sync) begin
				byte_cnt <= 0;
				word_frame <= 1'b1;
				valid <= 1'b1;
			end else if (packet_done) begin
				word_frame <= 1'b0;
				valid <= 1'b0;
			end

			if (valid) begin
				if (LANES == 4) begin
					word_out <= bytes_in;
					word_enable <= 1'b1;
				end else begin
					byte_cnt <= byte_cnt + LANES;
					word_int <= {bytes_in, word_int[31:8*LANES]};
					if ((byte_cnt + LANES) % 4 == 0) begin
						word_out <= {bytes_in, word_int[31:8*LANES]};
						word_enable <= 1'b1;
					end else begin
						word_enable <= 1'b0;
					end
				end
			end else begin
				word_enable <= 1'b0;
			end
		end
	end

	assign byte_packet_done = packet_done | invalid_start;
endmodule
