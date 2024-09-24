
module gba_timer_module(clk, gb_on, reset, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst,
        countup_in, tick, irp_timer, debugout);
    `include "pproc_bus_gba.sv"

    parameter     is_simu = 0;
    parameter     index = 0;
    parameter     regmap_type reg_l = '{0,0,0,0,0,0};
    parameter     regmap_type reg_h_prescaler = '{0,0,0,0,0,0};
    parameter     regmap_type reg_h_count_up = '{0,0,0,0,0,0};
    parameter     regmap_type reg_h_timer_irq_enable = '{0,0,0,0,0,0};
    parameter     regmap_type reg_h_timer_start_stop = '{0,0,0,0,0,0};

    input         clk;          // 16.7Mhz
    input         gb_on;
    input         reset;

    `GB_BUS_PORTS_DECL;    
    // inout proc_bus_gb_type gb_bus;
    
    // input [7:0]   new_cycles;
    // input         new_cycles_valid;
    input         countup_in;
    
    output reg    tick;
    output reg    irp_timer;
    
    output [31:0] debugout;
    
    
    wire [reg_l.upper:reg_l.lower]                                   L_Counter_Reload;
    wire [reg_h_prescaler.upper:reg_h_prescaler.lower]               H_Prescaler;
    wire [reg_h_count_up.upper:reg_h_count_up.lower]                 H_Count_up;
    wire [reg_h_timer_irq_enable.upper:reg_h_timer_irq_enable.lower] H_Timer_IRQ_Enable;
    // wire [reg_h_timer_start_stop.upper:reg_h_timer_start_stop.lower] H_Timer_Start_Stop;
    
    wire          H_Timer_Start_Stop_written;
    
    reg [15:0]    counter_readback;
    reg [15:0]    counter;
    reg [10:0]    prescalecounter;
    reg [10:0]    prescaleborder;
    reg           timer_on;
    
    eProcReg_gba #(reg_l) iL_Counter_Reload (clk, `GB_BUS_PORTS_LIST, counter_readback, L_Counter_Reload);
    eProcReg_gba #(reg_h_prescaler) iH_Prescaler(clk, `GB_BUS_PORTS_LIST, H_Prescaler, H_Prescaler);
    eProcReg_gba #(reg_h_count_up) iH_Count_up(clk, `GB_BUS_PORTS_LIST, H_Count_up, H_Count_up);
    eProcReg_gba #(reg_h_timer_irq_enable) iH_Timer_IRQ_Enable(clk, `GB_BUS_PORTS_LIST, H_Timer_IRQ_Enable, H_Timer_IRQ_Enable);
    // eProcReg_gba #(reg_h_timer_start_stop) iH_Timer_Start_Stop(clk, `GB_BUS_PORTS_LIST, H_Timer_Start_Stop, H_Timer_Start_Stop, H_Timer_Start_Stop_written);
    
    reg [31:0] reg_dout;
    reg reg_dout_en;
    assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};

    always @(posedge clk) begin
        reg_dout_en <= 0;
        if (gb_bus_ena && gb_bus_rnw) begin
            if (gb_bus_adr == reg_l.Adr) begin
                reg_dout <= {8'b0, timer_on, H_Timer_IRQ_Enable, 3'b0, H_Count_up, H_Prescaler, counter_readback};
                reg_dout_en <= 1;
            end
        end
    end

    assign debugout = {8'h00, timer_on, H_Timer_IRQ_Enable, 3'b000, H_Count_up, H_Prescaler, counter_readback};    
    
    always @(posedge clk) begin
        tick <= 1'b0;
        irp_timer <= 1'b0;
        
        if (reset) begin
            
            timer_on <= 0;
            counter <= 0;
            prescalecounter <= 0;
        
        end else if (gb_on) begin
            reg start_stop_written, start_stop;
            start_stop_written = 0;
            start_stop = 0;

            // start_stop_written = H_Timer_Start_Stop_written;
            // start_stop = H_Timer_Start_Stop;
            // 4000102h - TM0CNT_H - Timer 0 Control (R/W)
            //   7     Timer Start/Stop  (0=Stop, 1=Operate)
            if (gb_bus_ena & ~gb_bus_rnw & gb_bus_adr == reg_l.Adr & gb_bus_be[2]) begin
                start_stop_written = 1;
                start_stop = gb_bus_din[23];
            end

            // set_settings
            if (start_stop_written) begin
            // if (gb_bus_ena & ~gb_bus_rnw & gb_bus_adr == reg_l.Adr & gb_bus_be[2]) begin
                if (start_stop & ~timer_on) begin        // posedge timer_on
                // if (gb_bus_din[23] & ~timer_on) begin        // posedge timer_on
                    if (gb_bus_be[0])
                        counter <= gb_bus_din[15:0];
                    else
                        counter <= L_Counter_Reload;
                    prescalecounter <= {11{1'b0}};
                end 
                timer_on <= start_stop;
            end 
            
            case (H_Prescaler)
                0 : prescaleborder <= 1;
                1 : prescaleborder <= 64;
                2 : prescaleborder <= 256;
                3 : prescaleborder <= 1024;
                default : ;
            endcase
            
            // work
            if (timer_on) begin
                reg [15:0] counter_next;
                reg increment;
                counter_next = counter;
                increment = 0;

                if (H_Count_up & countup_in) begin
                    counter_next++;
                    increment = 1;
                end
                
                if (~H_Count_up| index == 0) begin
                    if (H_Prescaler == 2'b00) begin
                        counter_next++;
                        increment = 1;
                    end else begin
                        prescalecounter <= prescalecounter + 1;
                        if (prescalecounter >= prescaleborder-1) begin
                            prescalecounter <= 0;
                            counter_next = counter + 1;
                            increment = 1;
                        end 
                    end
                end

                // send tick or irp when overflow
                if (increment && counter == 16'hffff) begin         
                    counter <= L_Counter_Reload;
                    tick <= 1'b1;
                    if (H_Timer_IRQ_Enable)
                        irp_timer <= 1'b1;
                end else
                    counter <= counter_next;
            end 
        end 
        
        counter_readback <= counter[15:0];
    end 
    
endmodule
`undef pproc_bus_gba
