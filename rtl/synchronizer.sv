//=====================================================================================
// 		Multi-bit synchronizer (chain of flip-flops) module
//
//			Parameters:
//				DATA_WIDTH - input and output data width
//				SYNC_STAGES - number of flip-flops in the chain (>= 2)
//
//			Control signals:
//				clk - clock signal
//				rst_n - reset (Active-Low)
//
//			Data:
//				data_in - input data
//				data_out - output data
//=====================================================================================

module synchronizer
#(
	parameter DATA_WIDTH = 4, // Input and output data width
	parameter SYNC_STAGES = 2 // Number of flip-flops in the chain (>= 2)
)
(
	input clk, // Clock
	input rst_n, // Reset
	input [DATA_WIDTH - 1:0] data_in, // Input data
	output [DATA_WIDTH - 1:0] data_out // Output data
);

logic [DATA_WIDTH - 1:0] sync_reg [0:SYNC_STAGES - 1]; // A chain of a given number of flip-flops
integer i;

//=====================================================================================
// Synchronization
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		for (i = 0; i < SYNC_STAGES; i = i + 1) begin
			sync_reg[i] <= 0;
		end
	end
	else begin
		sync_reg[0] <= data_in;
		for (i = 1; i < SYNC_STAGES; i = i + 1) begin
			sync_reg[i] <= sync_reg[i - 1];
		end
	end
end

assign data_out = sync_reg[SYNC_STAGES - 1];

endmodule