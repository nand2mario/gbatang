# set_multicycle_path: https://docs.xilinx.com/r/en-US/ug903-vivado-using-constraints/set_multicycle_path-Syntax

# Main clock @ 16.75
create_clock -name clk16 -period 59.70  -waveform {0 29.85} [get_nets {clk16}]
#create_generated_clock -name clk16 -source [get_nets {clk67}] -divide_by 4 [get_nets {clk16}]

# SDRAM clock @ 67
# create_clock -name clk67 -period 14.92 -waveform {0 7.463} [get_nets {clk67}]
create_generated_clock -name clk67 -source [get_nets {clk16}] -multiply_by 4 [get_nets {clk67}]

# GPU clock @ 50
# create_clock -name clk50 -period 20.00 -waveform {0 10.00} [get_nets {clk50}]
create_generated_clock -name clk50 -source [get_nets {clk16}] -multiply_by 3 [get_nets {clk50}]

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

# 3-cycle path from CPU to GPU as GPU uses data on rising edge of clk16
set_multicycle_path 3 -setup -end -from [get_clocks {clk16}] -to [get_clocks {clk50}]
set_multicycle_path 2 -hold -end -from [get_clocks {clk16}] -to [get_clocks {clk50}]

# 3-cycle path from GPU to CPU (vblank_trigger_dma and etc)
set_multicycle_path 3 -setup -start -from [get_clocks {clk50}] -to [get_clocks {clk16}]
set_multicycle_path 2 -hold -start -from [get_clocks {clk50}] -to [get_clocks {clk16}]

# false paths
# No paths from VRAM to SDRAM (through CPU rom_data). No need to execute code from VRAM.
set_false_path -from [get_pins {gpu/drawer/ivram_lo/*/*}] -to [get_pins {sdram/*/*}]
