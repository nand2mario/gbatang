// SDRAM controller for GBA
// nand2mario 2024.7
//
// 1. This holds 4 memory regions:
//    32MB cartridge ROM    cpu_addr = 26'h000_0000_0000 - 26'h1FF_FFFF_FFFF
//    256KB EWRAM           cpu_addr = 26'h200_0000_0000 - 26'h203_FFFF_FFFF
//    128KB Flash/SRAM      cpu_addr = 26'h204_0000_0000 - 26'h204_FFFF_FFFF  (2x64KB banks `f_bank`)
//    1MB iosys memory      rv_addr  = 23'h 00_0000_0000 - 23'h 0F_FFFF_FFFF          
//
// 2. 32-bit interface for CPU, 16-bit interface for RISC-V iosys softcore.
//
// 3. The Flash/SRAM memory region implements the flash protocol if config_backup_type is 1 or 2. 
//    It behaves just like the GBA flash backup memory, including the bank switching 
//    behavior. Otherwise, it is normal memory and thus equivalent to SRAM backup memory.
//
// 4. RV can access Flash/SRAM/EEPROM for save persistence starting from 0x700000 (max 128KB). 
//
// We need to use both 32MB chips as the cartridge is already 32MB. CPU uses all banks of 
// chip 0 (cartridge ROM) and bank 0 of chip 1 (EWRAM / backup).  RISC-V uses bank 1 of 
// chip 1.
//
// Timing-wise this is actually easier thank SNES. Both cartridge rom and ewram 
// accesses allow 3 16Mhz cycles for 16 bits. That's 3*60ns = 180ns. We use a 67Mhz SDRAM clock.
// Total request latency is 14.8 * 6 = 89ns. So we use a simple CL2 design without bank 
// interleaving.
// 
// CPU accesses have high priority and is returned within 2 cycles for 16 bits and 3 cycles
// for 32 bits. RV has the lowest priority and may be delayed by CPU (or memory auto 
// refresh). Below's a typical schedule. Note that we allow the RV request to squeeze in 
// between adjacent CPU requests to avoid starvation.
// 
// mclk     /‾‾‾‾‾‾‾\_______/‾‾‾‾‾‾‾\_______/‾‾‾‾‾‾‾\_______/‾‾‾‾‾‾‾\_______/‾‾‾‾‾‾‾\_______/
// clk      /0\_/1\_/2\_/3\_/0\_/1\_/2\_/3\_/0\_/1\_/2\_/3\_/0\_/1\_/3\_/3\_/0\_/1\_/2\_/3\_/
// cpu      $-----------|RAS|CAS|       |DAT|CAS|       |DAT|-----------|RAS|CAS|       |DAT|
// cpu_rd   /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____
// cpu_ready                           _____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____
// rv       $-----------|BUB|-----------|BUB|-----------|RAS|CAS|       |DAT|---------------#
// rv_req   /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾ ...    
// rv_req_ack                                            ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾ ...
//
// RAS: row activation, CAS: read/write command, DAT: data available, 
// BUB: bubble inserted when CPU preempts the RV request.
//

