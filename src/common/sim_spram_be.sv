// Single-port byte enabled memory for simulation
module sim_spram_be #(
    parameter WIDTH = 32,
    parameter DEPTH = 1024,
    parameter FILE = "",
    parameter SIZE = 1
)(
    input clk,
    input rst,
    input ce,
    input [WIDTH-1:0] din,
    input [WIDTH-1:0] addr,
    input we,
    input [WIDTH/8-1:0] be,
    output reg [WIDTH-1:0] dout
);

reg [WIDTH-1:0] mem [0:DEPTH-1];

initial begin
    if (FILE != "") begin
        $readmemh(FILE, mem, 0, SIZE-1);
    end
end

always @(posedge clk)
begin
    if (~rst & ce) begin
        if (we) begin
            for (int i = 0; i < WIDTH/8; i++)
                if (be[i])
                    mem[addr][i*8 +: 8] <= din[i*8 +: 8];
        end
        dout <= mem[addr];
    end
end

endmodule