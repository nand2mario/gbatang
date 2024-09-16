// Generate timing signals for GPU using cycle counting
module gba_gpu_timing(fclk, mclk, reset, lockspeed, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
    //new_cycles, new_cycles_valid, 
    IRP_HBlank, IRP_VBlank, IRP_LCDStat, vram_block_mode, vram_blocked, videodma_start, videodma_stop, line_trigger, hblank_trigger, vblank_trigger, drawline, refpoint_update, newline_invsync, linecounter_drawer, pixelpos, DISPSTAT_debug);
    `include "pproc_bus_gba.sv"
    `include "preg_gba_display.sv"
    parameter              is_simu = 0;
    input                  fclk;
    input                  mclk;
    input                  reset;
    input                  lockspeed;
    
    `GB_BUS_PORTS_DECL;
    
    // input [7:0]            new_cycles;                  // \ input to cycle counting from CPU
    // input                  new_cycles_valid;            // /
    
    output reg             IRP_HBlank;
    output reg             IRP_VBlank;
    output reg             IRP_LCDStat;
    
    input                  vram_block_mode;
    output reg             vram_blocked;
    
    output reg             videodma_start;
    output reg             videodma_stop;
    
    output reg             line_trigger;                // pulse at visible line (1008 cycles to hblank)
    output reg             hblank_trigger;              // pulse at hblank (224 cycles to line_trigger)
    output reg             vblank_trigger;              // pulse at vblank
    output reg             drawline;
    output reg             refpoint_update;
    output reg             newline_invsync;
    output [7:0]           linecounter_drawer;          // y position (0-159 visible, 160-227 vblank)
    output reg [8:0]       pixelpos;                    // 0 or 240
    
    output [31:0]          DISPSTAT_debug;
    
    
    reg [DISPSTAT_V_Blank_flag.upper:DISPSTAT_V_Blank_flag.lower]                  REG_DISPSTAT_V_Blank_flag;
    reg [DISPSTAT_H_Blank_flag.upper:DISPSTAT_H_Blank_flag.lower]                  REG_DISPSTAT_H_Blank_flag;
    reg [DISPSTAT_V_Counter_flag.upper:DISPSTAT_V_Counter_flag.lower]              REG_DISPSTAT_V_Counter_flag;
    wire [DISPSTAT_V_Blank_IRQ_Enable.upper:DISPSTAT_V_Blank_IRQ_Enable.lower]     REG_DISPSTAT_V_Blank_IRQ_Enable;
    wire [DISPSTAT_H_Blank_IRQ_Enable.upper:DISPSTAT_H_Blank_IRQ_Enable.lower]     REG_DISPSTAT_H_Blank_IRQ_Enable;
    wire [DISPSTAT_V_Counter_IRQ_Enable.upper:DISPSTAT_V_Counter_IRQ_Enable.lower] REG_DISPSTAT_V_Counter_IRQ_Enable;
    wire [DISPSTAT_V_Count_Setting.upper:DISPSTAT_V_Count_Setting.lower]           REG_DISPSTAT_V_Count_Setting;
    wire [VCOUNT.upper:VCOUNT.lower]                                               REG_VCOUNT;
    
    parameter [1:0]        tGPUState_VISIBLE = 0,
                           tGPUState_HBLANK = 1,
                           tGPUState_VBLANK = 2,
                           tGPUState_VBLANKHBLANK = 3;
    reg [1:0]              gpustate;
    
    reg [7:0]              linecounter;
    reg [11:0]             cycles_reg;
    reg                    drawsoon;
    
    eProcReg_gba #(DISPSTAT_V_Blank_flag)         iREG_DISPSTAT_V_Blank_flag        (mclk, `GB_BUS_PORTS_LIST, REG_DISPSTAT_V_Blank_flag);
    eProcReg_gba #(DISPSTAT_H_Blank_flag)         iREG_DISPSTAT_H_Blank_flag        (mclk, `GB_BUS_PORTS_LIST, REG_DISPSTAT_H_Blank_flag);
    eProcReg_gba #(DISPSTAT_V_Counter_flag)       iREG_DISPSTAT_V_Counter_flag      (mclk, `GB_BUS_PORTS_LIST, REG_DISPSTAT_V_Counter_flag);
    eProcReg_gba #(DISPSTAT_V_Blank_IRQ_Enable)   iREG_DISPSTAT_V_Blank_IRQ_Enable  (mclk, `GB_BUS_PORTS_LIST, REG_DISPSTAT_V_Blank_IRQ_Enable,   REG_DISPSTAT_V_Blank_IRQ_Enable);
    eProcReg_gba #(DISPSTAT_H_Blank_IRQ_Enable)   iREG_DISPSTAT_H_Blank_IRQ_Enable  (mclk, `GB_BUS_PORTS_LIST, REG_DISPSTAT_H_Blank_IRQ_Enable,   REG_DISPSTAT_H_Blank_IRQ_Enable);
    eProcReg_gba #(DISPSTAT_V_Counter_IRQ_Enable) iREG_DISPSTAT_V_Counter_IRQ_Enable(mclk, `GB_BUS_PORTS_LIST, REG_DISPSTAT_V_Counter_IRQ_Enable, REG_DISPSTAT_V_Counter_IRQ_Enable);
    eProcReg_gba #(DISPSTAT_V_Count_Setting)      iREG_DISPSTAT_V_Count_Setting     (mclk, `GB_BUS_PORTS_LIST, REG_DISPSTAT_V_Count_Setting,      REG_DISPSTAT_V_Count_Setting);
    eProcReg_gba #(VCOUNT)                        iREG_VCOUNT                       (mclk, `GB_BUS_PORTS_LIST, REG_VCOUNT);
    
    reg [31:0] reg_dout /* synthesis syn_preserve=1 */;
    reg reg_dout_en;
    assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};

    // register read
    always @(posedge mclk) begin
        reg_dout_en <= 0;

        if (gb_bus_ena & gb_bus_rnw) begin
            if (gb_bus_adr == DISPSTAT.Adr)  begin   // 004
                reg_dout <= {REG_VCOUNT, REG_DISPSTAT_V_Count_Setting, 2'b0, 
                            REG_DISPSTAT_V_Counter_IRQ_Enable, REG_DISPSTAT_H_Blank_IRQ_Enable, REG_DISPSTAT_V_Blank_IRQ_Enable,
                            REG_DISPSTAT_V_Counter_flag, REG_DISPSTAT_H_Blank_flag, REG_DISPSTAT_V_Blank_flag};
                reg_dout_en <= 1;
            end
        end
    end

    assign linecounter_drawer = linecounter;
    
    assign REG_VCOUNT = {8'b0, linecounter};
    
    assign DISPSTAT_debug = {REG_VCOUNT, REG_DISPSTAT_V_Count_Setting, 2'b00, REG_DISPSTAT_V_Counter_IRQ_Enable,
                             REG_DISPSTAT_H_Blank_IRQ_Enable, REG_DISPSTAT_V_Blank_IRQ_Enable, REG_DISPSTAT_V_Counter_flag, 
                             REG_DISPSTAT_H_Blank_flag, REG_DISPSTAT_V_Blank_flag};
    
    reg mclk_r;

    always @(posedge fclk)
         begin
            reg [11:0] cycles;
            cycles = cycles_reg;

            IRP_HBlank <= 1'b0;
            IRP_VBlank <= 1'b0;
            IRP_LCDStat <= 1'b0;
            
            drawline <= 1'b0;
            refpoint_update <= 1'b0;
            line_trigger <= 1'b0;
            hblank_trigger <= 1'b0;
            vblank_trigger <= 1'b0;
            newline_invsync <= 1'b0;
            
            videodma_start <= 1'b0;
            videodma_stop <= 1'b0;
            
            vram_blocked <= 1'b0;
            if (gpustate == tGPUState_VISIBLE & vram_block_mode & cycles < 980)
                vram_blocked <= 1'b1;
            
            if (reset) begin
                
                gpustate <= 0;
                cycles_reg <= 0;
                linecounter <= 0;
                
                REG_DISPSTAT_V_Counter_flag <= 0;
                REG_DISPSTAT_H_Blank_flag <= 0;
                REG_DISPSTAT_V_Blank_flag <= 0;
            
            end else /* if (gb_on)*/ begin
                
                // really required?
                // if (forcedblank && !new_forcedblank) then
                //    gpustate = GPUState.VISIBLE
                //    cycles = 0
                //    GBRegs.Sect_display.DISPSTAT_V_Blank_flag.write(0);
                //    GBRegs.Sect_display.DISPSTAT_H_Blank_flag.write(0);
                // end if;
                
                // if (new_cycles_valid)
                //     cycles = cycles + new_cycles;
                mclk_r <= mclk;         // count CPU cycles for video timing
                if (mclk & ~mclk_r)
                    cycles = cycles + 1;
                
                case (gpustate)
                    tGPUState_VISIBLE :
                        begin
                            if ((lockspeed == 1'b0 | cycles >= 160)) begin
                                if (lockspeed)
                                    pixelpos <= (cycles/2) - 80;
                                if (drawsoon) begin
                                    drawline <= 1'b1;
                                    drawsoon <= 1'b0;
                                end 
                            end 
                            if (cycles >= 1008) begin		// 960 is drawing time
                                pixelpos <= 240;
                                cycles = cycles - 1008;
                                gpustate <= tGPUState_HBLANK;
                                REG_DISPSTAT_H_Blank_flag <= 1'b1;
                                hblank_trigger <= 1'b1;
                                if (linecounter >= 2)
                                    videodma_start <= 1'b1;
                                if (REG_DISPSTAT_H_Blank_IRQ_Enable)
                                    IRP_HBlank <= 1'b1;
                            end 
                        end
                    
                    tGPUState_HBLANK :
                        if (cycles >= 224) begin		// 272
                            cycles = cycles - 224;
                            linecounter <= linecounter + 1;
                            if ((linecounter + 1) == REG_DISPSTAT_V_Count_Setting) begin
                                if (REG_DISPSTAT_V_Counter_IRQ_Enable)
                                    IRP_LCDStat <= 1'b1;
                                REG_DISPSTAT_V_Counter_flag <= 1'b1;
                            end else
                                REG_DISPSTAT_V_Counter_flag <= 1'b0;
                            
                            REG_DISPSTAT_H_Blank_flag <= 1'b0;
                            if ((linecounter + 1) < 160) begin
                                gpustate <= tGPUState_VISIBLE;
                                drawsoon <= 1'b1;
                                pixelpos <= 0;
                                line_trigger <= 1'b1;
                            end else begin
                                gpustate <= tGPUState_VBLANK;
                                refpoint_update <= 1'b1;
                                REG_DISPSTAT_V_Blank_flag <= 1'b1;
                                vblank_trigger <= 1'b1;
                                if (REG_DISPSTAT_V_Blank_IRQ_Enable)
                                    IRP_VBlank <= 1'b1;
                            end
                        end 
                    
                    tGPUState_VBLANK :
                        if (cycles >= 1008) begin
                            cycles = cycles - 1008;
                            gpustate <= tGPUState_VBLANKHBLANK;
                            REG_DISPSTAT_H_Blank_flag <= 1'b1;
                            newline_invsync <= 1'b1;
                            // don't do hblank for dma here!
                            if (REG_DISPSTAT_H_Blank_IRQ_Enable)
                                IRP_HBlank <= 1'b1;		// Note that no H-Blank interrupts are generated within V-Blank period. Really? Seems to work this way...
                            if (linecounter < 162)
                                videodma_start <= 1'b1;
                            if (linecounter == 162)
                                videodma_stop <= 1'b1;
                        end 
                    
                    tGPUState_VBLANKHBLANK :
                        if (cycles >= 224) begin		// 272
                            cycles = cycles - 224;
                            linecounter <= linecounter + 1;
                            if ((linecounter + 1) == REG_DISPSTAT_V_Count_Setting | ((linecounter + 1) == 228 & REG_DISPSTAT_V_Count_Setting == 8'h00)) begin
                                if (REG_DISPSTAT_V_Counter_IRQ_Enable)
                                    IRP_LCDStat <= 1'b1;
                                REG_DISPSTAT_V_Counter_flag <= 1'b1;
                            end else
                                REG_DISPSTAT_V_Counter_flag <= 1'b0;
                            
                            REG_DISPSTAT_H_Blank_flag <= 1'b0;
                            line_trigger <= 1'b1;
                            if ((linecounter + 1) == 228) begin
                                linecounter <= 0;
                                gpustate <= tGPUState_VISIBLE;
                                drawsoon <= 1'b1;
                                pixelpos <= 0;
                            end else begin
                                gpustate <= tGPUState_VBLANK;
                                if ((linecounter + 1) == 227)
                                    REG_DISPSTAT_V_Blank_flag <= 1'b0;		// (set in line 160..226; not 227)
                            end
                        end 
                endcase
            end 

            cycles_reg <= cycles;
        end 

endmodule
`undef pproc_bus_gba
`undef preg_gba_display