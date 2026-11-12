create_clock -name {clk_write} -period 10.00 -waveform { 0.000 5.00 } [get_ports {w_clk}]
create_clock -name {clk_read} -period 22.00 -waveform { 0.000 11.00 } [get_ports {r_clk}]
set_clock_groups -asynchronous -group [get_clocks clk_write] -group [get_clocks clk_read]
set_max_delay 22.0 -from [get_cells {inst_w_ptr_full|w_ptr*}] \
						 -to [get_cells {inst_sync_w2r|sync_reg[0]*}]
set_max_delay 10.0 -from [get_cells {inst_r_ptr_empty|r_ptr*}] \
				       -to [get_cells {*inst_sync_r2w|sync_reg[0]*}]
derive_clock_uncertainty
set_false_path -from [get_ports w_rst_n]
set_false_path -from [get_ports r_rst_n]