
module gba_sound_dma(clk, reset, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
            settings_new, Enable_RIGHT, Enable_LEFT, Timer_Select, Reset_FIFO, volume_high, timer0_tick, timer1_tick, dma_req, sound_out_left, sound_out_right, sound_on, new_sample_out, debug_fifocount);
    `include "pproc_bus_gba.sv"
    `include "preg_gba_sound.sv"
    parameter regmap_type                REG_FIFO = FIFO_A;
    //      REG_SAVESTATE_DMASOUND  : regmap_type

    input                                clk;
    input                                reset;
    
    `GB_BUS_PORTS_DECL;

    input                                settings_new;
    input                                Enable_RIGHT;
    input                                Enable_LEFT;
    input                                Timer_Select;
    input                                Reset_FIFO;
    input                                volume_high;
    
    input                                timer0_tick;
    input                                timer1_tick;
    output reg                           dma_req;
    
    output signed [15:0]                 sound_out_left;
    output signed [15:0]                 sound_out_right;
    output                               sound_on;
    
    output                               new_sample_out;
    
    output [31:0]                        debug_fifocount;
    
    
    wire [REG_FIFO.upper:REG_FIFO.lower] FIFO_REGISTER;
    wire                                 FIFO_REGISTER_written;
    reg [3:0]                            FIFO_WRITE_ENABLES;
    
    wire                                 any_on;
    reg                                  new_sample_request;
    
    reg [1:0]                            afterfifo_cnt;
    reg [31:0]                           afterfifo_data;
    
    reg signed [15:0]                    sound_out;
    
    eProcReg_gba #(REG_FIFO) iFIFO_REGISTER(clk, `GB_BUS_PORTS_LIST, 32'h0, FIFO_REGISTER, FIFO_REGISTER_written);
    
    assign any_on = Enable_LEFT | Enable_RIGHT;
    assign sound_on = any_on;
    
    assign debug_fifocount = fifo_cnt;
    
    assign sound_out_left = (Enable_LEFT) ? sound_out : {16{1'b0}};
    assign sound_out_right = (Enable_RIGHT) ? sound_out : {16{1'b0}};
    
    assign new_sample_out = new_sample_request;
    
    // 8 x 32bit FIFO
    reg [31:0] fifo [0:7];
    reg [2:0] fifo_base;
    reg [2:0] fifo_cnt;
    reg fifo_Wr;
    reg fifo_be;

    always @(posedge clk) begin
            
        dma_req <= 1'b0;
        
        if (reset) begin
            
            sound_out <= {16{1'b0}};
            afterfifo_data <= {32{1'b0}};
            afterfifo_cnt <= 0;

            fifo_base <= 0;            
            fifo_cnt <= 0;
        
        end else begin
            reg [7:0] sound_raw;

            case (afterfifo_cnt)
                0 : sound_raw = afterfifo_data[7:0];
                1 : sound_raw = afterfifo_data[15:8];
                2 : sound_raw = afterfifo_data[23:16];
                3 : sound_raw = afterfifo_data[31:24];
                default : ;
            endcase
            
            if (volume_high)
                sound_out <= signed'(sound_raw) * 4;
            else
                sound_out <= signed'(sound_raw) * 2;
            
            FIFO_WRITE_ENABLES <= gb_bus_be;
            
            if (settings_new & Reset_FIFO) begin
                fifo_cnt <= 0;
                fifo_base <= 0;
                afterfifo_cnt <= 0;
            end 
            
            // keep new request if fifo is not idling to make sure the sample counter works correct
            if (any_on & ((timer0_tick & Timer_Select == 1'b0) | (timer1_tick & Timer_Select == 1'b1)))
                new_sample_request <= 1'b1;
            
            if (FIFO_REGISTER_written) begin
                
                if (fifo_cnt < 7) begin		// real hardware does also clear fifo when writing 8th dword(can only happen when writing without DMA)
                    fifo_cnt <= fifo_cnt + 1;
                end 
                
                if (FIFO_WRITE_ENABLES[0])
                    fifo[fifo_base + fifo_cnt][7:0] <= FIFO_REGISTER[7:0];
                if (FIFO_WRITE_ENABLES[1])
                    fifo[fifo_base + fifo_cnt][15:8] <= FIFO_REGISTER[15:8];
                if (FIFO_WRITE_ENABLES[2])
                    fifo[fifo_base + fifo_cnt][23:16] <= FIFO_REGISTER[23:16];
                if (FIFO_WRITE_ENABLES[3])
                    fifo[fifo_base + fifo_cnt][31:24] <= FIFO_REGISTER[31:24];
            
            end else if (new_sample_request) begin		// get sample from fifo
                
                new_sample_request <= 1'b0;
                
                if (fifo_cnt <= 3)
                    dma_req <= 1'b1;
                
                if (afterfifo_cnt < 3)
                    afterfifo_cnt <= afterfifo_cnt + 1;
                else if (fifo_cnt > 0) begin
                    afterfifo_cnt <= 0;
                    fifo_cnt <= fifo_cnt - 1;
                    fifo_base <= fifo_base + 1;
                    afterfifo_data <= fifo[fifo_base][31:0];
                end 
            end 
        end
    end 
    
endmodule
`undef pproc_bus_gba
`undef preg_gba_sound