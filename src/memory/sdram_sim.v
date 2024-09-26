// We only simulate 32MB+256KB+128KB of gamepak, EWRAM and SRAM/flash, for verilator with test loader to work.
module sdram_sim
(
    // Logic side interface
    input             clk,
    input       [2:0] config_backup_type,

    // CPU access. ROM (cartridge) uses chip 0. EWRAM uses bank 0 of chip 1.
    // 32-bit interface
	input      [31:0] cpu_wdata,
	input      [1:0]  cpu_port,     // put data in cpu_rdata[cpu_port], none-zero
    output reg [31:0] cpu_rdata [1:3],       // 3 output buffers
	input      [25:2] cpu_addr,     // [25] is chip select, [24:2] is address
                                    // Cartridge: 0 ~ 32MB, EWRAM: 32MB ~ (32MB+256KB), 
                                    // CartRAM, (32MB+256KB) ~ 32MB+512KB
    input             cpu_rd,
    input             cpu_wr,
	input       [3:0] cpu_be,       // byte enable
    output            cpu_ready
);

reg [31:0] mem [0:8*1024*1024+128*1024-1];
reg [2:0] cycle;

// flash backup chip behavior
reg [1:0] flash;                    // flash command state
localparam FLASH_IDLE       = 2'd0;
localparam FLASH_PREP       = 2'd1; // after [E005555h]=AAh
localparam FLASH_WAITCMD    = 2'd2; // after [E002AAAh]=55h

reg [2:0] f_mode;
localparam MODE_NORMAL      = 3'd0;
localparam MODE_WRITE       = 3'd1;
localparam MODE_BANK        = 3'd2;
localparam MODE_ERASE       = 3'd3;
localparam MODE_ID          = 3'd4;

reg f_bank;
localparam FLASH_BASE       = (32*1024*1024+256*1024)/4;

