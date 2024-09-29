module gba_dma_module (
    clk100, reset, ce, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
    new_cycles, new_cycles_valid, irp_dma, dma_on, cpu_preemptable, allow_on, lowprio_pending,
    sound_dma_req, hblank_trigger, vblank_trigger, videodma_start, videodma_stop,                    
    dma_new_cycles, dma_first_cycles, dma_dword_cycles, dma_torom, dma_init_cycles, dma_cycles_adrup,                
    dma_eepromcount, last_dma_out, last_dma_valid, last_dma_in, dma_bus_adr, dma_bus_rnw, dma_bus_ena, 
    dma_bus_acc, dma_bus_dout, dma_bus_din, dma_bus_done, dma_bus_unread, is_idle
);

`include "pproc_bus_gba.sv"

parameter [1:0] index;
parameter has_DRQ;
parameter regmap_type Reg_SAD                     ;
parameter regmap_type Reg_DAD                     ;
parameter regmap_type Reg_CNT_L                   ;
parameter regmap_type Reg_CNT_H_Dest_Addr_Control ;
parameter regmap_type Reg_CNT_H_Source_Adr_Control;
parameter regmap_type Reg_CNT_H_DMA_Repeat        ;
parameter regmap_type Reg_CNT_H_DMA_Transfer_Type ;
parameter regmap_type Reg_CNT_H_Game_Pak_DRQ      ;
parameter regmap_type Reg_CNT_H_DMA_start_timing  ;
parameter regmap_type Reg_CNT_H_IRQ_on            ;
parameter regmap_type Reg_CNT_H_DMA_Enable        ;

input           clk100;
input           reset;
input           ce;

`GB_BUS_PORTS_DECL;                     // MMIO bus where DMA requests come from 

input [7:0]     new_cycles;             // cycle counting
input           new_cycles_valid;

output reg      irp_dma;
                                   
output          dma_on;                 // Pause CPU because DMA is running
input           cpu_preemptable;        // CPU is preemptible and DMA can start
input           allow_on /* synthesis syn_keep=1 */;               // when DMA is running, allow read/write to happen
input           lowprio_pending;        // 1: any of lower priority DMA is running
                                   
input           sound_dma_req;          // DMA trigger signals
input           hblank_trigger;
input           vblank_trigger;
input           videodma_start;
input           videodma_stop;
                                   
output reg          dma_new_cycles;         // pulse at new cycle start
output reg          dma_first_cycles;        // 1: first DMA cycle
output reg          dma_dword_cycles;        // 1: 32-bit transfers
output reg          dma_torom;              
output reg          dma_init_cycles;        // extra cycle when lowprio_pending == 0?
output reg [3:0]    dma_cycles_adrup;       // [27:24] of address
                               
output reg [16:0]   dma_eepromcount;
                              
output reg [31:0]   last_dma_out;           // last data read from memory
output reg          last_dma_valid;         // 1: last data is valid
input      [31:0]   last_dma_in;            
                              
output reg [27:0]   dma_bus_adr;    
output reg          dma_bus_rnw;    
output reg          dma_bus_ena;    
output reg [1:0]    dma_bus_acc;    
output reg [31:0]   dma_bus_dout;   
input      [31:0]   dma_bus_din;  
input               dma_bus_done;
input               dma_bus_unread;
                              
output          is_idle;

wire [Reg_SAD                     .upper : Reg_SAD                     .lower] SAD                     ;
wire [Reg_DAD                     .upper : Reg_DAD                     .lower] DAD                     ;
wire [Reg_CNT_L                   .upper : Reg_CNT_L                   .lower] CNT_L                   ;
wire [Reg_CNT_H_Dest_Addr_Control .upper : Reg_CNT_H_Dest_Addr_Control .lower] CNT_H_Dest_Addr_Control ;
wire [Reg_CNT_H_Source_Adr_Control.upper : Reg_CNT_H_Source_Adr_Control.lower] CNT_H_Source_Adr_Control;
wire [Reg_CNT_H_DMA_Repeat        .upper : Reg_CNT_H_DMA_Repeat        .lower] CNT_H_DMA_Repeat        ;
wire [Reg_CNT_H_DMA_Transfer_Type .upper : Reg_CNT_H_DMA_Transfer_Type .lower] CNT_H_DMA_Transfer_Type ;
wire [Reg_CNT_H_Game_Pak_DRQ      .upper : Reg_CNT_H_Game_Pak_DRQ      .lower] CNT_H_Game_Pak_DRQ      ;
wire [Reg_CNT_H_DMA_start_timing  .upper : Reg_CNT_H_DMA_start_timing  .lower] CNT_H_DMA_start_timing  ;
wire [Reg_CNT_H_IRQ_on            .upper : Reg_CNT_H_IRQ_on            .lower] CNT_H_IRQ_on            ;
wire [Reg_CNT_H_DMA_Enable        .upper : Reg_CNT_H_DMA_Enable        .lower] CNT_H_DMA_Enable        ;

