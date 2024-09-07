// Cartridge flash / SRAM backup memory. This is mapped to 0xe000000-0xe00ffff.
// Both flash and SRAM can only be accessed in 8-bit.
module gba_flash_sram (
    input clk,
    input isflash,          // whether this is flash or SRAM
    input ce,               // sel_cartram

    input [16:0] addr,      // mapped to 0xe000000-0xe00ffff  (addr[16] is only used for loading)
    input valid,
    input write,
    input [31:0] din,       // 8-bit bus, only the corresponding byte is valid
    input setbank1,         // writing to 0xffff automatically sets bank 1
    output reg ready,           // dout is available NEXT cycle
    output reg [7:0] dout,      // 8-bit bus

    // sdram interface for data
    output reg sdram_rd,        // pulse for read request
    output reg sdram_wr,        // pulse for write request
    output reg [25:1] sdram_addr,
    output reg [15:0] sdram_d,
    input [15:0] sdram_q,
    output reg [1:0] sdram_ds
);

reg [3:0] state;
reg bank;
reg [15:0] count;       // half-words to erase - 1

localparam IDLE             = 4'd0;
localparam WAIT1            = 4'd1;
localparam WAIT2            = 4'd2;
localparam WAIT3            = 4'd3;
localparam READY            = 4'd4;
localparam ERASE_START      = 4'd5;
localparam ERASE_WAIT1      = 4'd6;
localparam ERASE_WAIT2      = 4'd7;
localparam ERASE_READY      = 4'd8;

reg [1:0] flash;
localparam FLASH_IDLE       = 2'd0;
localparam FLASH_PREP       = 2'd1;  // after [E005555h]=AAh
localparam FLASH_WAITCMD    = 2'd2;  // after [E002AAAh]=55h

reg [2:0] mode;
localparam MODE_NORMAL      = 3'd0;
localparam MODE_WRITE       = 3'd1;
localparam MODE_BANK        = 3'd2;
localparam MODE_ERASE       = 3'd3;
localparam MODE_ID          = 3'd4;

always @(posedge clk) if (ce) begin

    sdram_rd <= 0; sdram_wr <= 0;
    ready <= 0;

    case (state)
    IDLE: if (valid) begin
        state <= WAIT1;
        if (~write | ~isflash) begin                                // begin direct sdram access for SRAM or flash read
            sdram_rd <= ~write;
            sdram_wr <= write;
            sdram_addr <= {9'b1000_0001_0, bank, addr[15:1]};       // chip 1, bank 0, 2nd 256KB
            sdram_ds <= addr[0] ? 2'b10 : 2'b01;
            sdram_d <= addr[1] ? din[31:16] : din[15:0];

            if (setbank1 & write & addr == 16'hffff) begin
                bank <= 1;
                $display("switched to bank 1 during loading");
            end

            // if (write)
            //     $display("SRAM write: [%h]=%h", {bank|addr[16], addr[15:0]}, din[(addr[1:0]*8) +: 8]);

        end else if (write & isflash) begin                         // flash write state machine
            $display("flash write: [%h]=%h", {bank|addr[16], addr[15:0]}, din[(addr[1:0]*8) +: 8]);
            case (flash) 
            FLASH_IDLE: begin
                if (mode != MODE_WRITE & addr == 16'h5555 & din[7:0] == 8'hAA) 
                    flash <= FLASH_PREP;
                
                if (mode == MODE_WRITE) begin                       // flash byte write
                    sdram_wr <= 1;
                    sdram_addr <= {9'b1000_0001_0, bank, addr[15:1]};
                    sdram_ds <= addr[0] ? 2'b10 : 2'b01;
                    sdram_d <= addr[1] ? din[31:16] : din[15:0];
                    mode <= MODE_NORMAL;
                end
                
                if (addr[15:0] == 0 & mode == MODE_BANK) begin       // bank switch
                    bank <= din[0];
                    mode <= MODE_NORMAL;
                    $display("bank switch: %h", bank);
                end
            end

            FLASH_PREP: if (addr == 16'h2AAA & din[7:0] == 8'h55) flash <= FLASH_WAITCMD;

            FLASH_WAITCMD: begin
                flash <= FLASH_IDLE;
                if (addr == 16'h5555) begin
                    case (din[7:0])
                    8'h90: begin        // enter ID mode
                        $display("enter ID mode");
                        mode <= MODE_ID;
                    end
                    8'hF0: begin        // exit ID mode
                        $display("exit ID mode");
                        mode <= MODE_NORMAL;
                    end
                    8'h80: begin        // enter erase mode
                        $display("enter erase mode");
                        mode <= MODE_ERASE;
                    end
                    8'h10: if (mode == MODE_ERASE) begin    // erase entire chip
                        $display("erase entire chip");
                        state <= ERASE_START;               // blocks CPU until all 128KB are erased
                        sdram_addr <= {9'b1000_0001_0, 16'b0};
                        count <= 16'hffff;
                        mode <= MODE_NORMAL;
                    end
                    8'hA0:         // enter byte write mode
                        mode <= MODE_WRITE;
                    8'hB0:         // enter bank switch mode
                        mode <= MODE_BANK;
                    default: ;
                    endcase
                end else begin
                    if (din[7:0] == 8'h30 & mode == MODE_ERASE & addr[11:0] == 0) begin    
                        // erase 4KB sector
                        $display("erase 4KB sector: %h", addr[15:12]);
                        state <= ERASE_START;
                        sdram_addr <= {9'b1000_0001_0, bank, addr[15:12], 11'b0};
                        count <= 16'h7ff;   // 2K half-words == 4KB
                        mode <= MODE_NORMAL;
                    end
                end
            end

            default: ;
            endcase
        end
    end

    // normal read/write loop
    WAIT1: state <= WAIT2;
    
    WAIT2: state <= WAIT3; 

    WAIT3: begin
        state <= READY;
        ready <= 1;
    end
    
    READY: begin
        reg [7:0] dout_var;
        dout_var = addr[0] ? sdram_q[15:8] : sdram_q[7:0];

        if (mode == MODE_ID) begin
            if (addr == 16'h0) dout_var = 8'h62;       // Sanyo flash
            if (addr == 16'h1) dout_var = 8'h13;       
        end
        if (isflash & ~write)
            $display("flash read: [%h]=%h", {bank|addr[16], addr[15:0]}, dout_var);
        dout <= dout_var;
        state <= IDLE;
    end

    // Flash erase loop
    ERASE_START: begin
        sdram_wr <= 1;
        sdram_d <= 16'hffff;
        sdram_ds <= 2'b11;
        state <= ERASE_WAIT1;
    end
    
    ERASE_WAIT1: state <= ERASE_WAIT2;
    
    ERASE_WAIT2: begin
        if (count == 0) begin
            ready <= 1;
            state <= ERASE_READY;
        end else begin
            count <= count - 1;
            sdram_addr <= sdram_addr + 1;
            state <= ERASE_START;
        end
    end
    
    ERASE_READY: begin
        $display("erase done");
        state <= IDLE;
    end

    default: ;
    endcase

end

endmodule