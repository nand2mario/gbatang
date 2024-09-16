
module gba_gpu(fclk, mclk, phase, reset, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
        lockspeed, interframe_blend, maxpixels, shade_mode, hdmode2x_bg, hdmode2x_obj, bitmapdrawmode, pixel_out_x, pixel_out_2x, pixel_out_y, pixel_out_addr, pixel_out_data, pixel_out_we, pixel2_out_x, pixel2_out_data, pixel2_out_we, 
        //new_cycles, new_cycles_valid, 
        IRP_HBlank, IRP_VBlank, IRP_LCDStat, hblank_trigger_dma, vblank_trigger_dma, 
        videodma_start_dma, videodma_stop_dma, VRAM_Lo_addr, VRAM_Lo_datain, VRAM_Lo_dataout, VRAM_Lo_we, VRAM_Lo_be, VRAM_Hi_addr, VRAM_Hi_datain, VRAM_Hi_dataout, VRAM_Hi_we, VRAM_Hi_be, vram_blocked, OAMRAM_PROC_addr, OAMRAM_PROC_datain, OAMRAM_PROC_dataout, OAMRAM_PROC_we, PALETTE_BG_addr, PALETTE_BG_datain, PALETTE_BG_dataout, PALETTE_BG_we, PALETTE_OAM_addr, PALETTE_OAM_datain, PALETTE_OAM_dataout, PALETTE_OAM_we, DISPSTAT_debug);
    `include "pproc_bus_gba.sv"
    parameter                 FCLK_SPEED = 3;
    parameter                 is_simu = 0;
    input                     fclk;     // fast clock for everything GPU
    input                     mclk;     // 16Mhz main GBA clock
    input                     phase;
    input                     reset;
    
    `GB_BUS_PORTS_DECL;

    input                     lockspeed;
    input [1:0]               interframe_blend;
    input                     maxpixels;
    input [2:0]               shade_mode;
    input                     hdmode2x_bg;
    input                     hdmode2x_obj;
    
    output                    bitmapdrawmode;
    
    output [7:0]              pixel_out_x;
    output [8:0]              pixel_out_2x;
    output [7:0]              pixel_out_y;
    output [15:0]             pixel_out_addr;
    output [17:0]             pixel_out_data;   // Format is RGB8
    output                    pixel_out_we;
    
    output [8:0]              pixel2_out_x;
    output [17:0]             pixel2_out_data;
    output                    pixel2_out_we;
    
    // input [7:0]               new_cycles;
    // input                     new_cycles_valid;
    
    // mclk pulse signals for CPU and DMA
    output reg                IRP_HBlank;
    output reg                IRP_VBlank;
    output reg                IRP_LCDStat;    
    output reg                hblank_trigger_dma;
    output reg                vblank_trigger_dma;
    output reg                videodma_start_dma;
    output reg                videodma_stop_dma;
    
    input [13:0]              VRAM_Lo_addr;
    input [31:0]              VRAM_Lo_datain;
    output [31:0]             VRAM_Lo_dataout;
    input                     VRAM_Lo_we;
    input [3:0]               VRAM_Lo_be;
    input [12:0]              VRAM_Hi_addr;
    input [31:0]              VRAM_Hi_datain;
    output [31:0]             VRAM_Hi_dataout;
    input                     VRAM_Hi_we;
    input [3:0]               VRAM_Hi_be;
    output                    vram_blocked;
    
    input [7:0]               OAMRAM_PROC_addr;
    input [31:0]              OAMRAM_PROC_datain;
    output [31:0]             OAMRAM_PROC_dataout;
    input [3:0]               OAMRAM_PROC_we;
    
    input [7:0]               PALETTE_BG_addr;
    input [31:0]              PALETTE_BG_datain;
    output [31:0]             PALETTE_BG_dataout;
    input [3:0]               PALETTE_BG_we;
    input [7:0]               PALETTE_OAM_addr;
    input [31:0]              PALETTE_OAM_datain;
    output [31:0]             PALETTE_OAM_dataout;
    input [3:0]               PALETTE_OAM_we;
    
    output [31:0]             DISPSTAT_debug;
    
    
    // wiring
    wire                      drawline;
    wire                      line_trigger;
    wire                      refpoint_update;
    wire                      newline_invsync;
    wire [7:0]                linecounter_drawer;
    wire [8:0]                pixelpos;
    
    wire [7:0]                pixel_x;
    wire [8:0]                pixel_2x;
    wire [7:0]                pixel_y;
    wire [15:0]               pixel_addr;
    wire [14:0]               pixel_data;
    wire                      pixel_we;
    
    wire [8:0]                pixel2_2x;
    wire [14:0]               pixel2_data;
    wire                      pixel2_we;
    
    wire                      vram_block_mode;

    wire                      hblank_trigger;
    wire                      vblank_trigger;
    wire                      videodma_start;
    wire                      videodma_stop;
    
    wire                      IRP_HBlank_fclk;      // for converting to mclk
    wire                      IRP_VBlank_fclk;
    wire                      IRP_LCDStat_fclk;

    gba_gpu_timing #(.is_simu(is_simu)) igba_gpu_timing(
        .fclk(fclk),
        .mclk(mclk),
        .reset(reset),
        .lockspeed(lockspeed),
        
        `GB_BUS_PORTS_INST,
        
        // .new_cycles(new_cycles),
        // .new_cycles_valid(new_cycles_valid),
        
        .IRP_HBlank(IRP_HBlank_fclk),
        .IRP_VBlank(IRP_VBlank_fclk),
        .IRP_LCDStat(IRP_LCDStat_fclk),
        
        .vram_block_mode(vram_block_mode),
        .vram_blocked(vram_blocked),
        
        .videodma_start(videodma_start),
        .videodma_stop(videodma_stop),
        
        .line_trigger(line_trigger),
        .hblank_trigger(hblank_trigger),
        .vblank_trigger(vblank_trigger),
        .drawline(drawline),
        .refpoint_update(refpoint_update),
        .newline_invsync(newline_invsync),
        .linecounter_drawer(linecounter_drawer),
        .pixelpos(pixelpos),
        
        .DISPSTAT_debug(DISPSTAT_debug)
    );
    
    
    gba_gpu_drawer #(.is_simu(is_simu)) drawer(
        .fclk(fclk),
        .mclk(mclk),
        
        `GB_BUS_PORTS_INST,
        
        .lockspeed(lockspeed),
        .interframe_blend(interframe_blend),
        .maxpixels(maxpixels),
        .hdmode2x_bg(hdmode2x_bg),
        .hdmode2x_obj(hdmode2x_obj),
        
        .bitmapdrawmode(bitmapdrawmode),
        .vram_block_mode(vram_block_mode),
        
        .pixel_out_x(pixel_x),
        .pixel_out_2x(pixel_2x),
        .pixel_out_y(pixel_y),
        .pixel_out_addr(pixel_addr),
        .pixel_out_data(pixel_data),
        .pixel_out_we(pixel_we),
        
        .pixel2_out_x(pixel2_2x),
        .pixel2_out_data(pixel2_data),
        .pixel2_out_we(pixel2_we),
        
        .linecounter(linecounter_drawer),
        .drawline(drawline),
        .refpoint_update(refpoint_update),
        .hblank_trigger(hblank_trigger),
        .vblank_trigger(vblank_trigger),
        .line_trigger(line_trigger),
        .newline_invsync(newline_invsync),
        .pixelpos(pixelpos),
        
        .VRAM_Lo_addr(VRAM_Lo_addr),
        .VRAM_Lo_datain(VRAM_Lo_datain),
        .VRAM_Lo_dataout(VRAM_Lo_dataout),
        .VRAM_Lo_we(VRAM_Lo_we),
        .VRAM_Lo_be(VRAM_Lo_be),
        .VRAM_Hi_addr(VRAM_Hi_addr),
        .VRAM_Hi_datain(VRAM_Hi_datain),
        .VRAM_Hi_dataout(VRAM_Hi_dataout),
        .VRAM_Hi_we(VRAM_Hi_we),
        .VRAM_Hi_be(VRAM_Hi_be),
        
        .OAMRAM_PROC_addr(OAMRAM_PROC_addr),
        .OAMRAM_PROC_datain(OAMRAM_PROC_datain),
        .OAMRAM_PROC_dataout(OAMRAM_PROC_dataout),
        .OAMRAM_PROC_we(OAMRAM_PROC_we),
        
        .PALETTE_BG_addr(PALETTE_BG_addr),
        .PALETTE_BG_datain(PALETTE_BG_datain),
        .PALETTE_BG_dataout(PALETTE_BG_dataout),
        .PALETTE_BG_we(PALETTE_BG_we),
        .PALETTE_OAM_addr(PALETTE_OAM_addr),
        .PALETTE_OAM_datain(PALETTE_OAM_datain),
        .PALETTE_OAM_dataout(PALETTE_OAM_dataout),
        .PALETTE_OAM_we(PALETTE_OAM_we)
    );

    // assign pixel_out_x = pixel_x;
    // assign pixel_out_2x = pixel_2x;
    // assign pixel_out_y = pixel_y;
    // assign pixel_out_addr = pixel_addr;
    // assign pixel_out_data = pixel_data;
    // assign pixel_out_we = pixel_we;    
    
    gba_gpu_colorshade igba_gpu_colorshade(
        .fclk(fclk),
        
        .shade_mode(shade_mode),
        
        .pixel_in_x(pixel_x),
        .pixel_in_2x(pixel_2x),
        .pixel_in_y(pixel_y),
        .pixel_in_addr(pixel_addr),
        .pixel_in_data(pixel_data),
        .pixel_in_we(pixel_we),
        
        .pixel_out_x(pixel_out_x),
        .pixel_out_2x(pixel_out_2x),
        .pixel_out_y(pixel_out_y),
        .pixel_out_addr(pixel_out_addr),
        .pixel_out_data(pixel_out_data),
        .pixel_out_we(pixel_out_we)
    );
    
    
    gba_gpu_colorshade igba_gpu_colorshade2(
        .fclk(fclk),
        
        .shade_mode(shade_mode),
        
        .pixel_in_x(0),
        .pixel_in_2x(pixel2_2x),
        .pixel_in_y(0),
        .pixel_in_addr(0),
        .pixel_in_data(pixel2_data),
        .pixel_in_we(pixel2_we),
        
        .pixel_out_x(),
        .pixel_out_2x(pixel2_out_x),
        .pixel_out_y(),
        .pixel_out_addr(),
        .pixel_out_data(pixel2_out_data),
        .pixel_out_we(pixel2_out_we)
    );
    
    // Convert fclk pulses to mclk pulses
    reg hblank_trigger_seen, vblank_trigger_seen, videodma_start_seen, videodma_stop_seen;
    reg IRP_HBlank_seen, IRP_VBlank_seen, IRP_LCDStat_seen;
    reg [$clog2(FCLK_SPEED)-1:0] fclk_cycle;
    reg mclk_r;
    always @(posedge fclk) begin
        if (reset) begin
            fclk_cycle <= 0;
            hblank_trigger_seen <= 0;
            vblank_trigger_seen <= 0;
            videodma_start_seen <= 0;
            videodma_stop_seen <= 0;
            IRP_HBlank_seen <= 0;
            IRP_VBlank_seen <= 0;
            IRP_LCDStat_seen <= 0;
        end else begin
            fclk_cycle <= fclk_cycle + 1;
            mclk_r <= mclk;
            if (mclk & !mclk_r) fclk_cycle <= 1;            // sync cycle counter

            if (fclk_cycle == FCLK_SPEED-1) begin
                fclk_cycle <= 0;                            // reset cycle counter
            
                hblank_trigger_dma <= hblank_trigger_seen;  // generate mclk pulses
                vblank_trigger_dma <= vblank_trigger_seen;
                videodma_start_dma <= videodma_start_seen;
                videodma_stop_dma <= videodma_stop_seen;
                IRP_HBlank <= IRP_HBlank_seen;
                IRP_VBlank <= IRP_VBlank_seen;
                IRP_LCDStat <= IRP_LCDStat_seen;

                hblank_trigger_seen <= 0;                   // reset fclk pulse flags
                vblank_trigger_seen <= 0;
                videodma_start_seen <= 0;
                videodma_stop_seen <= 0;
                IRP_HBlank_seen <= 0;
                IRP_VBlank_seen <= 0;
                IRP_LCDStat_seen <= 0;
            end

            if (hblank_trigger) hblank_trigger_seen <= 1;   // capture fclk pulses
            if (vblank_trigger) vblank_trigger_seen <= 1;
            if (videodma_start) videodma_start_seen <= 1;
            if (videodma_stop) videodma_stop_seen <= 1;
            if (IRP_HBlank_fclk) IRP_HBlank_seen <= 1;
            if (IRP_VBlank_fclk) IRP_VBlank_seen <= 1;
            if (IRP_LCDStat_fclk) IRP_LCDStat_seen <= 1;

        end
    end

endmodule
`undef pproc_bus_gba
