// Adapter the 32-bit iosys RV memory interface to 16-bit sdram controller
module rv_sdram_adapter (
    input clk,
    input resetn,

    input rv_valid ,
    input [22:0] rv_addr ,
    input [31:0] rv_wdata ,
    input [3:0] rv_wstrb ,
    output reg rv_ready ,            // 1: rv_rdata is available now
    output [31:0] rv_rdata ,

    output reg [22:1]   mem_addr ,
    output reg          mem_req ,
    output reg [1:0]    mem_ds ,
    output reg [15:0]   mem_din ,
    output reg          mem_we ,
    input               mem_req_ack ,
    input [15:0]        mem_dout 
);

localparam RV_IDLE_REQ0 = 3'd0;
localparam RV_WAIT0 = 3'd1;
localparam RV_DATA0 = 3'd2;
localparam RV_REQ1 = 3'd3;
localparam RV_WAIT1 = 3'd4;
localparam RV_READY = 3'd5;

reg [2:0] rvst ;
reg rv_valid_r, rv_word;
reg [15:0] mem_dout0;
reg mem_req_r;
assign rv_rdata = {mem_dout, mem_dout0};

always @* begin
    reg w;
    if (rv_valid & rvst == RV_IDLE_REQ0) begin  // start of request
        w = rv_wstrb[3:2] != 2'b0 & rv_wstrb[1:0] == 2'b0;
        mem_req = ~mem_req_r;
    end else begin                              // subsequent cycles
        w = rv_word;
        mem_req = mem_req_r;
    end
    mem_addr = {rv_addr[22:2], w};
    mem_din = w ? rv_wdata[31:16] : rv_wdata[15:0];
    mem_we = rv_wstrb != 0;
    mem_ds = w ? rv_wstrb[3:2] : rv_wstrb[1:0];
end

always @(posedge clk) begin            // RV
    if (~resetn) begin
        rvst <= RV_IDLE_REQ0;
        rv_ready <= 0;
    end else begin
        reg write;
        write = rv_wstrb != 4'b0;
        rv_ready <= 0;
        mem_req_r <= mem_req;           // default

        case (rvst)
        RV_IDLE_REQ0: if (rv_valid) begin       // issue request 0
            rv_word <= rv_wstrb[3:2] != 2'b0 & rv_wstrb[1:0] == 2'b0;
            rvst <= RV_WAIT0;
        end

        RV_WAIT0: begin                    // wait for request 0 ack and issue request 1
            if (mem_req == mem_req_ack) begin
                if (rv_word | write & rv_wstrb[3:2] == 2'b0) begin
                    // 16-bit access
                    rv_ready <= 1;
                    rvst <= RV_READY;
                end else begin
                    // 32-bit access
                    // rvst <= RV_DATA0;
                    rv_word <= 1;
                    mem_req_r <= ~mem_req_r;    // issue request 1
                    rvst <= RV_REQ1;
                end
            end
        end

        RV_REQ1: begin
            mem_dout0 <= mem_dout;              // collect data from request 0
            rvst <= RV_WAIT1;
        end

        RV_WAIT1:                               // wait for request 1 ack
            if (mem_req == mem_req_ack) begin
                rv_ready <= 1;
                rvst <= RV_READY;
            end

        RV_READY:                               // wait a cycle before returning to idle
            rvst <= RV_IDLE_REQ0;

        default:;
        endcase
    end
end

endmodule