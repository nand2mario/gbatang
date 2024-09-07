// Gowin 32-bit dual-port RAM backed by 2 BSRAM blocks (max 4KB), with byte-enable support
module dpram32_block(
    
    input               clka,
    input       [9:0]   addr_a,         // word address
    input       [31:0]  datain_a,
    output reg  [31:0]  dataout_a,
    input               we_a,
    input               re_a,
    input       [3:0]   be_a,           // byte-enable
    
    input               clkb,
    input       [9:0]   addr_b,
    input       [31:0]  datain_b,
    output reg  [31:0]  dataout_b,
    input               we_b,
    input               re_b,
    input       [3:0]   be_b
);

`ifndef VERILATOR
// default to bypass read and normal write    
DPB #(
    .BIT_WIDTH_0(16), .BIT_WIDTH_1(16)
) dpb0 (
    .CLKA(clka), .RESETA(1'b0), .CEA(1'b1), .OCEA(re_a), .WREA(we_a), 
    .DIA(datain_a[15:0]), .DOA(dataout_a[15:0]), .BLKSELA(3'b0),
    .ADA({addr_a, 2'b0, be_a[1:0]}),

    .CLKB(clkb), .RESETB(1'b0), .CEB(1'b1), .OCEB(re_b), .WREB(we_b),
    .DIB(datain_b[15:0]), .DOB(dataout_b[15:0]), .BLKSELB(3'b0),
    .ADB({addr_b, 2'b0, be_b[1:0]})
);

DPB #(
    .BIT_WIDTH_0(16), .BIT_WIDTH_1(16)
) dpb1 (
    .CLKA(clka), .RESETA(1'b0), .CEA(1'b1), .OCEA(re_a), .WREA(we_a), 
    .DIA(datain_a[31:16]), .DOA(dataout_a[31:16]), .BLKSELA(3'b0),
    .ADA({addr_a, 2'b0, be_a[3:2]}),

    .CLKB(clkb), .RESETB(1'b0), .CEB(1'b1), .OCEB(re_b), .WREB(we_b),
    .DIB(datain_b[31:16]), .DOB(dataout_b[31:16]), .BLKSELB(3'b0),
    .ADB({addr_b, 2'b0, be_b[3:2]})
);

`else
reg [31:0]    ram[0:1023] /* verilator public */;

always @(posedge clka) begin
    // Port A
    if (we_a) begin
        if (be_a[0]) ram[addr_a][7:0] <= datain_a[7:0];
        if (be_a[1]) ram[addr_a][15:8] <= datain_a[15:8];
        if (be_a[2]) ram[addr_a][23:16] <= datain_a[23:16];
        if (be_a[3]) ram[addr_a][31:24] <= datain_a[31:24];
    end else if (re_a)
        dataout_a <= ram[addr_a];
end
        
always @(posedge clkb) begin
    // Port B
    if (we_b) begin
        if (be_b[0]) ram[addr_b][7:0] <= datain_b[7:0];
        if (be_b[1]) ram[addr_b][15:8] <= datain_b[15:8];
        if (be_b[2]) ram[addr_b][23:16] <= datain_b[23:16];
        if (be_b[3]) ram[addr_b][31:24] <= datain_b[31:24];
    end else if (re_b)
        dataout_b <= ram[addr_b];
end 
`endif
    
endmodule

