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
 * MIPI CSI-2 header ECC computation
 */

 module csi_header_ecc (
	 input [23:0] data,
	 output [7:0] ecc
);
	assign ecc[7:6] = 2'b00;
	assign ecc[5] = data[10] ^ data[11] ^ data[12] ^ data[13] ^ data[14] ^ data[15] ^ data[16] ^ data[17] ^ data[18] ^ data[19] ^ data[21] ^ data[22] ^ data[23];
	assign ecc[4] = data[4] ^ data[5] ^ data[6] ^ data[7] ^ data[8] ^ data[9] ^ data[16] ^ data[17] ^ data[18] ^ data[19] ^ data[20] ^ data[22] ^ data[23];
	assign ecc[3] = data[1] ^ data[2] ^ data[3] ^ data[7] ^ data[8] ^ data[9] ^ data[13] ^ data[14] ^ data[15] ^ data[19] ^ data[20] ^ data[21] ^ data[23];
	assign ecc[2] = data[0] ^ data[2] ^ data[3] ^ data[5] ^ data[6] ^ data[9] ^ data[11] ^ data[12] ^ data[15] ^ data[18] ^ data[20] ^ data[21] ^ data[22];
	assign ecc[1] = data[0] ^ data[1] ^ data[3] ^ data[4] ^ data[6] ^ data[8] ^ data[10] ^ data[12] ^ data[14] ^ data[17] ^ data[20] ^ data[21] ^ data[22] ^ data[23];
	assign ecc[0] = data[0] ^ data[1] ^ data[2] ^ data[4] ^ data[5] ^ data[7] ^ data[10] ^ data[11] ^ data[13] ^ data[16] ^ data[20] ^ data[21] ^ data[22] ^ data[23];
endmodule
