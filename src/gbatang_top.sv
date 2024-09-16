// GBA for Tang FPGA
// nand2mario, 2024.7

// uncomment this to use test rom instead of iosys menu system
//`define TEST_LOADER

module gbatang_top (

`ifndef VERILATOR
    input clk50,

    // MicroSD
    output sd_clk,
    inout  sd_cmd,                  // MOSI
    input  sd_dat0,                 // MISO
    output sd_dat1,
    output sd_dat2,
    output sd_dat3,

    // SPI flash
    output flash_spi_cs_n,          // chip select
    input flash_spi_miso,           // master in slave out
    output flash_spi_mosi,          // mster out slave in
    output flash_spi_clk,           // spi clock
    output flash_spi_wp_n,          // write protect
    output flash_spi_hold_n,        // hold operations

    // dualshock controller on pmod0
    output ds_clk,
    input ds_miso,
    output ds_mosi,
    output ds_cs,

    // SDRAM
    output O_sdram_clk,
    output O_sdram_cs_n,            // chip select
    output O_sdram_cas_n,           // columns address select
    output O_sdram_ras_n,           // row address select
    output O_sdram_wen_n,           // write enable
    inout [15:0] IO_sdram_dq,       // 16 bit bidirectional data bus
    output [12:0] O_sdram_addr,     // 13 bit multiplexed address bus
    output [1:0] O_sdram_dqm,       // 
    output [1:0] O_sdram_ba,        // 4 banks

    // UART
    input UART_RXD,
    output UART_TXD,    
`else           // Ports for Verilator
    input clk16,
    input clk50,
    input [11:0] joy_btns,
    output gba_on,

    input [2:0] loading,            // 0: gba on, 1: loading rom, 2: loading cartram, 3: set up flash backup
    input [7:0] loader_do,
    input loader_do_valid,
`endif

    output reg [7:0] led,           // debug leds on pmod1
    input s0,
    input s1,

    // HDMI output
    output       tmds_clk_n,
    output       tmds_clk_p,
    output [2:0] tmds_d_n,
    output [2:0] tmds_d_p    
);

`include "pproc_bus_gba.sv"

// Clocking
`ifndef VERILATOR
wire clk27;         // intermediate 27Mhz clock for HDMI
// wire clk105;
// OSC #(.FREQ_DIV(2)) osc (.OSCOUT(clk105));
// pll_27 pll27(.clkin(clk105), .clkout0(clk27));
pll_27 pll27(.clkin(clk50), .clkout0(clk27));

wire clk16;         // main clock: 16.7Mhz GBA CPU clock
wire clk50;         // ppu clock:  3 x 16.7Mhz
wire clk67, clk67_p;// ram clock:  67.2Mhz
wire hclk, hclk5;   // 74.25Mhz hdmi 720p pixel clock
pll_33 pll33(.clkin(clk27), .clkout0(clk50), .clkout1(clk16), .clkout2(clk67), .clkout3(clk67_p));
pll_74 pll74(.clkin(clk27), .clkout0(hclk), .clkout1(hclk5));
assign O_sdram_clk = clk67_p;

wire [2:0]  loading;
wire        loader_do_valid;
wire [7:0]  loader_do;
`endif

reg resetn = 0;
wire gbaon;         // this is resetn signal for everything gba except memory (needed by iosys)

/* verilator public_on */

// CPU bus signals
wire [27:0] ram_addr, rom_addr;
wire [31:0] ram_wdata;
wire thumb;         // whether next rom load is 16-bit
wire ram_cen, ram_wen, rom_en;
wire [3:0] ram_be;  // byte enable
wire [31:0] ram_rdata, rom_data;
wire cpu_en;        // Memory access done and there's no DMA
wire halt;          // HALTCNT write halts CPU until interrupts

// DMA bus signals
wire [27:0] dma_addr;
wire [31:0] dma_wdata, dma_rdata;
wire dma_rnw;
wire dma_on, dma_bus_ena; //dma_bus_unread;
wire dma_bus_done;
wire [1:0] dma_bus_acc;

/* verilator public_off */

// GPU to DMA signals
wire hblank_trigger, vblank_trigger, videodma_start, videodma_stop;

// sound
wire [15:0] sound_out_left /* verilator public */, sound_out_right /* verilator public */;
wire [1:0] sound_dma_req;

// timers
wire timer0_tick, timer1_tick;

// interrupts
wire cpu_IRP;
wire IRP_VBlank, IRP_HBlank, IRP_LCDStat, IRP_Serial, IRP_Joypad;
wire [3:0] IRP_Timer, IRP_DMA;


////////////////////////////
// CPU
////////////////////////////

gba_cpu cpu (
    .clk(clk16), .rst(~gbaon), .cpu_en(cpu_en & ~halt), .cpu_restart(~gbaon), .fiq(1'b0), 
    .irq(cpu_IRP), .thumb(thumb),
    .ram_abort(1'b0), .ram_rdata(ram_rdata), .rom_abort(1'b0), .rom_data(rom_data),
    .ram_addr(ram_addr), .ram_cen(ram_cen), .ram_flag(ram_be), .ram_wdata(ram_wdata),
    .ram_wen(ram_wen),  .rom_addr(rom_addr), .rom_en(rom_en) ); 

`ifndef VERILATOR
reg [15:0] rstCnt = 16'hffff;
`else
reg [1:0] rstCnt = 2'b11;
`endif

always @(posedge clk16) begin           // reset logic
    if (rstCnt != 0) begin
        rstCnt <= rstCnt - 1;
    end else begin
    // end else if (~s0) begin
        if (~resetn)
            $display("gbatang_top: reset done");
        resetn = 1;
    end
end

`ifdef VERILATOR
assign gba_on = gbaon;
`endif

////////////////////////////
// GPU
////////////////////////////

wire [7:0] pixel_out_x /* verilator public */, pixel_out_y /* verilator public */;
wire [17:0] pixel_out_data /* verilator public */;
wire pixel_out_we /* verilator public */;

wire [proc_buswidth-1:0] gb_bus_din;        // CPU bus
wire [proc_buswidth-1:0] gb_bus_dout;
wire [proc_busadr-1:0] gb_bus_adr;
wire gb_bus_rnw;
wire gb_bus_ena;
wire gb_bus_done;
wire [1:0] gb_bus_acc;
wire [3:0] gb_bus_be;
wire gb_bus_rst;

wire [13:0] vram_lo_addr;
wire [31:0] vram_lo_din, vram_lo_dout;
wire vram_lo_we;
wire [3:0] vram_lo_be;
wire [12:0] vram_hi_addr;
wire [31:0] vram_hi_din, vram_hi_dout;
wire vram_hi_we;
wire [3:0] vram_hi_be;
wire [7:0] oamram_addr;
wire [31:0] oamram_din, oamram_dout;
wire [3:0] oamram_we;
wire [6:0] palette_bg_addr;
wire [31:0] palette_bg_din, palette_bg_dout;
wire [3:0] palette_bg_we;
wire [6:0] palette_oam_addr;
wire [31:0] palette_oam_din, palette_oam_dout;
wire [3:0] palette_oam_we;

wire phase = ~clk16;    // 0: internal GPU work, 1: get data from CPU

gba_gpu #(.FCLK_SPEED(3)) gpu (
    .fclk(clk50), .mclk(clk16), .phase(phase), .reset(~gbaon),
    `GB_BUS_PORTS_INST,

    // config
    .lockspeed(1'b0), .interframe_blend(2'b0), .maxpixels(1'b0), .shade_mode(3'b0), 
    .hdmode2x_bg(1'b0), .hdmode2x_obj(1'b0), 
    .bitmapdrawmode(), 
    
    // output
    .pixel_out_x(pixel_out_x), .pixel_out_2x(), .pixel_out_y(pixel_out_y), .pixel_out_addr(), 
    .pixel_out_data(pixel_out_data), .pixel_out_we(pixel_out_we), .pixel2_out_x(), 
    .pixel2_out_data(), .pixel2_out_we(), 
    
    // one cycle a time on phase 0
    .new_cycles(8'd1), .new_cycles_valid(clk16 == 0),
    
    .IRP_HBlank(IRP_HBlank), .IRP_VBlank(IRP_VBlank), .IRP_LCDStat(IRP_LCDStat), 
    .hblank_trigger_dma(hblank_trigger), .vblank_trigger_dma(vblank_trigger), 
    .videodma_start_dma(videodma_start), .videodma_stop_dma(videodma_stop), 
    
    // VRAM access from CPU
    .VRAM_Lo_addr(vram_lo_addr), .VRAM_Lo_datain(vram_lo_din), .VRAM_Lo_dataout(vram_lo_dout), 
    .VRAM_Lo_we(vram_lo_we), .VRAM_Lo_be(vram_lo_be), 
    .VRAM_Hi_addr(vram_hi_addr), .VRAM_Hi_datain(vram_hi_din), .VRAM_Hi_dataout(vram_hi_dout), 
    .VRAM_Hi_we(vram_hi_we), .VRAM_Hi_be(vram_hi_be), 
    .vram_blocked(), .OAMRAM_PROC_addr(oamram_addr), .OAMRAM_PROC_datain(oamram_din), 
    .OAMRAM_PROC_dataout(oamram_dout), .OAMRAM_PROC_we(oamram_we), 
    
    // Palette access from CPU
    .PALETTE_BG_addr(palette_bg_addr), .PALETTE_BG_datain(palette_bg_din), .PALETTE_BG_dataout(palette_bg_dout), 
    .PALETTE_BG_we(palette_bg_we), 
    .PALETTE_OAM_addr(palette_oam_addr), .PALETTE_OAM_datain(palette_oam_din), .PALETTE_OAM_dataout(palette_oam_dout), 
    .PALETTE_OAM_we(palette_oam_we), 

    .DISPSTAT_debug()
);


////////////////////////////
// Sound
////////////////////////////

gba_sound sound (
    .clk(clk16), .reset(~gbaon), .gb_on(1'b1),
    `GB_BUS_PORTS_INST,
    .timer0_tick(timer0_tick), .timer1_tick(timer1_tick), .sound_dma_req(sound_dma_req),
    .sound_out_left(sound_out_left), .sound_out_right(sound_out_right),
    .debug_fifocount()
);

////////////////////////////
// Memory
////////////////////////////

// cpu sdram memory interface
wire [25:2] cpu_mem_addr;
wire [31:0] cpu_mem_wdata;
wire [31:0] cpu_mem_rdata [1:3];
wire        cpu_mem_rd, cpu_mem_wr;
wire [3:0]  cpu_mem_be;
wire        cpu_mem_ready;
wire [1:0]  cpu_mem_port;

// iosys RV memory interface
wire        rv_valid;
wire        rv_ready;
wire [22:0] rv_addr;
wire [31:0] rv_wdata;
wire [3:0]  rv_wstrb;
wire [31:0] rv_rdata;

// sdram-side interface
wire [22:1] rv_mem_addr;
wire [15:0] rv_mem_din;
wire [1:0]  rv_mem_ds;
wire [15:0] rv_mem_dout;
wire        rv_mem_req;
wire        rv_mem_req_ack;
wire        rv_mem_we;

wire        sdram_busy;
wire        flash_backup_en;

wire [16:0] dma_eepromcount;

gba_memory mem (
    .clk(clk16), .resetn(resetn), .ce(1'b1),
    // CPU memory interface
    .rom_en(rom_en), .rom_addr(rom_addr), .rom_data(rom_data), .thumb(thumb), .cpu_en(cpu_en), 

    .ram_cen(ram_cen), .ram_wen(ram_wen), .ram_addr(ram_addr), .ram_rdata(ram_rdata),
    .ram_wdata(ram_wdata), .ram_be(ram_be), 

    .dma_on(dma_on), .dma_addr(dma_addr), .dma_wdata(dma_wdata), .dma_ena(dma_bus_ena), 
    .dma_wr(~dma_rnw), .dma_be(calc_byte_ena(dma_bus_acc, dma_addr[1:0])), 
    .dma_rdata(dma_rdata), .dma_done(dma_bus_done), .dma_eepromcount(dma_eepromcount),

    // SDRAM interface
	.sdram_addr(cpu_mem_addr), .sdram_wdata(cpu_mem_wdata), .sdram_rdata(cpu_mem_rdata), 
    .sdram_rd(cpu_mem_rd), .sdram_wr(cpu_mem_wr), .sdram_be(cpu_mem_be),
    .sdram_port(cpu_mem_port), .sdram_ready(cpu_mem_ready),

    // Loader interface
    .loading(loading), .loader_data(loader_do), .loader_valid(loader_do_valid),
    .gbaon(gbaon), .flash_backup_en(flash_backup_en),

    // Interface to GPU to access special memory like VRAM, OAMRAM, PALETTE
    .vram_lo_addr(vram_lo_addr), .vram_lo_din(vram_lo_din), .vram_lo_dout(vram_lo_dout), 
    .vram_lo_we(vram_lo_we), .vram_lo_be(vram_lo_be), 
    .vram_hi_addr(vram_hi_addr), .vram_hi_din(vram_hi_din), .vram_hi_dout(vram_hi_dout), 
    .vram_hi_we(vram_hi_we), .vram_hi_be(vram_hi_be), 
    .gb_bus_din(gb_bus_din), .gb_bus_dout(gb_bus_dout), .gb_bus_adr(gb_bus_adr),
    .gb_bus_rnw(gb_bus_rnw), .gb_bus_ena(gb_bus_ena), .gb_bus_done(gb_bus_done),
    .gb_bus_acc(gb_bus_acc), .gb_bus_be(gb_bus_be), .gb_bus_rst(gb_bus_rst), 
    .oamram_addr(oamram_addr), .oamram_din(oamram_din), .oamram_dout(oamram_dout), .oamram_we(oamram_we), 
    .palette_bg_addr(palette_bg_addr), .palette_bg_din(palette_bg_din), 
    .palette_bg_dout(palette_bg_dout), .palette_bg_we(palette_bg_we), 
    .palette_oam_addr(palette_oam_addr), .palette_oam_din(palette_oam_din), 
    .palette_oam_dout(palette_oam_dout), .palette_oam_we(palette_oam_we)
);

`ifndef VERILATOR
sdram_gba sdram (
    .SDRAM_DQ(IO_sdram_dq), .SDRAM_A(O_sdram_addr),
	.SDRAM_BA(O_sdram_ba), .SDRAM_nCS(O_sdram_cs_n), .SDRAM_nWE(O_sdram_wen_n),
	.SDRAM_nRAS(O_sdram_ras_n), .SDRAM_nCAS(O_sdram_cas_n), 
    .SDRAM_DQM(O_sdram_dqm),

	// cpu/chipset interface
	.clk(clk67), .mclk(clk16), .resetn(resetn),

	.cpu_addr(cpu_mem_addr), .cpu_wdata(cpu_mem_wdata), .cpu_rdata(cpu_mem_rdata), 
    .cpu_rd(cpu_mem_rd), .cpu_wr(cpu_mem_wr), .cpu_be(cpu_mem_be),
    .cpu_ready(cpu_mem_ready), .cpu_port(cpu_mem_port),
    .flash_backup_en(flash_backup_en),
	
    .rv_addr(rv_mem_addr), .rv_din(rv_mem_din), .rv_ds(rv_mem_ds), 
    .rv_dout(rv_mem_dout), .rv_req(rv_mem_req), .rv_req_ack(rv_mem_req_ack), 
    .rv_we(rv_mem_we),

    .busy(sdram_busy)
);

rv_sdram_adapter rv_adapt (
    .clk(clk16), .resetn(resetn),
    .rv_valid(rv_valid), .rv_addr(rv_addr), .rv_wdata(rv_wdata),
    .rv_wstrb(rv_wstrb), .rv_ready(rv_ready), .rv_rdata(rv_rdata),
    .mem_addr(rv_mem_addr), .mem_req(rv_mem_req), .mem_ds(rv_mem_ds),
    .mem_din(rv_mem_din), .mem_we(rv_mem_we), .mem_req_ack(rv_mem_req_ack),
    .mem_dout(rv_mem_dout)
);
`else

// model for cpu to work under verilator
sdram_sim sdram (
	.clk(clk16),
	.cpu_addr(cpu_mem_addr), .cpu_wdata(cpu_mem_wdata), .cpu_rdata(cpu_mem_rdata), 
    .cpu_rd(cpu_mem_rd), .cpu_wr(cpu_mem_wr), .cpu_be(cpu_mem_be),
    .cpu_ready(cpu_mem_ready), .cpu_port(cpu_mem_port), 
    .flash_backup_en(flash_backup_en)
);

`endif

////////////////////////////
// Interrupts
////////////////////////////
gba_interrupts intr (.clk(clk16), .resetn(gbaon),
    `GB_BUS_PORTS_INST,
    .IRP_VBlank(IRP_VBlank), .IRP_HBlank(IRP_HBlank), .IRP_LCDStat(IRP_LCDStat), 
    .IRP_Timer(IRP_Timer), .IRP_Serial(IRP_Serial), .IRP_DMA(IRP_DMA), 
    .IRP_Joypad(IRP_Joypad), 
    .cpu_IRP(cpu_IRP), .halt(halt)
);

////////////////////////////
// DMA
////////////////////////////

gba_dma dma (
    .clk100(clk16), .reset(~gbaon), .ce(1'b1 /*~halt*/), `GB_BUS_PORTS_INST, 
    .new_cycles(1), .new_cycles_valid(1'b1), .irp_dma(IRP_DMA), .lastread_dma(), 
    .dma_on(dma_on), .do_step(1'b1), .cpu_preemptable(cpu_en),      // always start DMA after a ready cycle
    .sound_dma_req(sound_dma_req), .hblank_trigger(hblank_trigger), .vblank_trigger(vblank_trigger), 
    .videodma_start(videodma_start), .videodma_stop(videodma_stop), .dma_new_cycles(), 
    .dma_first_cycles(), .dma_dword_cycles(), .dma_toROM(), 
    .dma_init_cycles(), .dma_cycles_adrup(), .dma_eepromcount(dma_eepromcount), 
    .dma_bus_Adr(dma_addr), .dma_bus_rnw(dma_rnw), .dma_bus_ena(dma_bus_ena), 
    .dma_bus_acc(dma_bus_acc), .dma_bus_dout(dma_wdata), .dma_bus_din(dma_rdata), 
    .dma_bus_done(dma_bus_done), .dma_bus_unread(), .debug_dma()
);

////////////////////////////
// Timer
////////////////////////////
gba_timer timer (
    .clk(clk16), .gb_on(1'b1), .reset(~gbaon), 
    `GB_BUS_PORTS_INST,
    .IRP_Timer(IRP_Timer),  .timer0_tick(timer0_tick), .timer1_tick(timer1_tick), 
    .debugout0(), .debugout1(), .debugout2(), .debugout3() );


////////////////////////////
// Joypad
////////////////////////////

`ifndef VERILATOR
wire [11:0] joy_btns;       // (R L X A RT LT DN UP START SELECT Y B)
controller_ds2 ds2 (
    .clk(clk16), .snes_buttons(joy_btns),
    .ds_clk(ds_clk), .ds_miso(ds_miso), .ds_mosi(ds_mosi), .ds_cs(ds_cs) 
);
`endif
gba_joypad joypad (
    .mclk(clk16), /*.fclk(clk33),*/ `GB_BUS_PORTS_INST, .IRP_Joypad(IRP_Joypad),
    .KeyA(joy_btns[8]), .KeyB(joy_btns[0]), .KeySelect(joy_btns[2]), .KeyStart(joy_btns[3]), 
    .KeyRight(joy_btns[7]), .KeyLeft(joy_btns[6]), .KeyUp(joy_btns[4]), .KeyDown(joy_btns[5]), 
    .KeyR(joy_btns[11]), .KeyL(joy_btns[10]),
    .cpu_done()
);


////////////////////////////
// Video output
////////////////////////////

`ifndef VERILATOR
// wire overlay = ~s1;      // for debug
wire overlay;
wire [14:0] overlay_color;
wire [10:0] overlay_x;
wire [9:0] overlay_y;

gba2hdmi video (
	.clk(clk50), .resetn(resetn),
	.clk_pixel(hclk), .clk_5x_pixel(hclk5),
    .pixel_data(pixel_out_data), .pixel_x(pixel_out_x), .pixel_y(pixel_out_y),
    .pixel_we(pixel_out_we),
    .sound_left(sound_out_left), .sound_right(sound_out_right),
`ifdef TEST_LOADER
    .overlay(0),
`else
    .overlay(overlay), 
`endif
    .overlay_x(overlay_x), .overlay_y(overlay_y), .overlay_color(overlay_color),
	.tmds_clk_n(tmds_clk_n), .tmds_clk_p(tmds_clk_p), .tmds_d_n(tmds_d_n),
	.tmds_d_p(tmds_d_p)
);

////////////////////////////
// iosys for menu, rom loading and other functions
////////////////////////////

iosys #(.CORE_ID(3)) iosys (
    .clk(clk16), .hclk(hclk), .spi_clk(clk67), .resetn(resetn),

    .overlay(overlay), .overlay_x(overlay_x), .overlay_y(overlay_y), .overlay_color(overlay_color),
    .joy1(joy_btns), .joy2(12'b0),

`ifdef TEST_LOADER
    .rom_loading(), .rom_do(), .rom_do_valid(), 
`else
    .rom_loading(loading), .rom_do(loader_do), .rom_do_valid(loader_do_valid), 
`endif
    .ram_busy(sdram_busy),

    .rv_valid(rv_valid), .rv_ready(rv_ready), .rv_addr(rv_addr), .rv_wdata(rv_wdata), 
    .rv_wstrb(rv_wstrb), .rv_rdata(rv_rdata), 

    .flash_spi_cs_n(flash_spi_cs_n), .flash_spi_miso(flash_spi_miso),
    .flash_spi_mosi(flash_spi_mosi), .flash_spi_clk(flash_spi_clk),
    .flash_spi_wp_n(flash_spi_wp_n), .flash_spi_hold_n(flash_spi_hold_n),

    .uart_tx(UART_TXD), .uart_rx(UART_RXD),

    .sd_clk(sd_clk), .sd_cmd(sd_cmd), .sd_dat0(sd_dat0), .sd_dat1(sd_dat1),
    .sd_dat2(sd_dat2), .sd_dat3(sd_dat3)
);

`ifdef TEST_LOADER
// test rom, start loading once sdram is ready
test_loader loader (
    .clk(clk16), .resetn(resetn & ~sdram_busy), .loading(loading), .dout(loader_do), 
    .dout_valid(loader_do_valid)
);
`endif

`endif 

assign led = ~{7'b000, gbaon};

function [3:0] calc_byte_ena (input [1:0] size, input [1:0] addr);
    casez ({size, addr})
    // byte access
    4'b00_??: calc_byte_ena = 1 << addr;
    // half-word
    4'b01_0?: calc_byte_ena = 4'b0011;
    4'b01_1?: calc_byte_ena = 4'b1100;
    // word
    4'b10_??: calc_byte_ena = 4'b1111;
    default: calc_byte_ena = 4'b0;
    endcase
endfunction


endmodule

`undef pproc_bus_gba