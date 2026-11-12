//=====================================================================================
// 		Write pointer and full logic module
//
//			Parameters:
//				ADDR_WIDTH - address width
//				ALMOST_FULL_VAL - value for almost full flag
//
//			Control signals:
//				w_clk - write clock signal
//				w_rst_n - write reset (Active-Low)
//				w_en - write enable
//
//			Data:
//				r_ptr - Gray read pointer
//				w_addr - write address
//				w_ptr - Gray write pointer
//				w_full - full flag
//				w_almost_full - almost full flag
//=====================================================================================

module w_ptr_full
#(
	parameter ADDR_WIDTH = 4, // Address width
	parameter ALMOST_FULL_VAL = 2 ** ADDR_WIDTH - 2 // Value for almost full flag
)
(
	input w_clk, // Write clock (write clock domain)
	input w_rst_n, // Write reset
	input w_en, // Write enable
	input [ADDR_WIDTH:0] r_ptr, // Gray read pointer synchronized to w_clk
	output [ADDR_WIDTH - 1:0] w_addr, // Write address
	output logic [ADDR_WIDTH:0] w_ptr, // Gray write pointer
	output logic w_full, // Full flag
	output logic w_almost_full // Almost full flag
);

logic [ADDR_WIDTH:0] w_bin; // Binary write pointer
logic [ADDR_WIDTH:0] r_bin; // Binary read pointer (the synchonized Gray pointer converted to binary)
logic [ADDR_WIDTH:0] w_bin_next, w_gray_next; // Pointer values after the current operation
logic [ADDR_WIDTH:0] w_count; // Number of stored words

//=====================================================================================
// Registers
//=====================================================================================
always_ff @ (posedge w_clk, negedge w_rst_n) begin
	if (!w_rst_n) begin
		w_bin <= 0;
		w_ptr <= 0;
		w_full <= 1'b0;
		w_almost_full <= 1'b0;
	end
	else begin
		w_bin <= w_bin_next;
		w_ptr <= w_gray_next;
		w_full <= (w_gray_next == {~r_ptr[ADDR_WIDTH:ADDR_WIDTH - 1], r_ptr[ADDR_WIDTH - 2:0]}); // Full - the Gray pointers are equal with the two upper bits inverted
		w_almost_full <= (w_count >= ALMOST_FULL_VAL); // Almost full
	end
end

//=====================================================================================
// Pointer logic
//=====================================================================================
assign w_addr = w_bin[ADDR_WIDTH - 1:0]; // Binary write address
assign w_bin_next = w_bin + (w_en & ~w_full); // Next binary write pointer
assign w_gray_next = (w_bin_next >> 1) ^ w_bin_next; // Next Gray write pointer

//=====================================================================================
// Gray to binary conversion of the synchronized read pointer
//	B[MSB] = G[MSB], B[i] = B[i + 1] ^ G[i]
//=====================================================================================
integer i;
always_comb begin
	r_bin[ADDR_WIDTH] = r_ptr[ADDR_WIDTH];
	for (i = ADDR_WIDTH - 1; i >= 0; i = i - 1) begin
		r_bin[i] = r_bin[i + 1] ^ r_ptr[i];
	end
end

//=====================================================================================
// Number of stored words
//=====================================================================================
assign w_count = w_bin - r_bin;

endmodule