// Memory multiplexer for GBA
// nand2mario, 9/2024
//
// Cartridge ROM, EWRAM and flash/sram are in SDRAM. Others are in BRAM. Memory accesses 
// come from two sources, CPU and DMA, with three possible patterns from the CPU.
// 1. ROM (instruction) only access (rom_cen & ~ram_cen)
// 2. RAM (data) only access
// 3. Simultaneous ROM and RAM access (executed as ROM first, then RAM)
//
// This is how the controller serves requests.
// * A single ROM or RAM access can take 1 (bram), 3 (16-bit sdram) or 5 (32-bit sdram) 
//   cycles.
// * We use `valid` / `ready` handshakes similar to AXI-lite. Every memory cycles begins
///  with the CPU asserting rom_en and/or ram_cen ("valid"), while the memory controller 
//   `state == MAIN`. At the end of the memory cycle, the controller asserts `cpu_en` to 
//   indicate the "ready" cycle, before offering the data in the NEXT cycle.
// * Note that `main` and `ready` could be the same cycle for back-to-back execution. For
//   instance when CPU is executing register-only instructions in IWRAM, cpu_en=1 in the 
//   same cycle as the request.
// * During the memory cycle, CPU ensures that the address signals are constant. This memory 
//   controller keeps `ram_rdata` and `rom_rdata` constant (w/ `ram_rdata_buf`, `rom_rdata_buf`). 
//   After cpuen==1, they are updated with new values.
// * For every memory cycle, 1 or 2 CPU requests translates to at most 4 underlying requests
//   as our SDRAM is 16-bit. In cycle 0, comb logic drives the 1st request if it is backed 
//   by bram (e.g. BIOS, IWRAM). Then sequential logic drives other requests, including the
//   1st request if it is backed by sdram.
//
// Examples with state transitions:
//   cycle       0     1     2     3     4     5     6     7     8     9    
// cpu read 16-bit from game pak, data expected in cycle 2 (sequential) or 5 (random)
//   cpu      | req |     | DATA|
//   sdram    |rd_lo|ready| data|
//   state    | MAIN|WAIT1| MAIN|
//  cpu_ready       |  1  |
// cpu read 32-bit from game pak, data expected in cycle 4 (sequential) or 7 (random)
//   cpu      | req |                 | DATA      |
//   sdram    |rd_lo| wait|rd_hi|ready| data      |
//   state    | MAIN|WAIT1|WAIT1|WAIT1| MAIN
//  cpu_ready                   |  1  |
// cpu read 32-bit rom_data and 16-bit ram_rdata from game pak
//   cpu      | req |                             | rom/ram_rdata  |
//   sdram    |rd_lo| wait|rd_hi|ready|rd_lo|ready|
//   state    | MAIN|WAIT1|WAIT1|WAIT1|STRT2|WAIT2| MAIN
//  cpu_ready                               |  1  |
// read from IWRAM in a single cycle
//   dma      | req | DATA|
//   iwram    |  rd |     |      
//   state    | MAIN| MAIN|
//
// DMA can interrupt normal CPU operations. We make sure DMA happens only after a ready cycle 
// (`dma.cpu_preemptable`). The memory controler saves CPU data to `rom_rdata_buf` and 
// `ram_rdata_buf`, as the underlying memory registers could be overwritten by DMA. After
// DMA is done, the first cycle always outputs `rom_rdata_buf` and `ram_rdata_buf`.
//

// uncomment this to print memory debug messages in Verilator
// `define DEBUG

