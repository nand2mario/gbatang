//---------------------------------------------------------------
//------------- Reg Interface -----------------------------------
//---------------------------------------------------------------
// nand2mario: This module used to be a fully-generic register interface in the MiSTer core.
// However Verilator does not support sliced accesses to inout ports. So this module now
// only implements write accesses to registers. Read access is implemented manually in 
// each module containing the registers.
module eProcReg_gba(clk, gb_bus_din, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
                    Din, Dout, written);
    `include "pproc_bus_gba.sv"
    
    parameter regmap_type register = '{0,0,0,0,0,0};
    parameter index = 0;

    input clk;

    input [31:0] gb_bus_din;
    input [27:0] gb_bus_adr;
    input gb_bus_rnw;
    input gb_bus_ena;
    input gb_bus_done;
    input [1:0] gb_bus_acc;
    input [3:0] gb_bus_be;
    input gb_bus_rst;

    input [register.upper:register.lower]  Din;
    output [register.upper:register.lower] Dout;
    output reg written;

    reg [register.upper:register.lower]    Dout_buffer = register.def;     // actual register data
    wire [proc_busadr-1:0]                 Adr;
    
    assign Adr = register.Adr + index;
    
    generate                        // MMIO register write
        if (register.acccesstype == readwrite || register.acccesstype == writeonly || register.acccesstype == writeDone)
        begin : greadwrite
            integer i;
            always @(posedge clk) begin
                written <= 1'b0;
                if (gb_bus_rst)
                    Dout_buffer <= register.def;            // default value
                else if (gb_bus_adr == Adr & gb_bus_rnw == 1'b0 & gb_bus_ena) begin    // processor writes register
                        for (i = register.lower; i <= register.upper; i = i + 1)
                            if ((gb_bus_be[0] && i < 8) | 
                                (gb_bus_be[1] && i >= 8 && i < 16) | 
                                (gb_bus_be[2] && i >= 16 && i < 24) | 
                                (gb_bus_be[3] && i >= 24)) 
                            begin
                                Dout_buffer[i] <= gb_bus_din[i];
                                written <= 1'b1;
                            end 
                end
            end
        end
    endgenerate
    
    assign Dout = Dout_buffer;      // module output
    
endmodule
`undef pproc_bus_gba