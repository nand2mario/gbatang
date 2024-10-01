// Adapter the 32-bit iosys RV memory interface to 16-bit sdram controller
module rv_sdram_adapter (
    input clk,
    input resetn,
    input       [2:0] config_backup_type,       // EEPROM enabled when config_backup_type == 4

    input rv_valid        /* xsynthesis syn_keep=1 */,
    input [22:0] rv_addr  /* xsynthesis syn_keep=1 */,
    input [31:0] rv_wdata /* xsynthesis syn_keep=1 */,
    input [3:0] rv_wstrb  /* xsynthesis syn_keep=1 */,
    output reg rv_ready   /* xsynthesis syn_keep=1 */,            // 1: rv_rdata is available now
    output [31:0] rv_rdata/* xsynthesis syn_keep=1 */,

    // RV may access eeprom for save persistence (8-bit interface)
    output reg          eeprom_rd    /* xsynthesis syn_keep=1 */,
    output reg          eeprom_wr    /* xsynthesis syn_keep=1 */,
    output reg [12:0]   eeprom_addr  /* xsynthesis syn_keep=1 */,
    input  reg  [7:0]   eeprom_rdata /* xsynthesis syn_keep=1 */,
    output reg  [7:0]   eeprom_wdata /* xsynthesis syn_keep=1 */,

    output reg [22:1]   mem_addr,
    output reg          mem_req,
    output reg [1:0]    mem_ds,
    output reg [15:0]   mem_din,
    output reg          mem_we,
    input               mem_req_ack,
    input [15:0]        mem_dout 
);

localparam RV_IDLE_REQ0 = 0;
localparam RV_WAIT0 = 1;
localparam RV_DATA0 = 2;
localparam RV_REQ1 = 3;
localparam RV_WAIT1 = 4;
localparam RV_READY = 5;
localparam RV_EEPROM1 = 6;
localparam RV_EEPROM2 = 7;
localparam RV_EEPROM3 = 8;

// RV output
reg [3:0] rvst;
reg rv_valid_r, rv_word;
reg [15:0] mem_dout0;
reg mem_req_r;
reg eeprom_out;
reg [23:0] eeprom_rdata0;
assign rv_rdata = eeprom_out ? {eeprom_rdata, eeprom_rdata0} : {mem_dout, mem_dout0};

wire is_eeprom = config_backup_type == 4 && rv_addr[22:20] == 3'd7;

always @* begin
    reg w;
    if (rv_valid & ~is_eeprom & rvst == RV_IDLE_REQ0) begin  // start of RV request
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

// EEPROM output
reg eeprom_wr_buf;
reg [7:0] eeprom_wdata_buf;
reg [12:0] eeprom_addr_buf;

always @* begin
    eeprom_rd = 1;
    eeprom_wr = 0;
    eeprom_addr = eeprom_addr_buf;
    eeprom_wdata = eeprom_wdata_buf;
    if (rv_valid & is_eeprom) begin
        if (rvst == RV_IDLE_REQ0) begin
            eeprom_wr = rv_wstrb[0];
            eeprom_addr = {rv_addr[12:2], 2'b0};
            eeprom_wdata = rv_wdata[7:0];
        end else
            eeprom_wr = eeprom_wr_buf;
    end
end

always @(posedge clk) begin            // RV
    if (~resetn) begin
        rvst <= RV_IDLE_REQ0;
        rv_ready <= 0;
        eeprom_wr_buf <= 0;
    end else begin
        reg write;
        write = rv_wstrb != 4'b0;
        rv_ready <= 0;
        eeprom_out <= 0;
        mem_req_r <= mem_req;           // default

        case (rvst)
        RV_IDLE_REQ0: if (rv_valid) begin
            if (config_backup_type == 4 && rv_addr[22:20] == 3'd7) begin   // EEPROM request, 700000-701FFF (8KB)
                eeprom_addr_buf <= {rv_addr[12:2], 2'b01};
                eeprom_wr_buf <= rv_wstrb[1];
                eeprom_wdata_buf <= rv_wdata[15:8];
                rvst <= RV_EEPROM1;
            end else begin                                              // normal RV request
                rv_word <= rv_wstrb[3:2] != 2'b0 & rv_wstrb[1:0] == 2'b0;
                rvst <= RV_WAIT0;        
            end
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

        RV_EEPROM1: begin
            rvst <= RV_EEPROM2;
            eeprom_addr_buf <= {rv_addr[12:2], 2'b10};
            eeprom_rdata0[7:0] <= eeprom_rdata;
            eeprom_wr_buf <= rv_wstrb[2];
            eeprom_wdata_buf <= rv_wdata[23:16];
        end
        RV_EEPROM2: begin
            rvst <= RV_EEPROM3;
            eeprom_addr_buf <= {rv_addr[12:2], 2'b11};
            eeprom_rdata0[15:8] <= eeprom_rdata;
            eeprom_wr_buf <= rv_wstrb[3];
            eeprom_wdata_buf <= rv_wdata[31:24];
        end
        RV_EEPROM3: begin
            rvst <= RV_READY;
            eeprom_rdata0[23:16] <= eeprom_rdata;
            eeprom_wr_buf <= 0;
            rv_ready <= 1;
            eeprom_out <= 1;
        end

        default:;
        endcase

    end
end



always @(posedge clk) begin

end


endmodule