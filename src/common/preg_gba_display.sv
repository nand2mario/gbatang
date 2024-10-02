
`ifndef preg_gba_display
`define preg_gba_display

`include "pproc_bus_gba.sv"

// range 0x00 .. 0x56
//   (                                                  adr    upper lower size default accesstype)                                                     
localparam regmap_type DISPCNT                       = '{28'h000,  15,  0,  1,'h0080, readwrite}; // LCD Control                                   2    R/W   
localparam regmap_type DISPCNT_BG_Mode               = '{28'h000,   2,  0,  1,     0, readwrite}; // BG Mode                     (0-5=Video Mode 0-5, 6-7=Prohibited)
localparam regmap_type DISPCNT_Reserved_CGB_Mode     = '{28'h000,   3,  3,  1,     0, readwrite}; // Reserved / CGB Mode         (0=GBA, 1=CGB; can be set only by BIOS opcodes)
localparam regmap_type DISPCNT_Display_Frame_Select  = '{28'h000,   4,  4,  1,     0, readwrite}; // Display Frame Select        (0-1=Frame 0-1) (for BG Modes 4,5 only)
localparam regmap_type DISPCNT_H_Blank_IntervalFree  = '{28'h000,   5,  5,  1,     0, readwrite}; // H-Blank Interval Free       (1=Allow access to OAM during H-Blank)
localparam regmap_type DISPCNT_OBJ_Char_VRAM_Map     = '{28'h000,   6,  6,  1,     0, readwrite}; // OBJ Character VRAM Mapping  (0=Two dimensional, 1=One dimensional)
localparam regmap_type DISPCNT_Forced_Blank          = '{28'h000,   7,  7,  1,     1, readwrite}; // Forced Blank                (1=Allow FAST access to VRAM,Palette,OAM)
localparam regmap_type DISPCNT_Screen_Display_BG0    = '{28'h000,   8,  8,  1,     0, readwrite}; // Screen Display BG0          (0=Off, 1=On)
localparam regmap_type DISPCNT_Screen_Display_BG1    = '{28'h000,   9,  9,  1,     0, readwrite}; // Screen Display BG1          (0=Off, 1=On)
localparam regmap_type DISPCNT_Screen_Display_BG2    = '{28'h000,  10, 10,  1,     0, readwrite}; // Screen Display BG2          (0=Off, 1=On)
localparam regmap_type DISPCNT_Screen_Display_BG3    = '{28'h000,  11, 11,  1,     0, readwrite}; // Screen Display BG3          (0=Off, 1=On)
localparam regmap_type DISPCNT_Screen_Display_OBJ    = '{28'h000,  12, 12,  1,     0, readwrite}; // Screen Display OBJ          (0=Off, 1=On)
localparam regmap_type DISPCNT_Window_0_Display_Flag = '{28'h000,  13, 13,  1,     0, readwrite}; // Window 0 Display Flag       (0=Off, 1=On)
localparam regmap_type DISPCNT_Window_1_Display_Flag = '{28'h000,  14, 14,  1,     0, readwrite}; // Window 1 Display Flag       (0=Off, 1=On)
localparam regmap_type DISPCNT_OBJ_Wnd_Display_Flag  = '{28'h000,  15, 15,  1,     0, readwrite}; // OBJ Window Display Flag     (0=Off, 1=On)

localparam regmap_type GREENSWAP                     = '{28'h000,  31, 16,  1,     0, readwrite}; // Undocumented - Green Swap                     2    R/W

localparam regmap_type DISPSTAT                      = '{28'h004,  15,  0,  1,     0, readwrite}; // General LCD Status (STAT,LYC)                 2    R/W
localparam regmap_type DISPSTAT_V_Blank_flag         = '{28'h004,   0,  0,  1,     0, readonly }; // V-Blank flag   (Read only) (1=VBlank) (set in line 160..226; not 227)
localparam regmap_type DISPSTAT_H_Blank_flag         = '{28'h004,   1,  1,  1,     0, readonly }; // H-Blank flag   (Read only) (1=HBlank) (toggled in all lines, 0..227)
localparam regmap_type DISPSTAT_V_Counter_flag       = '{28'h004,   2,  2,  1,     0, readonly }; // V-Counter flag (Read only) (1=Match)  (set in selected line)     (R)
localparam regmap_type DISPSTAT_V_Blank_IRQ_Enable   = '{28'h004,   3,  3,  1,     0, readwrite}; // V-Blank IRQ Enable         (1=Enable)                          (R/W)
localparam regmap_type DISPSTAT_H_Blank_IRQ_Enable   = '{28'h004,   4,  4,  1,     0, readwrite}; // H-Blank IRQ Enable         (1=Enable)                          (R/W)
localparam regmap_type DISPSTAT_V_Counter_IRQ_Enable = '{28'h004,   5,  5,  1,     0, readwrite}; // V-Counter IRQ Enable       (1=Enable)                          (R/W)
                                                                                                 // Not used (0) / DSi: LCD Initialization Ready (0=Busy, 1=Ready)   (R)
                                                                                                 // Not used (0) / NDS: MSB of V-Vcount Setting (LYC.Bit8) (0..262)(R/W)
localparam regmap_type DISPSTAT_V_Count_Setting      = '{28'h004,  15,  8,  1,     0, readwrite}; // V-Count Setting (LYC)      (0..227)                            (R/W)

localparam regmap_type VCOUNT                        = '{28'h004,  31, 16,  1,     0, readonly }; // Vertical Counter (LY)                         2    R  

localparam regmap_type BG0CNT                        = '{28'h008,  15,  0,  1,     0, writeonly}; // BG0 Control                                   2    R/W
localparam regmap_type BG0CNT_BG_Priority            = '{28'h008,   1,  0,  1,     0, readwrite}; // BG Priority           (0-3, 0=Highest)
localparam regmap_type BG0CNT_Character_Base_Block   = '{28'h008,   3,  2,  1,     0, readwrite}; // Character Base Block  (0-3, in units of 16 KBytes) (=BG Tile Data)
localparam regmap_type BG0CNT_UNUSED_4_5             = '{28'h008,   5,  4,  1,     0, readwrite}; // 4-5   Not used (must be zero)
localparam regmap_type BG0CNT_Mosaic                 = '{28'h008,   6,  6,  1,     0, readwrite}; // Mosaic                (0=Disable, 1=Enable)
localparam regmap_type BG0CNT_Colors_Palettes        = '{28'h008,   7,  7,  1,     0, readwrite}; // Colors/Palettes       (0=16/16, 1=256/1)
localparam regmap_type BG0CNT_Screen_Base_Block      = '{28'h008,  12,  8,  1,     0, readwrite}; // Screen Base Block     (0-31, in units of 2 KBytes) (=BG Map Data)
localparam regmap_type BG0CNT_Screen_Size            = '{28'h008,  15, 14,  1,     0, readwrite}; // Screen Size (0-3)

localparam regmap_type BG1CNT                        = '{28'h008,  31, 16,  1,     0, writeonly}; // BG1 Control                                   2    R/W
localparam regmap_type BG1CNT_BG_Priority            = '{28'h008,  17, 16,  1,     0, readwrite}; // BG Priority           (0-3, 0=Highest)
localparam regmap_type BG1CNT_Character_Base_Block   = '{28'h008,  19, 18,  1,     0, readwrite}; // Character Base Block  (0-3, in units of 16 KBytes) (=BG Tile Data)
localparam regmap_type BG1CNT_UNUSED_4_5             = '{28'h008,  21, 20,  1,     0, readwrite}; // 4-5   Not used (must be zero)
localparam regmap_type BG1CNT_Mosaic                 = '{28'h008,  22, 22,  1,     0, readwrite}; // Mosaic                (0=Disable, 1=Enable)
localparam regmap_type BG1CNT_Colors_Palettes        = '{28'h008,  23, 23,  1,     0, readwrite}; // Colors/Palettes       (0=16/16, 1=256/1)
localparam regmap_type BG1CNT_Screen_Base_Block      = '{28'h008,  28, 24,  1,     0, readwrite}; // Screen Base Block     (0-31, in units of 2 KBytes) (=BG Map Data)
localparam regmap_type BG1CNT_Screen_Size            = '{28'h008,  31, 30,  1,     0, readwrite}; // Screen Size (0-3)

localparam regmap_type BG2CNT                        = '{28'h00C,  15,  0,  1,     0, readwrite}; // BG2 Control                                   2    R/W
localparam regmap_type BG2CNT_BG_Priority            = '{28'h00C,   1,  0,  1,     0, readwrite}; // BG Priority           (0-3, 0=Highest)
localparam regmap_type BG2CNT_Character_Base_Block   = '{28'h00C,   3,  2,  1,     0, readwrite}; // Character Base Block  (0-3, in units of 16 KBytes) (=BG Tile Data)
localparam regmap_type BG2CNT_UNUSED_4_5             = '{28'h00C,   5,  4,  1,     0, readwrite}; // 4-5   Not used (must be zero)
localparam regmap_type BG2CNT_Mosaic                 = '{28'h00C,   6,  6,  1,     0, readwrite}; // Mosaic                (0=Disable, 1=Enable)
localparam regmap_type BG2CNT_Colors_Palettes        = '{28'h00C,   7,  7,  1,     0, readwrite}; // Colors/Palettes       (0=16/16, 1=256/1)
localparam regmap_type BG2CNT_Screen_Base_Block      = '{28'h00C,  12,  8,  1,     0, readwrite}; // Screen Base Block     (0-31, in units of 2 KBytes) (=BG Map Data)
localparam regmap_type BG2CNT_Display_Area_Overflow  = '{28'h00C,  13, 13,  1,     0, readwrite}; // Display Area Overflow (0=Transparent, 1=Wraparound; BG2CNT/BG3CNT only)
localparam regmap_type BG2CNT_Screen_Size            = '{28'h00C,  15, 14,  1,     0, readwrite}; // Screen Size (0-3)

localparam regmap_type BG3CNT                        = '{28'h00C,  31, 16,  1,     0, readwrite}; // BG3 Control                                   2    R/W
localparam regmap_type BG3CNT_BG_Priority            = '{28'h00C,  17, 16,  1,     0, readwrite}; // BG Priority           (0-3, 0=Highest)
localparam regmap_type BG3CNT_Character_Base_Block   = '{28'h00C,  19, 18,  1,     0, readwrite}; // Character Base Block  (0-3, in units of 16 KBytes) (=BG Tile Data)
localparam regmap_type BG3CNT_UNUSED_4_5             = '{28'h00C,  21, 20,  1,     0, readwrite}; // 4-5   Not used (must be zero)
localparam regmap_type BG3CNT_Mosaic                 = '{28'h00C,  22, 22,  1,     0, readwrite}; // Mosaic                (0=Disable, 1=Enable)
localparam regmap_type BG3CNT_Colors_Palettes        = '{28'h00C,  23, 23,  1,     0, readwrite}; // Colors/Palettes       (0=16/16, 1=256/1)
localparam regmap_type BG3CNT_Screen_Base_Block      = '{28'h00C,  28, 24,  1,     0, readwrite}; // Screen Base Block     (0-31, in units of 2 KBytes) (=BG Map Data)
localparam regmap_type BG3CNT_Display_Area_Overflow  = '{28'h00C,  29, 29,  1,     0, readwrite}; // Display Area Overflow (0=Transparent, 1=Wraparound; BG2CNT/BG3CNT only)
localparam regmap_type BG3CNT_Screen_Size            = '{28'h00C,  31, 30,  1,     0, readwrite}; // Screen Size (0-3)

localparam regmap_type BG0HOFS                       = '{28'h010,  15,  0,  1,     0, writeonly}; // BG0 X-Offset                                  2    W  
localparam regmap_type BG0VOFS                       = '{28'h010,  31, 16,  1,     0, writeonly}; // BG0 Y-Offset                                  2    W  
localparam regmap_type BG1HOFS                       = '{28'h014,  15,  0,  1,     0, writeonly}; // BG1 X-Offset                                  2    W  
localparam regmap_type BG1VOFS                       = '{28'h014,  31, 16,  1,     0, writeonly}; // BG1 Y-Offset                                  2    W  
localparam regmap_type BG2HOFS                       = '{28'h018,  15,  0,  1,     0, writeonly}; // BG2 X-Offset                                  2    W  
localparam regmap_type BG2VOFS                       = '{28'h018,  31, 16,  1,     0, writeonly}; // BG2 Y-Offset                                  2    W  
localparam regmap_type BG3HOFS                       = '{28'h01C,  15,  0,  1,     0, writeonly}; // BG3 X-Offset                                  2    W  
localparam regmap_type BG3VOFS                       = '{28'h01C,  31, 16,  1,     0, writeonly}; // BG3 Y-Offset                                  2    W  

localparam regmap_type BG2RotScaleParDX              = '{28'h020,  15,  0,  1,   256, writeonly}; // BG2 Rotation/Scaling localparam regmap_type A (dx)         2    W  
localparam regmap_type BG2RotScaleParDMX             = '{28'h020,  31, 16,  1,     0, writeonly}; // BG2 Rotation/Scaling localparam regmap_type B (dmx)        2    W  
localparam regmap_type BG2RotScaleParDY              = '{28'h024,  15,  0,  1,     0, writeonly}; // BG2 Rotation/Scaling localparam regmap_type C (dy)         2    W  
localparam regmap_type BG2RotScaleParDMY             = '{28'h024,  31, 16,  1,   256, writeonly}; // BG2 Rotation/Scaling localparam regmap_type D (dmy)        2    W  
localparam regmap_type BG2RefX                       = '{28'h028,  27,  0,  1,     0, writeonly}; // BG2 Reference Point X-Coordinate              4    W  
localparam regmap_type BG2RefY                       = '{28'h02C,  27,  0,  1,     0, writeonly}; // BG2 Reference Point Y-Coordinate              4    W  

localparam regmap_type BG3RotScaleParDX              = '{28'h030,  15,  0,  1,   256, writeonly}; // BG3 Rotation/Scaling localparam regmap_type A (dx)         2    W  
localparam regmap_type BG3RotScaleParDMX             = '{28'h030,  31, 16,  1,     0, writeonly}; // BG3 Rotation/Scaling localparam regmap_type B (dmx)        2    W  
localparam regmap_type BG3RotScaleParDY              = '{28'h034,  15,  0,  1,     0, writeonly}; // BG3 Rotation/Scaling localparam regmap_type C (dy)         2    W  
localparam regmap_type BG3RotScaleParDMY             = '{28'h034,  31, 16,  1,   256, writeonly}; // BG3 Rotation/Scaling localparam regmap_type D (dmy)        2    W  
localparam regmap_type BG3RefX                       = '{28'h038,  27,  0,  1,     0, writeonly}; // BG3 Reference Point X-Coordinate              4    W  
localparam regmap_type BG3RefY                       = '{28'h03C,  27,  0,  1,     0, writeonly}; // BG3 Reference Point Y-Coordinate              4    W  

localparam regmap_type WIN0H                         = '{28'h040,  15,  0,  1,     0, writeonly}; // Window 0 Horizontal Dimensions                2    W  
localparam regmap_type WIN0H_X2                      = '{28'h040,   7,  0,  1,     0, writeonly}; // Window 0 Horizontal Dimensions                2    W  
localparam regmap_type WIN0H_X1                      = '{28'h040,  15,  8,  1,     0, writeonly}; // Window 0 Horizontal Dimensions                2    W  

localparam regmap_type WIN1H                         = '{28'h040,  31, 16,  1,     0, writeonly}; // Window 1 Horizontal Dimensions                2    W  
localparam regmap_type WIN1H_X2                      = '{28'h040,  23, 16,  1,     0, writeonly}; // Window 1 Horizontal Dimensions                2    W  
localparam regmap_type WIN1H_X1                      = '{28'h040,  31, 24,  1,     0, writeonly}; // Window 1 Horizontal Dimensions                2    W  

localparam regmap_type WIN0V                         = '{28'h044,  15,  0,  1,     0, writeonly}; // Window 0 Vertical Dimensions                  2    W  
localparam regmap_type WIN0V_Y2                      = '{28'h044,   7,  0,  1,     0, writeonly}; // Window 0 Vertical Dimensions                  2    W  
localparam regmap_type WIN0V_Y1                      = '{28'h044,  15,  8,  1,     0, writeonly}; // Window 0 Vertical Dimensions                  2    W  
                                                                    
localparam regmap_type WIN1V                         = '{28'h044,  31, 16,  1,     0, writeonly}; // Window 1 Vertical Dimensions                  2    W  
localparam regmap_type WIN1V_Y2                      = '{28'h044,  23, 16,  1,     0, writeonly}; // Window 1 Vertical Dimensions                  2    W  
localparam regmap_type WIN1V_Y1                      = '{28'h044,  31, 24,  1,     0, writeonly}; // Window 1 Vertical Dimensions                  2    W  

localparam regmap_type WININ                         = '{28'h048,  15,  0,  1,     0, writeonly}; // Inside of Window 0 and 1                      2    R/W
localparam regmap_type WININ_Window_0_BG0_Enable     = '{28'h048,   0,  0,  1,     0, readwrite}; // 0-3   Window_0_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WININ_Window_0_BG1_Enable     = '{28'h048,   1,  1,  1,     0, readwrite}; // 0-3   Window_0_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WININ_Window_0_BG2_Enable     = '{28'h048,   2,  2,  1,     0, readwrite}; // 0-3   Window_0_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WININ_Window_0_BG3_Enable     = '{28'h048,   3,  3,  1,     0, readwrite}; // 0-3   Window_0_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WININ_Window_0_OBJ_Enable     = '{28'h048,   4,  4,  1,     0, readwrite}; // 4     Window_0_OBJ_Enable         (0=No Display, 1=Display)
localparam regmap_type WININ_Window_0_Special_Effect = '{28'h048,   5,  5,  1,     0, readwrite}; // 5     Window_0_Special_Effect     (0=Disable, 1=Enable)
localparam regmap_type WININ_Window_1_BG0_Enable     = '{28'h048,   8,  8,  1,     0, readwrite}; // 8-11  Window_1_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WININ_Window_1_BG1_Enable     = '{28'h048,   9,  9,  1,     0, readwrite}; // 8-11  Window_1_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WININ_Window_1_BG2_Enable     = '{28'h048,  10, 10,  1,     0, readwrite}; // 8-11  Window_1_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WININ_Window_1_BG3_Enable     = '{28'h048,  11, 11,  1,     0, readwrite}; // 8-11  Window_1_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WININ_Window_1_OBJ_Enable     = '{28'h048,  12, 12,  1,     0, readwrite}; // 12    Window_1_OBJ_Enable         (0=No Display, 1=Display)
localparam regmap_type WININ_Window_1_Special_Effect = '{28'h048,  13, 13,  1,     0, readwrite}; // 13    Window_1_Special_Effect     (0=Disable, 1=Enable)

localparam regmap_type WINOUT                        = '{28'h048,  31, 16,  1,     0, writeonly}; // Inside of OBJ Window & Outside of Windows     2    R/W
localparam regmap_type WINOUT_Outside_BG0_Enable     = '{28'h048,  16, 16,  1,     0, readwrite}; // 0-3   Outside_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WINOUT_Outside_BG1_Enable     = '{28'h048,  17, 17,  1,     0, readwrite}; // 0-3   Outside_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WINOUT_Outside_BG2_Enable     = '{28'h048,  18, 18,  1,     0, readwrite}; // 0-3   Outside_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WINOUT_Outside_BG3_Enable     = '{28'h048,  19, 19,  1,     0, readwrite}; // 0-3   Outside_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WINOUT_Outside_OBJ_Enable     = '{28'h048,  20, 20,  1,     0, readwrite}; // 4     Outside_OBJ_Enable         (0=No Display, 1=Display)
localparam regmap_type WINOUT_Outside_Special_Effect = '{28'h048,  21, 21,  1,     0, readwrite}; // 5     Outside_Special_Effect     (0=Disable, 1=Enable)
localparam regmap_type WINOUT_Objwnd_BG0_Enable      = '{28'h048,  24, 24,  1,     0, readwrite}; // 8-11  object window_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WINOUT_Objwnd_BG1_Enable      = '{28'h048,  25, 25,  1,     0, readwrite}; // 8-11  object window_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WINOUT_Objwnd_BG2_Enable      = '{28'h048,  26, 26,  1,     0, readwrite}; // 8-11  object window_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WINOUT_Objwnd_BG3_Enable      = '{28'h048,  27, 27,  1,     0, readwrite}; // 8-11  object window_BG0_BG3_Enable     (0=No Display, 1=Display)
localparam regmap_type WINOUT_Objwnd_OBJ_Enable      = '{28'h048,  28, 28,  1,     0, readwrite}; // 12    object window_OBJ_Enable         (0=No Display, 1=Display)
localparam regmap_type WINOUT_Objwnd_Special_Effect  = '{28'h048,  29, 29,  1,     0, readwrite}; // 13    object window_Special_Effect     (0=Disable, 1=Enable)

localparam regmap_type MOSAIC                        = '{28'h04C,  15,  0,  1,     0, writeonly}; // Mosaic Size                                   2    W  
localparam regmap_type MOSAIC_BG_Mosaic_H_Size       = '{28'h04C,   3,  0,  1,     0, writeonly}; //   0-3   BG_Mosaic_H_Size  (minus 1)  
localparam regmap_type MOSAIC_BG_Mosaic_V_Size       = '{28'h04C,   7,  4,  1,     0, writeonly}; //   4-7   BG_Mosaic_V_Size  (minus 1)  
localparam regmap_type MOSAIC_OBJ_Mosaic_H_Size      = '{28'h04C,  11,  8,  1,     0, writeonly}; //   8-11  OBJ_Mosaic_H_Size (minus 1)  
localparam regmap_type MOSAIC_OBJ_Mosaic_V_Size      = '{28'h04C,  15, 12,  1,     0, writeonly}; //   12-15 OBJ_Mosaic_V_Size (minus 1)  
                            
localparam regmap_type BLDCNT                        = '{28'h050,  13,  0,  1,     0, readwrite}; // Color Special Effects Selection               2    R/W
localparam regmap_type BLDCNT_BG0_1st_Target_Pixel   = '{28'h050,   0,  0,  1,     0, readwrite}; // 0      (Background 0)
localparam regmap_type BLDCNT_BG1_1st_Target_Pixel   = '{28'h050,   1,  1,  1,     0, readwrite}; // 1      (Background 1)
localparam regmap_type BLDCNT_BG2_1st_Target_Pixel   = '{28'h050,   2,  2,  1,     0, readwrite}; // 2      (Background 2)
localparam regmap_type BLDCNT_BG3_1st_Target_Pixel   = '{28'h050,   3,  3,  1,     0, readwrite}; // 3      (Background 3)
localparam regmap_type BLDCNT_OBJ_1st_Target_Pixel   = '{28'h050,   4,  4,  1,     0, readwrite}; // 4      (Top-most OBJ pixel)
localparam regmap_type BLDCNT_BD_1st_Target_Pixel    = '{28'h050,   5,  5,  1,     0, readwrite}; // 5      (Backdrop)
localparam regmap_type BLDCNT_Color_Special_Effect   = '{28'h050,   7,  6,  1,     0, readwrite}; // 6-7    (0-3, see below) 0 = None (Special effects disabled), 1 = Alpha Blending (1st+2nd Target mixed), 2 = Brightness Increase (1st Target becomes whiter), 3 = Brightness Decrease (1st Target becomes blacker)
localparam regmap_type BLDCNT_BG0_2nd_Target_Pixel   = '{28'h050,   8,  8,  1,     0, readwrite}; // 8      (Background 0)
localparam regmap_type BLDCNT_BG1_2nd_Target_Pixel   = '{28'h050,   9,  9,  1,     0, readwrite}; // 9      (Background 1)
localparam regmap_type BLDCNT_BG2_2nd_Target_Pixel   = '{28'h050,  10, 10,  1,     0, readwrite}; // 10     (Background 2)
localparam regmap_type BLDCNT_BG3_2nd_Target_Pixel   = '{28'h050,  11, 11,  1,     0, readwrite}; // 11     (Background 3)
localparam regmap_type BLDCNT_OBJ_2nd_Target_Pixel   = '{28'h050,  12, 12,  1,     0, readwrite}; // 12     (Top-most OBJ pixel)
localparam regmap_type BLDCNT_BD_2nd_Target_Pixel    = '{28'h050,  13, 13,  1,     0, readwrite}; // 13     (Backdrop)

localparam regmap_type BLDALPHA                      = '{28'h050,  28, 16,  1,     0, writeonly}; // Alpha Blending Coefficients                   2    W  
localparam regmap_type BLDALPHA_EVA_Coefficient      = '{28'h050,  20, 16,  1,     0, readwrite}; // 0-4   (1st Target) (0..16 = 0/16..16/16, 17..31=16/16)
localparam regmap_type BLDALPHA_EVB_Coefficient      = '{28'h050,  28, 24,  1,     0, readwrite}; // 8-12  (2nd Target) (0..16 = 0/16..16/16, 17..31=16/16)

localparam regmap_type BLDY                          = '{28'h054,   4,  0,  1,     0, writeonly}; // Brightness (Fade-In/Out) Coefficient  0-4   EVY Coefficient (Brightness) (0..16 = 0/16..16/16, 17..31=16/16 

`endif
