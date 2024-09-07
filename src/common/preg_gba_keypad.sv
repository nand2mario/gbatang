
`ifndef preg_gba_keypad
`define preg_gba_keypad

`include "pproc_bus_gba.v"

// range 0x130 .. 0x133
//   (                    adr      upper    lower    size   default   accesstype)                                     
localparam regmap_type KEYINPUT = '{28'h130,  15,       0,        1,        0,   readonly } // Key Status            2    R  
localparam regmap_type KEYCNT   = '{28'h130,  31,      16,        1,        0,   readwrite} // Key Interrupt Control 2    R/W


`endif
