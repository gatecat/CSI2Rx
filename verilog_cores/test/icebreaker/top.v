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

module top(input clk12,
		   input mpsse_sda, mpsse_scl, inout cam_sda, cam_scl, output cam_enable,
		   input dphy_clk, input [1:0] dphy_data, input dphy_lp,
		   output LEDR_N, LEDG_N, LED1, LED2, LED3, LED4, LED5,
		   input BTN_N, BTN1, BTN2, BTN3,
		   output dbg_tx);

	wire areset = !BTN_N;
	assign cam_scl = mpsse_scl ? 1'bz : 1'b0;
    assign cam_sda = mpsse_sda ? 1'bz : 1'b0;
	assign cam_enable = 1'b1;
	wire video_clk;
	wire in_line, in_frame, vsync;
	wire [31:0] payload_data;
	wire payload_valid;
	wire [15:0] raw_deser;
	wire [15:0] aligned_deser;
	wire [3:0] raw_ddr;
	wire [1:0] aligned_valid;
	wire wait_sync;
	wire payload_frame;

	csi_rx_ice40 #(
		.LANES(2), // lane count
		.PAIRSWAP(2'b10), // lane pair swap (inverts data for given  lane)

		.VC(2'b00), // MIPI CSI-2 "virtual channel"
		.FS_DT(6'h12), // Frame start data type
		.FE_DT(6'h01), // Frame end data type
		.VIDEO_DT(6'h2A), // Video payload data type (6'h2A = 8-bit raw, 6'h2B = 10-bit raw, 6'h2C = 12-bit raw)
		.MAX_LEN(8192) // Max expected packet len, used as timeout
	) csi_rx_i (
		.dphy_clk_lane(dphy_clk),
		.dphy_data_lane(dphy_data),
		.dphy_lp_sense(dphy_lp),

		.areset(areset),

		.word_clk(video_clk),
		.payload_data(payload_data),
		.payload_enable(payload_valid),
		.payload_frame(payload_frame),

		.vsync(vsync),
		.in_line(in_line),
		.in_frame(in_frame),

		.dbg_aligned_valid(aligned_valid),
		.dbg_raw_deser(raw_deser),
		.dbg_raw_ddr(raw_ddr),
		.dbg_wait_sync(wait_sync)
	);


	reg [22:0] sclk_div;
	always @(posedge video_clk)
		sclk_div <= sclk_div + 1'b1;
	
	reg [15:0] vsync_monostable = 0;
	always @(posedge video_clk)
		if (vsync || vsync_monostable != 0)
			vsync_monostable <= vsync_monostable + 1'b1;
	
	
	assign LEDR_N = !sclk_div[22];
	assign LEDG_N = !(|vsync_monostable);
	assign LED1 = video_clk;
	assign {LED5, LED4, LED3, LED2} = (payload_frame&&payload_valid) ? payload_data[5:2] : 0;

	reg [5:0] read_x;
	reg [4:0] read_y;
	wire [7:0] read_data;
	downsample ds_i(
		.pixel_clock(video_clk),
		.in_line(in_line),
		.in_frame(!vsync),
		.pixel_data(payload_data),
		.data_enable(payload_frame&&payload_valid),

		.read_clock(clk12),
		.read_x(read_x),
		.read_y(read_y),
		.read_q(read_data)
	);

	reg do_send = 1'b0;
	wire uart_busy;
	reg uart_write;
	reg [13:0] btn_debounce;
	reg btn_reg;
	reg [12:0] uart_holdoff;

	always @(posedge clk12)
	begin
		btn_reg <= BTN1;

		if (btn_reg)
			btn_debounce <= 0;
		else if (!&(btn_debounce))
			btn_debounce <= btn_debounce + 1;


		uart_write <= 1'b0;
		if (btn_reg && &btn_debounce && !do_send) begin
			do_send <= 1'b1;
			read_x <= 0;
			read_y <= 0;
		end

		if (uart_busy)
			uart_holdoff <= 0;
		else if (!&(uart_holdoff))
			uart_holdoff <= uart_holdoff + 1'b1;

		if (do_send) begin
			if (read_x == 0 && read_y == 30) begin
				do_send <= 1'b0;
			end else begin
				if (&uart_holdoff && !uart_busy && !uart_write) begin
					uart_write <= 1'b1;
					if (read_x == 39) begin
						read_y <= read_y + 1'b1;
						read_x <= 0;
					end else begin
						read_x <= read_x + 1'b1;
					end
				end
			end
		end
	end

	uart uart_i (
	   // Outputs
	   .uart_busy(uart_busy),   // High means UART is transmitting
	   .uart_tx(dbg_tx),     // UART transmit wire
	   // Inputs
	   .uart_wr_i(uart_write),   // Raise to transmit byte
	   .uart_dat_i(read_data),  // 8-bit data
	   .sys_clk_i(clk12),   // System clock, 12 MHz
	   .sys_rst_i(areset)    // System reset
	);

endmodule
