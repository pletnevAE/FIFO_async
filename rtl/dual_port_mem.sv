//=====================================================================================
// 		Dual-port memory module
//
//			Parameters:
//				DATA_WIDTH - input and output data width
//				ADDR_WIDTH - memory address width
//				MEM_STYLE - memory type (D-flip-flop, BRAM)
//			
//			Control signals:
//				clk - write clock
//				w_en - write enable
//
//			Data:
//				w_addr - write address
//				r_addr - read_address
//				w_data - write data
//				r_data - read_data
//=====================================================================================
module dual_port_mem
#(
	parameter DATA_WIDTH = 8, // Input and output data width
	parameter ADDR_WIDTH = 4, // Memory address width
	parameter MEM_STYLE = "M9K" // "logic" for D-flip-flops, "M9K" for BRAM MAX10
)
(
	input clk, // Write clock
	input w_en, // Write enable
	input [ADDR_WIDTH - 1:0] w_addr, // Write address
	input [ADDR_WIDTH - 1:0] r_addr, // Read address
	input [DATA_WIDTH - 1:0] w_data, // Input data
	output [DATA_WIDTH - 1:0] r_data // Output data
);

localparam MEM_DEPTH = 1 << ADDR_WIDTH; // Memory depth

(* ramstyle = MEM_STYLE *) logic [DATA_WIDTH - 1:0] mem [0:MEM_DEPTH - 1]; // Memory

//=====================================================================================
// Data to memory
//=====================================================================================
always_ff @ (posedge clk) begin
	if (w_en) begin
		mem[w_addr] <= w_data;
	end
end

//=====================================================================================
// Memory data to output
//=====================================================================================
assign r_data = mem[r_addr];

endmodule