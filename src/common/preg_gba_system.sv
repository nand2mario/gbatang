
`ifndef preg_gba_system
`define preg_gba_system

`include "pproc_bus_gba.sv"

// range 0x200 .. 0x800
//   (                     adr      upper    lower size default accesstype)                                     
localparam   regmap_type IRP_IE  = '{28'h200,  15,   0,      1,  0,   readwrite}; // Interrupt Enable Register
localparam   regmap_type IRP_IF  = '{28'h200,  31,  16,      1,  0,   readwrite}; // Interrupt Request Flags / IRQ Acknowledge  

localparam   regmap_type WAITCNT = '{28'h204,  14,   0,      1,  0,   readwrite}; // Game Pak Waitstate Control  
localparam   regmap_type ISCGB   = '{28'h204,  15,  15,      1,  0,   readwrite}; // is CGB = 1, GBA = 0

localparam   regmap_type IME     = '{28'h208,   0,   0,      1,  0,   readwrite}; // Interrupt Master Enable Register  

// `ifdef VERILATOR
// For verilator, set POSTFLG and skip boot animation
// localparam   regmap_type POSTFLG = '{28'h300,   7,   0,      1,  1,   readwrite}; // Undocumented - Post Boot Flag  
// `else
localparam   regmap_type POSTFLG = '{28'h300,   7,   0,      1,  0,   readwrite}; // Undocumented - Post Boot Flag  
// `endif
localparam   regmap_type HALTCNT = '{28'h300,  15,   8,      1,  0,   writeonly}; // Undocumented - Power Down Control
 
localparam   regmap_type MemCtrl = '{28'h800,  31,   0,      1,  0,   readwrite}; // Undocumented - Internal Memory Control (R/W) -- Mirrors of 4000800h (repeated each 64K) 

`endif