always @(posedge clk) begin
    reg [25:2] f_cpu_addr;          // cpu address with flash bank offset applied
    reg is_flash;
    is_flash = config_backup_type == 3'd1 | config_backup_type == 3'd2;
    f_cpu_addr = cpu_addr;
    if (is_flash & cpu_addr[25:17] == 9'b10_0000_010 & f_bank)       // 0x204 & 0x205
        f_cpu_addr[16] = 1'b1;

    cpu_ready <= 0;
    case (cycle)
    0: begin
        if (is_flash & cpu_wr & cpu_addr[25:16] == 10'h204) begin
            // flash backup behavior
            reg [15:0] f_addr = {cpu_addr[15:2], 2'b0};
            reg [7:0] f_din;

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
            $display("flash write: [%h] = %h", f_addr, f_din);

            case (flash)
            FLASH_IDLE: begin
                if (f_mode != MODE_WRITE & f_addr == 16'h5555 & f_din == 8'hAA)
                    flash <= FLASH_PREP;

                if (f_mode == MODE_WRITE) begin 
                    // $display("flash write");
                    mem[f_cpu_addr] <= 
                        {cpu_be[3] ? cpu_wdata[31:24] : mem[f_cpu_addr][31:24],
                         cpu_be[2] ? cpu_wdata[23:16] : mem[f_cpu_addr][23:16],
                         cpu_be[1] ? cpu_wdata[15:8]  : mem[f_cpu_addr][15:8],
                         cpu_be[0] ? cpu_wdata[7:0]   : mem[f_cpu_addr][7:0]};
                    f_mode <= MODE_NORMAL;
                end

                if (f_addr[15:0] == 0 & f_mode == MODE_BANK) begin
                    f_bank <= f_din[0];
                    f_mode <= MODE_NORMAL;
                    $display("bank switch: %h", f_din[0]);
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
                    8'h90: begin        // enter ID mode
                        $display("flash: enter ID mode");
                        f_mode <= MODE_ID;
                    end
                    8'hF0: begin        // exit ID mode
                        $display("flash: exit ID mode");
                        f_mode <= MODE_NORMAL;
                    end
                    8'h80: begin        // enter erase mode
                        $display("flash: enter erase mode");
                        f_mode <= MODE_ERASE;
                    end
                    8'h10: if (f_mode == MODE_ERASE) begin    // erase entire chip
                        $display("flash: erase entire chip");
                        // not synthesizable
                        for (int i = FLASH_BASE; i < FLASH_BASE + 32768; i++)   // clear 128KB
                            mem[i] <= 32'hffffffff;
                        f_mode <= MODE_NORMAL;
                    end
                    8'hA0:         // enter byte write mode
                        f_mode <= MODE_WRITE;
                    8'hB0:         // enter bank switch mode
                        f_mode <= MODE_BANK;
                    default: ;
                    endcase
                end
                // erase 4KB sector
                if (f_addr[11:0] == 0 & f_mode == MODE_ERASE) begin
                    reg [25:2] base;
                    base = FLASH_BASE + 16384*f_bank + f_addr[15:12]*1024;
                    $display("flash: erase 4KB sector %h (bank %d)", f_addr[15:12], f_bank);
                    for (int i = base; i < base+1024; i++)
                        mem[i] <= 32'hffffffff;
                    f_mode <= MODE_NORMAL;
                end
            end 

            default: ;
            endcase

            cpu_ready <= 1;

        end else if (cpu_rd | cpu_wr) begin
            
            // normal memory behavior
            if (cpu_wr) begin
                mem[cpu_addr] <= {cpu_be[3] ? cpu_wdata[31:24] : mem[cpu_addr][31:24],
                                  cpu_be[2] ? cpu_wdata[23:16] : mem[cpu_addr][23:16],
                                  cpu_be[1] ? cpu_wdata[15:8] : mem[cpu_addr][15:8],
                                  cpu_be[0] ? cpu_wdata[7:0] : mem[cpu_addr][7:0]};
            end
            cycle <= 2'd1;
            if (cpu_be[3:2] == 0 | cpu_be[1:0] == 0)
                cpu_ready <= 1;
        end 

    end


    1: begin

        casez (cpu_be)
        4'b0000: cpu_rdata[cpu_port] <= 32'habadcafe;
        4'b0001: cpu_rdata[cpu_port] <= {4{mem[f_cpu_addr][7:0]}};
        4'b0010: cpu_rdata[cpu_port] <= {4{mem[f_cpu_addr][15:8]}};
        4'b0100: cpu_rdata[cpu_port] <= {4{mem[f_cpu_addr][23:16]}};
        4'b1000: cpu_rdata[cpu_port] <= {4{mem[f_cpu_addr][31:24]}};
        4'b0011: cpu_rdata[cpu_port] <= {2{mem[f_cpu_addr][15:0]}};
        4'b1100: cpu_rdata[cpu_port] <= {2{mem[f_cpu_addr][31:16]}};
        default: begin
            cpu_rdata[cpu_port] <= mem[f_cpu_addr];
            // $display("sdram: f_cpu_addr=%x, data=%x", f_cpu_addr, mem[f_cpu_addr]);
        end
        endcase

        // flash: read ID
        if (is_flash & f_mode == MODE_ID & {cpu_addr,2'b0} == 26'h204_0000) begin
            reg is1m;
            is1m = config_backup_type == 3'd2;       // 0x1362 (Sanyo) for large chip, 0x1B32 (Pansonic) for small chip
            if (cpu_be == 4'b0001) cpu_rdata[cpu_port] <= is1m ? {4{8'h62}} : {4{8'h32}};
            if (cpu_be == 4'b0010) cpu_rdata[cpu_port] <= is1m ? {4{8'h13}} : {4{8'h1B}};
            $display("flash: read ID");
        end

        if (cpu_ready)      // 16-bit
            cycle <= 0;
        else begin
            cycle <= 2;
            cpu_ready <= 1; // 32-bit
        end
    end
    2: begin
        if (cpu_be[3:2] != 0)
            cpu_rdata[cpu_port][31:16] <= mem[cpu_addr][31:16];
        cycle <= 0;
    end
    default: ;
    endcase
end

endmodule