module sdram_gba
#(
    // Clock frequency
    parameter         FREQ = 67_120_000,  

    // Time delays for 66.7Mhz max clock (min clock cycle 15ns)
    // The SDRAM supports max 166.7Mhz (RP/RCD/RC need changes)
    // Alliance AS4C32M16SB-7TIN 512Mb
    parameter [3:0]   CAS  = 4'd2,     // 2/3 cycles, set in mode register
    parameter [3:0]   T_WR = 4'd2,     // 2 cycles, write recovery
    parameter [3:0]   T_MRD= 4'd2,     // 2 cycles, mode register set
    parameter [3:0]   T_RP = 4'd1,     // 15ns, precharge to active
    parameter [3:0]   T_RCD= 4'd1,     // 15ns, active to r/w
    parameter [3:0]   T_RC = 4'd4      // 63ns, ref/active to ref/active
)
(
    // SDRAM side interface
    inout      [15:0] SDRAM_DQ,
    output     [12:0] SDRAM_A,
    output reg [1:0]  SDRAM_DQM,
    output reg [1:0]  SDRAM_BA,
    output            SDRAM_nCS,
    output            SDRAM_nWE,
    output            SDRAM_nRAS,
    output            SDRAM_nCAS,

    // Logic side interface
    input             clk,          // 67Mhz sdram clock
    input             mclk,         // 16Mhz main GBA clock
    input             resetn,
    input       [2:0] config_backup_type, // backup chip behavior for 26'h204_0000 ~ 26'h204_FFFF
                                    // 0: none, 1: 512Kbit flash, 2: 1Mbit flash, 3: SRAM, 4:EEPROM
    output reg        backup_written,  // pulse when backup memory is written to

    // CPU access. cartridge ROM uses chip 0. EWRAM / cart RAM uses bank 0 of chip 1.
    // 32-bit interface, 2 or 4 cycle latency depending on `cpu_be` values.
    input             cpu_rd,       // pulse for read request
    input             cpu_wr,       // pulse for write request
	input      [25:2] cpu_addr,     // [25] is chip select, [24:2] is 32-bit word address
                                    // Cartridge: 0 - 32MB, EWRAM: 32MB - 32MB+256KB, CartRAM: 32MB+256KB - 32MB+384KB
	input      [31:0] cpu_wdata,
	input      [1:0]  cpu_port,     // put data in cpu_dout[cpu_port], none-zero
    output reg [31:0] cpu_rdata [1:3],// 3 output buffers
	input       [3:0] cpu_be,       // byte enable
	output reg        cpu_ready,    // ready for new requests. data available NEXT mclk if there's a read request
                                    // normally 2 or 4 cycles latency. the exception is flash erase, which takes really long.

    // RISC-V softcore uses bank 1 of chip 1. 
    // 16-bit interface, 2 or 3 cycle latency as it has lower priority.
    // top 1MB is mapped to cart RAM for read and write (max 128KB, config_backup_type specifies type)
    input      [22:1] rv_addr,      // 8MB RV memory space
    input      [15:0] rv_din,       // 16-bit accesses
    input      [1:0]  rv_ds,
    output reg [15:0] rv_dout,
    input             rv_req,
    output reg        rv_req_ack,   // ready for new requests. read data available on NEXT mclk
    input             rv_we,

    output reg [23:0] total_refresh,
    output reg        busy
);

