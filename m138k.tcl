
add_file -type cst "src/m138k/m138k.cst"
add_file -type sdc "src/gbatang.sdc"
set_device GW5AST-LV138PG484AC1/I0 -device_version B

add_file -type verilog "src/m138k/config.v"
add_file -type verilog "src/m138k/pll_27.v"
add_file -type verilog "src/m138k/pll_33.v"
add_file -type verilog "src/m138k/pll_74.v"

set_option -output_base_name gbatang-m138k

source build.tcl

