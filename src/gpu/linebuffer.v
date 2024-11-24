// Line buffer with SSRAM memory

`ifndef CONFIG_H
$error("config.v must be parsed first");
`endif

module linebuffer #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 8
) (
    input clk,
    input [ADDR_WIDTH-1:0] waddr,
    input [ADDR_WIDTH-1:0] raddr,
    input [DATA_WIDTH-1:0] wdata,
    output reg [DATA_WIDTH-1:0] rdata,
    input we
);

//`ifdef M138K
//reg [DATA_WIDTH-1:0] ram[0:2**ADDR_WIDTH-1] /* synthesis syn_ramstyle = "block_ram" */;
//`else
reg [DATA_WIDTH-1:0] ram[0:2**ADDR_WIDTH-1] /* synthesis syn_ramstyle = "distributed_ram" */;
//`endif

//assign rdata = ram[raddr];

always @(posedge clk) begin
    rdata <= ram[raddr];
end

always @(posedge clk) begin
    if (we == 1'b1)
        ram[waddr] <= wdata;
end

endmodule