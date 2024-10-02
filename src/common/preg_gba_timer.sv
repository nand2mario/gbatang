
`ifndef preg_gba_timer
`define preg_gba_timer

`include "pproc_bus_gba.sv"

// range 0x100 -  0x110
//   (                                               adr      upper    lower    size   default   accesstype)                                     
localparam regmap_type TM0CNT_L                   = '{28'h100,  15,      0,        1,        0,   readwrite}; // Timer 0 Counter/Reload  2    R/W
localparam regmap_type TM0CNT_H                   = '{28'h100,  31,     16,        1,        0,   readwrite}; // Timer 0 Control         2    R/W
localparam regmap_type TM0CNT_H_Prescaler         = '{28'h100,  17,     16,        1,        0,   readwrite}; // Prescaler Selection (0=F/1, 1=F/64, 2=F/256, 3=F/1024)
localparam regmap_type TM0CNT_H_Count_up          = '{28'h100,  18,     18,        1,        0,   readwrite}; // Count-up Timing   (0=Normal, 1=See below)
localparam regmap_type TM0CNT_H_Timer_IRQ_Enable  = '{28'h100,  22,     22,        1,        0,   readwrite}; // Timer IRQ Enable  (0=Disable, 1=IRQ on Timer overflow)
localparam regmap_type TM0CNT_H_Timer_Start_Stop  = '{28'h100,  23,     23,        1,        0,   readwrite}; // Timer Start/Stop  (0=Stop, 1=Operate)

localparam regmap_type TM1CNT_L                   = '{28'h104,  15,      0,        1,        0,   readwrite}; // Timer 1 Counter/Reload  2    R/W
localparam regmap_type TM1CNT_H                   = '{28'h104,  31,     16,        1,        0,   readwrite}; // Timer 1 Control         2    R/W
localparam regmap_type TM1CNT_H_Prescaler         = '{28'h104,  17,     16,        1,        0,   readwrite}; // Prescaler Selection (0=F/1, 1=F/64, 2=F/256, 3=F/1024)
localparam regmap_type TM1CNT_H_Count_up          = '{28'h104,  18,     18,        1,        0,   readwrite}; // Count-up Timing   (0=Normal, 1=See below)
localparam regmap_type TM1CNT_H_Timer_IRQ_Enable  = '{28'h104,  22,     22,        1,        0,   readwrite}; // Timer IRQ Enable  (0=Disable, 1=IRQ on Timer overflow)
localparam regmap_type TM1CNT_H_Timer_Start_Stop  = '{28'h104,  23,     23,        1,        0,   readwrite}; // Timer Start/Stop  (0=Stop, 1=Operate)

localparam regmap_type TM2CNT_L                   = '{28'h108,  15,      0,        1,        0,   readwrite}; // Timer 2 Counter/Reload  2    R/W
localparam regmap_type TM2CNT_H                   = '{28'h108,  31,     16,        1,        0,   readwrite}; // Timer 2 Control         2    R/W
localparam regmap_type TM2CNT_H_Prescaler         = '{28'h108,  17,     16,        1,        0,   readwrite}; // Prescaler Selection (0=F/1, 1=F/64, 2=F/256, 3=F/1024)
localparam regmap_type TM2CNT_H_Count_up          = '{28'h108,  18,     18,        1,        0,   readwrite}; // Count-up Timing   (0=Normal, 1=See below)
localparam regmap_type TM2CNT_H_Timer_IRQ_Enable  = '{28'h108,  22,     22,        1,        0,   readwrite}; // Timer IRQ Enable  (0=Disable, 1=IRQ on Timer overflow)
localparam regmap_type TM2CNT_H_Timer_Start_Stop  = '{28'h108,  23,     23,        1,        0,   readwrite}; // Timer Start/Stop  (0=Stop, 1=Operate)

localparam regmap_type TM3CNT_L                   = '{28'h10C,  15,      0,        1,        0,   readwrite}; // Timer 3 Counter/Reload  2    R/W
localparam regmap_type TM3CNT_H                   = '{28'h10C,  31,     16,        1,        0,   readwrite}; // Timer 3 Control         2    R/W
localparam regmap_type TM3CNT_H_Prescaler         = '{28'h10C,  17,     16,        1,        0,   readwrite}; // Prescaler Selection (0=F/1, 1=F/64, 2=F/256, 3=F/1024)
localparam regmap_type TM3CNT_H_Count_up          = '{28'h10C,  18,     18,        1,        0,   readwrite}; // Count-up Timing   (0=Normal, 1=See below)
localparam regmap_type TM3CNT_H_Timer_IRQ_Enable  = '{28'h10C,  22,     22,        1,        0,   readwrite}; // Timer IRQ Enable  (0=Disable, 1=IRQ on Timer overflow)
localparam regmap_type TM3CNT_H_Timer_Start_Stop  = '{28'h10C,  23,     23,        1,        0,   readwrite}; // Timer Start/Stop  (0=Stop, 1=Operate)
   
`endif
