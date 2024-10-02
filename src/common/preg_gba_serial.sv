
`ifndef preg_gba_serial
`define preg_gba_serial

`include "pproc_bus_gba.sv"

//   (                                  adr    upper lower size default accesstype)                                                     
localparam regmap_type SIODATA32       = '{28'h120,  31,  0,  1,  'h0000, readwrite}; 
localparam regmap_type SIOMULTI0       = '{28'h120,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type SIOMULTI1       = '{28'h122,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type SIOMULTI2       = '{28'h124,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type SIOMULTI3       = '{28'h126,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type SIOCNT          = '{28'h128,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type SIOMLT_SEND     = '{28'h12A,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type SIODATA8        = '{28'h12A,  15,  0,  1,  'h0000, readwrite}; 
// localparam regmap_type -               = '{28'h12C,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type RCNT            = '{28'h134,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type IR              = '{28'h136,  15,  0,  1,  'h0000, readwrite}; 
// localparam regmap_type -               = '{28'h138,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type JOYCNT          = '{28'h140,  15,  0,  1,  'h0000, readwrite}; 
// localparam regmap_type -               = '{28'h142,  15,  0,  1,  'h0000, readwrite}; 
localparam regmap_type JOY_RECV        = '{28'h150,  31,  0,  1,  'h0000, readwrite}; 
localparam regmap_type JOY_TRANS       = '{28'h154,  31,  0,  1,  'h0000, readwrite}; 
localparam regmap_type JOYSTAT         = '{28'h158,  15,  0,  1,  'h0000, readwrite}; 

`endif