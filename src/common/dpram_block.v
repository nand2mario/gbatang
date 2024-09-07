// Gowin dual-port RAM backed by a single BSRAM block (max 2KB)
module dpram_block(clka, clkb, addr_a, datain_a, dataout_a, we_a, re_a, addr_b, datain_b, dataout_b, we_b, re_b);
    parameter                   DATA_WIDTH = 8;     // 4,8,16
    parameter                   ADDR_WIDTH = 6;
    
    input                       clka;
    input  [ADDR_WIDTH-1:0]     addr_a;
    input  [DATA_WIDTH-1:0]     datain_a;
    output reg [DATA_WIDTH-1:0]     dataout_a;
    input                       we_a;
    input                       re_a;
    
    input                       clkb;
    input  [ADDR_WIDTH-1:0]     addr_b;
    input  [DATA_WIDTH-1:0]     datain_b;
    output reg [DATA_WIDTH-1:0]     dataout_b;
    input                       we_b;
    input                       re_b;

if (DATA_WIDTH != 4 && DATA_WIDTH != 8 && DATA_WIDTH != 16)
    $error("ERROR: DATA_WIDTH must be 4, 8, or 16");
if (ADDR_WIDTH > 12)
    $error("ERROR: ADDR_WIDTH must be <= 12");

`ifndef VERILATOR
// default to bypass read and normal write    
DPB #(
    .BIT_WIDTH_0(DATA_WIDTH), .BIT_WIDTH_1(DATA_WIDTH)
) dpb (
    .CLKA(clka), .RESETA(1'b0), .CEA(1'b1), .OCEA(re_a), .WREA(we_a), 
    .DIA(datain_a), .DOA(dataout_a), .BLKSELA(3'b0),
    .ADA(DATA_WIDTH == 4 ? {addr_a, 2'b0} :
         DATA_WIDTH == 8 ? {addr_a, 3'b0} :
         DATA_WIDTH == 16 ? {addr_a, 4'b0011} : 
         addr_a), 

    .CLKB(clkb), .RESETB(1'b0), .CEB(1'b1), .OCEB(re_b), .WREB(we_b),
    .DIB(datain_b), .DOB(dataout_b), .BLKSELB(3'b0),
    .ADB(DATA_WIDTH == 4 ? {addr_b, 2'b0} :
         DATA_WIDTH == 8 ? {addr_b, 3'b0} :
         DATA_WIDTH == 16 ? {addr_b, 4'b0011} :
         addr_b)
);
`else
reg [DATA_WIDTH-1:0]    ram[0:2**ADDR_WIDTH-1] /* verilator public */;

always @(posedge clka) begin
    // Port A
    if (we_a == 1'b1)
        ram[addr_a] <= datain_a;
    else if (re_a == 1'b1)
        dataout_a <= ram[addr_a];
end
        
always @(posedge clkb) begin
    // Port B
    if (we_b == 1'b1)
        ram[addr_b] <= datain_b;
    else if (re_b == 1'b1)
        dataout_b <= ram[addr_b];
end 
`endif
    
endmodule

