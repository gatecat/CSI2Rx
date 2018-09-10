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
 * Simple downsampler and buffer 640x480 => 40x30
*/

module downsample (
	input pixel_clock,
	input in_line,
	input in_frame,
	input [31:0] pixel_data,
	input data_enable,

	input read_clock,
	input [5:0] read_x,
	input [4:0] read_y,
	output reg [7:0] read_q
);


	reg [7:0] buffer[0:2047];

	reg [11:0] pixel_acc;
	reg [7:0] pixel_x;
	reg [8:0] pixel_y;
	reg last_in_line;

	wire [11:0] next_acc = pixel_acc + pixel_data[7:0] + pixel_data[15:8] + pixel_data[23:16] + pixel_data[31:24];

	always @(posedge pixel_clock)
	begin
		if (!in_frame) begin
			pixel_acc <= 0;
			pixel_x <= 0;
			pixel_y <= 0;
			last_in_line <= in_line;
		end else begin
			if (in_line && data_enable) begin
				if (pixel_y[3:0] == 0) begin
					if (&(pixel_x[1:0])) begin
						pixel_acc <= 0;
						buffer[{pixel_y[8:4], pixel_x[7:2]}] <= next_acc[11:4];
					end else begin
						pixel_acc <= next_acc;
					end
					if (pixel_x < 160)
						pixel_x <= pixel_x + 1;
				end
			end else if (!in_line) begin
				pixel_x <= 0;
				pixel_acc <= 0;
				if (last_in_line)
					pixel_y <= pixel_y + 1'b1;
			end
			last_in_line <= in_line;
		end
	end

	always @(posedge read_clock)
		read_q <= buffer[{read_y, read_x}];
endmodule