module gba_memory (
    input               clk,
    input               resetn,
    input               ce,

    // CPU interface
    input               rom_en    /* xxsynthesis syn_keep=1 */,
    input      [31:0]   rom_addr  /* xxsynthesis syn_keep=1 */,       // PC address, word aligned for ARM mode, half-word aligned for thumb mode
    input               thumb,          // 1: thumb (16-bit) mode for this rom load
    output reg [31:0]   rom_data  /* xsynthesis syn_keep=1 */,

    input               ram_cen   /* xsynthesis syn_keep=1 */,        // cpu ram interface, also used for DMA
    input               ram_wen   /* xsynthesis syn_keep=1 */,
    input      [31:0]   ram_addr  /* xsynthesis syn_keep=1 */,       // last two bits ignored because we have ram_be
    input      [31:0]   ram_wdata /* xsynthesis syn_keep=1 */,
    input       [3:0]   ram_be    /* xsynthesis syn_keep=1 */,
    output reg [31:0]   ram_rdata /* xsynthesis syn_keep=1 */,

    output reg          cpu_en    /* xsynthesis syn_keep=1 */,         // rom_data and ram_rdata is available NEXT cycle and there's no ongoing DMA

    // DMA interface
    input               dma_on,         // DMA is accessing memory, save state and pause CPU
    input      [31:0]   dma_addr,
    input      [31:0]   dma_wdata,
    input               dma_ena,
    input               dma_wr,
    input       [3:0]   dma_be,
    output reg [31:0]   dma_rdata,
    output reg          dma_done,       // mem_ready for dma
    input      [16:0]   dma_eepromcount,    // for eeprom address length detection

    // MMIO register bus to various components
    output     [31:0]   gb_bus_din  /* xsynthesis syn_keep=1 */, 
    input      [31:0]   gb_bus_dout /* xsynthesis syn_keep=1 */, 
    output     [27:0]   gb_bus_adr  /* xsynthesis syn_keep=1 */, 
    output              gb_bus_rnw, 
    output              gb_bus_ena, 
    output              gb_bus_done, 
    output      [1:0]   gb_bus_acc,
    output      [3:0]   gb_bus_be,
    output              gb_bus_rst,

    // SDRAM interface
	output reg [1:0]    sdram_port,           
    output reg [25:2]   sdram_addr,
    output reg [31:0]   sdram_wdata,
    input      [31:0]   sdram_rdata [1:3],
    output reg          sdram_rd,
    output reg          sdram_wr,
    output reg [3:0]    sdram_be,
    input               sdram_ready,
    input               backup_written,

    // EEPROM for access from RV
    input               eeprom_rd,
    input       [3:0]   eeprom_wr,
    input      [12:0]   eeprom_addr,
    output      [7:0]   eeprom_rdata,
    input       [7:0]   eeprom_wdata,

    // Loader interface
    input       [2:0]   loading      /* xsynthesis syn_keep=1 */,     // 0: off, 1: ROM, 2: Cart RAM, 3: Config, 4: BIOS
    input       [7:0]   loader_data  /* xsynthesis syn_keep=1 */, 
    input               loader_valid /* xsynthesis syn_keep=1 */,
    output reg          gbaon,          // GBA is turned on after loading goes from none-zero to zero
    output reg  [2:0]   config_backup_type,   // 0: no backup, 1: 512Kbit, 2: 1Mbit, 3: SRAM, 4: EEPROM

    output reg          cartram_dirty,  // set to 1 whenever cartram is written to
    input               cartram_dirty_clear,    // clears cartram_dirty

    // GPU memory interface
    output     [13:0]   vram_lo_addr,
    output     [31:0]   vram_lo_din,
    input      [31:0]   vram_lo_dout,
    output              vram_lo_we,
    output      [3:0]   vram_lo_be,     // byte enable

    output     [12:0]   vram_hi_addr,
    output     [31:0]   vram_hi_din,
    input      [31:0]   vram_hi_dout,
    output              vram_hi_we,
    output      [3:0]   vram_hi_be,     // byte enable

    output      [7:0]   oamram_addr,
    output     [31:0]   oamram_din,
    input      [31:0]   oamram_dout,
    output      [3:0]   oamram_we,      // per-byte write enable

    output      [6:0]   palette_bg_addr,
    output     [31:0]   palette_bg_din,
    input      [31:0]   palette_bg_dout,
    output      [3:0]   palette_bg_we,  // per-byte write enable

    output      [6:0]   palette_oam_addr,
    output     [31:0]   palette_oam_din,
    input      [31:0]   palette_oam_dout,
    output      [3:0]   palette_oam_we  // per-byte write enable
);

// GBA memory map:
// 0x00000000 - 0x00003FFF - 16 KB BIOS (executable, but not readable)
// 0x02000000 - 0x0203FFFF - 256 KB EWRAM (general purpose RAM external to the CPU)
// 0x03000000 - 0x03007FFF - 32 KB IWRAM (general purpose RAM internal to the CPU)
// 0x04000000 - 0x040003FF - I/O Registers
// 0x05000000 - 0x050003FF - 1 KB Colour Palette RAM
// 0x06000000 - 0x06017FFF - 96 KB VRAM (Video RAM)
// 0x07000000 - 0x070003FF - 1 KB OAM RAM (Object Attribute Memory)
// 0x08000000 - 0x0CFFFFFF - Game Pak ROM (max 32 MB)
// 0x0D000000 - 0x0DFFFFFF - EEPROM serial access (bit0). For 32MB carts, only 0x0DFFFF00 - 0x0DFFFFFF
// 0x0E000000 - 0x0E00FFFF - Cartridge RAM (SRAM, Flash). Flash is max 128KB (2 banks)


