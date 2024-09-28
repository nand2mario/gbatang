// Combine 4 DMA modules and do arbitration among them
module gba_dma(clk100, reset, ce, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
                new_cycles, new_cycles_valid, irp_dma, lastread_dma, 
                dma_on, cpu_preemptable, do_step, sound_dma_req, hblank_trigger, vblank_trigger, 
                videodma_start, videodma_stop, dma_new_cycles, dma_first_cycles, dma_dword_cycles, dma_toROM, 
                dma_init_cycles, dma_cycles_adrup, dma_eepromcount, dma_bus_Adr, dma_bus_rnw, dma_bus_ena, 
                dma_bus_acc, dma_bus_dout, dma_bus_din, dma_bus_done, dma_bus_unread, debug_dma);

    `include "pproc_bus_gba.sv"
    `include "preg_gba_dma.sv"

    input         clk100;
    input         reset;
    input         ce;
    
    `GB_BUS_PORTS_DECL;
    
    input [7:0]   new_cycles;           // cycle counting
    input         new_cycles_valid;
    
    output [3:0]  irp_dma;
    output [31:0] lastread_dma;         // last read value from dma
    
    output        dma_on  /* xsynthesis syn_keep=1 */;               // at least one of DMA is on
    input         cpu_preemptable;      // CPU is idle and DMA is allowed
    input         do_step;              // enable execution
    // output        dma_pause;            // CPU needs to be paused for DMA
    
    input [1:0]   sound_dma_req;        // DMA trigger signals 
    input         hblank_trigger;
    input         vblank_trigger;
    input         videodma_start;
    input         videodma_stop;
    
    output        dma_new_cycles;       // pulse at new DMA cycle start
    output        dma_first_cycles;     // pulse at first DMA cycle start
    output        dma_dword_cycles;     // dword DMA cycle
    output        dma_toROM;
    output        dma_init_cycles;
    output [3:0]  dma_cycles_adrup;
    
    output [16:0] dma_eepromcount;      // DMA3 transfer count for EEPROM size detection
    
    output [27:0] dma_bus_Adr  /* xsynthesis syn_keep=1 */;          // DMA address
    output        dma_bus_rnw  /* xsynthesis syn_keep=1 */;          // 1: read, 0: write
    output        dma_bus_ena  /* xsynthesis syn_keep=1 */;          // 1: DMA bus active
    output [1:0]  dma_bus_acc;          // 00: byte, 01: halfword, 10: word
    output [31:0] dma_bus_dout;         // data to be written
    input [31:0]  dma_bus_din;          // read result
    input         dma_bus_done;         // pulse at DMA bus done
    input         dma_bus_unread;       // the requested address is unreadable
    
    output [31:0] debug_dma;

    
    wire [31:0]   array_dout[0:3];
    wire [27:0]   array_adr[0:3];
    wire [1:0]    array_acc[0:3];
    wire          array_rnw[0:3];
    wire          array_ena[0:3];
    wire          array_done[0:3];
    
    wire [3:0]    single_new_cycles;
    wire [3:0]    single_first_cycles;
    wire [3:0]    single_dword_cycles;
    wire [3:0]    single_dword_toRom;
    wire [3:0]    single_init_cycles;
    wire [15:0]   single_cycles_adrup;
    
    wire [3:0]    single_dma_on;
    wire [3:0]    single_allow_on;
    wire [3:0]    single_soon;
    
    wire [2:0]    lowprio_pending;
    
    reg [1:0]     dma_switch;
    
    reg           dma_idle = 1'b1;
    
    reg [31:0]    last_dma_value;
    
    wire [31:0]   last_dma0;
    wire [31:0]   last_dma1;
    wire [31:0]   last_dma2;
    wire [31:0]   last_dma3;
    wire          last_dma_valid0;
    wire          last_dma_valid1;
    wire          last_dma_valid2;
    wire          last_dma_valid3;
    
    wire [3:0]    single_is_idle;
    
    gba_dma_module #(0, 1'b0, DMA0SAD, DMA0DAD, DMA0CNT_L, DMA0CNT_H_Dest_Addr_Control, DMA0CNT_H_Source_Adr_Control, DMA0CNT_H_DMA_Repeat, DMA0CNT_H_DMA_Transfer_Type, DMA3CNT_H_Game_Pak_DRQ, DMA0CNT_H_DMA_Start_Timing, DMA0CNT_H_IRQ_on, DMA0CNT_H_DMA_Enable) igba_dma_module0(		//unsued
        .clk100(clk100),
        .reset(reset),
        .ce(ce),
        
        `GB_BUS_PORTS_INST,

        .new_cycles(new_cycles),
        .new_cycles_valid(new_cycles_valid),
        
        .irp_dma(irp_dma[0]),
        
        .dma_on(single_dma_on[0]),
        .cpu_preemptable(cpu_preemptable),
        .allow_on(single_allow_on[0]),
        // .dma_pause(single_soon[0]),
        .lowprio_pending(lowprio_pending[0]),
        
        .sound_dma_req(1'b0),
        .hblank_trigger(hblank_trigger),
        .vblank_trigger(vblank_trigger),
        .videodma_start(1'b0),
        .videodma_stop(1'b0),
        
        .dma_new_cycles(single_new_cycles[0]),
        .dma_first_cycles(single_first_cycles[0]),
        .dma_dword_cycles(single_dword_cycles[0]),
        .dma_torom(single_dword_toRom[0]),
        .dma_init_cycles(single_init_cycles[0]),
        .dma_cycles_adrup(single_cycles_adrup[3:0]),
        
        .dma_eepromcount(),
        
        .last_dma_out(last_dma0),
        .last_dma_valid(last_dma_valid0),
        .last_dma_in(last_dma_value),
        
        .dma_bus_adr(array_adr[0]),
        .dma_bus_rnw(array_rnw[0]),
        .dma_bus_ena(array_ena[0]),
        .dma_bus_acc(array_acc[0]),
        .dma_bus_dout(array_dout[0]),
        .dma_bus_din(dma_bus_din),
        .dma_bus_done(array_done[0]),
        .dma_bus_unread(dma_bus_unread),
        
        .is_idle(single_is_idle[0])
    );
    
    
    gba_dma_module #(1, 1'b0, DMA1SAD, DMA1DAD, DMA1CNT_L, DMA1CNT_H_Dest_Addr_Control, DMA1CNT_H_Source_Adr_Control, DMA1CNT_H_DMA_Repeat, DMA1CNT_H_DMA_Transfer_Type, DMA3CNT_H_Game_Pak_DRQ, DMA1CNT_H_DMA_Start_Timing, DMA1CNT_H_IRQ_on, DMA1CNT_H_DMA_Enable) igba_dma_module1(		//unsued
        .clk100(clk100),
        .reset(reset),
        .ce(ce),
        
        `GB_BUS_PORTS_INST,

        .new_cycles(new_cycles),
        .new_cycles_valid(new_cycles_valid),
        
        .irp_dma(irp_dma[1]),
        
        .dma_on(single_dma_on[1]),
        .cpu_preemptable(cpu_preemptable),
        .allow_on(single_allow_on[1]),
        // .dma_pause(single_soon[1]),
        .lowprio_pending(lowprio_pending[1]),
        
        .sound_dma_req(sound_dma_req[0]),
        .hblank_trigger(hblank_trigger),
        .vblank_trigger(vblank_trigger),
        .videodma_start(1'b0),
        .videodma_stop(1'b0),
        
        .dma_new_cycles(single_new_cycles[1]),
        .dma_first_cycles(single_first_cycles[1]),
        .dma_dword_cycles(single_dword_cycles[1]),
        .dma_torom(single_dword_toRom[1]),
        .dma_init_cycles(single_init_cycles[1]),
        .dma_cycles_adrup(single_cycles_adrup[7:4]),
        
        .dma_eepromcount(),
        
        .last_dma_out(last_dma1),
        .last_dma_valid(last_dma_valid1),
        .last_dma_in(last_dma_value),
        
        .dma_bus_adr(array_adr[1]),
        .dma_bus_rnw(array_rnw[1]),
        .dma_bus_ena(array_ena[1]),
        .dma_bus_acc(array_acc[1]),
        .dma_bus_dout(array_dout[1]),
        .dma_bus_din(dma_bus_din),
        .dma_bus_done(array_done[1]),
        .dma_bus_unread(dma_bus_unread),
        
        .is_idle(single_is_idle[1])
    );
    
    
    gba_dma_module #(2, 1'b0, DMA2SAD, DMA2DAD, DMA2CNT_L, DMA2CNT_H_Dest_Addr_Control, DMA2CNT_H_Source_Adr_Control, DMA2CNT_H_DMA_Repeat, DMA2CNT_H_DMA_Transfer_Type, DMA3CNT_H_Game_Pak_DRQ, DMA2CNT_H_DMA_Start_Timing, DMA2CNT_H_IRQ_on, DMA2CNT_H_DMA_Enable) igba_dma_module2(		//unsued
        .clk100(clk100),
        .reset(reset),
        .ce(ce),
        
        `GB_BUS_PORTS_INST,
        
        .new_cycles(new_cycles),
        .new_cycles_valid(new_cycles_valid),
        
        .irp_dma(irp_dma[2]),
        
        .dma_on(single_dma_on[2]),
        .cpu_preemptable(cpu_preemptable),
        .allow_on(single_allow_on[2]),
        // .dma_pause(single_soon[2]),
        .lowprio_pending(lowprio_pending[2]),
        
        .sound_dma_req(sound_dma_req[1]),
        .hblank_trigger(hblank_trigger),
        .vblank_trigger(vblank_trigger),
        .videodma_start(1'b0),
        .videodma_stop(1'b0),
        
        .dma_new_cycles(single_new_cycles[2]),
        .dma_first_cycles(single_first_cycles[2]),
        .dma_dword_cycles(single_dword_cycles[2]),
        .dma_torom(single_dword_toRom[2]),
        .dma_init_cycles(single_init_cycles[2]),
        .dma_cycles_adrup(single_cycles_adrup[11:8]),
        
        .dma_eepromcount(),
        
        .last_dma_out(last_dma2),
        .last_dma_valid(last_dma_valid2),
        .last_dma_in(last_dma_value),
        
        .dma_bus_adr(array_adr[2]),
        .dma_bus_rnw(array_rnw[2]),
        .dma_bus_ena(array_ena[2]),
        .dma_bus_acc(array_acc[2]),
        .dma_bus_dout(array_dout[2]),
        .dma_bus_din(dma_bus_din),
        .dma_bus_done(array_done[2]),
        .dma_bus_unread(dma_bus_unread),
        
        .is_idle(single_is_idle[2])
    );
    
    
    gba_dma_module #(3, 1'b1, DMA3SAD, DMA3DAD, DMA3CNT_L, DMA3CNT_H_Dest_Addr_Control, DMA3CNT_H_Source_Adr_Control, DMA3CNT_H_DMA_Repeat, DMA3CNT_H_DMA_Transfer_Type, DMA3CNT_H_Game_Pak_DRQ, DMA3CNT_H_DMA_Start_Timing, DMA3CNT_H_IRQ_on, DMA3CNT_H_DMA_Enable) igba_dma_module3(		//unsued
        .clk100(clk100),
        .reset(reset),
        .ce(ce),
        
        `GB_BUS_PORTS_INST,
        
        .new_cycles(new_cycles),
        .new_cycles_valid(new_cycles_valid),
        
        .irp_dma(irp_dma[3]),
        
        .dma_on(single_dma_on[3]),
        .cpu_preemptable(cpu_preemptable),
        .allow_on(single_allow_on[3]),
        // .dma_pause(single_soon[3]),
        .lowprio_pending(1'b0),
        
        .sound_dma_req(1'b0),
        .hblank_trigger(hblank_trigger),
        .vblank_trigger(vblank_trigger),
        .videodma_start(videodma_start),
        .videodma_stop(videodma_stop),
        
        .dma_new_cycles(single_new_cycles[3]),
        .dma_first_cycles(single_first_cycles[3]),
        .dma_dword_cycles(single_dword_cycles[3]),
        .dma_torom(single_dword_toRom[3]),
        .dma_init_cycles(single_init_cycles[3]),
        .dma_cycles_adrup(single_cycles_adrup[15:12]),
        
        .dma_eepromcount(dma_eepromcount),
        
        .last_dma_out(last_dma3),
        .last_dma_valid(last_dma_valid3),
        .last_dma_in(last_dma_value),
        
        .dma_bus_adr(array_adr[3]),
        .dma_bus_rnw(array_rnw[3]),
        .dma_bus_ena(array_ena[3]),
        .dma_bus_acc(array_acc[3]),
        .dma_bus_dout(array_dout[3]),
        .dma_bus_din(dma_bus_din),
        .dma_bus_done(array_done[3]),
        .dma_bus_unread(dma_bus_unread),
        
        .is_idle(single_is_idle[3])
    );
    
    assign lastread_dma = last_dma_value;
    
    assign dma_bus_dout = array_dout[dma_switch];
    assign dma_bus_Adr = array_adr[dma_switch];
    assign dma_bus_acc = array_acc[dma_switch];
    assign dma_bus_rnw = array_rnw[dma_switch];
    assign dma_bus_ena = array_ena[dma_switch];
    
    assign array_done[0] = dma_switch == 0 ? dma_bus_done : 1'b0;
    assign array_done[1] = dma_switch == 1 ? dma_bus_done : 1'b0;
    assign array_done[2] = dma_switch == 2 ? dma_bus_done : 1'b0;
    assign array_done[3] = dma_switch == 3 ? dma_bus_done : 1'b0;
    
    assign single_allow_on[0] = ~dma_idle & dma_switch == 0;
    assign single_allow_on[1] = ~dma_idle & dma_switch == 1;
    assign single_allow_on[2] = ~dma_idle & dma_switch == 2;
    assign single_allow_on[3] = ~dma_idle & dma_switch == 3;
    
    assign lowprio_pending[0] = single_dma_on[1] | single_dma_on[2] | single_dma_on[3];
    assign lowprio_pending[1] = single_dma_on[2] | single_dma_on[3];
    assign lowprio_pending[2] = single_dma_on[3];
    
    assign dma_new_cycles = single_new_cycles[0] | single_new_cycles[1] | single_new_cycles[2] | single_new_cycles[3];
    assign dma_first_cycles = single_first_cycles[0] | single_first_cycles[1] | single_first_cycles[2] | single_first_cycles[3];
    assign dma_dword_cycles = single_dword_cycles[0] | single_dword_cycles[1] | single_dword_cycles[2] | single_dword_cycles[3];
    assign dma_toROM = single_dword_toRom[0] | single_dword_toRom[1] | single_dword_toRom[2] | single_dword_toRom[3];
    assign dma_init_cycles = single_init_cycles[0] | single_init_cycles[1] | single_init_cycles[2] | single_init_cycles[3];
    assign dma_cycles_adrup = single_cycles_adrup[3:0] | single_cycles_adrup[7:4] | single_cycles_adrup[11:8] | single_cycles_adrup[15:12];
    
    assign dma_on = single_dma_on[0] | single_dma_on[1] | single_dma_on[2] | single_dma_on[3];
    // assign dma_pause = single_soon[0] | single_soon[1] | single_soon[2] | single_soon[3];
    
    always @(posedge clk100) begin
        // possible speedup here, as if only 1 dma is requesting, it must wait 1 cycle after each r+w transfer
        // currently implementing this speedup cannot work, as the dma module is turned off the cycle after dma_bus_done
        // so we don't know here if it will require more
        
        if (reset) begin
            dma_idle <= 1'b1;
            dma_switch <= 0;
        end else if (ce) begin
            if (last_dma_valid0)
                last_dma_value <= last_dma0;
            else if (last_dma_valid1)
                last_dma_value <= last_dma1;
            else if (last_dma_valid2)
                last_dma_value <= last_dma2;
            else if (last_dma_valid3)
                last_dma_value <= last_dma3;
        
            if (dma_idle) begin
                if (single_dma_on[0]) begin
                    dma_switch <= 0;
                    dma_idle <= 1'b0;
                end else if (single_dma_on[1]) begin
                    dma_switch <= 1;
                    dma_idle <= 1'b0;
                end else if (single_dma_on[2]) begin
                    dma_switch <= 2;
                    dma_idle <= 1'b0;
                end else if (single_dma_on[3]) begin
                    dma_switch <= 3;
                    dma_idle <= 1'b0;
                end 
            end else if (dma_bus_done & dma_bus_rnw == 1'b0 | single_dma_on == 0)
                dma_idle <= 1'b1;
        end
    end 
    
    assign debug_dma[0] = dma_idle;
    assign debug_dma[2:1] = dma_switch;
    assign debug_dma[3] = single_dma_on[0];
    assign debug_dma[4] = single_dma_on[1];
    assign debug_dma[5] = single_dma_on[2];
    assign debug_dma[6] = single_dma_on[3];
    assign debug_dma[7] = 1'b0;
    assign debug_dma[8] = single_allow_on[0];
    assign debug_dma[9] = single_allow_on[1];
    assign debug_dma[10] = single_allow_on[2];
    assign debug_dma[11] = single_allow_on[3];
    assign debug_dma[12] = single_is_idle[0];
    assign debug_dma[13] = single_is_idle[1];
    assign debug_dma[14] = single_is_idle[2];
    assign debug_dma[15] = single_is_idle[3];
    assign debug_dma[31:16] = {32{1'b0}};
    
endmodule
`undef pproc_bus_gba
`undef preg_gba_dma