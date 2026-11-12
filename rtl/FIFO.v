//=====================================================================================
// 		Asynchronous FIFO module
//
//			Parameters:
//				DATA_WIDTH - input and output data width
//				ADDR_WIDTH - address width
//				ALMOST_FULL_VAL - value for almost full flag
//				ALMOST_EMPTY_VAL - value for almost empty flag
//				MEM_STYLE - memory type (D-flip-flop, BRAM)
//
//			Control signals:
//				w_clk - write clock signal
//				w_rst_n - write reset (Active-Low)
//				w_en - write enable
//				r_clk - read clock signal
//				r_rst_n - read reset (Active-Low)
//				r_en - read enable
//
//			Data:
//				w_data - write data
//				r_data - read data
//				w_full - full flag
//				r_empty - empty flag
//				w_almost_full - almost full flag
//				r_almost_empty - almost empty flag
//=====================================================================================

module FIFO
#(
	parameter DATA_WIDTH = 8, // Input and output data width
	parameter ADDR_WIDTH = 4, // Memory address width
	parameter ALMOST_FULL_VAL = 2 ** ADDR_WIDTH - 2, // Value for almost full flag
	parameter ALMOST_EMPTY_VAL = 2, // Value for almost empty flag
	parameter MEM_STYLE = "M9K" // "logic" for D-flip-flops, "M9K" for BRAM MAX10
)
(
	input w_clk, // Write clock
	input w_rst_n, // Write reset
	input w_en, // Write enable
	input [DATA_WIDTH - 1:0] w_data, // Write data
	input r_clk, // Read clock
	input r_rst_n, // Read reset
	input r_en, // Read enable
	output [DATA_WIDTH - 1:0] r_data, // Read data
	output w_full, // Full flag
	output r_empty, // Empty flag
	output w_almost_full, // Almost full flag
	output r_almost_empty // Almost empty flag
);

wire [ADDR_WIDTH - 1:0] w_addr, r_addr; // Memory addresses (lower bits of the binary pointers)
wire [ADDR_WIDTH:0] w_ptr, r_ptr; // Gray-coded pointers, registered in their own clock domain 
wire [ADDR_WIDTH:0] w_ptr_sync, r_ptr_sync; // Gray-coded pointers, synchronized to the other clock domain

//=====================================================================================
// Dual port memory instantiation
//=====================================================================================
dual_port_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .MEM_STYLE(MEM_STYLE)) inst_mem
(
	.clk(w_clk),
	.w_en(w_en & ~w_full),
	.w_addr(w_addr),
	.r_addr(r_addr),
	.w_data(w_data),
	.r_data(r_data)
);

//=====================================================================================
// Read pointer synchronizer instantiation
//=====================================================================================
synchronizer #(.DATA_WIDTH(ADDR_WIDTH + 1), .SYNC_STAGES(2)) inst_sync_r2w
(
	.clk(w_clk),
	.rst_n(w_rst_n),
	.data_in(r_ptr),
	.data_out(r_ptr_sync)
);

//=====================================================================================
// Write pointer synchronizer instantiation
//=====================================================================================
synchronizer #(.DATA_WIDTH(ADDR_WIDTH + 1), .SYNC_STAGES(2)) inst_sync_w2r
(
	.clk(r_clk),
	.rst_n(r_rst_n),
	.data_in(w_ptr),
	.data_out(w_ptr_sync)
);

//=====================================================================================
// Write pointer and full logic module instantiation
//=====================================================================================
w_ptr_full #(.ADDR_WIDTH(ADDR_WIDTH), .ALMOST_FULL_VAL(ALMOST_FULL_VAL)) inst_w_ptr_full
(
	.w_clk(w_clk),
	.w_rst_n(w_rst_n),
	.w_en(w_en),
	.r_ptr(r_ptr_sync),
	.w_addr(w_addr),
	.w_ptr(w_ptr),
	.w_full(w_full),
	.w_almost_full(w_almost_full)
);

//=====================================================================================
// Read pointer and empty logic module instantiation
//=====================================================================================
r_ptr_empty #(.ADDR_WIDTH(ADDR_WIDTH), .ALMOST_EMPTY_VAL(ALMOST_EMPTY_VAL)) inst_r_ptr_empty
(
	.r_clk(r_clk),
	.r_rst_n(r_rst_n),
	.r_en(r_en),
	.w_ptr(w_ptr_sync),
	.r_addr(r_addr),
	.r_ptr(r_ptr),
	.r_empty(r_empty),
	.r_almost_empty(r_almost_empty)
);

endmodule