wire CNT_H_DMA_Enable_written;

reg enable, running, waiting, first, dmaon;
reg [1:0] waitTicks;
reg CNT_H_DMA_Enable_written_r;
// assign dma_pause = CNT_H_DMA_Enable_written & ~CNT_H_DMA_Enable_written_r | enable;       // 1: cpu is paused because of DMA.

reg [1:0] dest_addr_control, source_addr_control, start_timing;
reg Repeat; 
reg Transfer_Type_DW;
reg iRQ_on;

reg [27:0] addr_source, addr_target;
reg [16:0] count, fullcount;

localparam IDLE = 3'd0;
localparam START = 3'd1;            // wait for write finish and start next read
localparam READING = 3'd2;          // wait for read finish and start next write
// localparam READ_READY = 3'd3;
// localparam WRITING = 3'd4;
reg [2:0] state, last_state;

generate
if (has_DRQ) begin
    eProcReg_gba #(Reg_CNT_H_Game_Pak_DRQ) iCNT_H_Game_Pak_DRQ (clk100, `GB_BUS_PORTS_LIST, CNT_H_Game_Pak_DRQ, CNT_H_Game_Pak_DRQ);
end
endgenerate

eProcReg_gba #( Reg_SAD                      ) iSAD                      (clk100, `GB_BUS_PORTS_LIST, 32'h0                    , SAD                     );  
eProcReg_gba #( Reg_DAD                      ) iDAD                      (clk100, `GB_BUS_PORTS_LIST, 32'h0                    , DAD                     );  
eProcReg_gba #( Reg_CNT_L                    ) iCNT_L                    (clk100, `GB_BUS_PORTS_LIST, 16'h0                    , CNT_L                   );   
eProcReg_gba #( Reg_CNT_H_Dest_Addr_Control  ) iCNT_H_Dest_Addr_Control  (clk100, `GB_BUS_PORTS_LIST, CNT_H_Dest_Addr_Control  , CNT_H_Dest_Addr_Control );  
eProcReg_gba #( Reg_CNT_H_Source_Adr_Control ) iCNT_H_Source_Adr_Control (clk100, `GB_BUS_PORTS_LIST, CNT_H_Source_Adr_Control , CNT_H_Source_Adr_Control);  
eProcReg_gba #( Reg_CNT_H_DMA_Repeat         ) iCNT_H_DMA_Repeat         (clk100, `GB_BUS_PORTS_LIST, CNT_H_DMA_Repeat         , CNT_H_DMA_Repeat        );  
eProcReg_gba #( Reg_CNT_H_DMA_Transfer_Type  ) iCNT_H_DMA_Transfer_Type  (clk100, `GB_BUS_PORTS_LIST, CNT_H_DMA_Transfer_Type  , CNT_H_DMA_Transfer_Type );  
eProcReg_gba #( Reg_CNT_H_DMA_start_timing   ) iCNT_H_DMA_start_timing   (clk100, `GB_BUS_PORTS_LIST, CNT_H_DMA_start_timing   , CNT_H_DMA_start_timing  );  
eProcReg_gba #( Reg_CNT_H_IRQ_on             ) iCNT_H_IRQ_on             (clk100, `GB_BUS_PORTS_LIST, CNT_H_IRQ_on             , CNT_H_IRQ_on            );
eProcReg_gba #( Reg_CNT_H_DMA_Enable         ) iCNT_H_DMA_Enable         (clk100, `GB_BUS_PORTS_LIST, enable                   , CNT_H_DMA_Enable         , CNT_H_DMA_Enable_written);

// MMIO reg reads
reg [31:0] reg_dout;
reg reg_dout_en;
assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};

