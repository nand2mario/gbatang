
module gba_timer(clk, gb_on, reset, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
            IRP_Timer, timer0_tick, timer1_tick, debugout0, debugout1, debugout2, debugout3);
    `include "pproc_bus_gba.sv"
    `include "preg_gba_timer.sv"
    parameter                 is_simu = 0;
    input                     clk;              // 16Mhz
    input                     gb_on;
    input                     reset;
    `GB_BUS_PORTS_DECL;
    output [3:0]              IRP_Timer;
    output                    timer0_tick;
    output                    timer1_tick;
    output [31:0]             debugout0;
    output [31:0]             debugout1;
    output [31:0]             debugout2;
    output [31:0]             debugout3;
    
    
    wire [3:0]                timerticks;
    
    assign timer0_tick = timerticks[0];
    assign timer1_tick = timerticks[1];
    
    
    gba_timer_module #(is_simu, 0, TM0CNT_L, TM0CNT_H_Prescaler, TM0CNT_H_Count_up, TM0CNT_H_Timer_IRQ_Enable, TM0CNT_H_Timer_Start_Stop) igba_timer_module0(
        .clk(clk),
        .gb_on(gb_on),
        .reset(reset),
        `GB_BUS_PORTS_INST,
        .countup_in(1'b0),
        .tick(timerticks[0]),
        .irp_timer(IRP_Timer[0]),
        .debugout(debugout0)
    );
    
    
    gba_timer_module #(is_simu, 1, TM1CNT_L, TM1CNT_H_Prescaler, TM1CNT_H_Count_up, TM1CNT_H_Timer_IRQ_Enable, TM1CNT_H_Timer_Start_Stop) igba_timer_module1(
        .clk(clk),
        .gb_on(gb_on),
        .reset(reset),
        `GB_BUS_PORTS_INST,
        .countup_in(timerticks[0]),
        .tick(timerticks[1]),
        .irp_timer(IRP_Timer[1]),
        .debugout(debugout1)
    );
    
    
    gba_timer_module #(is_simu, 2, TM2CNT_L, TM2CNT_H_Prescaler, TM2CNT_H_Count_up, TM2CNT_H_Timer_IRQ_Enable, TM2CNT_H_Timer_Start_Stop) igba_timer_module2(
        .clk(clk),
        .gb_on(gb_on),
        .reset(reset),
        `GB_BUS_PORTS_INST,
        .countup_in(timerticks[1]),
        .tick(timerticks[2]),
        .irp_timer(IRP_Timer[2]),
        .debugout(debugout2)
    );
    
    
    gba_timer_module #(is_simu, 3, TM3CNT_L, TM3CNT_H_Prescaler, TM3CNT_H_Count_up, TM3CNT_H_Timer_IRQ_Enable, TM3CNT_H_Timer_Start_Stop) igba_timer_module3(
        .clk(clk),
        .gb_on(gb_on),
        .reset(reset),
        `GB_BUS_PORTS_INST,
        .countup_in(timerticks[2]),
        .tick(timerticks[3]),
        .irp_timer(IRP_Timer[3]),
        .debugout(debugout3)
    );
    
endmodule
`undef preg_gba_timer
`undef pproc_bus_gba
