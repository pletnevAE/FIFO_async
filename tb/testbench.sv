//=====================================================================================
//		Asynchronous FIFO Testbench Module
//
//		The module is used to test asynchronous FIFO.
//		The test was conducted in ModelSim 10.6d.
//		To verify the correct operation of the FIFO module, it's necessary to display signal waveforms.
//		The console displays messages about the start of each test and errors;
//		Finally, a success/failure message is displayed, along with the number of errors, if any.
//
//=====================================================================================

`timescale 1 ns/1 ps

module testbench;

//=====================================================================================
// Testbench parameters
//=====================================================================================
parameter W_CLK_PERIOD = 10; // Write clock period in PASS 1, ns (swapped in PASS 2)
parameter R_CLK_PERIOD = 22; // Read clock period in PASS 1, ns (swapped in PASS 2)
parameter R_CLK_OFFSET = 3; // Read clock phase shift, ns
parameter RESET_CYCLES = 10; // Number of clock cycles of each domain in reset
parameter SETTLE_CYCLES = 6; // Number of clock cycles of each domain to wait until the flags settle
parameter FULL_ATTEMPTS = 5; // Number of write attempts to the full FIFO
parameter EMPTY_ATTEMPTS = 5; // Number of read attempts from the empty FIFO
parameter RAND_CYCLES = 1000; // Number of clock cycles of each phase of the random test
parameter DATA_WIDTH = 8; // Input and output data width
parameter ADDR_WIDTH = 4; // FIFO address width
parameter ALMOST_FULL_VAL = 2 ** ADDR_WIDTH - 2; // Value for almost full flag
parameter ALMOST_EMPTY_VAL = 2; // Value for almost empty flag
parameter MEM_STYLE = "M9K"; // FIFO memory type (D-flip-flop, BRAM)

localparam FIFO_DEPTH = 2 ** ADDR_WIDTH; // FIFO depth
localparam TIMEOUT = 100 * (W_CLK_PERIOD + R_CLK_PERIOD) * (RAND_CYCLES + 100); // Simulation time limit, ns

//=====================================================================================
// Testbench signals
//=====================================================================================	
logic w_clk; // Write clock
logic w_rst_n; // Write reset
logic w_en; // Write enable
logic [DATA_WIDTH - 1:0] w_data; // Write data
logic r_clk; // Read clock
logic r_rst_n; // Read reset
logic r_en; // Read enable
logic [DATA_WIDTH - 1:0] r_data; // Read data
logic w_full; // FIFO full
logic r_empty; // FIFO empty
logic w_almost_full; // FIFO almost full
logic r_almost_empty; // FIFO almost empty

//=====================================================================================
// FIFO Instantiation
//=====================================================================================
FIFO #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .ALMOST_FULL_VAL(ALMOST_FULL_VAL), .ALMOST_EMPTY_VAL(ALMOST_EMPTY_VAL), .MEM_STYLE(MEM_STYLE)) dut
(
	.w_clk(w_clk),
	.w_rst_n(w_rst_n),
	.w_en(w_en),
	.w_data(w_data),
	.r_clk(r_clk),
	.r_rst_n(r_rst_n),
	.r_en(r_en),
	.r_data(r_data),
	.w_full(w_full),
	.r_empty(r_empty),
	.w_almost_full(w_almost_full),
	.r_almost_empty(r_almost_empty)
);

//=====================================================================================
// Clock signals generation
//=====================================================================================
realtime w_period = W_CLK_PERIOD;
realtime r_period = R_CLK_PERIOD;

initial begin
	w_clk = 0;
	forever w_clk = #(w_period/2) ~w_clk;
end

initial begin
	r_clk = 0;
	#(R_CLK_OFFSET);
	forever r_clk = #(r_period/2) ~r_clk;
end

//=====================================================================================
// Scoreboard Class
//=====================================================================================
class Scoreboard;
	logic [DATA_WIDTH - 1:0] ref_queue[$];
	int w_prev_count = 0;
	int r_prev_count = 0;
	int max_count = 0;
	int error_count = 0;
	int wr_accepted = 0;
	int rd_accepted = 0;
	int wr_rejected = 0;
	int rd_rejected = 0;
	
//=====================================================================================
// Reference FIFO reset and number of words functions
//=====================================================================================	
	function void reset ();
		ref_queue.delete();
		w_prev_count = 0;
		r_prev_count = 0;
	endfunction
	
	function int count ();
		return ref_queue.size();
	endfunction
	
	function void clear_stats ();
		max_count = 0;
		wr_accepted = 0;
		rd_accepted = 0;
		wr_rejected = 0;
		rd_rejected = 0;
	endfunction

//=====================================================================================
// Reference FIFO write update function
//=====================================================================================
	function void w_update (logic en, logic full_before, logic [DATA_WIDTH - 1:0] din);
		w_prev_count = ref_queue.size();
		if (en && !full_before) begin
			if (ref_queue.size() >= FIFO_DEPTH) begin
				$error("[ERROR] Overflow! Write is accepted, but the FIFO already holds %0d words (w_full = 0)", ref_queue.size());
				error_count++;
			end
			else begin
				ref_queue.push_back(din);
				wr_accepted++;
				if (ref_queue.size() > max_count) begin
					max_count = ref_queue.size();
				end
			end
		end
		else if (en) begin
			wr_rejected++;
		end
	endfunction
	
//=====================================================================================
// Reference FIFO read update function
//=====================================================================================
	function void r_update (logic en, logic empty_before, logic [DATA_WIDTH - 1:0] dout_before);
		logic [DATA_WIDTH - 1:0] expected_data;
		r_prev_count = ref_queue.size();
		if (en && !empty_before) begin
			if (ref_queue.size() == 0) begin
				$error("[ERROR] Underflow! Read is accepted, but the FIFO holds no words (r_empty = 0)");
				error_count++;
			end
			else begin
				expected_data = ref_queue.pop_front();
				rd_accepted++;
				if (dout_before != expected_data) begin
					$error("[ERROR] Data out mismatch! Words in FIFO before the read: %0d. Expected data: %0b | Got data: %0b", r_prev_count, expected_data, dout_before);
					error_count++;
				end
			end
		end
		else if (en) begin
			rd_rejected++;
		end
	endfunction
	
//=====================================================================================
// Write domain check function
//=====================================================================================
	function void w_check (logic f, logic af);
		if (ref_queue.size() == FIFO_DEPTH && !f) begin
			$error("[ERROR] Full is not asserted! Words in FIFO: %0d", ref_queue.size());
			error_count++;
		end
		if (w_prev_count >= ALMOST_FULL_VAL && !af) begin
			$error("[ERROR] Almost full is not asserted! Words in FIFO before the clock edge: %0d", w_prev_count);
			error_count++;
		end
	endfunction
	
//=====================================================================================
// Read domain check function
//=====================================================================================
	function void r_check (logic e, logic ae);
		if (ref_queue.size() == 0 && !e) begin
			$error("[ERROR] Empty is not asserted! Words in FIFO: %0d", ref_queue.size());
			error_count++;
		end
		if (r_prev_count <= ALMOST_EMPTY_VAL && !ae) begin
			$error("[ERROR] Almost empty is not asserted! Words in FIFO before the clock edge: %0d", r_prev_count);
			error_count++;
		end
	endfunction
	
//=====================================================================================
// Check function at rest
//=====================================================================================
	function void check_settled (logic f, logic e, logic af, logic ae, logic [DATA_WIDTH - 1:0] dout);
		int n = ref_queue.size();
		logic expected_full = (n == FIFO_DEPTH);
		logic expected_empty = (n == 0);
		logic expected_almost_full = (n >= ALMOST_FULL_VAL);
		logic expected_almost_empty = (n <= ALMOST_EMPTY_VAL);
		
		if (f != expected_full) begin
			$error("[ERROR] Full mismatch at rest! Words in FIFO: %0d. Expected full: %0b | Got full: %0b", n, expected_full, f);
			error_count++;
		end
		if (e != expected_empty) begin
			$error("[ERROR] Empty mismatch at rest! Words in FIFO: %0d. Expected empty: %0b | Got empty: %0b", n, expected_empty, e);
			error_count++;
		end
		if (af != expected_almost_full) begin
			$error("[ERROR] Almost full mismatch at rest! Words in FIFO: %0d. Expected almost full: %0b | Got almost full: %0b", n, expected_almost_full, af);
			error_count++;
		end
		if (ae != expected_almost_empty) begin
			$error("[ERROR] Almost empty mismatch at rest! Words in FIFO: %0d. Expected almost empty: %0b | Got almost empty: %0b", n, expected_almost_empty, ae);
			error_count++;
		end
		if (n != 0) begin
			if (dout != ref_queue[0]) begin
				$error("[ERROR] Data out mismatch at rest! Words in FIFO: %0d. Expected data: %0b | Got data: %0b", n, ref_queue[0], dout);
				error_count++;
			end
		end
	endfunction
endclass

Scoreboard sb = new();

//=====================================================================================
// Scoreboard update and check in every clock cycle of each domain
//=====================================================================================
logic mon_en = 1'b0;

always @ (posedge w_clk) begin
	if (mon_en) begin
		sb.w_update(w_en, w_full, w_data);
		#1;
		sb.w_check(w_full, w_almost_full);
	end
end

always @ (posedge r_clk) begin
	if (mon_en) begin
		sb.r_update(r_en, r_empty, r_data);
		#1;
		sb.r_check(r_empty, r_almost_empty);
	end
end

//=====================================================================================
// Stimulus tasks: one clock cycle of write/read domain
//=====================================================================================
task automatic w_drive (input logic en);
	w_en = en;
	w_data = $urandom();
	@(negedge w_clk);
endtask

task automatic r_drive (input logic en);
	r_en = en;
	@(negedge r_clk);
endtask

//=====================================================================================
// Task to wait until the flags settle
//=====================================================================================
task automatic settle ();
	repeat (SETTLE_CYCLES) @(negedge w_clk);
	repeat (SETTLE_CYCLES) @(negedge r_clk);
endtask

//=====================================================================================
// Check task at rest
//=====================================================================================
task automatic check_at_rest ();
	sb.check_settled(w_full, r_empty, w_almost_full, r_almost_empty, r_data);
endtask

//=====================================================================================
// Reset task
//=====================================================================================
task automatic apply_reset ();
	mon_en = 1'b0;
	w_en = 1'b0;
	r_en = 1'b0;
	@(negedge w_clk);
	@(negedge r_clk);
	w_rst_n = 1'b0;
	r_rst_n = 1'b0;
	sb.reset();
	repeat (RESET_CYCLES) @(posedge w_clk);
	repeat (RESET_CYCLES) @(posedge r_clk);
	#1;
	check_at_rest();
	fork
		begin
			@(negedge w_clk);
			w_rst_n = 1'b1;
		end
		begin
			@(negedge r_clk);
			r_rst_n = 1'b1;
		end
	join
	settle();
	check_at_rest();
	mon_en = 1'b1;
endtask

//=====================================================================================
// Task to put several words to the FIFO before the reset
//=====================================================================================
task automatic fill_before_reset ();
	@(negedge w_clk);
	repeat (5) begin
		w_drive(1'b1);
	end
	w_en = 1'b0;
	settle();
	$display("[%0t] The FIFO holds %0d words, the reset will be applied now", $time, sb.count());
endtask

//=====================================================================================
// Random read and write task
//=====================================================================================
task automatic random_phase (input real wr_rate, input real rd_rate, input int cycles);
	real t_slow;
	real p_wr;
	real p_rd;
	int w_cycles;
	int r_cycles;
	t_slow = (w_period > r_period) ? w_period : r_period;
	p_wr = wr_rate * w_period / t_slow;
	p_rd = rd_rate * r_period / t_slow;
	w_cycles = int'(cycles * t_slow / w_period);
	r_cycles = int'(cycles * t_slow / r_period);
	fork
		begin
			@(negedge w_clk);
			repeat (w_cycles) begin
				w_drive(($urandom_range(0, 9999) / 100.0) < p_wr);
			end
			w_en = 1'b0;
		end
		begin
			@(negedge r_clk);
			repeat (r_cycles) begin
				r_drive(($urandom_range(0, 9999) / 100.0) < p_rd);
			end
			r_en = 1'b0;
		end
	join
endtask

//=====================================================================================
// Tests
//=====================================================================================
task automatic run_tests ();
	// Test 1: Writing to the FIFO before setting almost full
	$display("[%0t] TEST 1: Writing to the FIFO before setting almost full", $time);
	@(negedge w_clk);
	while (sb.count() != ALMOST_FULL_VAL) begin
		w_drive(1'b1);
	end
	w_en = 1'b0;
	settle();
	check_at_rest();
	
	// Test 2: Writing to the FIFO before setting full, then write attempts to the full FIFO
	$display("[%0t] TEST 2: Writing to the FIFO before setting full", $time);
	@(negedge w_clk);
	while (sb.count() != FIFO_DEPTH) begin
		w_drive(1'b1);
	end
	repeat (FULL_ATTEMPTS) begin
		w_drive(1'b1);
	end
	w_en = 1'b0;
	settle();
	check_at_rest();
	
	// Test 3: Reading from the FIFO before setting almost empty
	$display("[%0t] TEST 3: Reading from the FIFO before setting almost empty", $time);
	@(negedge r_clk);
	while (sb.count() != ALMOST_EMPTY_VAL) begin
		r_drive(1'b1);
	end
	r_en = 1'b0;
	settle();
	check_at_rest();
	
	// Test 4: Reading from the FIFO before setting empty, then read attempts from the empty FIFO
	$display("[%0t] TEST 4: Reading from the FIFO before setting empty", $time);
	@(negedge r_clk);
	while (sb.count() != 0) begin
		r_drive(1'b1);
	end
	repeat (EMPTY_ATTEMPTS) begin
		r_drive(1'b1);
	end
	r_en = 1'b0;
	settle();
	check_at_rest();
	
	// Test 5: Random reading and writing (balanced, write-heavy and read-heavy phases)
	$display("[%0t] TEST 5: Random reading and writing", $time);
	random_phase(80, 80, RAND_CYCLES);
	random_phase(100, 60, RAND_CYCLES);
	random_phase(60, 100, RAND_CYCLES);
	settle();
	check_at_rest();
endtask

//=====================================================================================
// Statistics task
//=====================================================================================
task automatic print_stats ();
	$display("[%0t] Statistics: writes accepted/rejected(full) = %0d/%0d, reads accepted/rejected(empty) = %0d/%0d, max words in FIFO = %0d", $time, sb.wr_accepted, sb.wr_rejected, sb.rd_accepted, sb.rd_rejected, sb.max_count);
	sb.clear_stats();
endtask

//=====================================================================================
// Watchdog
//=====================================================================================
logic tests_done = 1'b0;

initial begin
	#(TIMEOUT);
	if (!tests_done) begin
		$display("[FAIL] TESTS FAILED! Simulation timeout, the testbench is stuck.");
		$stop;
	end
end

//=====================================================================================
// Main initial block
//=====================================================================================
initial begin
	$display("\n\nSTARTING TESTBENCH FOR ASYNCHRONOUS FIFO (DATA_WIDTH = %0d, ADDR_WIDTH = %0d, ALMOST_FULL_VAL = %0d, ALMOST_EMPTY_VAL = %0d)", DATA_WIDTH, ADDR_WIDTH, ALMOST_FULL_VAL, ALMOST_EMPTY_VAL);
	w_rst_n = 0;
	r_rst_n = 0;
	w_en = 0;
	r_en = 0;
	w_data = 0;
	
	// PASS 1: initial clock periods
	$display("[%0t] PASS 1: write clock period = %0.1f ns, read clock period = %0.1f ns", $time, w_period, r_period);
	apply_reset();
	run_tests();
	print_stats();
	
	// PASS 2: reset and swapped clock periods
	fill_before_reset();
	w_period = R_CLK_PERIOD;
	r_period = W_CLK_PERIOD;
	$display("[%0t] PASS 2: reset, write clock period = %0.1f ns, read clock period = %0.1f ns", $time, w_period, r_period);
	apply_reset();
	run_tests();
	print_stats();
	
	if (sb.error_count == 0) begin
		$display("[PASS] ASYNCHRONOUS FIFO MODULE TESTS PASSED!");
	end
	else begin
		$display("[FAIL] TESTS FAILED! %0d errors detected!", sb.error_count);
	end
	tests_done = 1'b1;
	$stop;
end

endmodule