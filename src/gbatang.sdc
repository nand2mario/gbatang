# set_multicycle_path: https://docs.xilinx.com/r/en-US/ug903-vivado-using-constraints/set_multicycle_path-Syntax

# SDRAM clock @ 67
create_clock -name clk67 -period 14.92 -waveform {0 7.463} [get_nets {clk67}]

# Main clock @ 16.75
#create_clock -name clk16 -period 59.49  -waveform {0 29.74} [get_nets {clk16}]
create_generated_clock -name clk16 -source [get_nets {clk67}] -divide_by 4 [get_nets {clk16}]

# GPU clock @ 33.5
#create_clock -name clk33 -period 29.74 -waveform {0 14.87} [get_nets {clk33}]
#create_generated_clock -name clk33 -source [get_nets {clk67}] -divide_by 2 [get_nets {clk33}]

# 4-cycle path from SDRAM to CPU/RV
set_multicycle_path 4 -setup -start -from [get_clocks {clk67}] -to [get_clocks {clk16}]
set_multicycle_path 3 -hold -start -from [get_clocks {clk67}] -to [get_clocks {clk16}]

# 4-cycle path from RV/CPU to SDRAM
set_multicycle_path 4 -setup -end -from [get_clocks {clk16}] -to [get_clocks {clk67}]
set_multicycle_path 3 -hold -end -from [get_clocks {clk16}] -to [get_clocks {clk67}]

# sdram.cpu_dout through the CPU back to sdram: 4 cycles
set_multicycle_path 4 -setup -end -from [get_pins {sdram/cpu_rdata*/*}] -to [get_clocks {clk67}]
set_multicycle_path 3 -hold -end -from [get_pins {sdram/cpu_rdata*/*}] -to [get_clocks {clk67}]

# HDMI clocks
create_clock -name hclk5 -period 2.694 -waveform {0 1.347} [get_nets {hclk5}]
create_generated_clock -name hclk -source [get_nets {hclk5}] -master_clock hclk5 -divide_by 5 [get_nets {hclk}]

# 2-cycle path from CPU to GPU as GPU uses data on rising edge of clk16
#set_multicycle_path 2 -setup -end -from [get_clocks {clk16}] -to [get_clocks {clk33}]
#set_multicycle_path 1 -hold -end -from [get_clocks {clk16}] -to [get_clocks {clk33}]

# false paths
# No paths from VRAM to SDRAM (through CPU rom_data). No need to execute code from VRAM.
set_false_path -from [get_pins {gpu/drawer/ivram_lo/*/*}] -to [get_pins {sdram/*/*}]