// Tri-state DQ input/output
reg dq_oen;        // 0 means output
reg [15:0] dq_out;
assign SDRAM_DQ = dq_oen ? {16{1'bz}} : dq_out;
wire [15:0] dq_in = SDRAM_DQ;     // DQ input
reg [3:0] cmd;
reg [12:0] a;
assign {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} = cmd;
assign SDRAM_A = a;

// RAS# CAS# WE#
localparam CMD_NOP=3'b111;
localparam CMD_SetModeReg=3'b000;
localparam CMD_BankActivate=3'b011;
localparam CMD_Write=3'b100;
localparam CMD_Read=3'b101;
localparam CMD_AutoRefresh=3'b001;
localparam CMD_PreCharge=3'b010;

localparam [2:0] BURST_LEN = 3'b0;      // burst length 1
localparam BURST_MODE = 1'b0;           // sequential
localparam [10:0] MODE_REG = {4'b0, CAS[2:0], BURST_MODE, BURST_LEN};
// 64ms/8192 rows = 7.8us -> 500 cycles@64.8MHz
localparam RFRSH_CYCLES = 9'd501;

// flash state
localparam FLASH_IDLE       = 3'd0;
localparam FLASH_PREP       = 3'd1; // after [E005555h]=AAh
localparam FLASH_WAITCMD    = 3'd2; // after [E002AAAh]=55h
localparam FLASH_ERASEALL   = 3'd3;
localparam FLASH_ERASESECT  = 3'd4;

// flash mode
localparam MODE_NORMAL      = 3'd0;
localparam MODE_WRITE       = 3'd1;
localparam MODE_BANK        = 3'd2;
localparam MODE_ERASE       = 3'd3;
localparam MODE_ID          = 3'd4;

localparam FLASH_BASE       = (32*1024*1024+256*1024)/4;

// state
reg [11:0] cycle;       // one hot encoded
reg normal, setup, setup_ncs;
reg cfg_now;            // pulse for configuration

// flash state
reg [2:0]  flash;       // flash command state
reg [2:0]  f_mode;
reg        f_bank;      // active flash bank
reg [16:1] f_erase_addr;// halfword address for erase

// requests
reg  [1:0] port [0:1];  // port[0]: CPU output port, port[1]: whether RV req is valid
reg [25:0] addr_latch[2];
reg [31:0] din_latch[2];
reg  [1:0] oe_latch;
reg  [1:0] we_latch;
reg  [3:0] ds_latch[0:1];

wire clkref = mclk;
reg clkref_r;
always @(posedge clk) clkref_r <= clkref;

reg [8:0]  refresh_cnt;
reg        need_refresh;
reg        refresh_chip1;

always @(posedge clk) begin
	if (refresh_cnt == 0)
		need_refresh <= 0;
	else if (refresh_cnt == RFRSH_CYCLES)
		need_refresh <= 1;
end

//
// SDRAM state machine
//
always @(posedge clk) begin
    if (~resetn) begin
        busy <= 1'b1;
        dq_oen <= 1;
        SDRAM_DQM <= 2'b11;
        normal <= 0;
        setup <= 0;
        setup_ncs <= 0;
    end else begin
        reg hi, flash_cmd_en;
        reg is_flash;
        is_flash = config_backup_type == 3'd1 | config_backup_type == 3'd2;
        hi = 0;
        // request goes to flash controller
        flash_cmd_en = 0;
        if (is_flash & (cpu_wr & cpu_addr[25:16] == 10'h204 | flash == FLASH_ERASEALL | flash == FLASH_ERASESECT))
            flash_cmd_en = 1;
        if (f_mode == MODE_WRITE) 
            flash_cmd_en = 0;

        // defaults
        dq_oen <= 1'b1;
        SDRAM_DQM <= 2'b11;
        cmd <= {1'b1, CMD_NOP};

        // wait 200 us on power-on
        if (~normal && ~setup && cfg_now) begin // wait 200 us on power-on
            setup <= 1;
            cycle <= 1;
        end 

        // setup process
        if (setup) begin
            cycle <= {cycle[10:0], 1'b0};       // cycle 0-11 for setup
            // configuration sequence
            if (cycle[0]) begin
                // precharge all
                cmd <= {setup_ncs, CMD_PreCharge};
                a[10] <= 1'b1;
            end
            if (cycle[T_RP]) begin
                // 1st AutoRefresh
                cmd <= {setup_ncs, CMD_AutoRefresh};
            end
            if (cycle[T_RP+T_RC]) begin
                // 2nd AutoRefresh
                cmd <= {setup_ncs, CMD_AutoRefresh};
            end
            if (cycle[T_RP+T_RC+T_RC]) begin
                // set register
                cmd <= {setup_ncs, CMD_SetModeReg};
                a[10:0] <= MODE_REG;
            end
            if (cycle[T_RP+T_RC+T_RC+T_MRD]) begin
                if (!setup_ncs) begin
                    setup_ncs = 1;              // setup the other chip
                    cycle <= 1; 
                end else begin
                    setup <= 0;                 // init&config is done
                    normal <= 1;
                    cycle <= 1;
                    busy <= 0;                  
                end
            end
        end 

        // normal operations
        if (normal) begin
            if (clkref & ~clkref_r & cycle != 12'h1 & cycle != 12'h10)  // go to cycle 1 after clkref posedge
                cycle <= 12'h2;
            else
                cycle[3:0] <= {cycle[2:0], cycle[3]};   // loop cycle 0-3
            refresh_cnt <= refresh_cnt + 1'd1;
            if (cycle[3]) backup_written <= 0;

            ////////////////////////////////////////
            // Collect read data
            ////////////////////////////////////////
            if (cycle[3] & port[0] != 0) begin              // CPU
                hi = addr_latch[0][1];
                if (oe_latch[0])
                    casez (ds_latch[0])                     // broadcast byte/halfword reads
                    4'b0000: cpu_rdata[port[0]] <= 32'habadcafe;
                    4'b0001: cpu_rdata[port[0]] <= {4{dq_in[7:0]}};
                    4'b0010: cpu_rdata[port[0]] <= {4{dq_in[15:8]}};
                    4'b0100: cpu_rdata[port[0]] <= {4{dq_in[7:0]}};
                    4'b1000: cpu_rdata[port[0]] <= {4{dq_in[15:8]}};
                    4'b0011, 4'b1100: 
                             cpu_rdata[port[0]] <= {2{dq_in}};
                    default: 
                        if (hi) 
                             cpu_rdata[port[0]] <= {dq_in, cpu_rdata[port[0]][15:0]};
                        else    
                             cpu_rdata[port[0]] <= {cpu_rdata[port[0]][31:15], dq_in};
                    endcase

                if (f_mode == MODE_ID & addr_latch[0] == 26'h204_0000) begin
                    reg is1m;
                    is1m = config_backup_type == 3'd2;       // 0x1362 (Sanyo) for large chip, 0x1B32 (Pansonic) for small chip
                    if (ds_latch[0][0])      cpu_rdata[port[0]] <= is1m ? {4{8'h62}} : {4{8'h32}};
                    else if (ds_latch[0][1]) cpu_rdata[port[0]] <= is1m ? {4{8'h13}} : {4{8'h1B}};
                end

                if (hi | ds_latch[0][3:2] == 0)             // mark done after both halfwords
                    port[0] <= 0;
            end
            if (cycle[3] & port[1] != 0) begin              // RV
                if (oe_latch[1]) rv_dout <= dq_in;
                port[1] <= 0;
            end

            ////////////////////////////////////////
            // RAS
            ////////////////////////////////////////
            if (cycle[3] & ~flash_cmd_en) begin
                reg new_cpu, new_rv;
                new_cpu = cpu_rd | cpu_wr;
                new_rv = rv_req ^ rv_req_ack;
                cpu_ready <= 0;
                if (port[0] != 0 & ~addr_latch[0][1] & ds_latch[0][3:2] != 0) begin // continue to next halfword
                    addr_latch[0][1] <= 1;                      // access high halfword

                    cmd <= {addr_latch[0][25], CMD_BankActivate};
                    a <= addr_latch[0][22:10];
                    SDRAM_BA <= addr_latch[0][24:23];

                    cpu_ready <= 1;                             // ready signal on next cycle
                end else if (new_cpu) begin                     // new CPU request 
                    reg [25:2] cpu_addr_with_bank;              // patch flash bank
                    cpu_addr_with_bank = cpu_addr;
                    if (is_flash & cpu_addr[25:16] == 10'h204) begin
                        cpu_addr_with_bank[16] = f_bank;
                        if (cpu_wr) f_mode <= MODE_NORMAL;      // clear flash byte write mode
                        if (cpu_wr) backup_written <= 1;        // flash written to
                    end
                    if (config_backup_type == 3'd3 & cpu_addr[25:16] == 10'h204) begin
                        if (cpu_wr) backup_written <= 1;        // SRAM written to
                    end

                    hi = !cpu_be[1:0];
                    port[0] <= cpu_port;                        // back-to-back requests are allowed
                    addr_latch[0] <= {cpu_addr_with_bank, hi, 1'b0};      // bit 1: which halfword is being accessed
                    din_latch[0] <= cpu_wdata;
                    we_latch[0] <= cpu_wr;
                    oe_latch[0] <= cpu_rd;
                    ds_latch[0] <= cpu_be;

                    cmd <= {cpu_addr[25], CMD_BankActivate};    // addr[25] selects chip
                    a <= cpu_addr_with_bank[22:10];
                    SDRAM_BA <= cpu_addr[24:23];

                    cpu_ready <= cpu_be[3:2] == 0 | cpu_be[1:0] == 0;
                end else if ((~new_cpu | cpu_ready) & need_refresh) begin 
                    // refresh both chips when needed and no upcoming or ongoing cpu request
                    if (~refresh_chip1) begin
                        total_refresh <= total_refresh + 1;
                        cmd <= {1'b0, CMD_AutoRefresh};         // refresh chip 0 first
                        refresh_chip1 <= 1;
                    end else begin
                        cmd <= {1'b1, CMD_AutoRefresh};         // then chip 1
                        refresh_cnt <= 0;                       // reset `need_refresh` 
                    end
                end else if (new_rv) begin                      // new RV request, with lower priority
                    port[1] <= 1;

                    cmd <= {1'b1, CMD_BankActivate};            // uses chip 1
                    if (rv_addr[22:20] == 3'd7) begin           // cart RAM access
                        addr_latch[1] <= { 8'b1000_0001, rv_addr[17:1], 1'b0};        // 256KB total cart RAM
                        SDRAM_BA <= 2'b00;
                        a <= {5'b0_0001, rv_addr[17:10]};
                    end else begin                              // normal RV memory
                        addr_latch[1] <= { 3'b101, rv_addr, 1'b0};
                        SDRAM_BA <= 2'b01;         
                        a <= rv_addr[22:10];
                    end
                    din_latch[1] <= rv_din;
                    we_latch[1] <= rv_we;
                    oe_latch[1] <= ~rv_we;
                    ds_latch[1] <= {rv_ds,rv_ds};

                    rv_req_ack <= rv_req; 
                end 

                if (~need_refresh) refresh_chip1 <= 0;
            end

            ////////////////////////////////////////
            // RAS for flash backup controller
            ////////////////////////////////////////
            if (cycle[3] & flash_cmd_en) begin
                // flash backup behavior
                reg [15:0] f_addr = {cpu_addr[15:2], 2'b0};
                reg [7:0] f_din;

                cpu_ready <= 1; 

                case (cpu_be)
                    4'b0010: begin 
                        f_addr[1:0] = 2'd1;
                        f_din = cpu_wdata[15:8];
                    end
                    4'b0100: begin
                        f_addr[1:0] = 2'd2;
                        f_din = cpu_wdata[23:16];
                    end
                    4'b1000: begin
                        f_addr[1:0] = 2'd3;
                        f_din = cpu_wdata[31:24];
                    end
                    default: begin
                        f_din = cpu_wdata[7:0];
                    end
                endcase
                $display("flash write: %h %h %h", f_addr, cpu_be, f_din);

                case (flash)
                FLASH_IDLE: begin
                    if (f_mode != MODE_WRITE & f_addr == 16'h5555 & f_din == 8'hAA)
                        flash <= FLASH_PREP;

                    // MODE_WRITE goes into normal RAS above

                    if (f_addr[15:0] == 0 & f_mode == MODE_BANK) begin
                        f_bank <= f_din[0];
                        f_mode <= MODE_NORMAL;
                        $display("bank switch: %h", f_bank);
                    end
                end

                FLASH_PREP :
                    if (f_addr == 16'h2AAA & f_din == 8'h55)
                        flash <= FLASH_WAITCMD;
                    else
                        flash <= FLASH_IDLE;
                
                FLASH_WAITCMD : begin
                    flash <= FLASH_IDLE;
                    if (f_addr == 16'h5555) begin
                        case (f_din)
                        8'h90:              // enter ID mode
                            f_mode <= MODE_ID;
                        8'hF0:              // exit ID mode
                            f_mode <= MODE_NORMAL;
                        8'h80:              // enter erase mode
                            f_mode <= MODE_ERASE;
                        8'h10: if (f_mode == MODE_ERASE) begin    // erase entire chip
                            flash <= FLASH_ERASEALL;
                            f_erase_addr <= 0;
                            cpu_ready <= 0; // until erase is done
                            f_mode <= MODE_NORMAL;
                        end
                        8'hA0:              // enter byte write mode
                            f_mode <= MODE_WRITE;
                        8'hB0:              // enter bank switch mode
                            f_mode <= MODE_BANK;
                        default: ;
                        endcase
                    end
                    // erase 4KB sector
                    if (f_addr[11:0] == 0 & f_mode == MODE_ERASE) begin
                        flash <= FLASH_ERASESECT;
                        f_erase_addr <= {f_bank, f_addr[15:1]};
                        cpu_ready <= 0; // until erase is done
                        f_mode <= MODE_NORMAL;
                    end
                end 

                FLASH_ERASEALL, FLASH_ERASESECT: begin
                    port[0] <= cpu_port;
                    addr_latch[0] <= {9'b10_0000_010, f_erase_addr, 1'b0};
                    din_latch[0] <= 32'hffffffff;
                    we_latch[0] <= 1;
                    oe_latch[0] <= 0;
                    ds_latch[0] <= 4'b1111;

                    cmd <= {1'b1, CMD_BankActivate};
                    a <= { 6'b000_010, f_erase_addr[16:10] }; // 13-bit row address
                    SDRAM_BA <= 2'b00;

                    f_erase_addr <= f_erase_addr + 1;
                    cpu_ready <= 0;
                    if (f_erase_addr[11:1] == {11{1'b1}} & flash == FLASH_ERASESECT | f_erase_addr == 16'hffff) begin
                        flash <= FLASH_IDLE;
                        cpu_ready <= 1;
                        backup_written <= 1;                // flash written to at end of erase
                    end
                end

                default: ;
                endcase                

            end

            ////////////////////////////////////////
            // CAS
            ////////////////////////////////////////
            if (cycle[0] & (port[0] != 0 | port[1] != 0)) begin
                reg p;
                p = port[1];
                cmd <= {addr_latch[p][25], we_latch[p]?CMD_Write:CMD_Read};
                if (we_latch[p]) begin
                    dq_oen <= 0;
                    if (p == 0 & addr_latch[p][1]) begin    // cpu writing high halfword
                        dq_out <= din_latch[p][31:16];
                        SDRAM_DQM <= ~ds_latch[p][3:2];   
                    end else begin
                        dq_out <= din_latch[p][15:0];
                        SDRAM_DQM <= ~ds_latch[p][1:0]; 
                    end
                end else
                    SDRAM_DQM <= 2'b00;
                a <= { 4'b0010, addr_latch[p][9:1] };  // auto precharge
                SDRAM_BA <= addr_latch[p][24:23];
            end

        end
    end
end

//
// Generate cfg_now pulse after initialization delay (normally 200us)
//
reg  [14:0]   rst_cnt;
reg rst_done, rst_done_p1, cfg_busy;
  
always @(posedge clk) begin
    if (~resetn) begin
        rst_cnt  <= 15'd0;
        rst_done <= 1'b0;
        cfg_busy <= 1'b1;
    end else begin
        rst_done_p1 <= rst_done;
        cfg_now     <= rst_done & ~rst_done_p1;// Rising Edge Detect

        if (rst_cnt != FREQ / 1000 * 200 / 1000) begin      // count to 200 us
            rst_cnt  <= rst_cnt[14:0] + 15'd1;
            rst_done <= 1'b0;
            cfg_busy <= 1'b1;
        end else begin
            rst_done <= 1'b1;
            cfg_busy <= 1'b0;
        end        
    end
end

endmodule