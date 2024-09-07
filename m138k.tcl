
add_file -type cst "src/m138k/m138k.cst"
add_file -type sdc "src/gbatang.sdc"
set_device GW5AST-LV138PG484AC1/I0 -device_version B

set_option -output_base_name gbatang-m138k

source build.tcl

