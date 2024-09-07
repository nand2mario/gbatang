
module SyncRamDual(clk, addr_a, datain_a, dataout_a, we_a, re_a, addr_b, datain_b, dataout_b, we_b, re_b);
    parameter                 DATA_WIDTH = 8;
    parameter                 ADDR_WIDTH = 6;
    input                     clk;
    
    input [ADDR_WIDTH-1:0]      addr_a;
    input [DATA_WIDTH-1:0]      datain_a;
    output reg [DATA_WIDTH-1:0] dataout_a;
    input                       we_a;
    input                       re_a;
    
    input [ADDR_WIDTH-1:0]      addr_b;
    input [DATA_WIDTH-1:0]      datain_b;
    output reg [DATA_WIDTH-1:0] dataout_b;
    input                       we_b;
    input                       re_b;
    
    
    // Build a 2-D array type for the RAM
    // Declare the RAM 
    reg [DATA_WIDTH-1:0]    ram[0:2**ADDR_WIDTH-1];
    
    always @(posedge clk)
         begin
            // Port A
            if (we_a == 1'b1)
                ram[addr_a] <= datain_a;
            else if (re_a == 1'b1)
                dataout_a <= ram[addr_a];
            
            // Port B
            if (we_b == 1'b1)
                ram[addr_b] <= datain_b;
            else if (re_b == 1'b1)
                dataout_b <= ram[addr_b];
        end 
    
endmodule

