//=====================================================================================
// 		Read pointer and empty logic module
//
//			Parameters:
//				ADDR_WIDTH - address width
//				ALMOST_EMPTY_VAL - value for almost empty flag
//
//			Control signals:
//				r_clk - read clock signal
//				r_rst_n - read reset (Active-Low)
//				r_en - read enable
//
//			Data:
//				w_ptr - Gray write pointer
//				r_addr - read address
//				r_ptr - Gray read pointer
//				r_empty - empty flag
//				r_almost_empty - almost empty flag
//=====================================================================================

module r_ptr_empty
#(
	parameter ADDR_WIDTH = 4, // Address width
	parameter ALMOST_EMPTY_VAL = 2 // Value for almost empty flag
)
(
	input r_clk, // Read clock (read clock domain)
	input r_rst_n, // Read reset
	input r_en, // Read enable
	input [ADDR_WIDTH:0] w_ptr, // Gray write pointer synchronized to r_clk
	output [ADDR_WIDTH - 1:0] r_addr, // Read address
	output logic [ADDR_WIDTH:0] r_ptr, // Gray read pointer
	output logic r_empty, // Empty flag
	output logic r_almost_empty // Almost empty flag
);

logic [ADDR_WIDTH:0] r_bin; // Binary read pointer
logic [ADDR_WIDTH:0] w_bin; // Binary write pointer (the sycnhronized Gray pointer to binary)
logic [ADDR_WIDTH:0] r_bin_next, r_gray_next; // Pointer values after the current operation
logic [ADDR_WIDTH:0] r_count; // Number of stored words

//=====================================================================================
// Registers
//=====================================================================================
always_ff @ (posedge r_clk, negedge r_rst_n) begin
	if (!r_rst_n) begin
		r_bin <= 0;
		r_ptr <= 0;
		r_empty <= 1'b1;
		r_almost_empty <= 1'b1;
	end
	else begin
		r_bin <= r_bin_next;
		r_ptr <= r_gray_next;
		r_empty <= (r_gray_next == w_ptr); // empty - the read pointer has caught up with the write pointer
		r_almost_empty <= (r_count <= ALMOST_EMPTY_VAL); // almost empty
	end
end

//=====================================================================================
// Pointer logic
//=====================================================================================
assign r_addr = r_bin[ADDR_WIDTH - 1:0]; // Binary read address
assign r_bin_next = r_bin + (r_en & ~r_empty); // Next binary read pointer
assign r_gray_next = (r_bin_next >> 1) ^ r_bin_next; // Next Gray read pointer

//=====================================================================================
// Gray to binary conversion of the synchronized write pointer
//	B[MSB] = G[MSB], B[i] = B[i + 1] ^ G[i]
//=====================================================================================
integer i;
always_comb begin
	w_bin[ADDR_WIDTH] = w_ptr[ADDR_WIDTH];
	for (i = ADDR_WIDTH - 1; i >= 0; i = i - 1) begin
		w_bin[i] = w_bin[i + 1] ^ w_ptr[i];
	end
end

//=====================================================================================
// Number of stored words
//=====================================================================================
assign r_count = w_bin - r_bin;

endmodule