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
 * MIPI D-PHY byte aligner
 * This receives raw, unaligned bytes (which could contain part of two actual bytes)
 * from the SERDES and aligns them by looking for the D-PHY sync pattern
 *
 * When wait_for_sync is high the entity will wait until it sees the valid header at some alignment,
 * at which point the found alignment is locked until packet_done is asserted
 *
 * valid_data is asserted as soon as the sync pattern is found, so the next byte
 * contains the CSI packet header
 *
 * In reality to avoid false triggers we must look for a valid sync pattern on all k lanes,
 * if this does not occur the word aligner (a seperate entity) will assert packet_done immediately
 *
 */
`default_nettype none
module dphy_rx_byte_align(
	input clock, // byte clock
	input reset, // active high sync reset
	input enable, // byte clock enable
	input [7:0] deser_byte, // raw bytes from iserdes
	input wait_for_sync, // when high will look for a sync pattern if sync not already found
	input packet_done, // assert to reset synchronisation status
	output reg valid_data, // goes high as soon as sync pattern is found (so data out on next cycle contains header)
	output reg [7:0] data_out //aligned data out, typically delayed by 2 cycles
);

	reg [7:0] curr_byte;
	reg [7:0] last_byte;
	reg [7:0] shifted_byte;

	reg found_sync;
	reg [2:0] sync_offs; // found offset of sync pattern
	reg [2:0] data_offs; // current data offset

	always @(posedge clock)
	begin
		if (reset) begin
			valid_data <= 1'b0;
			last_byte <= 0;
			curr_byte <= 0;
			data_out <= 0;
			data_offs <= 0;
		end else if (enable) begin
			last_byte <= curr_byte;
			curr_byte <= deser_byte;
			data_out <= shifted_byte;

			if (packet_done) begin
				valid_data <= found_sync;
			end else if (wait_for_sync && found_sync && !valid_data) begin
				// Waiting for sync, just found it now so use sync position as offset
				valid_data <= 1'b1;
				data_offs <= sync_offs;
			end
		end
	end

	localparam [7:0] sync_word = 8'b10111000;
	reg was_found;
	reg [2:0] offset;
	integer i;

	wire [15:0] concat_word = {curr_byte, last_byte};

	always @(*)
	begin
		offset = 0;
		was_found = 1'b0;
		found_sync = 1'b0;
		sync_offs = 0;
		for (i = 0; i < 8; i = i + 1) begin
			if ((concat_word[(1+i) +: 8] == sync_word) && (last_byte[i:0]  == 0)) begin
				was_found = 1'b1;
				offset = i;
			end
		end
		if (was_found) begin
			found_sync = 1'b1;
			sync_offs = offset;
		end
	end

	assign shifted_byte = concat_word[(1 + data_offs) +: 8];


endmodule