always @(posedge clk100) begin
    if (ce) begin
        reg_dout_en <= 0;
        if (gb_bus_ena & gb_bus_rnw) begin
            reg_dout_en <= 1;
            casez (gb_bus_adr) 
            Reg_SAD.Adr:
                reg_dout <= 32'b0; // 32'hDEADDEAD; // SAD;
            Reg_DAD.Adr:
                reg_dout <= 32'hDEADDEAD; // DAD;
            Reg_CNT_L.Adr:
                reg_dout <= {enable, CNT_H_IRQ_on, CNT_H_DMA_start_timing, CNT_H_Game_Pak_DRQ,
                                CNT_H_DMA_Transfer_Type, CNT_H_DMA_Repeat, CNT_H_Source_Adr_Control,
                                CNT_H_Dest_Addr_Control, 5'b0, 
                                /* CNT_L */ 16'h0};
            28'hE?, 28'hF?:
                reg_dout <= 32'hDEADDEAD;
                
            default: 
                reg_dout_en <= 0;
            endcase
        end
    end
end

reg pre_enable;
assign is_idle = state == IDLE;
assign dma_on = dmaon | pre_enable;     // 1: pause cpu because of DMA.
assign dma_eepromcount = fullcount;

// assign dma_bus_ena = running && (state == READING || state == WRITING);

reg [31:0] dma_bus_dout_buf;
reg [2:0] dmaout;
localparam DMAOUT_DIN = 3'd0;
localparam DMAOUT_DIN_HI16 = 3'd1;
localparam DMAOUT_DIN_LO16 = 3'd2;
localparam DMAOUT_BUF = 3'd3;

always @* begin
    case (dmaout)
    DMAOUT_DIN:         dma_bus_dout = dma_bus_din;
    DMAOUT_DIN_HI16:    dma_bus_dout = {dma_bus_din[31:16], dma_bus_din[31:16]};
    DMAOUT_DIN_LO16:    dma_bus_dout = {dma_bus_din[15:0], dma_bus_din[15:0]};
    DMAOUT_BUF:         dma_bus_dout = dma_bus_dout_buf;
    default:            dma_bus_dout = 32'hDEADDEAD;
    endcase
end

always @(posedge clk100) begin
    if (reset) begin
        addr_source        <= 0;
        addr_target        <= 0;
        count              <= 0;
        
        enable             <= 0;
        running            <= 0;
        waiting            <= 0;
        first              <= 0;
        dest_addr_control  <= 0;
        source_addr_control <= 0;
        start_timing       <= 0;
        Repeat             <= 0;
        Transfer_Type_DW   <= 0;
        iRQ_on             <= 0;
        dmaon              <= 0;
        
        waitTicks          <= 0;
        state              <= IDLE;
    end else if (ce) begin
        reg dma_enable_written;
        reg dma_enable;
        irp_dma       <= 0;
        
        // dma_bus_ena   <= 0;
        
        last_dma_valid   <= 0;
        
        dma_new_cycles   <= 0;
        dma_first_cycles <= 0;
        dma_dword_cycles <= 0;
        dma_torom        <= 0;
        dma_init_cycles  <= 0;
        dma_cycles_adrup <= 0;
        CNT_H_DMA_Enable_written_r <= CNT_H_DMA_Enable_written;

        // make sure dma_on is turned on immediate after DMAxCNT is written to
        pre_enable <= 0;
        if (gb_bus_ena & ~gb_bus_rnw & gb_bus_adr == Reg_CNT_H_DMA_Enable.Adr & gb_bus_be[3] & gb_bus_din[31]) 
            pre_enable <= 1;

        // DMA init
        if (CNT_H_DMA_Enable_written) begin
        
            enable <= CNT_H_DMA_Enable;
            
            if (!CNT_H_DMA_Enable) begin
                running <= 0;
                waiting <= 0;
                dmaon   <= 0;
            end;
        
            if (~enable & CNT_H_DMA_Enable) begin          // posedge enable
                // DRQ not implemented! Reg_CNT_H_Game_Pak_DRQ                
                dest_addr_control   <= CNT_H_Dest_Addr_Control;
                source_addr_control <= CNT_H_Source_Adr_Control;
                start_timing        <= CNT_H_DMA_start_timing;
                Repeat              <= CNT_H_DMA_Repeat[Reg_CNT_H_DMA_Repeat.upper];
                Transfer_Type_DW    <= CNT_H_DMA_Transfer_Type[Reg_CNT_H_DMA_Transfer_Type.upper];
                iRQ_on              <= CNT_H_IRQ_on[Reg_CNT_H_IRQ_on.upper];

                addr_source         <= SAD[27:0];
                addr_target         <= DAD[27:0];

                case (index)
                0 : begin addr_source[27] <= 0; addr_target[27] <= 0; end
                1 :                             addr_target[27] <= 0;
                2 :                             addr_target[27] <= 0;
                3 : ;
                endcase;
                    
                if (index == 3) begin
                    if (CNT_L[15:0] == 0) 
                        count <= {1'b1, 16'h0};
                    else
                        count <= {1'b0, CNT_L[15:0]};
                end else begin
                    if (CNT_L[13:0] == 0) 
                        count <= {1'b0, 16'h4000};
                    else
                        count <= {3'b0, CNT_L[13:0]};
                end 

                waiting <= 1;
                
                if (CNT_H_DMA_start_timing == 2'b11 && (index == 1 || index == 2)) begin // sound dma
                    count             <= 4;
                    dest_addr_control <= 3;
                    Transfer_Type_DW  <= 1;
                end

                // if start timing is immediate, make sure cpu is paused
                if (CNT_H_DMA_start_timing == 0)
                    dmaon <= 1;
            end
    
        end 
        
        // DMA checkrun
        if (enable && ce && CNT_H_DMA_Enable) begin     // CNT_H_DMA_Enable is necessary to stop DMA when 0 is written to it
        
            if (waiting) begin
                if (start_timing == 0 ||
                (start_timing == 1 && vblank_trigger) ||
                (start_timing == 2 && hblank_trigger) ||
                (start_timing == 3 && sound_dma_req) ||
                (start_timing == 3 && videodma_start)) begin
                    // dma_soon   <= 1;
                    waitTicks  <= 3;
                    waiting    <= 0;
                    first      <= 1;
                    fullcount  <= count;
                end
            end
            
            if (start_timing == 3 && videodma_stop) begin
                enable <= 0;
            end
    
            if (waitTicks > 0) begin
                if (new_cycles_valid) begin
                    if (new_cycles >= waitTicks) begin
                        if (cpu_preemptable | CNT_H_DMA_start_timing == 0) begin
                            running   <= 1;
                            dmaon     <= 1;         
                            waitTicks <= 0;
                            // dma_soon  <= 0;
                            state     <= IDLE;
                        end
                    end else begin
                        waitTicks <= waitTicks - new_cycles;
                    end
                end
            end
                
            // DMA work
            // clk    /‾‾‾\___/‾‾‾\___/‾‾‾\___/‾‾‾\___/‾‾‾\___/‾‾‾\___/
            // state  | IDLE  | START | READ  | START | READ  | START | IDLE
            // dma_bus_done           |   1   |   1   |   1   |   1   |
            if (running) begin
                case (state)
                IDLE :
                    if (allow_on) begin
                        if (lowprio_pending == 0) 
                            dma_init_cycles  <= 1;
                        state <= START;
                        last_state <= IDLE;
                    end
                
                START : begin
                    reg next_read;
                    next_read = last_state == IDLE;

                    if (last_state == READING) begin            // wait for writing finish to start next datum
                        dma_bus_dout_buf <= dma_bus_dout;
                        dmaout <= DMAOUT_BUF;
                        if (dmaout == DMAOUT_DIN || dmaout == DMAOUT_DIN_HI16 || dmaout == DMAOUT_DIN_LO16) begin
                            last_dma_valid <= 1;
                            last_dma_out   <= dma_bus_dout;
                        end

                        if (dma_bus_done) begin
                            dma_bus_ena <= 0;
                            if (count == 0) begin
                                state   <= IDLE;
                                last_state <= START;
                                running <= 0;
                                dmaon   <= 0;

                                irp_dma <= iRQ_on;

                                if (Repeat && start_timing != 0) begin
                                    waiting <= 1;
                                    if (start_timing == 3 && (index == 1 || index == 2))    // sound dma
                                        count <= 4;
                                    else begin
                                    
                                        if (index == 3) begin
                                            if (CNT_L[15:0] == 0) 
                                                count <= {1'b1, 16'h0000};
                                            else
                                                count <= {1'b0, CNT_L[15:0]};
                                        end else begin
                                            if (CNT_L[13:0] == 0) 
                                                count <= {1'b0, 16'h4000};
                                            else
                                                count <= {3'b000, CNT_L[13:0]};
                                        end
                                        
                                        if (dest_addr_control == 3) begin
                                            addr_target <= DAD[27:0];
                                            if (index < 3) begin
                                                addr_target[27] <= 0;
                                            end
                                        end
                                    end
                                end else
                                    enable <= 0;
                            end else
                                next_read = 1;         // continue to read next datum
                        end
                    end

                    // issue next read request
                    if (next_read && allow_on && !dma_init_cycles) begin
                        state <= READING;
                        dma_bus_rnw <= 1;       // read
                        dma_bus_ena <= 1;
                        if (Transfer_Type_DW) begin
                            dma_bus_adr <= {addr_source[27:2], 2'b0};
                            dma_bus_acc <= ACCESS_32BIT;
                        end else begin
                            dma_bus_adr <= {addr_source[27:1], 1'b0};
                            dma_bus_acc <= ACCESS_16BIT;
                        end  
                        // timing
                        count <= count - 1;
                        first <= 0;
                        dma_new_cycles   <= 1;
                        dma_first_cycles <= first;
                        dma_dword_cycles <= Transfer_Type_DW;
                        dma_cycles_adrup <= addr_source[27:24]; 
                        if (!addr_source[27] && addr_target[27]) begin
                            dma_torom <= 1;
                        end
                    end

                end
                    
                READING :
                    if (dma_bus_done) begin         // data is available next cycle
                        state <= START;
                        last_state <= READING;

                        // issue write request
                        dma_bus_rnw  <= 0;
                        dma_bus_ena  <= 1;
                        if (Transfer_Type_DW) 
                            dma_bus_adr <= {addr_target[27:2], 2'b00};
                        else
                            dma_bus_adr <= {addr_target[27:1], 1'b0};
                        
                        if (addr_source >= 'h200_0000 && !dma_bus_unread) begin
                            if (Transfer_Type_DW) begin
                                dmaout <= DMAOUT_DIN;
                                // dma_bus_dout   <= dma_bus_din;
                                // last_dma_out   <= dma_bus_din;
                            end else begin
                                dmaout <= addr_source[1] ? DMAOUT_DIN_HI16 : DMAOUT_DIN_LO16;
                                // dma_bus_dout   <= addr_source[1] ? 
                                //     {dma_bus_din[31:16], dma_bus_din[31:16]} :
                                //     {dma_bus_din[15:0], dma_bus_din[15:0]};
                                // last_dma_out   <= addr_source[1] ? 
                                //     {dma_bus_din[31:16], dma_bus_din[31:16]} :
                                //     {dma_bus_din[15:0], dma_bus_din[15:0]};
                            end
                        end else begin
                            dmaout <= DMAOUT_BUF;
                            if (Transfer_Type_DW)
                                dma_bus_dout_buf <= last_dma_in;
                                // dma_bus_dout <= last_dma_in;
                            else
                                dma_bus_dout_buf <= {last_dma_in[15:0], last_dma_in[15:0]};
                                // dma_bus_dout <= {last_dma_in[15:0], last_dma_in[15:0]};
                        end
                        
                        // next settings
                        if (Transfer_Type_DW) begin
                            if (source_addr_control == 0 || source_addr_control == 3 || (addr_source >= 'h8000000 && addr_source < 'hE000000))
                                addr_source <= addr_source + 4; 
                            else if (source_addr_control == 1) 
                                addr_source <= addr_source - 4;

                            if (dest_addr_control == 0 || (dest_addr_control == 3 && start_timing != 3))
                                addr_target <= addr_target + 4;
                            else if (dest_addr_control == 1)
                                addr_target <= addr_target - 4;
                        end else begin
                            if (source_addr_control == 0 || source_addr_control == 3 || (addr_source >= 'h8000000 && addr_source < 'hE000000))  
                                addr_source <= addr_source + 2; 
                            else if (source_addr_control == 1) 
                                addr_source <= addr_source - 2;

                            if (dest_addr_control == 0 || (dest_addr_control == 3 && start_timing != 3)) 
                                addr_target <= addr_target + 2;
                            else if (dest_addr_control == 1) 
                                addr_target <= addr_target - 2;
                        end
                        // timing
                        dma_new_cycles   <= 1;
                        dma_first_cycles <= first;
                        dma_dword_cycles <= Transfer_Type_DW;
                        dma_cycles_adrup <= addr_target[27:24];                        
                    end
                                       
                default: ;
                endcase
            end
        end
    end         
end

endmodule
`undef pproc_bus_gba