`include "pproc_bus_gba.sv"

/////////////////////////////////////////////////////////
// CPU instruction/data access and DMA multiplexer
/////////////////////////////////////////////////////////


reg         loader_writing;
reg [7:0]   loader_buf[0:3];                        // byte-by-byte. bottleneck is SD card
reg [7:0]   loader_d;
reg [27:0]  loader_addr;                            // region 8 and 9 for ROM, region E for cart RAM

localparam BACKUP_NONE = 3'd0;
localparam BACKUP_FLASH512K = 3'd1;
localparam BACKUP_FLASH1M = 3'd2;
localparam BACKUP_SRAM = 3'd3;
localparam BACKUP_EEPROM = 3'd4;

reg         config_eeprom_type = 1;                 // 1: 64kbit eeprom, 0: 4kbit
reg         active;
wire        eeprom_written;

// these drive all bram-backed memory (iwram, bios, palette, vram, oam, eeprom)
reg  [1:0]  bram_port;      // 1: ROM, 2: RAM, 3: DMA
reg [27:0]  bram_addr;
reg         bram_rd, bram_wr;
reg [3:0]   bram_be;
reg [31:0]  bram_wdata;
reg [31:0]  bram_rdata;

// buffers for non-0 cycles
reg [27:0]  bram_addr_buf;
reg         bram_rd_buf, bram_wr_buf;                                 
reg [31:0]  bram_wdata_buf;
reg [3:0]   bram_be_buf;
reg [1:0]   bram_port_buf;
reg [25:2]  sdram_addr_buf;
reg         sdram_rd_buf, sdram_wr_buf;
reg [31:0]  sdram_wdata_buf;
reg [3:0]   sdram_be_buf;
reg [1:0]   sdram_port_buf;

// delayed
reg  [1:0]  bram_port_r;
reg  [27:0] bram_addr_r;
reg         bram_rd_r;
reg         rom_en_r, ram_cen_r;
reg         dma_on_r;

// current values for CPU
reg [31:0]  rom_rdata_buf, ram_rdata_buf;
reg [31:0]  rom_rdata_new;  // new value for next MAIN
reg         second_start;   // for collecting rom_rdata_new
reg         double_req;     // the last request is a rom/ram double request
reg         dma_sdram;      // last dma request is sdram

reg [2:0]   state;
localparam  MAIN        = 3'd0; // idle, or comb logic is driving bram request
localparam  REQ1_START  = 3'd1; // sdram request 1 first cycle
localparam  REQ1_WAIT   = 3'd2; // sdram request 1 wait 
localparam  REQ2_BRAM   = 3'd3; // bram (single cycle) request 2
localparam  REQ2_START  = 3'd4; // sdram request 2 first cycle
localparam  REQ2_WAIT   = 3'd5; // sdram request 2 wait

localparam  PORT_NONE = 2'd0;
localparam  PORT_ROM  = 2'd1;
localparam  PORT_RAM  = 2'd2;
localparam  PORT_DMA  = 2'd3;

// BRAM memory requests
always @* begin
    bram_addr = 32'hbaaddeed;
    bram_wdata = 32'hdeadbeef;
    bram_rd = 0; 
    bram_wr = 0;
    bram_be = 4'b0;
    bram_port = PORT_NONE;

    if (state == MAIN) begin
        // cycle 0 BRAM memory requests
        if (dma_on) begin
            if (dma_ena & issingle(dma_addr[27:24])) begin
                bram_addr = dma_addr;
                bram_rd = ~dma_wr;
                bram_wr = dma_wr;
                bram_wdata = dma_wdata;
                bram_be = dma_be;
                bram_port = PORT_DMA;
            end
        end else if (rom_en) begin
            if (issingle(rom_addr[27:24])) begin
                bram_addr = rom_addr;
                bram_rd = 1; 
                bram_wr = 0;
                bram_be = 4'b1111;
                bram_port = PORT_ROM;    
            end
        end else if (ram_cen & issingle(ram_addr[27:24])) begin
            bram_addr = ram_addr;
            bram_rd = ~ram_wen;
            bram_wr = ram_wen;
            bram_wdata = ram_wdata;
            bram_be = ram_be;
            bram_port = PORT_RAM;
        end
    end else begin
        bram_addr = bram_addr_buf;
        bram_rd = bram_rd_buf; 
        bram_wr = bram_wr_buf;
        bram_wdata = bram_wdata_buf;
        bram_be = bram_be_buf;
        bram_port = bram_port_buf;
    end
end

// SDRAM memory requests
always @* begin
    if (state == MAIN & ~dma_on) begin
        sdram_rd = 0; sdram_wr = 0;
        sdram_addr = 24'hbadbad; sdram_wdata = 0; sdram_be = 0;
        sdram_port = PORT_NONE;
        if (rom_en) begin
            if (~issingle(rom_addr[27:24])) begin
                sdram_rd = 1;
                sdram_addr = tosdram(rom_addr);
                if (thumb)
                    sdram_be = rom_addr[1] ? 4'b1100 : 4'b0011; 
                else
                    sdram_be = 4'b1111;                
                sdram_port = PORT_ROM;
            end
        end else if (ram_cen & ~issingle(ram_addr[27:24])) begin
            sdram_rd = ~ram_wen;
            sdram_wr = ram_wen;
            if (isreadonly(ram_addr[27:24])) begin
                sdram_rd = 1;
                sdram_wr = 0;
            end
            sdram_addr = tosdram(ram_addr);
            sdram_wdata = ram_wdata;
            if (ram_addr[27:25] == 3'b111)          // 8-bit access for flash/SRAM
                sdram_be = 4'b1 << ram_addr[1:0];
            else
                sdram_be = ram_be;
            sdram_port = PORT_RAM;
        end
    end else begin
        sdram_rd = sdram_rd_buf;
        sdram_wr = sdram_wr_buf;
        sdram_addr = sdram_addr_buf;
        sdram_wdata = sdram_wdata_buf;
        sdram_be = sdram_be_buf;
        sdram_port = sdram_port_buf;
    end
end

// the state machine
always @(posedge clk) begin
    reg [1:0] port;
    reg [27:0] addr;
    reg [31:0] wdata;
    reg [3:0] be;
    reg wr;

    if (~resetn) begin
        port = 0; addr = 0; wdata = 0; be = 0; wr = 0;
    end else begin
        reg active_var, hi;
        hi = 0;

        // default values
        sdram_rd_buf <= 0; sdram_wr_buf <= 0;

        // new rom value from bram needs to be saved as 2nd request may overwrite it
        if (state == REQ2_BRAM | state == REQ2_START)
            if (bram_port_r != PORT_NONE)
                rom_rdata_new <= bram_rdata;
            else
                rom_rdata_new <= sdram_rdata[PORT_ROM];

        dma_on_r <= dma_on;

        case (state) 
        MAIN, REQ1_WAIT: begin
            if (state == MAIN | ~dma_on_r) begin                // new values
                rom_rdata_buf <= rom_data;
                ram_rdata_buf <= ram_rdata;
            end
            if (state == MAIN) begin
                bram_rd_buf <= 0;
                bram_wr_buf <= 0;
                bram_port_buf <= 0;
            end

            if (state == MAIN & bram_port != PORT_NONE |        // bram is driving first request
                state == REQ1_WAIT & sdram_ready)               // last cycle of sdram request 1
            begin
                state <= MAIN;                                  // by default return to MAIN state
                if (~dma_on & rom_en & ram_cen) begin
                    double_req <= 1;

                    // issue request 2
                    if (issingle(ram_addr[27:24])) begin
                        // req2.single
                        state <= REQ2_BRAM;
                        bram_addr_buf <= ram_addr;
                        bram_rd_buf <= ~ram_wen;
                        bram_wr_buf <= ram_wen;
                        bram_wdata_buf <= ram_wdata;
                        bram_be_buf <= ram_be;
                        bram_port_buf <= PORT_RAM;
                    end else begin                              // start multi-cycle request 2 for RAM
                        // req2.sdram
                        state <= REQ2_START;
                        sdram_rd_buf <= ~ram_wen;
                        sdram_wr_buf <= ram_wen;
                        if (isreadonly(ram_addr[27:24])) begin
                            sdram_rd_buf <= 1;
                            sdram_wr_buf <= 0;
                        end
                        sdram_addr_buf <= tosdram(ram_addr);
                        sdram_wdata_buf <= ram_wdata;
                        if (ram_addr[27:25] == 3'b111)          // 8-bit access for flash/SRAM
                            sdram_be_buf <= 4'b1 << ram_addr[1:0];
                        else
                            sdram_be_buf <= ram_be;
                        sdram_port_buf <= PORT_RAM;
                    end
                end else 
                    double_req <= 0;
                
                dma_sdram <= state != MAIN;
            end 
            
            if (state == MAIN & bram_port == PORT_NONE) begin
                // idle. start multi-cycle request 1 for DMA / ROM / RAM
                if (dma_on) begin
                    if (dma_ena) begin
                        sdram_rd_buf  <= ~dma_wr;
                        sdram_wr_buf  <= dma_wr;
                        if (isreadonly(dma_addr[27:24])) begin
                            sdram_rd_buf <= 1;
                            sdram_wr_buf <= 0;
                        end
                        sdram_addr_buf <= tosdram(dma_addr);
                        sdram_wdata_buf <= dma_wdata;
                        if (dma_addr[27:25] == 3'b111)          // 8-bit access for flash/SRAM
                            sdram_be_buf <= 4'b1 << dma_addr[1:0];
                        else
                            sdram_be_buf <= dma_be;
                        sdram_port_buf <= PORT_DMA;
                        state <= REQ1_START;
                    end
                end else if (rom_en | ram_cen) begin            // for ROM or RAM, request is issued in cycle 0
                    sdram_rd_buf <= sdram_rd;
                    sdram_wr_buf <= sdram_wr;
                    sdram_addr_buf <= sdram_addr;
                    sdram_wdata_buf <= sdram_wdata;
                    sdram_be_buf <= sdram_be;
                    sdram_port_buf <= sdram_port;
                    state <= REQ1_WAIT;                         // skip start state and go directly to wait
                end else if ((loading == 2'd1 | loading == 2'd2) & loader_writing) begin     // start loading
                    sdram_wr_buf <= 1;
                    sdram_addr_buf <= tosdram(loader_addr);
                    if (loading == 2)
                        sdram_addr_buf[16] <= loader_addr[16];  // hack to write to bank 1
                    sdram_wdata_buf <= {4{loader_d}};
                    sdram_be_buf <= 4'b1 << loader_addr[1:0];
                    sdram_port_buf <= PORT_RAM;
                    state <= REQ1_START;
                end
            end

        end

        REQ1_START: state <= REQ1_WAIT;

        REQ2_BRAM:  state <= MAIN;

        REQ2_START: state <= REQ2_WAIT;
        
        REQ2_WAIT: 
            if (sdram_ready) 
                state <= MAIN; 

        default: ;

        endcase
    end
end

// cpu_en = `ready` for the whole combined memory access
// TODO: this is on the critical path, optimize further
always @* begin
    casez ({dma_on, rom_en, ram_cen})
        3'b1??: cpu_en = 0;     // dma is ongoing
        3'b000: cpu_en = 1;     // no memory access
        3'b010:                 // rom only
            if (state == MAIN)     
                cpu_en = issingle(rom_addr[27:24]);
            else
                cpu_en = sdram_ready; 
        3'b001:                 // ram only
            if (state == MAIN)
                cpu_en = issingle(ram_addr[27:24]);
            else
                cpu_en = sdram_ready; 
        default:                // both rom and ram
            cpu_en = state == REQ2_BRAM | state == REQ2_WAIT & sdram_ready;
    endcase

    dma_done = 0;
    if (dma_on & dma_ena) begin
        if (state == MAIN)
            dma_done = issingle(dma_addr[27:24]);
        else
            dma_done = sdram_ready;
    end
end

// bram_rdata is result for bram access from the last cycle
reg  [31:0] rdata_bios;
reg  [31:0] rdata_iwram;
wire [31:0] rdata_palette_bg;
wire [31:0] rdata_palette_oam;
wire [31:0] rdata_vram_hi;
wire [31:0] rdata_vram_lo;
wire [31:0] rdata_oamram;
wire        rdata_eeprom;
always @* begin
    // combine BRAM output
    casez (bram_addr_r[27:24])
    4'h0:    bram_rdata = rdata_bios;
    4'h3:    bram_rdata = rdata_iwram;
    4'h4:    bram_rdata = gb_bus_dout;
    4'h5:    bram_rdata = bram_addr_r[9] ? palette_oam_dout : palette_bg_dout;
    4'h6:    bram_rdata = bram_addr_r[16] ? vram_hi_dout : vram_lo_dout;
    4'h7:    bram_rdata = oamram_dout;
    4'hD:    bram_rdata = {32{rdata_eeprom}};
    default: bram_rdata = 32'hdead_beef;
    endcase
end
always @(posedge clk) begin
    bram_port_r <= bram_port;
    bram_rd_r <= bram_rd;
    bram_addr_r <= bram_addr;
    rom_en_r <= rom_en;
    ram_cen_r <= ram_cen;
end

// global data output. cpu values are only updated on MAIN states.
always @* begin
    dma_rdata = dma_sdram ? sdram_rdata[PORT_DMA] : bram_rdata;

    // CPU output
    rom_data = rom_rdata_buf;       // default values
    ram_rdata = ram_rdata_buf;
    if (state == MAIN & ~dma_on_r) begin    // do not output on first cycle after DMA
        if (rom_en_r) begin         // rom access, update value
            if (double_req)
                rom_data = rom_rdata_new;
            else if (bram_rd_r & bram_port_r == PORT_ROM)
                rom_data = bram_rdata;
            else
                rom_data = sdram_rdata[PORT_ROM];
        end
        if (ram_cen_r) begin        // ram access, update value
            if (bram_rd_r & bram_port_r == PORT_RAM)
                ram_rdata = bram_rdata;
            else
                ram_rdata = sdram_rdata[PORT_RAM];
        end
    end
end

// rom loading
reg [2:0] loading_r;
reg [1:0] loader_buf_front;    // fifo 
reg [1:0] loader_buf_back;   
reg [1:0] loader_cnt;           // write cycle count
reg loader_start;  
reg [7:0] loader_bios_buf [0:2];
always @(posedge clk) begin
    if (~resetn) begin
        loader_addr <= 0;
        loader_buf_front <= 0;
        loader_buf_back <= 0;
        gbaon <= 0;
    end else begin
        case (loading)
        1, 2: begin                               // ROM or Cart RAM, write to SDRAM
            if (loader_valid) begin                     // push data into fifo
                loader_buf[loader_buf_front] <= loader_data;
                loader_buf_front <= loader_buf_front + 1;
            end

            if (loader_writing) 
                loader_cnt <= loader_cnt == 2'd2 ? 2'd2 : loader_cnt + 2'd1;

            if ((loader_writing & loader_cnt == 2'd2) | ~loader_writing) begin
                // memory is free or just finished writing
                if (loader_buf_front != loader_buf_back) begin
                    // take data from fifo and write to memory
                    loader_d <= loader_buf[loader_buf_back];
                    loader_buf_back <= loader_buf_back + 1;
                    loader_writing <= 1;
                    loader_cnt <= 0;
                    if (!loader_start)
                        loader_addr <= loader_addr + 1;
                    else
                        loader_start <= 0;
                end else
                    loader_writing <= 0;
            end
        end
        
        3: if (loader_valid) begin                   // configuration
            loader_addr[2:0] <= loader_addr[2:0] + 1;
            if (loader_addr[2:0] == 0) begin
                config_backup_type <= loader_data;
                // config_flash_backup <= (loader_data == BACKUP_FLASH512K | loader_data == BACKUP_FLASH1M);
                $display("backup type=%d", loader_data);
                // auto-detection works fine, so we don't need this
                // if (loader_data == 8'd3)        
                //     config_eeprom_type <= 0;            // 4 is 64kbit eeprom (default), 3 is 4kbit eeprom
            end
        end

        4: if (loader_valid) begin                  // 16KB BIOS
            loader_addr[13:0] <= loader_addr[13:0] + 1;
            if (loader_addr[1:0] == 2'd3)
                mem_bios[loader_addr[13:2]] <= {loader_data, loader_bios_buf[2], loader_bios_buf[1], loader_bios_buf[0]};
            else
                loader_bios_buf[loader_addr[1:0]] <= loader_data;
        end

        default: ;
        endcase

        loading_r <= loading;
        if (loading != loading_r) begin                 // reset loader state
            if (loading != 0)
                $display("Loading stage %d", loading);
            else
                $display("Loading is done");
            loader_addr <= {loading == 2'd1 ? 4'h8 : 4'hE, 24'b0};
            loader_writing <= 0;
            loader_start <= 1;
            if (loading == 1) begin                     // reset backup settings on loading start
                config_backup_type <= BACKUP_NONE;
                config_eeprom_type <= 1;
                // config_flash_backup <= 0;
            end
        end

        // turning GBA on and off
        if (loading && !loading_r) 
            gbaon <= 0;

        if (!loading && loading_r) 
            gbaon <= 1;

    end
end

// cartram_dirty
always @(posedge clk) begin
    if (~resetn) begin
        cartram_dirty <= 0;
    end else begin
        if (cartram_dirty_clear)
            cartram_dirty <= 0;
        if (backup_written | eeprom_written)
            cartram_dirty <= 1;
    end
end

//////////////////////////////////////////////
// Interface different memory blocks
//////////////////////////////////////////////

// memory access selection
// mirroring: https://gbadev.net/gbadoc/memory.html
wire sel_bios   = bram_addr[27:24] == 4'h0 && bram_addr[23:0] < 24'h4000;
wire sel_ewram  = bram_addr[27:24] == 4'h2;
wire sel_iwram  = bram_addr[27:24] == 4'h3;
wire sel_io     = bram_addr[27:24] == 4'h4 && bram_addr[23:0] < 24'h400;
wire sel_palette= bram_addr[27:24] == 4'h5;
wire sel_vram   = bram_addr[27:24] == 4'h6;
wire sel_oam    = bram_addr[27:24] == 4'h7;
wire sel_eeprom = bram_addr[27:24] == 4'hD;
wire sel_gamepak= (bram_addr[27:26] == 2'b10 | bram_addr[27:24] == 4'hC);       // 8-C are game pak regions
wire sel_cartram= bram_addr[27:25] == 3'b111;                    // 64KB of cartridge RAM, mirrored to region E and F

// BIOS:        0:000000 - 0:003FFF (16KB)
reg [31:0] mem_bios [0:4095];
initial $readmemh("gba_bios_cultofgba.hex", mem_bios);
always @(posedge clk) 
    if (ce) begin
        rdata_bios <= mem_bios[bram_addr[13:2]];
    end

// IWRAM:       3:000000 - 3:007FFF (32KB)
wire [31:0]     rdata_iwram0;
`ifndef VERILATOR
mem_iwram iwram (
    .clk(clk), .reset(1'b0), .oce(1'b1), .ce(ce), 
    .ad(bram_addr[14:2]), .dout(rdata_iwram), .wre(bram_wr & sel_iwram), 
    .din(bram_wdata), .byte_en(bram_be)
);
`else
sim_spram_be #(32, 8*1024) iwram (
    .clk(clk), .rst(~resetn), .din(bram_wdata), .ce(ce),
    .addr(bram_addr[14:2]), .dout(rdata_iwram),
    .we(bram_wr & sel_iwram), .be(bram_be)
);
`endif

