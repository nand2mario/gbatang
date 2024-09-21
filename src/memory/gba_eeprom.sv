
// The eeprom is connected to Bit0 of the data bus, and to the upper 1 bit (or upper 17 bits in case of 
// large 32MB ROM) of the cartridge ROM address bus, communication with the chip takes place serially.
//
// Data can be read from (or written to) the EEPROM in units of 64bits (8 bytes). Writing automatically 
// erases the old 64bits of data.
//
// Set address for read:
//   2 bits "11" (Read Request)
//   n bits eeprom address (MSB first, 6 or 14 bits, depending on EEPROM)
//   1 bit "0"
// Then read 68 bits
//   4 bits - ignore these
//  64 bits - data (conventionally MSB first)
//
// Write Data to Address
//   2 bits "10" (Write Request)
//   n bits eeprom address (MSB first, 6 or 14 bits, depending on EEPROM)
//  64 bits data (conventionally MSB first)
//   1 bit "0"
// After DMA, keep reading from chip until it return "1" (ready).
//
// DMA
//
// A buffer in memory must be used (that buffer would be typically allocated temporarily on stack, one 
// halfword for each bit, bit1-15 of the halfwords are don’t care, only bit0 is of interest).
// 
// The buffer must be transfered as a whole to/from EEPROM by using DMA3 (only DMA 3 is valid to read & 
// write external memory), use 16bit transfer mode, both source and destination address incrementing 
// (ie. DMA3CNT=80000000h+length).

module gba_eeprom( 
    input clk,
    input rst,
    input cs,
    input model,        // 0: 512 bytes (SMA), 1: 8KB (Boktai)
    input [16:0] dma_eepromcount,   // DMA transfer count to detect model

    input valid,        // 1 bit serial memory interface
    input write,
    output ready,
    input din,
    output dout
);

assign ready = valid;   // immediately ready

reg [13:0] addr;        // 6 or 10 bit block address of 64-bit blocks
reg  [5:0] off;         // in block bit address
reg init_write;
wire [19:0] fulladdr = {addr, off};

wire mem_write = state == WR_DATA ? write : init_write;
wire mem_din = state == WR_DATA ? din : 1'b1;
reg mem_dout;
reg out1;               // always output 1 when IDLE 

assign dout = out1 ? 1'b1 : mem_dout;

`ifndef VERILATOR
mem_eeprom m_eeprom (
    .clk(clk), .ce(1'b1), .reset(rst),
    .ad(fulladdr[15:0]), .wre(mem_write), .oce(1'b1),
    .dout(mem_dout), .din(mem_din)
);
`else
reg [64*1024-1:0] mem;  // 64Kbits of memory, 4 BRAM blocks

always @(posedge clk) begin
    if (mem_write) mem[fulladdr[15:0]] <= mem_din;
    mem_dout <= mem[fulladdr[15:0]];
end

`endif

reg [3:0] state;
reg [3:0] cnt;
localparam INIT     = 4'd0;
localparam IDLE     = 4'd1;
localparam BIT2     = 4'd2;
localparam RD_ADDR  = 4'd3;
localparam RD_ZERO  = 4'd4;
localparam RD_HEAD  = 4'd5;
localparam RD_DATA  = 4'd6;
localparam WR_ADDR  = 4'd7;
localparam WR_DATA  = 4'd8;
localparam WR_ZERO  = 4'd9;

always @(posedge clk) begin
    if (rst) begin
        state <= INIT;
        cnt <= 0;
        addr <= 0;
        off <= 0;
    end else begin
        reg model_detected;     // 1: 64Kbits, 0: 4Kbits
        model_detected <= model;
        if (dma_eepromcount == 9 | dma_eepromcount == 73) model_detected <= 0;
        else if (dma_eepromcount == 17 | dma_eepromcount == 81) model_detected <= 1;

        if (state == INIT) begin
            {addr,off} <= {addr,off} + 1;
            init_write <= 1;
            if (fulladdr == 64*1024-1) state <= IDLE;
        end

        if (cs & valid) begin
            case (state) 
            
            IDLE: begin
                init_write <= 0;
                out1 <= 1;      // when in IDLE, always output 1 (for 'ready' signal after EEPROM write)
                if (write & din) begin
                    state <= BIT2;
                    out1 <= 0;
                end
            end
            
            BIT2: if (write) begin
                state <= din ? RD_ADDR : WR_ADDR;
                cnt <= model_detected ? 13 : 5;     // 14 bit or 6 bit address
                addr <= 0;
                off <= 0;
            end

            RD_ADDR, WR_ADDR: if (write) begin
                addr[cnt] <= din;
                if (cnt == 0) begin
                    state <= state == RD_ADDR ? RD_ZERO : WR_DATA;

                    if (state == RD_ADDR)
                        $display("EEPROM read address %h (address len=%d)", {addr[13:1], din}, model_detected ? 14 : 6);
                    else
                        $display("EEPROM write address %h (address len=%d)", {addr[13:1], din}, model_detected ? 14 : 6);
                end
                cnt <= cnt - 1;
            end

            // read command
            RD_ZERO: if (write) begin
                state <= RD_HEAD;          
                cnt <= 0;
            end

            RD_HEAD: if (~write) begin      // 4 not-care bits before read data is sent
                if (cnt == 3) state <= RD_DATA;
                cnt <= cnt + 1;
            end

            RD_DATA: if (~write) begin
                off <= off + 6'd1;
                if (off == 6'd63) begin
                    state <= IDLE;
`ifdef VERILATOR
                    $display("Data read: %h", mem[addr*64 +: 64]);
`endif
                end
            end

            // write command
            WR_DATA: if (write) begin
                // writing to memory
                off <= off + 6'd1;
                if (off == 6'd63) begin
                    state <= WR_ZERO;
`ifdef VERILATOR
                    $display("Data written: %h", mem[addr*64 +: 64]);
`endif
                end
            end

            WR_ZERO: 
                if (write) state <= IDLE;

            default: ;

            endcase
        end
    end
end

endmodule