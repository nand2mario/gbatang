module gba_joypad (
    // input fclk,
    input mclk,
    input [31:0] gb_bus_din,
    inout [31:0] gb_bus_dout,
    input [27:0] gb_bus_adr,
    input gb_bus_rnw,
    input gb_bus_ena,
    input gb_bus_done,
    input [1:0] gb_bus_acc,
    input [3:0] gb_bus_be,
    input gb_bus_rst,

    output reg IRP_Joypad,
    input KeyA,
    input KeyB,
    input KeySelect,
    input KeyStart,
    input KeyRight,
    input KeyLeft,
    input KeyUp,
    input KeyDown,
    input KeyR,
    input KeyL,

    input cpu_done
);

`include "pproc_bus_gba.sv"
`include "preg_gba_serial.sv"

//    range 0x130 .. 0x133
//  (                              adr   upper lower size default accesstype)                                     
localparam regmap_type KEYINPUT = '{28'h130,  15,  0,  1,  0, readonly }; // Key Status            2    R  
localparam regmap_type KEYCNT   = '{28'h130,  31, 16,  1,  0, readwrite}; // Key Interrupt Control 2    R/W

wire [KEYINPUT.upper:KEYINPUT.lower] REG_KEYINPUT;
wire [KEYCNT.upper:KEYCNT.lower]     REG_KEYCNT;

reg [KEYINPUT.upper:KEYINPUT.lower] Keys;
reg [KEYINPUT.upper:KEYINPUT.lower] Keys_1;

reg [KEYCNT.upper:KEYCNT.lower]     REG_KEYCNT_1;

eProcReg_gba #(KEYINPUT) iReg_KEYINPUT (mclk, `GB_BUS_PORTS_LIST, REG_KEYINPUT);
eProcReg_gba #(KEYCNT)   iReg_KEYCNT   (mclk, `GB_BUS_PORTS_LIST, REG_KEYCNT, REG_KEYCNT);

assign REG_KEYINPUT = Keys;

// MMIO reg reads
reg [31:0] reg_dout;
reg reg_dout_en;
assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};

always @(posedge mclk) begin
    reg_dout_en <= 0;

    if (gb_bus_ena & gb_bus_rnw) begin
        reg_dout_en <= 1;
        case (gb_bus_adr)
        KEYINPUT.Adr:    // 130
            reg_dout <= {REG_KEYCNT, REG_KEYINPUT};

        // dummy read for RCNT / IR
        RCNT.Adr:        // 134
            reg_dout <= 32'h0000_8000;

        default: reg_dout_en <= 0;
        endcase
    end
end

// always @(posedge fclk) begin
always @(posedge mclk) begin
    IRP_Joypad <= 0;
    
    Keys_1 <= Keys;
    REG_KEYCNT_1 <= REG_KEYCNT;

    Keys[0] <= ~KeyA;
    Keys[1] <= ~KeyB;
    Keys[2] <= ~KeySelect;
    Keys[3] <= ~KeyStart;
    Keys[4] <= ~KeyRight;
    Keys[5] <= ~KeyLeft;
    Keys[6] <= ~KeyUp;
    Keys[7] <= ~KeyDown;
    Keys[8] <= ~KeyR;
    Keys[9] <= ~KeyL;

    if (Keys_1 != Keys || REG_KEYCNT_1 != REG_KEYCNT) begin
        if (REG_KEYCNT[30]) 
            if (REG_KEYCNT[31]) begin   // logical and
                if (~Keys[9:0] == REG_KEYCNT[25:16])
                    IRP_Joypad <= 1;
            end else                    // logical or
                if ((~Keys[9:0] & REG_KEYCNT[25:16]) != 0)
                    IRP_Joypad <= 1;
    end

end

endmodule
`undef pproc_bus_gba