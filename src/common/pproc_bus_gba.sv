`ifndef pproc_bus_gba
`define pproc_bus_gba

// nand2mario: bus and register map header with SystemVerilog structs

///////////////////////////////////////////////
// Proc Bus Interface
// This is mostly for MMIO register access
///////////////////////////////////////////////

localparam       proc_buswidth = 32;
localparam       proc_busadr = 28;
localparam       proc_buscount = 1;
localparam [1:0] ACCESS_8BIT = 2'b00;
localparam [1:0] ACCESS_16BIT = 2'b01;
localparam [1:0] ACCESS_32BIT = 2'b10;

// gb_bus_dout is INOUT (tristate) so several components can drive it 
`define GB_BUS_PORTS_DECL \
    input [31:0] gb_bus_din /* synthesis syn_keep=1 */; \
    inout [31:0] gb_bus_dout /* synthesis syn_preserve=1 */; \
    input [27:0] gb_bus_adr /* synthesis syn_keep=1 */; \
    input gb_bus_rnw; \
    input gb_bus_ena; \
    input gb_bus_done; \
    input [1:0] gb_bus_acc; \
    input [3:0] gb_bus_be; \
    input gb_bus_rst

`define GB_BUS_PORTS_INST \
    .gb_bus_din(gb_bus_din), .gb_bus_dout(gb_bus_dout), .gb_bus_adr(gb_bus_adr), \
    .gb_bus_rnw(gb_bus_rnw), .gb_bus_ena(gb_bus_ena), .gb_bus_done(gb_bus_done), \
    .gb_bus_acc(gb_bus_acc), .gb_bus_be(gb_bus_be), .gb_bus_rst(gb_bus_rst)

`define GB_BUS_PORTS_LIST \
    gb_bus_din, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst


///////////////////////////////////////////////
// Reg Map Interface
///////////////////////////////////////////////

localparam [1:0] readwrite = 2'd0;
localparam [1:0] readonly = 2'd1;
localparam [1:0] writeonly = 2'd2;
localparam [1:0] writeDone = 2'd3;

typedef struct packed {
    reg [27:0] Adr;
    reg [5:0] upper;
    reg [5:0] lower;
    reg [27:0] size;
    reg [31:0] def;
    reg [1:0] acccesstype;
} regmap_type;

//
// Actual register module is in eprocreg_gba.sv
// 

`endif
