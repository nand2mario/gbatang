// Dual-port byte enabled memory for simulation
module sim_dpram_be #(
    parameter WIDTH = 32,
    parameter DEPTH = 1024
)(
    input      rst,

    input      clka,
    input      [WIDTH-1:0] dina,
    input      [WIDTH-1:0] addra,
    input      wea,                 // write enable
    input      [WIDTH/8-1:0] bea,   // byte enable
    output reg [WIDTH-1:0] douta,

    input      clkb,
    input      [WIDTH-1:0] dinb,
    input      [WIDTH-1:0] addrb,
    input      web,
    input      [WIDTH/8-1:0] beb,
    output reg [WIDTH-1:0] doutb
);

reg [WIDTH-1:0] mem [0:DEPTH-1] /* verilator public */;

always @(posedge clka)
begin
    if (rst) begin
        for (int i = 0; i < DEPTH; i++)
            mem[i] <= 0;
    end else begin
        if (wea) begin
            for (int i = 0; i < WIDTH/8; i++)
                if (bea[i])
                    mem[addra][i*8 +: 8] <= dina[i*8 +: 8];
        end
        douta <= mem[addra];
    end
end

always @(posedge clkb)
begin
    if (rst) begin
        for (int i = 0; i < DEPTH; i++)
            mem[i] <= 0;
    end else begin
        if (web) begin
            for (int i = 0; i < WIDTH/8; i++)
                if (beb[i])
                    mem[addrb][i*8 +: 8] <= dinb[i*8 +: 8];
        end
        doutb <= mem[addrb];
    end
end

endmodule