wire bram_valid = bram_rd | bram_wr;

// MMIO registers: 4:000000 - 4:0003FF (1KB)
assign gb_bus_adr = {bram_addr[11:2], 2'b0};
assign gb_bus_din = bram_wdata;
assign gb_bus_ena = sel_io & bram_valid;
assign gb_bus_rnw = ~bram_wr;    // 0 is write
assign gb_bus_acc = bram_wr ? be2size(bram_be) : 2'b10;              // default to 32-bit
assign gb_bus_be = bram_be;

reg [31:0] bram_wdata16;    // 16-bit write data (palette, VRAM, OAM)
reg [3:0]  bram_be16;       // 16-bit write byte enable for palette and vram_lo
reg [3:0]  bram_be16b;      // vram_hi and OAM does not support 8-bit write at all
always @* begin
    bram_wdata16 = bram_wdata;
    bram_be16 = bram_be;
    bram_be16b = bram_be;
    if (bram_wr) case (bram_be)                 // No 8-bit writes for palette, force 16-bit
    4'b0001: begin bram_wdata16 = {bram_wdata[31:16], {2{bram_wdata[ 7:0]}}}; bram_be16 = 4'b0011; bram_be16b = 0; end
    4'b0010: begin bram_wdata16 = {bram_wdata[31:16], {2{bram_wdata[15:8]}}}; bram_be16 = 4'b0011; bram_be16b = 0; end
    4'b0100: begin bram_wdata16 = {{2{bram_wdata[23:16]}}, bram_wdata[15:0]}; bram_be16 = 4'b1100; bram_be16b = 0; end
    4'b1000: begin bram_wdata16 = {{2{bram_wdata[31:24]}}, bram_wdata[15:0]}; bram_be16 = 4'b1100; bram_be16b = 0; end
    default: ;
    endcase
end

// Palette:     5:000000 - 5:0003FF (1KB)
assign palette_bg_addr = bram_addr[8:2];
assign palette_bg_din = bram_wdata16;
assign palette_bg_we = (bram_wr & sel_palette & ~bram_addr[9]) ? bram_be16 : 4'b0;

assign palette_oam_addr = bram_addr[8:2];
assign palette_oam_din = bram_wdata16;
assign palette_oam_we = (bram_wr & sel_palette & bram_addr[9]) ? bram_be16 : 4'b0;

// VRAM:        6:000000 - 6:017FFF (96KB)
assign vram_lo_addr = bram_addr[15:2];
assign vram_lo_din = bram_wdata16;
assign vram_lo_we = bram_wr & sel_vram & ~bram_addr[16];
assign vram_lo_be = bram_wr ? bram_be16 : 4'b1111;

assign vram_hi_addr = bram_addr[14:2];
assign vram_hi_din = bram_wdata16;
assign vram_hi_we = bram_wr & sel_vram & bram_addr[16];
// assign vram_hi_be = bram_wr ? bram_be16b : 4'b1111;
assign vram_hi_be = bram_wr ? bram_be16 : 4'b1111;     

// OAM:         7:000000 - 7:0003FF (1KB)
assign oamram_addr = bram_addr[9:2];
assign oamram_din = bram_wdata16;
assign oamram_we = (bram_wr & sel_oam) ? bram_be16b : 4'b0;

// EEPROM:      D:FFFF00 - D:FFFFFF.
gba_eeprom eeprom (
    .clk(clk), .rst(~resetn), .cs(sel_eeprom), .model(config_eeprom_type),
    .valid(bram_valid), .write(bram_wr), .ready(),
    .din(bram_wdata[0]), .dout(rdata_eeprom),
    .dma_eepromcount(dma_eepromcount), .written(eeprom_written),

    .rv_rd(eeprom_rd), .rv_wr(eeprom_wr), .rv_addr(eeprom_addr), .rv_rdata(eeprom_rdata), 
    .rv_wdata(eeprom_wdata)
);

//////////////////////////////////////////////
// Helper functions
//////////////////////////////////////////////

function [1:0] be2size(input [3:0] be);
    casez (be)
    4'b0001,4'b0010,4'b0100,4'b1000: be2size = 2'b00;    // byte
    4'b0011,4'b1100:                 be2size = 2'b01;    // half-word
    4'b1111:                         be2size = 2'b10;    // word
    default:                         be2size = 2'b10;    // default to word
    endcase
endfunction

// is this region a single cycle region?
function issingle(input [3:0] region);
    case (region)
    4'h0,4'h3,4'h4,4'h5,4'h6,4'h7,4'hD: issingle = 1;
    default: issingle = 0;
    endcase
endfunction

function isreadonly(input [3:0] region);
    case (region)
    4'h0,4'h8,4'h9,4'ha,4'hb,4'hc: isreadonly = 1;
    4'he,4'hf:                     isreadonly = config_backup_type != BACKUP_FLASH512K & 
                                                config_backup_type != BACKUP_FLASH1M & 
                                                config_backup_type != BACKUP_SRAM;
    default: isreadonly = 0;
    endcase
endfunction

// convert GBA address to SDRAM address
function [25:2] tosdram(input [27:0] addr);
    casez (addr[27:24])
    4'b10??, 4'hC:  tosdram = {1'b0,             addr[24:2]};   // 32MB cartridge rom
    4'd2:           tosdram = {8'b1000_0000,     addr[17:2]};   // 256KB ewram
    4'b111?:        tosdram = {10'b1000_0001_00, addr[15:2]};   // 64KB cartridge ram
    default: tosdram = {24{1'b1}};
    endcase 
endfunction


// memory watch points
// always @(posedge clk) begin
//     if (ce) begin
//         if (cpu_en & ram_cen & ram_wen) begin
//             if (ram_addr == 32'h0300_09C4 | ram_addr == 32'h0300_0BE0)
//                 $display("WR [%h] <= %h (be=%h)", ram_addr, ram_wdata, ram_be);
//         end
//     end
// end

endmodule
`undef pproc_bus_gba