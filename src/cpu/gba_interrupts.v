// Interrupt controller:
// 1. Generate cpu_IRP signal for CPU
// 2. Maintain interrupt registers like IE, IF, IME and etc
// 3. Halts and wakes up the CPU on WAITCNT writes and interrupts
module gba_interrupts (clk, resetn,
    gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
    IRP_VBlank, IRP_HBlank, IRP_LCDStat, IRP_Timer, IRP_Serial, IRP_DMA, 
    IRP_Joypad, cpu_IRP, halt
);
`include "pproc_bus_gba.sv"
`include "preg_gba_system.sv"

input clk, resetn;

`GB_BUS_PORTS_DECL;

input IRP_VBlank, IRP_HBlank, IRP_LCDStat, IRP_Serial, IRP_Joypad;
input [3:0] IRP_DMA, IRP_Timer;
output reg cpu_IRP /* synthesis syn_keep=1 */, halt /* synthesis syn_keep=1 */;

reg [15:0] IRPFlags;

wire [IRP_IE.upper:IRP_IE.lower]    REG_IRP_IE;     // 4000200[15:0]
wire [IRP_IF.upper:IRP_IF.lower]    REG_IRP_IF;     // 4000200[31:16]
wire [WAITCNT.upper:WAITCNT.lower]  REG_WAITCNT;
wire [IME.upper:IME.lower]          REG_IME;
wire [POSTFLG.upper:POSTFLG.lower]  REG_POSTFLG;
wire [HALTCNT.upper:HALTCNT.lower]  REG_HALTCNT;
wire IF_written, HALTCNT_written,   WAITCNT_written;

eProcReg_gba #(IRP_IE)  iREG_IRP_IE (clk, `GB_BUS_PORTS_LIST, 0, REG_IRP_IE); 
eProcReg_gba #(IRP_IF)  iREG_IRP_IF (clk, `GB_BUS_PORTS_LIST, 0, REG_IRP_IF, IF_written); 
eProcReg_gba #(WAITCNT) iREG_WAITCNT(clk, `GB_BUS_PORTS_LIST, 0, REG_WAITCNT, WAITCNT_written); 
eProcReg_gba #(ISCGB)   iREG_ISCGB  (clk, `GB_BUS_PORTS_LIST, 0); 
eProcReg_gba #(IME)     iREG_IME    (clk, `GB_BUS_PORTS_LIST, 0, REG_IME); 
eProcReg_gba #(POSTFLG) iREG_POSTFLG(clk, `GB_BUS_PORTS_LIST, 0, REG_POSTFLG); 
eProcReg_gba #(HALTCNT) iREG_HALTCNT(clk, `GB_BUS_PORTS_LIST, 0, REG_HALTCNT, HALTCNT_written); 

// MMIO reg reads
reg [31:0] reg_dout;
reg reg_dout_en;
assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};

always @(posedge clk) begin
    if (~resetn) begin
        IRPFlags <= 16'h0000;
        cpu_IRP <= 0;
        halt <= 0;
    end else begin
        if (IF_written)
            IRPFlags <= IRPFlags & ~REG_IRP_IF; // write 1 to 0x4000200 to clear corresponding interrupt flag

        if (IRP_VBlank) IRPFlags[0] <= 1'b1;
        if (IRP_HBlank) IRPFlags[1] <= 1'b1;
        if (IRP_LCDStat) IRPFlags[2] <= 1'b1;
        if (IRP_Timer[0]) IRPFlags[3] <= 1'b1;
        if (IRP_Timer[1]) IRPFlags[4] <= 1'b1;
        if (IRP_Timer[2]) IRPFlags[5] <= 1'b1;
        if (IRP_Timer[3]) IRPFlags[6] <= 1'b1;
        if (IRP_Serial) IRPFlags[7] <= 1'b1;
        if (IRP_DMA[0]) IRPFlags[8] <= 1'b1;
        if (IRP_DMA[1]) IRPFlags[9] <= 1'b1;
        if (IRP_DMA[2]) IRPFlags[10] <= 1'b1;
        if (IRP_DMA[3]) IRPFlags[11] <= 1'b1;
        if (IRP_Joypad) IRPFlags[12] <= 1'b1;

        cpu_IRP <= 0;
        if ((IRPFlags & REG_IRP_IE) != 16'b0 & REG_IME[0])
            cpu_IRP <= 1;
        
        if (gb_bus_ena & ~gb_bus_rnw & gb_bus_adr == HALTCNT.Adr & gb_bus_be[1] & gb_bus_din[15] == 1'b0)
            // writing 0 to HALTCNT[15]
            halt <= 1;
        if (IRPFlags != 16'b0)
            halt <= 0;

        // register reads
        reg_dout_en <= 0;
        if (gb_bus_ena & gb_bus_rnw) begin
            reg_dout_en <= 1;
            case (gb_bus_adr) 
            IRP_IE.Adr:         // 200
                reg_dout <= {IRPFlags, REG_IRP_IE};
            WAITCNT.Adr:        // 204
                reg_dout <= REG_WAITCNT;
            IME.Adr:            // 208
                reg_dout <= {31'b0, REG_IME};
            POSTFLG.Adr:        // 300
                reg_dout <= {REG_HALTCNT, /* REG_POSTFLG */ 8'h0};

            28'h100C:
                reg_dout <= 32'hDEADDEAD;
                
            default: reg_dout_en <= 0;
            endcase 
        end 
    end
end

endmodule
`undef pproc_bus_gba
`undef preg_gba_system
