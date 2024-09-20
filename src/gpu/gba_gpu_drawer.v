module gba_gpu_drawer(fclk, mclk, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
        lockspeed, interframe_blend, maxpixels, hdmode2x_bg, hdmode2x_obj, bitmapdrawmode, vram_block_mode, pixel_out_x, pixel_out_2x, pixel_out_y, pixel_out_addr, pixel_out_data, pixel_out_we, pixel2_out_x, pixel2_out_data, pixel2_out_we, linecounter, pixelpos, drawline, refpoint_update, hblank_trigger, vblank_trigger, line_trigger, newline_invsync, VRAM_Lo_addr, VRAM_Lo_datain, VRAM_Lo_dataout, VRAM_Lo_we, VRAM_Lo_be, VRAM_Hi_addr, VRAM_Hi_datain, VRAM_Hi_dataout, VRAM_Hi_we, VRAM_Hi_be, OAMRAM_PROC_addr, OAMRAM_PROC_datain, OAMRAM_PROC_dataout, OAMRAM_PROC_we, PALETTE_BG_addr, PALETTE_BG_datain, PALETTE_BG_dataout, PALETTE_BG_we, PALETTE_OAM_addr, PALETTE_OAM_datain, PALETTE_OAM_dataout, PALETTE_OAM_we);
    `include "pproc_bus_gba.sv"
    `include "preg_gba_display.sv"
    parameter               is_simu = 0;
    input                   fclk;
    input                   mclk;
    
    `GB_BUS_PORTS_DECL;
    
    input                   lockspeed;
    input [1:0]             interframe_blend;
    input                   maxpixels;
    input                   hdmode2x_bg;
    input                   hdmode2x_obj;
    
    output reg              bitmapdrawmode;
    output reg              vram_block_mode;
    
    // video output
    output reg [7:0]        pixel_out_x;
    output reg [8:0]        pixel_out_2x;
    output reg [7:0]        pixel_out_y;
    output reg [15:0]       pixel_out_addr;
    output reg [14:0]       pixel_out_data;     // Format is RGB5
    output reg              pixel_out_we;
    
    output reg [8:0]        pixel2_out_x;
    output reg [14:0]       pixel2_out_data;
    output reg              pixel2_out_we;
    
    // timing signals from gba_gpu_timing
    input [7:0]             linecounter;            
    input [8:0]             pixelpos;
    input                   drawline;
    input                   refpoint_update;
    input                   hblank_trigger;
    input                   vblank_trigger;
    input                   line_trigger;
    input                   newline_invsync;
    
    // VRAM/OAM/PALETTE ram access lines from CPU
    input [13:0]            VRAM_Lo_addr;
    input [31:0]            VRAM_Lo_datain;
    output [31:0]           VRAM_Lo_dataout;
    input                   VRAM_Lo_we;
    input [3:0]             VRAM_Lo_be;
    input [12:0]            VRAM_Hi_addr;
    input [31:0]            VRAM_Hi_datain;
    output [31:0]           VRAM_Hi_dataout;
    input                   VRAM_Hi_we;
    input [3:0]             VRAM_Hi_be;
    
    input [7:0]             OAMRAM_PROC_addr;
    input [31:0]            OAMRAM_PROC_datain;
    output [31:0]           OAMRAM_PROC_dataout;
    input [3:0]             OAMRAM_PROC_we;
    
    input [7:0]             PALETTE_BG_addr;
    input [31:0]            PALETTE_BG_datain;
    output [31:0]           PALETTE_BG_dataout;
    input [3:0]             PALETTE_BG_we;
    input [7:0]             PALETTE_OAM_addr;
    input [31:0]            PALETTE_OAM_datain;
    output [31:0]           PALETTE_OAM_dataout;
    input [3:0]             PALETTE_OAM_we;
    
    
    wire [DISPCNT_BG_Mode.upper:DISPCNT_BG_Mode.lower]                             BG_Mode;
    wire [DISPCNT_Reserved_CGB_Mode.upper:DISPCNT_Reserved_CGB_Mode.lower]         REG_DISPCNT_Reserved_CGB_Mode;
    wire [DISPCNT_Display_Frame_Select.upper:DISPCNT_Display_Frame_Select.lower]   REG_DISPCNT_Display_Frame_Select;
    wire [DISPCNT_H_Blank_IntervalFree.upper:DISPCNT_H_Blank_IntervalFree.lower]   REG_DISPCNT_H_Blank_IntervalFree;
    wire [DISPCNT_OBJ_Char_VRAM_Map.upper:DISPCNT_OBJ_Char_VRAM_Map.lower]         REG_DISPCNT_OBJ_Char_VRAM_Map /* verilator public */;
    wire [DISPCNT_Forced_Blank.upper:DISPCNT_Forced_Blank.lower]                   Forced_Blank;
    wire [DISPCNT_Screen_Display_BG0.upper:DISPCNT_Screen_Display_BG0.lower]       Screen_Display_BG0;
    wire [DISPCNT_Screen_Display_BG1.upper:DISPCNT_Screen_Display_BG1.lower]       Screen_Display_BG1;
    wire [DISPCNT_Screen_Display_BG2.upper:DISPCNT_Screen_Display_BG2.lower]       Screen_Display_BG2;
    wire [DISPCNT_Screen_Display_BG3.upper:DISPCNT_Screen_Display_BG3.lower]       Screen_Display_BG3;
    wire [DISPCNT_Screen_Display_OBJ.upper:DISPCNT_Screen_Display_OBJ.lower]       Screen_Display_OBJ;
    wire [DISPCNT_Window_0_Display_Flag.upper:DISPCNT_Window_0_Display_Flag.lower] REG_DISPCNT_Window_0_Display_Flag;
    wire [DISPCNT_Window_1_Display_Flag.upper:DISPCNT_Window_1_Display_Flag.lower] REG_DISPCNT_Window_1_Display_Flag;
    wire [DISPCNT_OBJ_Wnd_Display_Flag.upper:DISPCNT_OBJ_Wnd_Display_Flag.lower]   REG_DISPCNT_OBJ_Wnd_Display_Flag;
    wire [GREENSWAP.upper:GREENSWAP.lower]                                         REG_GREENSWAP;
    
    wire [BG0CNT_BG_Priority.upper:BG0CNT_BG_Priority.lower]                       REG_BG0CNT_BG_Priority;
    wire [BG0CNT_Character_Base_Block.upper:BG0CNT_Character_Base_Block.lower]     REG_BG0CNT_Character_Base_Block  /* verilator public */;
    wire [BG0CNT_UNUSED_4_5.upper:BG0CNT_UNUSED_4_5.lower]                         REG_BG0CNT_UNUSED_4_5;
    wire [BG0CNT_Mosaic.upper:BG0CNT_Mosaic.lower]                                 REG_BG0CNT_Mosaic;
    wire [BG0CNT_Colors_Palettes.upper:BG0CNT_Colors_Palettes.lower]               REG_BG0CNT_Colors_Palettes /* verilator public */;
    wire [BG0CNT_Screen_Base_Block.upper:BG0CNT_Screen_Base_Block.lower]           REG_BG0CNT_Screen_Base_Block  /* verilator public */;
    wire [BG0CNT_Screen_Size.upper:BG0CNT_Screen_Size.lower]                       REG_BG0CNT_Screen_Size  /* verilator public */;
    
    wire [BG1CNT_BG_Priority.upper:BG1CNT_BG_Priority.lower]                       REG_BG1CNT_BG_Priority;
    wire [BG1CNT_Character_Base_Block.upper:BG1CNT_Character_Base_Block.lower]     REG_BG1CNT_Character_Base_Block /* verilator public */;
    wire [BG1CNT_UNUSED_4_5.upper:BG1CNT_UNUSED_4_5.lower]                         REG_BG1CNT_UNUSED_4_5;
    wire [BG1CNT_Mosaic.upper:BG1CNT_Mosaic.lower]                                 REG_BG1CNT_Mosaic;
    wire [BG1CNT_Colors_Palettes.upper:BG1CNT_Colors_Palettes.lower]               REG_BG1CNT_Colors_Palettes /* verilator public */;
    wire [BG1CNT_Screen_Base_Block.upper:BG1CNT_Screen_Base_Block.lower]           REG_BG1CNT_Screen_Base_Block /* verilator public */;
    wire [BG1CNT_Screen_Size.upper:BG1CNT_Screen_Size.lower]                       REG_BG1CNT_Screen_Size /* verilator public */;
    
    wire [BG2CNT_BG_Priority.upper:BG2CNT_BG_Priority.lower]                       REG_BG2CNT_BG_Priority;
    wire [BG2CNT_Character_Base_Block.upper:BG2CNT_Character_Base_Block.lower]     REG_BG2CNT_Character_Base_Block /* verilator public */;
    wire [BG2CNT_UNUSED_4_5.upper:BG2CNT_UNUSED_4_5.lower]                         REG_BG2CNT_UNUSED_4_5;
    wire [BG2CNT_Mosaic.upper:BG2CNT_Mosaic.lower]                                 REG_BG2CNT_Mosaic;
    wire [BG2CNT_Colors_Palettes.upper:BG2CNT_Colors_Palettes.lower]               REG_BG2CNT_Colors_Palettes /* verilator public */;
    wire [BG2CNT_Screen_Base_Block.upper:BG2CNT_Screen_Base_Block.lower]           REG_BG2CNT_Screen_Base_Block /* verilator public */;
    wire [BG2CNT_Display_Area_Overflow.upper:BG2CNT_Display_Area_Overflow.lower]   REG_BG2CNT_Display_Area_Overflow;
    wire [BG2CNT_Screen_Size.upper:BG2CNT_Screen_Size.lower]                       REG_BG2CNT_Screen_Size /* verilator public */;
    
    wire [BG3CNT_BG_Priority.upper:BG3CNT_BG_Priority.lower]                       REG_BG3CNT_BG_Priority;
    wire [BG3CNT_Character_Base_Block.upper:BG3CNT_Character_Base_Block.lower]     REG_BG3CNT_Character_Base_Block /* verilator public */;
    wire [BG3CNT_UNUSED_4_5.upper:BG3CNT_UNUSED_4_5.lower]                         REG_BG3CNT_UNUSED_4_5;
    wire [BG3CNT_Mosaic.upper:BG3CNT_Mosaic.lower]                                 REG_BG3CNT_Mosaic;
    wire [BG3CNT_Colors_Palettes.upper:BG3CNT_Colors_Palettes.lower]               REG_BG3CNT_Colors_Palettes /* verilator public */;
    wire [BG3CNT_Screen_Base_Block.upper:BG3CNT_Screen_Base_Block.lower]           REG_BG3CNT_Screen_Base_Block /* verilator public */;
    wire [BG3CNT_Display_Area_Overflow.upper:BG3CNT_Display_Area_Overflow.lower]   REG_BG3CNT_Display_Area_Overflow;
    wire [BG3CNT_Screen_Size.upper:BG3CNT_Screen_Size.lower]                       REG_BG3CNT_Screen_Size /* verilator public */;
    
    wire [BG0HOFS.upper:BG0HOFS.lower]                                             REG_BG0HOFS;
    wire [BG0VOFS.upper:BG0VOFS.lower]                                             REG_BG0VOFS;
    wire [BG1HOFS.upper:BG1HOFS.lower]                                             REG_BG1HOFS;
    wire [BG1VOFS.upper:BG1VOFS.lower]                                             REG_BG1VOFS;
    wire [BG2HOFS.upper:BG2HOFS.lower]                                             REG_BG2HOFS;
    wire [BG2VOFS.upper:BG2VOFS.lower]                                             REG_BG2VOFS;
    wire [BG3HOFS.upper:BG3HOFS.lower]                                             REG_BG3HOFS;
    wire [BG3VOFS.upper:BG3VOFS.lower]                                             REG_BG3VOFS;
    
    wire [BG2RotScaleParDX.upper:BG2RotScaleParDX.lower]                           REG_BG2RotScaleParDX;
    wire [BG2RotScaleParDMX.upper:BG2RotScaleParDMX.lower]                         REG_BG2RotScaleParDMX;
    wire [BG2RotScaleParDY.upper:BG2RotScaleParDY.lower]                           REG_BG2RotScaleParDY;
    wire [BG2RotScaleParDMY.upper:BG2RotScaleParDMY.lower]                         REG_BG2RotScaleParDMY;
    wire [BG2RefX.upper:BG2RefX.lower]                                             REG_BG2RefX;
    wire [BG2RefY.upper:BG2RefY.lower]                                             REG_BG2RefY;
    
    wire [BG3RotScaleParDX.upper:BG3RotScaleParDX.lower]                           REG_BG3RotScaleParDX;
    wire [BG3RotScaleParDMX.upper:BG3RotScaleParDMX.lower]                         REG_BG3RotScaleParDMX;
    wire [BG3RotScaleParDY.upper:BG3RotScaleParDY.lower]                           REG_BG3RotScaleParDY;
    wire [BG3RotScaleParDMY.upper:BG3RotScaleParDMY.lower]                         REG_BG3RotScaleParDMY;
    wire [BG3RefX.upper:BG3RefX.lower]                                             REG_BG3RefX;
    wire [BG3RefY.upper:BG3RefY.lower]                                             REG_BG3RefY;
    
    wire [WIN0H_X2.upper:WIN0H_X2.lower]                                           REG_WIN0H_X2;
    wire [WIN0H_X1.upper:WIN0H_X1.lower]                                           REG_WIN0H_X1;
    
    wire [WIN1H_X2.upper:WIN1H_X2.lower]                                           REG_WIN1H_X2;
    wire [WIN1H_X1.upper:WIN1H_X1.lower]                                           REG_WIN1H_X1;
    
    wire [WIN0V_Y2.upper:WIN0V_Y2.lower]                                           REG_WIN0V_Y2;
    wire [WIN0V_Y1.upper:WIN0V_Y1.lower]                                           REG_WIN0V_Y1;
    
    wire [WIN1V_Y2.upper:WIN1V_Y2.lower]                                           REG_WIN1V_Y2;
    wire [WIN1V_Y1.upper:WIN1V_Y1.lower]                                           REG_WIN1V_Y1;
    
    wire [WININ_Window_0_BG0_Enable.upper:WININ_Window_0_BG0_Enable.lower]         REG_WININ_Window_0_BG0_Enable;
    wire [WININ_Window_0_BG1_Enable.upper:WININ_Window_0_BG1_Enable.lower]         REG_WININ_Window_0_BG1_Enable;
    wire [WININ_Window_0_BG2_Enable.upper:WININ_Window_0_BG2_Enable.lower]         REG_WININ_Window_0_BG2_Enable;
    wire [WININ_Window_0_BG3_Enable.upper:WININ_Window_0_BG3_Enable.lower]         REG_WININ_Window_0_BG3_Enable;
    wire [WININ_Window_0_OBJ_Enable.upper:WININ_Window_0_OBJ_Enable.lower]         REG_WININ_Window_0_OBJ_Enable;
    wire [WININ_Window_0_Special_Effect.upper:WININ_Window_0_Special_Effect.lower] REG_WININ_Window_0_Special_Effect;
    wire [WININ_Window_1_BG0_Enable.upper:WININ_Window_1_BG0_Enable.lower]         REG_WININ_Window_1_BG0_Enable;
    wire [WININ_Window_1_BG1_Enable.upper:WININ_Window_1_BG1_Enable.lower]         REG_WININ_Window_1_BG1_Enable;
    wire [WININ_Window_1_BG2_Enable.upper:WININ_Window_1_BG2_Enable.lower]         REG_WININ_Window_1_BG2_Enable;
    wire [WININ_Window_1_BG3_Enable.upper:WININ_Window_1_BG3_Enable.lower]         REG_WININ_Window_1_BG3_Enable;
    wire [WININ_Window_1_OBJ_Enable.upper:WININ_Window_1_OBJ_Enable.lower]         REG_WININ_Window_1_OBJ_Enable;
    wire [WININ_Window_1_Special_Effect.upper:WININ_Window_1_Special_Effect.lower] REG_WININ_Window_1_Special_Effect;
    
    wire [WINOUT_Outside_BG0_Enable.upper:WINOUT_Outside_BG0_Enable.lower]         REG_WINOUT_Outside_BG0_Enable;
    wire [WINOUT_Outside_BG1_Enable.upper:WINOUT_Outside_BG1_Enable.lower]         REG_WINOUT_Outside_BG1_Enable;
    wire [WINOUT_Outside_BG2_Enable.upper:WINOUT_Outside_BG2_Enable.lower]         REG_WINOUT_Outside_BG2_Enable;
    wire [WINOUT_Outside_BG3_Enable.upper:WINOUT_Outside_BG3_Enable.lower]         REG_WINOUT_Outside_BG3_Enable;
    wire [WINOUT_Outside_OBJ_Enable.upper:WINOUT_Outside_OBJ_Enable.lower]         REG_WINOUT_Outside_OBJ_Enable;
    wire [WINOUT_Outside_Special_Effect.upper:WINOUT_Outside_Special_Effect.lower] REG_WINOUT_Outside_Special_Effect;
    wire [WINOUT_Objwnd_BG0_Enable.upper:WINOUT_Objwnd_BG0_Enable.lower]           REG_WINOUT_Objwnd_BG0_Enable;
    wire [WINOUT_Objwnd_BG1_Enable.upper:WINOUT_Objwnd_BG1_Enable.lower]           REG_WINOUT_Objwnd_BG1_Enable;
    wire [WINOUT_Objwnd_BG2_Enable.upper:WINOUT_Objwnd_BG2_Enable.lower]           REG_WINOUT_Objwnd_BG2_Enable;
    wire [WINOUT_Objwnd_BG3_Enable.upper:WINOUT_Objwnd_BG3_Enable.lower]           REG_WINOUT_Objwnd_BG3_Enable;
    wire [WINOUT_Objwnd_OBJ_Enable.upper:WINOUT_Objwnd_OBJ_Enable.lower]           REG_WINOUT_Objwnd_OBJ_Enable;
    wire [WINOUT_Objwnd_Special_Effect.upper:WINOUT_Objwnd_Special_Effect.lower]   REG_WINOUT_Objwnd_Special_Effect;
    
    wire [MOSAIC_BG_Mosaic_H_Size.upper:MOSAIC_BG_Mosaic_H_Size.lower]             REG_MOSAIC_BG_Mosaic_H_Size;
    wire [MOSAIC_BG_Mosaic_V_Size.upper:MOSAIC_BG_Mosaic_V_Size.lower]             REG_MOSAIC_BG_Mosaic_V_Size;
    wire [MOSAIC_OBJ_Mosaic_H_Size.upper:MOSAIC_OBJ_Mosaic_H_Size.lower]           REG_MOSAIC_OBJ_Mosaic_H_Size;
    wire [MOSAIC_OBJ_Mosaic_V_Size.upper:MOSAIC_OBJ_Mosaic_V_Size.lower]           REG_MOSAIC_OBJ_Mosaic_V_Size;
    
    wire [BLDCNT_BG0_1st_Target_Pixel.upper:BLDCNT_BG0_1st_Target_Pixel.lower]     REG_BLDCNT_BG0_1st_Target_Pixel;
    wire [BLDCNT_BG1_1st_Target_Pixel.upper:BLDCNT_BG1_1st_Target_Pixel.lower]     REG_BLDCNT_BG1_1st_Target_Pixel;
    wire [BLDCNT_BG2_1st_Target_Pixel.upper:BLDCNT_BG2_1st_Target_Pixel.lower]     REG_BLDCNT_BG2_1st_Target_Pixel;
    wire [BLDCNT_BG3_1st_Target_Pixel.upper:BLDCNT_BG3_1st_Target_Pixel.lower]     REG_BLDCNT_BG3_1st_Target_Pixel;
    wire [BLDCNT_OBJ_1st_Target_Pixel.upper:BLDCNT_OBJ_1st_Target_Pixel.lower]     REG_BLDCNT_OBJ_1st_Target_Pixel;
    wire [BLDCNT_BD_1st_Target_Pixel.upper:BLDCNT_BD_1st_Target_Pixel.lower]       REG_BLDCNT_BD_1st_Target_Pixel;
    wire [BLDCNT_Color_Special_Effect.upper:BLDCNT_Color_Special_Effect.lower]     REG_BLDCNT_Color_Special_Effect;
    wire [BLDCNT_BG0_2nd_Target_Pixel.upper:BLDCNT_BG0_2nd_Target_Pixel.lower]     REG_BLDCNT_BG0_2nd_Target_Pixel;
    wire [BLDCNT_BG1_2nd_Target_Pixel.upper:BLDCNT_BG1_2nd_Target_Pixel.lower]     REG_BLDCNT_BG1_2nd_Target_Pixel;
    wire [BLDCNT_BG2_2nd_Target_Pixel.upper:BLDCNT_BG2_2nd_Target_Pixel.lower]     REG_BLDCNT_BG2_2nd_Target_Pixel;
    wire [BLDCNT_BG3_2nd_Target_Pixel.upper:BLDCNT_BG3_2nd_Target_Pixel.lower]     REG_BLDCNT_BG3_2nd_Target_Pixel;
    wire [BLDCNT_OBJ_2nd_Target_Pixel.upper:BLDCNT_OBJ_2nd_Target_Pixel.lower]     REG_BLDCNT_OBJ_2nd_Target_Pixel;
    wire [BLDCNT_BD_2nd_Target_Pixel.upper:BLDCNT_BD_2nd_Target_Pixel.lower]       REG_BLDCNT_BD_2nd_Target_Pixel;
    
    wire [BLDALPHA_EVA_Coefficient.upper:BLDALPHA_EVA_Coefficient.lower]           REG_BLDALPHA_EVA_Coefficient;
    wire [BLDALPHA_EVB_Coefficient.upper:BLDALPHA_EVB_Coefficient.lower]           REG_BLDALPHA_EVB_Coefficient;
    
    wire [BLDY.upper:BLDY.lower] REG_BLDY;
    
    reg [2:0]     on_delay_bg0;
    reg [2:0]     on_delay_bg1;
    reg [2:0]     on_delay_bg2;
    reg [2:0]     on_delay_bg3;
    
    wire          ref2_x_written;
    wire          ref2_y_written;
    wire          ref3_x_written;
    wire          ref3_y_written;
    
    wire [5:0]    enables_wnd0;
    wire [5:0]    enables_wnd1;
    wire [5:0]    enables_wndobj;
    wire [5:0]    enables_wndout;
    
    // ram wiring
    wire [7:0]    OAMRAM_Drawer_addr;
    wire [7:0]    OAMRAM_Drawer_addr_hd0;
    wire [7:0]    OAMRAM_Drawer_addr_hd1;
    wire [31:0]   OAMRAM_Drawer_data;
    wire [31:0]   OAMRAM_Drawer_data_hd0;
    wire [31:0]   OAMRAM_Drawer_data_hd1;
    wire [6:0]    PALETTE_OAM_Drawer_addr;
    wire [6:0]    PALETTE_OAM_Drawer_addr_hd0;
    wire [6:0]    PALETTE_OAM_Drawer_addr_hd1;
    wire [31:0]   PALETTE_OAM_Drawer_data;
    wire [31:0]   PALETTE_OAM_Drawer_data_hd0;
    wire [31:0]   PALETTE_OAM_Drawer_data_hd1;
    
    reg [6:0]     PALETTE_BG_Drawer_addr;
    wire [6:0]    PALETTE_BG_Drawer_addr0;
    wire [6:0]    PALETTE_BG_Drawer_addr1;
    wire [6:0]    PALETTE_BG_Drawer_addr2;
    wire [6:0]    PALETTE_BG_Drawer_addr3;
    wire [31:0]   PALETTE_BG_Drawer_data;
    reg [3:0]     PALETTE_BG_Drawer_valid;
    reg [1:0]     PALETTE_BG_Drawer_cnt;
    
    reg [13:0]    VRAM_Drawer_addr_Lo;
    reg [12:0]    VRAM_Drawer_addr_Hi;
    wire [13:0]   VRAM_Drawer_addr0;
    wire [13:0]   VRAM_Drawer_addr1;
    wire [13:0]   VRAM_Drawer_addr2;
    wire [13:0]   VRAM_Drawer_addr3;
    wire [31:0]   VRAM_Drawer_data_Lo;
    wire [31:0]   VRAM_Drawer_data_Hi;
    reg [3:0]     VRAM_Drawer_valid_Lo;
    reg [1:0]     VRAM_Drawer_valid_Hi;
    reg [1:0]     VRAM_Drawer_cnt_Lo;
    reg           VRAM_Drawer_cnt_Hi;
    
    // background multiplexin
    reg           line_trigger_1;
    reg           drawline_1;
    reg           hblank_trigger_1;
    
    wire          drawline_mode0_0;
    wire          drawline_mode0_1;
    wire          drawline_mode0_2;
    wire          drawline_mode0_3;
    wire          drawline_mode2_2;
    wire          drawline_mode2_2_hd0;
    wire          drawline_mode2_2_hd1;
    wire          drawline_mode2_3;
    wire          drawline_mode2_3_hd0;
    wire          drawline_mode2_3_hd1;
    wire          drawline_mode345;
    wire          drawline_obj;
    wire          drawline_obj_hd0;
    wire          drawline_obj_hd1;
    
    wire          pixel_we_mode0_0;
    wire          pixel_we_mode0_1;
    wire          pixel_we_mode0_2;
    wire          pixel_we_mode0_3;
    wire          pixel_we_mode2_2;
    wire          pixel_we_mode2_2_hd0;
    wire          pixel_we_mode2_2_hd1;
    wire          pixel_we_mode2_3;
    wire          pixel_we_mode2_3_hd0;
    wire          pixel_we_mode2_3_hd1;
    wire          pixel_we_mode345;
    wire          pixel_we_modeobj_color;
    wire          pixel_we_modeobj_color_hd0;
    wire          pixel_we_modeobj_color_hd1;
    wire          pixel_we_modeobj_settings;
    wire          pixel_we_modeobj_settings_hd0;
    wire          pixel_we_modeobj_settings_hd1;
    reg           pixel_we_bg0;
    reg           pixel_we_bg1;
    reg           pixel_we_bg2;
    reg           pixel_we_bg3;
    reg           pixel_we_obj_color;
    reg           pixel_we_obj_color_hd0;
    reg           pixel_we_obj_color_hd1;
    reg           pixel_we_obj_settings;
    reg           pixel_we_obj_settings_hd0;
    reg           pixel_we_obj_settings_hd1;
    
    wire [15:0]   pixeldata_mode0_0;
    wire [15:0]   pixeldata_mode0_1;
    wire [15:0]   pixeldata_mode0_2;
    wire [15:0]   pixeldata_mode0_3;
    wire [15:0]   pixeldata_mode2_2;
    wire [15:0]   pixeldata_mode2_2_hd0;
    wire [15:0]   pixeldata_mode2_2_hd1;
    wire [15:0]   pixeldata_mode2_3;
    wire [15:0]   pixeldata_mode2_3_hd0;
    wire [15:0]   pixeldata_mode2_3_hd1;
    wire [15:0]   pixeldata_mode345;
    wire [15:0]   pixeldata_modeobj_color;
    wire [15:0]   pixeldata_modeobj_color_hd0;
    wire [15:0]   pixeldata_modeobj_color_hd1;
    wire [2:0]    pixeldata_modeobj_settings;
    wire [2:0]    pixeldata_modeobj_settings_hd0;
    wire [2:0]    pixeldata_modeobj_settings_hd1;
    reg [15:0]    pixeldata_bg0;
    reg [15:0]    pixeldata_bg1;
    reg [15:0]    pixeldata_bg2;
    reg [15:0]    pixeldata_bg3;
    wire [18:0]   pixeldata_obj;
    reg [15:0]    pixeldata_obj_color;
    reg [15:0]    pixeldata_obj_color_hd0;
    reg [15:0]    pixeldata_obj_color_hd1;
    reg [2:0]     pixeldata_obj_settings;
    reg [2:0]     pixeldata_obj_settings_hd0;
    reg [2:0]     pixeldata_obj_settings_hd1;
    
    wire [7:0]    pixel_x_mode0_0;
    wire [7:0]    pixel_x_mode0_1;
    wire [7:0]    pixel_x_mode0_2;
    wire [7:0]    pixel_x_mode0_3;
    wire [7:0]    pixel_x_mode2_2;
    wire [8:0]    pixel_x_mode2_2_hd0;
    wire [8:0]    pixel_x_mode2_2_hd1;
    wire [7:0]    pixel_x_mode2_3;
    wire [8:0]    pixel_x_mode2_3_hd0;
    wire [8:0]    pixel_x_mode2_3_hd1;
    wire [7:0]    pixel_x_mode345;
    wire [7:0]    pixel_x_modeobj;
    wire [8:0]    pixel_x_modeobj_hd0;
    wire [8:0]    pixel_x_modeobj_hd1;
    reg [7:0]     pixel_x_bg0;
    reg [7:0]     pixel_x_bg1;
    reg [7:0]     pixel_x_bg2;
    reg [7:0]     pixel_x_bg3;
    reg [7:0]     pixel_x_obj;
    reg [8:0]     pixel_x_obj_hd0;
    reg [8:0]     pixel_x_obj_hd1;
    
    wire          pixel_objwnd;
    wire          pixel_objwnd_hd0;
    wire          pixel_objwnd_hd1;
    
    reg [8:0]     pixel_x_bg2_hd0;
    reg [15:0]    pixeldata_bg2_hd0;
    reg           pixel_we_bg2_hd0;
    
    reg [8:0]     pixel_x_bg2_hd1;
    reg [15:0]    pixeldata_bg2_hd1;
    reg           pixel_we_bg2_hd1;
    
    reg [8:0]     pixel_x_bg3_hd0;
    reg [15:0]    pixeldata_bg3_hd0;
    reg           pixel_we_bg3_hd0;
    
    reg [8:0]     pixel_x_bg3_hd1;
    reg [15:0]    pixeldata_bg3_hd1;
    reg           pixel_we_bg3_hd1;
    
    wire [6:0]    PALETTE_Drawer_addr_mode0_0;
    wire [6:0]    PALETTE_Drawer_addr_mode0_1;
    wire [6:0]    PALETTE_Drawer_addr_mode0_2;
    wire [6:0]    PALETTE_Drawer_addr_mode0_3;
    wire [6:0]    PALETTE_Drawer_addr_mode2_2;
    wire [6:0]    PALETTE_Drawer_addr_mode2_2_hd0;
    wire [6:0]    PALETTE_Drawer_addr_mode2_2_hd1;
    wire [6:0]    PALETTE_Drawer_addr_mode2_3;
    wire [6:0]    PALETTE_Drawer_addr_mode2_3_hd0;
    wire [6:0]    PALETTE_Drawer_addr_mode2_3_hd1;
    wire [6:0]    PALETTE_Drawer_addr_mode345;
    
    wire [13:0]   VRAM_Drawer_addr_mode0_0;
    wire [13:0]   VRAM_Drawer_addr_mode0_1;
    wire [13:0]   VRAM_Drawer_addr_mode0_2;
    wire [13:0]   VRAM_Drawer_addr_mode0_3;
    wire [13:0]   VRAM_Drawer_addr_mode2_2;
    wire [13:0]   VRAM_Drawer_addr_mode2_2_hd0;
    wire [13:0]   VRAM_Drawer_addr_mode2_2_hd1;
    wire [13:0]   VRAM_Drawer_addr_mode2_3;
    wire [13:0]   VRAM_Drawer_addr_mode2_3_hd0;
    wire [13:0]   VRAM_Drawer_addr_mode2_3_hd1;
    wire [13:0]   VRAM_Drawer_addr_345_Lo;
    wire [12:0]   VRAM_Drawer_addr_345_Hi;
    wire [12:0]   VRAM_Drawer_addrobj;
    wire [12:0]   VRAM_Drawer_addrobj_hd0;
    wire [12:0]   VRAM_Drawer_addrobj_hd1;
    
    wire          busy_mode0_0;
    wire          busy_mode0_1;
    wire          busy_mode0_2;
    wire          busy_mode0_3;
    wire          busy_mode2_2;
    wire          busy_mode2_2_hd0;
    wire          busy_mode2_2_hd1;
    wire          busy_mode2_3;
    wire          busy_mode2_3_hd0;
    wire          busy_mode2_3_hd1;
    wire          busy_mode345;
    wire          busy_modeobj;
    wire          busy_modeobj_hd0;
    wire          busy_modeobj_hd1;
    
    wire [7:0]    busy_allmod;
    
    // linebuffers
    reg           clear_enable;
    reg [8:0]     clear_addr;
    reg           clear_trigger;
    reg           clear_trigger_1;
    
    reg [7:0]     linecounter_int;
    reg [7:0]     linebuffer_addr;
    reg [7:0]     linebuffer_addr_1;
    reg           pixelmult;
    reg [8:0]     linebuffer_addr_hd;
    
    wire [15:0]   linebuffer_bg0_data;
    wire [15:0]   linebuffer_bg1_data;
    wire [15:0]   linebuffer_bg2_data;
    wire [15:0]   linebuffer_bg3_data;
    wire [18:0]   linebuffer_obj_data;
    wire [15:0]   linebuffer_obj_color;
    wire [2:0]    linebuffer_obj_setting;
    
    reg [239:0]   linebuffer_objwindow;
    reg [479:0]   linebuffer_objwindow_hd0;
    reg [479:0]   linebuffer_objwindow_hd1;
    
    wire [15:0]   linebuffer_bg2_data_hd0;
    wire [15:0]   linebuffer_bg2_data_hd1;
    wire [15:0]   linebuffer_bg3_data_hd0;
    wire [15:0]   linebuffer_bg3_data_hd1;
    
    wire [18:0]   linebuffer_obj_data_hd0;
    wire [15:0]   linebuffer_obj_color_hd0;
    wire [2:0]    linebuffer_obj_setting_hd0;
    wire [18:0]   linebuffer_obj_data_hd1;
    wire [15:0]   linebuffer_obj_color_hd1;
    wire [2:0]    linebuffer_obj_setting_hd1;
    
    wire [15:0]   merge_in_bg2;
    wire [15:0]   merge_in_bg3;
    wire [18:0]   merge_in_obj;
    wire [15:0]   merge2_in_bg2;
    wire [15:0]   merge2_in_bg3;
    wire [18:0]   merge2_in_obj;
    
    // merge_pixel
    reg [15:0]    pixeldata_back_next;
    reg [15:0]    pixeldata_back;
    reg           merge_enable;
    reg           merge_enable_1;
    wire [15:0]   merge_pixeldata_out;
    wire [7:0]    merge_pixel_x;
    wire [7:0]    merge_pixel_y;
    wire          merge_pixel_we;
    reg           objwindow_merge;
    reg           objwindow_merge_hd0;
    reg           objwindow_merge_hd1;
    wire          objwindow_merge_in;
    wire          objwindow_merge2_in;
    
    wire [15:0]   merge2_pixeldata_out;
    wire [7:0]    merge2_pixel_x;
    wire          merge2_pixel_we;
    
    reg [7:0]     pixel_out_x_1;
    reg [7:0]     pixel_out_y_1;
    reg [15:0]    pixelout_addr_1;
    reg           merge_pixel_we_1;
    reg [15:0]    merge_pixeldata_out_1;
    
    reg [7:0]     pixel_out_x_2;
    reg [7:0]     pixel_out_y_2;
    reg [15:0]    pixelout_addr_2;
    reg           merge_pixel_we_2;
    reg [15:0]    merge_pixeldata_out_2;
    
    reg [159:0]   lineUpToDate;
    reg [7:0]     linesDrawn;
    reg           nextLineDrawn;
    reg           start_draw;
    
    parameter [1:0] tdrawstate_IDLE = 0,
                    tdrawstate_WAITHBLANK = 1,
                    tdrawstate_DRAWING = 2,
                    tdrawstate_MERGING = 3;
    reg [1:0]     drawstate;
    
    // affine + mosaik
    reg signed [27:0]    ref2_x;
    reg signed [27:0]    ref2_y;
    reg signed [27:0]    ref3_x;
    reg signed [27:0]    ref3_y;
    
    reg signed [27:0]    ref2_x_last;
    reg signed [27:0]    ref2_y_last;
    reg signed [27:0]    ref3_x_last;
    reg signed [27:0]    ref3_y_last;
    
    reg signed [28:0]    ref2_x_hd0;
    reg signed [28:0]    ref2_y_hd0;
    reg signed [28:0]    ref2_x_hd1;
    reg signed [28:0]    ref2_y_hd1;
    reg signed [28:0]    ref3_x_hd0;
    reg signed [28:0]    ref3_y_hd0;
    reg signed [28:0]    ref3_x_hd1;
    reg signed [28:0]    ref3_y_hd1;
    
    reg signed [15:0]    dx2_last;
    reg signed [16:0]    dx2_hd0;
    reg signed [16:0]    dx2_hd1;
    reg signed [15:0]    dy2_last;
    reg signed [16:0]    dy2_hd0;
    reg signed [16:0]    dy2_hd1;
    reg signed [15:0]    dx3_last;
    reg signed [16:0]    dx3_hd0;
    reg signed [16:0]    dx3_hd1;
    reg signed [15:0]    dy3_last;
    reg signed [16:0]    dy3_hd0;
    reg signed [16:0]    dy3_hd1;
    
    reg           new_dx2;
    reg           new_dy2;
    reg           new_dx3;
    reg           new_dy3;
    
    reg [3:0]     mosaik_vcnt_bg;
    reg [3:0]     mosaik_vcnt_obj;
    
    reg [7:0]     linecounter_mosaic_bg;
    reg [7:0]     linecounter_mosaic_obj;
    
    reg signed [27:0]    mosaic_ref2_x;
    reg signed [27:0]    mosaic_ref2_y;
    reg signed [27:0]    mosaic_ref3_x;
    reg signed [27:0]    mosaic_ref3_y;
    
    // interframe_blend option
    reg [14:0]    PixelArraySmooth[0:(240*160)-1];
    reg [14:0]    pixel_smooth;
    reg           frameselect;
    
    // MMIO register definitions
    eProcReg_gba #(DISPCNT_BG_Mode              ) iREG_DISPCNT_BG_Mode                (mclk, `GB_BUS_PORTS_LIST, BG_Mode                           , BG_Mode               ); 
    eProcReg_gba #(DISPCNT_Reserved_CGB_Mode    ) iREG_DISPCNT_Reserved_CGB_Mode      (mclk, `GB_BUS_PORTS_LIST, REG_DISPCNT_Reserved_CGB_Mode     , REG_DISPCNT_Reserved_CGB_Mode     ); 
    eProcReg_gba #(DISPCNT_Display_Frame_Select ) iREG_DISPCNT_Display_Frame_Select   (mclk, `GB_BUS_PORTS_LIST, REG_DISPCNT_Display_Frame_Select  , REG_DISPCNT_Display_Frame_Select  ); 
    eProcReg_gba #(DISPCNT_H_Blank_IntervalFree ) iREG_DISPCNT_H_Blank_IntervalFree   (mclk, `GB_BUS_PORTS_LIST, REG_DISPCNT_H_Blank_IntervalFree  , REG_DISPCNT_H_Blank_IntervalFree  ); 
    eProcReg_gba #(DISPCNT_OBJ_Char_VRAM_Map    ) iREG_DISPCNT_OBJ_Char_VRAM_Map      (mclk, `GB_BUS_PORTS_LIST, REG_DISPCNT_OBJ_Char_VRAM_Map     , REG_DISPCNT_OBJ_Char_VRAM_Map     ); 
    eProcReg_gba #(DISPCNT_Forced_Blank         ) iREG_DISPCNT_Forced_Blank           (mclk, `GB_BUS_PORTS_LIST, Forced_Blank                      , Forced_Blank                      ); 
    eProcReg_gba #(DISPCNT_Screen_Display_BG0   ) iREG_DISPCNT_Screen_Display_BG0     (mclk, `GB_BUS_PORTS_LIST, Screen_Display_BG0                , Screen_Display_BG0                ); 
    eProcReg_gba #(DISPCNT_Screen_Display_BG1   ) iREG_DISPCNT_Screen_Display_BG1     (mclk, `GB_BUS_PORTS_LIST, Screen_Display_BG1                , Screen_Display_BG1                ); 
    eProcReg_gba #(DISPCNT_Screen_Display_BG2   ) iREG_DISPCNT_Screen_Display_BG2     (mclk, `GB_BUS_PORTS_LIST, Screen_Display_BG2                , Screen_Display_BG2                ); 
    eProcReg_gba #(DISPCNT_Screen_Display_BG3   ) iREG_DISPCNT_Screen_Display_BG3     (mclk, `GB_BUS_PORTS_LIST, Screen_Display_BG3                , Screen_Display_BG3                ); 
    eProcReg_gba #(DISPCNT_Screen_Display_OBJ   ) iREG_DISPCNT_Screen_Display_OBJ     (mclk, `GB_BUS_PORTS_LIST, Screen_Display_OBJ                , Screen_Display_OBJ                ); 
    eProcReg_gba #(DISPCNT_Window_0_Display_Flag) iREG_DISPCNT_Window_0_Display_Flag  (mclk, `GB_BUS_PORTS_LIST, REG_DISPCNT_Window_0_Display_Flag , REG_DISPCNT_Window_0_Display_Flag ); 
    eProcReg_gba #(DISPCNT_Window_1_Display_Flag) iREG_DISPCNT_Window_1_Display_Flag  (mclk, `GB_BUS_PORTS_LIST, REG_DISPCNT_Window_1_Display_Flag , REG_DISPCNT_Window_1_Display_Flag ); 
    eProcReg_gba #(DISPCNT_OBJ_Wnd_Display_Flag ) iREG_DISPCNT_OBJ_Wnd_Display_Flag   (mclk, `GB_BUS_PORTS_LIST, REG_DISPCNT_OBJ_Wnd_Display_Flag  , REG_DISPCNT_OBJ_Wnd_Display_Flag  ); 
    eProcReg_gba #(GREENSWAP                    ) iREG_GREENSWAP                      (mclk, `GB_BUS_PORTS_LIST, REG_GREENSWAP                     , REG_GREENSWAP                     ); 
    
    eProcReg_gba #(BG0CNT_BG_Priority           ) iREG_BG0CNT_BG_Priority             (mclk, `GB_BUS_PORTS_LIST, REG_BG0CNT_BG_Priority            , REG_BG0CNT_BG_Priority            ); 
    eProcReg_gba #(BG0CNT_Character_Base_Block  ) iREG_BG0CNT_Character_Base_Block    (mclk, `GB_BUS_PORTS_LIST, REG_BG0CNT_Character_Base_Block   , REG_BG0CNT_Character_Base_Block   ); 
    eProcReg_gba #(BG0CNT_UNUSED_4_5            ) iREG_BG0CNT_UNUSED_4_5              (mclk, `GB_BUS_PORTS_LIST, REG_BG0CNT_UNUSED_4_5             , REG_BG0CNT_UNUSED_4_5             ); 
    eProcReg_gba #(BG0CNT_Mosaic                ) iREG_BG0CNT_Mosaic                  (mclk, `GB_BUS_PORTS_LIST, REG_BG0CNT_Mosaic                 , REG_BG0CNT_Mosaic                 ); 
    eProcReg_gba #(BG0CNT_Colors_Palettes       ) iREG_BG0CNT_Colors_Palettes         (mclk, `GB_BUS_PORTS_LIST, REG_BG0CNT_Colors_Palettes        , REG_BG0CNT_Colors_Palettes        ); 
    eProcReg_gba #(BG0CNT_Screen_Base_Block     ) iREG_BG0CNT_Screen_Base_Block       (mclk, `GB_BUS_PORTS_LIST, REG_BG0CNT_Screen_Base_Block      , REG_BG0CNT_Screen_Base_Block      ); 
    eProcReg_gba #(BG0CNT_Screen_Size           ) iREG_BG0CNT_Screen_Size             (mclk, `GB_BUS_PORTS_LIST, REG_BG0CNT_Screen_Size            , REG_BG0CNT_Screen_Size            ); 
                                                                                                                                                                                        
    eProcReg_gba #(BG1CNT_BG_Priority           ) iREG_BG1CNT_BG_Priority             (mclk, `GB_BUS_PORTS_LIST, REG_BG1CNT_BG_Priority            , REG_BG1CNT_BG_Priority            ); 
    eProcReg_gba #(BG1CNT_Character_Base_Block  ) iREG_BG1CNT_Character_Base_Block    (mclk, `GB_BUS_PORTS_LIST, REG_BG1CNT_Character_Base_Block   , REG_BG1CNT_Character_Base_Block   ); 
    eProcReg_gba #(BG1CNT_UNUSED_4_5            ) iREG_BG1CNT_UNUSED_4_5              (mclk, `GB_BUS_PORTS_LIST, REG_BG1CNT_UNUSED_4_5             , REG_BG1CNT_UNUSED_4_5             ); 
    eProcReg_gba #(BG1CNT_Mosaic                ) iREG_BG1CNT_Mosaic                  (mclk, `GB_BUS_PORTS_LIST, REG_BG1CNT_Mosaic                 , REG_BG1CNT_Mosaic                 ); 
    eProcReg_gba #(BG1CNT_Colors_Palettes       ) iREG_BG1CNT_Colors_Palettes         (mclk, `GB_BUS_PORTS_LIST, REG_BG1CNT_Colors_Palettes        , REG_BG1CNT_Colors_Palettes        ); 
    eProcReg_gba #(BG1CNT_Screen_Base_Block     ) iREG_BG1CNT_Screen_Base_Block       (mclk, `GB_BUS_PORTS_LIST, REG_BG1CNT_Screen_Base_Block      , REG_BG1CNT_Screen_Base_Block      ); 
    eProcReg_gba #(BG1CNT_Screen_Size           ) iREG_BG1CNT_Screen_Size             (mclk, `GB_BUS_PORTS_LIST, REG_BG1CNT_Screen_Size            , REG_BG1CNT_Screen_Size            ); 
                                                                                                                                                                                        
    eProcReg_gba #(BG2CNT_BG_Priority           ) iREG_BG2CNT_BG_Priority             (mclk, `GB_BUS_PORTS_LIST, REG_BG2CNT_BG_Priority            , REG_BG2CNT_BG_Priority            ); 
    eProcReg_gba #(BG2CNT_Character_Base_Block  ) iREG_BG2CNT_Character_Base_Block    (mclk, `GB_BUS_PORTS_LIST, REG_BG2CNT_Character_Base_Block   , REG_BG2CNT_Character_Base_Block   ); 
    eProcReg_gba #(BG2CNT_UNUSED_4_5            ) iREG_BG2CNT_UNUSED_4_5              (mclk, `GB_BUS_PORTS_LIST, REG_BG2CNT_UNUSED_4_5             , REG_BG2CNT_UNUSED_4_5             ); 
    eProcReg_gba #(BG2CNT_Mosaic                ) iREG_BG2CNT_Mosaic                  (mclk, `GB_BUS_PORTS_LIST, REG_BG2CNT_Mosaic                 , REG_BG2CNT_Mosaic                 ); 
    eProcReg_gba #(BG2CNT_Colors_Palettes       ) iREG_BG2CNT_Colors_Palettes         (mclk, `GB_BUS_PORTS_LIST, REG_BG2CNT_Colors_Palettes        , REG_BG2CNT_Colors_Palettes        ); 
    eProcReg_gba #(BG2CNT_Screen_Base_Block     ) iREG_BG2CNT_Screen_Base_Block       (mclk, `GB_BUS_PORTS_LIST, REG_BG2CNT_Screen_Base_Block      , REG_BG2CNT_Screen_Base_Block      ); 
    eProcReg_gba #(BG2CNT_Display_Area_Overflow ) iREG_BG2CNT_Display_Area_Overflow   (mclk, `GB_BUS_PORTS_LIST, REG_BG2CNT_Display_Area_Overflow  , REG_BG2CNT_Display_Area_Overflow  ); 
    eProcReg_gba #(BG2CNT_Screen_Size           ) iREG_BG2CNT_Screen_Size             (mclk, `GB_BUS_PORTS_LIST, REG_BG2CNT_Screen_Size            , REG_BG2CNT_Screen_Size            ); 
                                                                                                                                                                                        
    eProcReg_gba #(BG3CNT_BG_Priority           ) iREG_BG3CNT_BG_Priority             (mclk, `GB_BUS_PORTS_LIST, REG_BG3CNT_BG_Priority            , REG_BG3CNT_BG_Priority            ); 
    eProcReg_gba #(BG3CNT_Character_Base_Block  ) iREG_BG3CNT_Character_Base_Block    (mclk, `GB_BUS_PORTS_LIST, REG_BG3CNT_Character_Base_Block   , REG_BG3CNT_Character_Base_Block   ); 
    eProcReg_gba #(BG3CNT_UNUSED_4_5            ) iREG_BG3CNT_UNUSED_4_5              (mclk, `GB_BUS_PORTS_LIST, REG_BG3CNT_UNUSED_4_5             , REG_BG3CNT_UNUSED_4_5             ); 
    eProcReg_gba #(BG3CNT_Mosaic                ) iREG_BG3CNT_Mosaic                  (mclk, `GB_BUS_PORTS_LIST, REG_BG3CNT_Mosaic                 , REG_BG3CNT_Mosaic                 ); 
    eProcReg_gba #(BG3CNT_Colors_Palettes       ) iREG_BG3CNT_Colors_Palettes         (mclk, `GB_BUS_PORTS_LIST, REG_BG3CNT_Colors_Palettes        , REG_BG3CNT_Colors_Palettes        ); 
    eProcReg_gba #(BG3CNT_Screen_Base_Block     ) iREG_BG3CNT_Screen_Base_Block       (mclk, `GB_BUS_PORTS_LIST, REG_BG3CNT_Screen_Base_Block      , REG_BG3CNT_Screen_Base_Block      ); 
    eProcReg_gba #(BG3CNT_Display_Area_Overflow ) iREG_BG3CNT_Display_Area_Overflow   (mclk, `GB_BUS_PORTS_LIST, REG_BG3CNT_Display_Area_Overflow  , REG_BG3CNT_Display_Area_Overflow  ); 
    eProcReg_gba #(BG3CNT_Screen_Size           ) iREG_BG3CNT_Screen_Size             (mclk, `GB_BUS_PORTS_LIST, REG_BG3CNT_Screen_Size            , REG_BG3CNT_Screen_Size            ); 
                                                                                                                                                                                        
    eProcReg_gba #(BG0HOFS                      ) iREG_BG0HOFS                        (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG0HOFS                       ); 
    eProcReg_gba #(BG0VOFS                      ) iREG_BG0VOFS                        (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG0VOFS                       ); 
    eProcReg_gba #(BG1HOFS                      ) iREG_BG1HOFS                        (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG1HOFS                       ); 
    eProcReg_gba #(BG1VOFS                      ) iREG_BG1VOFS                        (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG1VOFS                       ); 
    eProcReg_gba #(BG2HOFS                      ) iREG_BG2HOFS                        (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG2HOFS                       ); 
    eProcReg_gba #(BG2VOFS                      ) iREG_BG2VOFS                        (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG2VOFS                       ); 
    eProcReg_gba #(BG3HOFS                      ) iREG_BG3HOFS                        (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG3HOFS                       ); 
    eProcReg_gba #(BG3VOFS                      ) iREG_BG3VOFS                        (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG3VOFS                       ); 

wire bg2_dx_written, bg2_dmx_written, bg2_dy_written, bg2_dmy_written;
wire bg3_dx_written, bg3_dmx_written, bg3_dy_written, bg3_dmy_written;

    eProcReg_gba #(BG2RotScaleParDX             ) iREG_BG2RotScaleParDX               (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG2RotScaleParDX              , bg2_dx_written); 
    eProcReg_gba #(BG2RotScaleParDMX            ) iREG_BG2RotScaleParDMX              (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG2RotScaleParDMX             , bg2_dmx_written); 
    eProcReg_gba #(BG2RotScaleParDY             ) iREG_BG2RotScaleParDY               (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG2RotScaleParDY              , bg2_dy_written); 
    eProcReg_gba #(BG2RotScaleParDMY            ) iREG_BG2RotScaleParDMY              (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG2RotScaleParDMY             , bg2_dmy_written); 
    eProcReg_gba #(BG2RefX                      ) iREG_BG2RefX                        (mclk, `GB_BUS_PORTS_LIST, 28'b0                             , REG_BG2RefX                       , ref2_x_written); 
    eProcReg_gba #(BG2RefY                      ) iREG_BG2RefY                        (mclk, `GB_BUS_PORTS_LIST, 28'b0                             , REG_BG2RefY                       , ref2_y_written); 
                                                                                                                                                                                        
    eProcReg_gba #(BG3RotScaleParDX             ) iREG_BG3RotScaleParDX               (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG3RotScaleParDX              , bg3_dx_written); 
    eProcReg_gba #(BG3RotScaleParDMX            ) iREG_BG3RotScaleParDMX              (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG3RotScaleParDMX             , bg3_dmx_written); 
    eProcReg_gba #(BG3RotScaleParDY             ) iREG_BG3RotScaleParDY               (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG3RotScaleParDY              , bg3_dy_written); 
    eProcReg_gba #(BG3RotScaleParDMY            ) iREG_BG3RotScaleParDMY              (mclk, `GB_BUS_PORTS_LIST, 16'b0                             , REG_BG3RotScaleParDMY             , bg3_dmy_written); 
    eProcReg_gba #(BG3RefX                      ) iREG_BG3RefX                        (mclk, `GB_BUS_PORTS_LIST, 28'b0                             , REG_BG3RefX                       , ref3_x_written); 
    eProcReg_gba #(BG3RefY                      ) iREG_BG3RefY                        (mclk, `GB_BUS_PORTS_LIST, 28'b0                             , REG_BG3RefY                       , ref3_y_written); 

/*
always @(posedge mclk) begin
    if (bg2_dx_written) $display("BG2DX=%h", REG_BG2RotScaleParDX);
    if (bg2_dmx_written) $display("BG2DMX=%h", REG_BG2RotScaleParDMX);
    if (bg2_dy_written) $display("BG2DY=%h", REG_BG2RotScaleParDY);
    if (bg2_dmy_written) $display("BG2DMY=%h", REG_BG2RotScaleParDMY);

    if (bg3_dx_written) $display("BG3DX=%h", REG_BG3RotScaleParDX);
    if (bg3_dmx_written) $display("BG3DMX=%h", REG_BG3RotScaleParDMX);
    if (bg3_dy_written) $display("BG3DY=%h", REG_BG3RotScaleParDY);
    if (bg3_dmy_written) $display("BG3DMY=%h", REG_BG3RotScaleParDMY);
end
*/

    eProcReg_gba #(WIN0H_X2                     ) iREG_WIN0H_X2                       (mclk, `GB_BUS_PORTS_LIST, 8'b0                             , REG_WIN0H_X2                      ); 
    eProcReg_gba #(WIN0H_X1                     ) iREG_WIN0H_X1                       (mclk, `GB_BUS_PORTS_LIST, 8'b0                             , REG_WIN0H_X1                      ); 
                                                                                                                                                                            
    eProcReg_gba #(WIN1H_X2                     ) iREG_WIN1H_X2                       (mclk, `GB_BUS_PORTS_LIST, 8'b0                             , REG_WIN1H_X2                      ); 
    eProcReg_gba #(WIN1H_X1                     ) iREG_WIN1H_X1                       (mclk, `GB_BUS_PORTS_LIST, 8'b0                             , REG_WIN1H_X1                      ); 
                                                                                                                                                                                
    eProcReg_gba #(WIN0V_Y2                     ) iREG_WIN0V_Y2                       (mclk, `GB_BUS_PORTS_LIST, 8'b0                             , REG_WIN0V_Y2                      ); 
    eProcReg_gba #(WIN0V_Y1                     ) iREG_WIN0V_Y1                       (mclk, `GB_BUS_PORTS_LIST, 8'b0                             , REG_WIN0V_Y1                      ); 
                                                                                                                                                                                
    eProcReg_gba #(WIN1V_Y2                     ) iREG_WIN1V_Y2                       (mclk, `GB_BUS_PORTS_LIST, 8'b0                             , REG_WIN1V_Y2                      ); 
    eProcReg_gba #(WIN1V_Y1                     ) iREG_WIN1V_Y1                       (mclk, `GB_BUS_PORTS_LIST, 8'b0                             , REG_WIN1V_Y1                      ); 
                                                                                                                                                                                        
    eProcReg_gba #(WININ_Window_0_BG0_Enable    ) iREG_WININ_Window_0_BG0_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_0_BG0_Enable     , REG_WININ_Window_0_BG0_Enable     ); 
    eProcReg_gba #(WININ_Window_0_BG1_Enable    ) iREG_WININ_Window_0_BG1_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_0_BG1_Enable     , REG_WININ_Window_0_BG1_Enable     ); 
    eProcReg_gba #(WININ_Window_0_BG2_Enable    ) iREG_WININ_Window_0_BG2_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_0_BG2_Enable     , REG_WININ_Window_0_BG2_Enable     ); 
    eProcReg_gba #(WININ_Window_0_BG3_Enable    ) iREG_WININ_Window_0_BG3_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_0_BG3_Enable     , REG_WININ_Window_0_BG3_Enable     ); 
    eProcReg_gba #(WININ_Window_0_OBJ_Enable    ) iREG_WININ_Window_0_OBJ_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_0_OBJ_Enable     , REG_WININ_Window_0_OBJ_Enable     ); 
    eProcReg_gba #(WININ_Window_0_Special_Effect) iREG_WININ_Window_0_Special_Effect  (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_0_Special_Effect , REG_WININ_Window_0_Special_Effect ); 
    eProcReg_gba #(WININ_Window_1_BG0_Enable    ) iREG_WININ_Window_1_BG0_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_1_BG0_Enable     , REG_WININ_Window_1_BG0_Enable     ); 
    eProcReg_gba #(WININ_Window_1_BG1_Enable    ) iREG_WININ_Window_1_BG1_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_1_BG1_Enable     , REG_WININ_Window_1_BG1_Enable     ); 
    eProcReg_gba #(WININ_Window_1_BG2_Enable    ) iREG_WININ_Window_1_BG2_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_1_BG2_Enable     , REG_WININ_Window_1_BG2_Enable     ); 
    eProcReg_gba #(WININ_Window_1_BG3_Enable    ) iREG_WININ_Window_1_BG3_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_1_BG3_Enable     , REG_WININ_Window_1_BG3_Enable     ); 
    eProcReg_gba #(WININ_Window_1_OBJ_Enable    ) iREG_WININ_Window_1_OBJ_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_1_OBJ_Enable     , REG_WININ_Window_1_OBJ_Enable     ); 
    eProcReg_gba #(WININ_Window_1_Special_Effect) iREG_WININ_Window_1_Special_Effect  (mclk, `GB_BUS_PORTS_LIST, REG_WININ_Window_1_Special_Effect , REG_WININ_Window_1_Special_Effect ); 
                                                                                                                                                                                        
    eProcReg_gba #(WINOUT_Outside_BG0_Enable    ) iREG_WINOUT_Outside_BG0_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Outside_BG0_Enable     , REG_WINOUT_Outside_BG0_Enable     ); 
    eProcReg_gba #(WINOUT_Outside_BG1_Enable    ) iREG_WINOUT_Outside_BG1_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Outside_BG1_Enable     , REG_WINOUT_Outside_BG1_Enable     ); 
    eProcReg_gba #(WINOUT_Outside_BG2_Enable    ) iREG_WINOUT_Outside_BG2_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Outside_BG2_Enable     , REG_WINOUT_Outside_BG2_Enable     ); 
    eProcReg_gba #(WINOUT_Outside_BG3_Enable    ) iREG_WINOUT_Outside_BG3_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Outside_BG3_Enable     , REG_WINOUT_Outside_BG3_Enable     ); 
    eProcReg_gba #(WINOUT_Outside_OBJ_Enable    ) iREG_WINOUT_Outside_OBJ_Enable      (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Outside_OBJ_Enable     , REG_WINOUT_Outside_OBJ_Enable     ); 
    eProcReg_gba #(WINOUT_Outside_Special_Effect) iREG_WINOUT_Outside_Special_Effect  (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Outside_Special_Effect , REG_WINOUT_Outside_Special_Effect ); 
    eProcReg_gba #(WINOUT_Objwnd_BG0_Enable     ) iREG_WINOUT_Objwnd_BG0_Enable       (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Objwnd_BG0_Enable      , REG_WINOUT_Objwnd_BG0_Enable      ); 
    eProcReg_gba #(WINOUT_Objwnd_BG1_Enable     ) iREG_WINOUT_Objwnd_BG1_Enable       (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Objwnd_BG1_Enable      , REG_WINOUT_Objwnd_BG1_Enable      ); 
    eProcReg_gba #(WINOUT_Objwnd_BG2_Enable     ) iREG_WINOUT_Objwnd_BG2_Enable       (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Objwnd_BG2_Enable      , REG_WINOUT_Objwnd_BG2_Enable      ); 
    eProcReg_gba #(WINOUT_Objwnd_BG3_Enable     ) iREG_WINOUT_Objwnd_BG3_Enable       (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Objwnd_BG3_Enable      , REG_WINOUT_Objwnd_BG3_Enable      ); 
    eProcReg_gba #(WINOUT_Objwnd_OBJ_Enable     ) iREG_WINOUT_Objwnd_OBJ_Enable       (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Objwnd_OBJ_Enable      , REG_WINOUT_Objwnd_OBJ_Enable      ); 
    eProcReg_gba #(WINOUT_Objwnd_Special_Effect ) iREG_WINOUT_Objwnd_Special_Effect   (mclk, `GB_BUS_PORTS_LIST, REG_WINOUT_Objwnd_Special_Effect  , REG_WINOUT_Objwnd_Special_Effect  ); 
                                                                                                                                                                                        
    eProcReg_gba #(MOSAIC_BG_Mosaic_H_Size      ) iREG_MOSAIC_BG_Mosaic_H_Size        (mclk, `GB_BUS_PORTS_LIST, 4'b0                              , REG_MOSAIC_BG_Mosaic_H_Size       ); 
    eProcReg_gba #(MOSAIC_BG_Mosaic_V_Size      ) iREG_MOSAIC_BG_Mosaic_V_Size        (mclk, `GB_BUS_PORTS_LIST, 4'b0                              , REG_MOSAIC_BG_Mosaic_V_Size       ); 
    eProcReg_gba #(MOSAIC_OBJ_Mosaic_H_Size     ) iREG_MOSAIC_OBJ_Mosaic_H_Size       (mclk, `GB_BUS_PORTS_LIST, 4'b0                              , REG_MOSAIC_OBJ_Mosaic_H_Size      ); 
    eProcReg_gba #(MOSAIC_OBJ_Mosaic_V_Size     ) iREG_MOSAIC_OBJ_Mosaic_V_Size       (mclk, `GB_BUS_PORTS_LIST, 4'b0                              , REG_MOSAIC_OBJ_Mosaic_V_Size      ); 
                                                                                                                                                                                        
    eProcReg_gba #(BLDCNT_BG0_1st_Target_Pixel  ) iREG_BLDCNT_BG0_1st_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BG0_1st_Target_Pixel   , REG_BLDCNT_BG0_1st_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_BG1_1st_Target_Pixel  ) iREG_BLDCNT_BG1_1st_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BG1_1st_Target_Pixel   , REG_BLDCNT_BG1_1st_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_BG2_1st_Target_Pixel  ) iREG_BLDCNT_BG2_1st_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BG2_1st_Target_Pixel   , REG_BLDCNT_BG2_1st_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_BG3_1st_Target_Pixel  ) iREG_BLDCNT_BG3_1st_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BG3_1st_Target_Pixel   , REG_BLDCNT_BG3_1st_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_OBJ_1st_Target_Pixel  ) iREG_BLDCNT_OBJ_1st_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_OBJ_1st_Target_Pixel   , REG_BLDCNT_OBJ_1st_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_BD_1st_Target_Pixel   ) iREG_BLDCNT_BD_1st_Target_Pixel     (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BD_1st_Target_Pixel    , REG_BLDCNT_BD_1st_Target_Pixel    ); 
    eProcReg_gba #(BLDCNT_Color_Special_Effect  ) iREG_BLDCNT_Color_Special_Effect    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_Color_Special_Effect   , REG_BLDCNT_Color_Special_Effect   ); 
    eProcReg_gba #(BLDCNT_BG0_2nd_Target_Pixel  ) iREG_BLDCNT_BG0_2nd_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BG0_2nd_Target_Pixel   , REG_BLDCNT_BG0_2nd_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_BG1_2nd_Target_Pixel  ) iREG_BLDCNT_BG1_2nd_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BG1_2nd_Target_Pixel   , REG_BLDCNT_BG1_2nd_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_BG2_2nd_Target_Pixel  ) iREG_BLDCNT_BG2_2nd_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BG2_2nd_Target_Pixel   , REG_BLDCNT_BG2_2nd_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_BG3_2nd_Target_Pixel  ) iREG_BLDCNT_BG3_2nd_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BG3_2nd_Target_Pixel   , REG_BLDCNT_BG3_2nd_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_OBJ_2nd_Target_Pixel  ) iREG_BLDCNT_OBJ_2nd_Target_Pixel    (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_OBJ_2nd_Target_Pixel   , REG_BLDCNT_OBJ_2nd_Target_Pixel   ); 
    eProcReg_gba #(BLDCNT_BD_2nd_Target_Pixel   ) iREG_BLDCNT_BD_2nd_Target_Pixel     (mclk, `GB_BUS_PORTS_LIST, REG_BLDCNT_BD_2nd_Target_Pixel    , REG_BLDCNT_BD_2nd_Target_Pixel    ); 
                                                                                                                                                                                        
    eProcReg_gba #(BLDALPHA_EVA_Coefficient     ) iREG_BLDALPHA_EVA_Coefficient       (mclk, `GB_BUS_PORTS_LIST, REG_BLDALPHA_EVA_Coefficient      , REG_BLDALPHA_EVA_Coefficient      ); 
    eProcReg_gba #(BLDALPHA_EVB_Coefficient     ) iREG_BLDALPHA_EVB_Coefficient       (mclk, `GB_BUS_PORTS_LIST, REG_BLDALPHA_EVB_Coefficient      , REG_BLDALPHA_EVB_Coefficient      ); 
                                                                                                                                                                                        
    eProcReg_gba #(BLDY                         ) iREG_BLDY                           (mclk, `GB_BUS_PORTS_LIST, 5'b0                              , REG_BLDY                          ); 
        
    // MMIO reg reads
    reg [31:0] reg_dout;
    reg reg_dout_en;
    assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};

    always @(posedge mclk) begin
        reg_dout_en <= 0;

        if (gb_bus_ena & gb_bus_rnw) begin
            reg_dout_en <= 1;
            case (gb_bus_adr)
            DISPCNT.Adr:    // 000
                reg_dout <= {REG_GREENSWAP, REG_DISPCNT_OBJ_Wnd_Display_Flag, REG_DISPCNT_Window_1_Display_Flag,
                             REG_DISPCNT_Window_0_Display_Flag, Screen_Display_OBJ, Screen_Display_BG3,
                             Screen_Display_BG2, Screen_Display_BG1, Screen_Display_BG0, Forced_Blank,
                             REG_DISPCNT_OBJ_Char_VRAM_Map, REG_DISPCNT_H_Blank_IntervalFree, REG_DISPCNT_Display_Frame_Select,
                             REG_DISPCNT_Reserved_CGB_Mode, BG_Mode};
            BG0CNT.Adr:     // 008
                reg_dout <= {REG_BG1CNT_Screen_Size, 1'b0, REG_BG1CNT_Screen_Base_Block, REG_BG1CNT_Colors_Palettes,
                             REG_BG1CNT_Mosaic, REG_BG1CNT_UNUSED_4_5, REG_BG1CNT_Character_Base_Block, REG_BG1CNT_BG_Priority, 
                             REG_BG0CNT_Screen_Size, 1'b0, REG_BG0CNT_Screen_Base_Block, REG_BG0CNT_Colors_Palettes,
                             REG_BG0CNT_Mosaic, REG_BG0CNT_UNUSED_4_5, REG_BG0CNT_Character_Base_Block, REG_BG0CNT_BG_Priority};
            BG2CNT.Adr:     // 00C
                reg_dout <= {REG_BG3CNT_Screen_Size, REG_BG3CNT_Display_Area_Overflow, REG_BG3CNT_Screen_Base_Block, REG_BG3CNT_Colors_Palettes,
                             REG_BG3CNT_Mosaic, REG_BG3CNT_UNUSED_4_5, REG_BG3CNT_Character_Base_Block, REG_BG3CNT_BG_Priority, 
                             REG_BG2CNT_Screen_Size, REG_BG2CNT_Display_Area_Overflow, REG_BG2CNT_Screen_Base_Block, REG_BG2CNT_Colors_Palettes,
                             REG_BG2CNT_Mosaic, REG_BG2CNT_UNUSED_4_5, REG_BG2CNT_Character_Base_Block, REG_BG2CNT_BG_Priority};
            
            // all write-only register return 32'hDEADDEAD
            BG0HOFS.Adr:    // 010
                reg_dout <= 32'hDEADDEAD; // {REG_BG0VOFS, REG_BG0HOFS};
            BG1HOFS.Adr:    // 014
                reg_dout <= 32'hDEADDEAD; // {REG_BG1VOFS, REG_BG1HOFS};
            BG2HOFS.Adr:    // 018
                reg_dout <= 32'hDEADDEAD; // {REG_BG2VOFS, REG_BG2HOFS};
            BG3HOFS.Adr:    // 01C
                reg_dout <= 32'hDEADDEAD; // {REG_BG2VOFS, REG_BG2HOFS};

            BG2RotScaleParDX.Adr:   // 020
                reg_dout <= 32'hDEADDEAD; // {REG_BG2RotScaleParDMX, REG_BG2RotScaleParDX};
            BG2RotScaleParDY.Adr:   // 024
                reg_dout <= 32'hDEADDEAD; // {REG_BG2RotScaleParDMY, REG_BG2RotScaleParDY};
            BG2RefX.Adr:            // 028
                reg_dout <= 32'hDEADDEAD; // REG_BG2RefX;
            BG2RefY.Adr:            // 02C
                reg_dout <= 32'hDEADDEAD; // REG_BG2RefY;

            BG3RotScaleParDX.Adr:   // 030
                reg_dout <= 32'hDEADDEAD; // {REG_BG3RotScaleParDMX, REG_BG3RotScaleParDX};
            BG3RotScaleParDY.Adr:   // 034
                reg_dout <= 32'hDEADDEAD; // {REG_BG3RotScaleParDMY, REG_BG3RotScaleParDY};
            BG3RefX.Adr:            // 038
                reg_dout <= 32'hDEADDEAD; // REG_BG3RefX;
            BG3RefY.Adr:            // 03C
                reg_dout <= 32'hDEADDEAD; // REG_BG3RefY;

            WIN0H.Adr:              // 040
                reg_dout <= 32'hDEADDEAD; // {REG_WIN1H_X1, REG_WIN1H_X2, REG_WIN0H_X1, REG_WIN0H_X2};
            WIN0V.Adr:              // 044
                reg_dout <= 32'hDEADDEAD; // {REG_WIN1V_Y1, REG_WIN1V_Y2, REG_WIN0V_Y1, REG_WIN0V_Y2};
            WININ.Adr:              // 048
                reg_dout <= {2'b0, REG_WINOUT_Objwnd_Special_Effect, REG_WINOUT_Objwnd_OBJ_Enable,
                                REG_WINOUT_Objwnd_BG3_Enable, REG_WINOUT_Objwnd_BG2_Enable,
                                REG_WINOUT_Objwnd_BG1_Enable, REG_WINOUT_Objwnd_BG0_Enable,
                                2'b0, REG_WINOUT_Outside_Special_Effect, REG_WINOUT_Outside_OBJ_Enable,
                                REG_WINOUT_Outside_BG3_Enable, REG_WINOUT_Outside_BG2_Enable,
                                REG_WINOUT_Outside_BG1_Enable, REG_WINOUT_Outside_BG0_Enable,
                                2'b0, REG_WININ_Window_1_Special_Effect, REG_WININ_Window_1_OBJ_Enable,
                                REG_WININ_Window_1_BG3_Enable, REG_WININ_Window_1_BG2_Enable, 
                                REG_WININ_Window_1_BG1_Enable, REG_WININ_Window_1_BG0_Enable,
                                2'b0, REG_WININ_Window_0_Special_Effect, REG_WININ_Window_0_OBJ_Enable,
                                REG_WININ_Window_0_BG3_Enable, REG_WININ_Window_0_BG2_Enable,
                                REG_WININ_Window_0_BG1_Enable, REG_WININ_Window_0_BG0_Enable};
            MOSAIC.Adr:             // 04C
                reg_dout <= 32'hDEADDEAD; // {REG_MOSAIC_OBJ_Mosaic_V_Size, REG_MOSAIC_OBJ_Mosaic_H_Size,
                                // REG_MOSAIC_BG_Mosaic_V_Size, REG_MOSAIC_BG_Mosaic_H_Size};
            
            BLDCNT.Adr:             // 050
                reg_dout <= {3'b0, REG_BLDALPHA_EVB_Coefficient, 3'b0, REG_BLDALPHA_EVA_Coefficient, 
                                2'b0, REG_BLDCNT_BD_2nd_Target_Pixel, REG_BLDCNT_OBJ_2nd_Target_Pixel,
                                REG_BLDCNT_BG3_2nd_Target_Pixel, REG_BLDCNT_BG2_2nd_Target_Pixel,
                                REG_BLDCNT_BG1_2nd_Target_Pixel, REG_BLDCNT_BG0_2nd_Target_Pixel, 
                                REG_BLDCNT_Color_Special_Effect, REG_BLDCNT_BD_1st_Target_Pixel,
                                REG_BLDCNT_OBJ_1st_Target_Pixel, REG_BLDCNT_BG3_1st_Target_Pixel, 
                                REG_BLDCNT_BG2_1st_Target_Pixel, REG_BLDCNT_BG1_1st_Target_Pixel,
                                REG_BLDCNT_BG0_1st_Target_Pixel };

            BLDY.Adr:               // 054
                reg_dout <= 32'hDEADDEAD; // REG_BLDY;

            28'h58, 28'h5C:
                reg_dout <= 32'hDEADDEAD;

            default: reg_dout_en <= 0;

            endcase
        end
    end


    `ifndef VERILATOR
    vram_lo ivram_lo (
        .clka(mclk), .clkb(fclk), .reseta(1'b0), .resetb(1'b0),
        .cea(1'b1), .ocea(1'b1), .ceb(1'b1), .oceb(1'b1),
        
        .ada(VRAM_Lo_addr), .dina(VRAM_Lo_datain), .douta(VRAM_Lo_dataout), 
        .wrea(VRAM_Lo_we), .byte_ena(VRAM_Lo_be),
        
        .adb(VRAM_Drawer_addr_Lo), .dinb(32'b0), .doutb(VRAM_Drawer_data_Lo), 
        .wreb(1'b0), .byte_enb(4'b0)
    );

    vram_hi ivram_hi (
        .clka(mclk), .clkb(fclk), .reseta(1'b0), .resetb(1'b0),
        .cea(1'b1), .ocea(1'b1), .ceb(1'b1), .oceb(1'b1),
        
        .ada(VRAM_Hi_addr), .dina(VRAM_Hi_datain), .douta(VRAM_Hi_dataout), 
        .wrea(VRAM_Hi_we), .byte_ena(VRAM_Hi_be),
        
        .adb(VRAM_Drawer_addr_Hi), .dinb(32'b0), .doutb(VRAM_Drawer_data_Hi), 
        .wreb(1'b0), .byte_enb(4'b0)
    );
    `else
    sim_dpram_be #(32, 16*1024) ivram_lo (
        .clka(mclk), .clkb(fclk), .rst(1'b0),        
        .addra(VRAM_Lo_addr), .dina(VRAM_Lo_datain), .douta(VRAM_Lo_dataout),
        .wea(VRAM_Lo_we), .bea(VRAM_Lo_be), 
        .addrb(VRAM_Drawer_addr_Lo), .dinb(32'b0), .doutb(VRAM_Drawer_data_Lo),
        .web(1'b0), .beb(4'b0) 
    );
    // always @(posedge fclk) begin
    //     if (VRAM_Lo_we)
    //         $display("vram_lo[%x] <= %x", VRAM_Lo_addr, VRAM_Lo_datain);
    // end

    sim_dpram_be #(32, 8*1024) ivram_hi (
        .clka(mclk), .clkb(fclk), .rst(1'b0),        
        .addra(VRAM_Hi_addr), .dina(VRAM_Hi_datain), .douta(VRAM_Hi_dataout),
        .wea(VRAM_Hi_we), .bea(VRAM_Hi_be), 
        .addrb(VRAM_Drawer_addr_Hi), .dinb(32'b0), .doutb(VRAM_Drawer_data_Hi),
        .web(1'b0), .beb(4'b0)
    );
    // always @(posedge fclk) begin
    //     if (VRAM_Hi_we)
    //         $display("vram_hi[%x] <= %x", VRAM_Hi_addr, VRAM_Hi_datain);
    // end

    `endif

    // 4 x SyncRamDualNotPow2 #(8, 256)
    dpram32_block oamram (
        .clka(mclk), .clkb(fclk),

        .addr_a(OAMRAM_PROC_addr),
        .datain_a(OAMRAM_PROC_datain),
        .dataout_a(OAMRAM_PROC_dataout),
        .be_a(OAMRAM_PROC_we),
        .we_a(OAMRAM_PROC_we != 4'b0), .re_a(1'b1),
        
        .addr_b(OAMRAM_Drawer_addr),
        .datain_b(8'h00),
        .dataout_b(OAMRAM_Drawer_data),
        .be_b(4'b0), .we_b(1'b0), .re_b(1'b1)
    );
            

    // 4 x SyncRamDualNotPow2 #(8, 256) 
    dpram32_block oamram_hd0 (
        .clka(mclk), .clkb(fclk),

        .addr_a(OAMRAM_PROC_addr),
        .datain_a(OAMRAM_PROC_datain),
        .dataout_a(),
        .be_a(OAMRAM_PROC_we),
        .we_a(OAMRAM_PROC_we != 4'b0), .re_a(1'b0),
        
        .addr_b(OAMRAM_Drawer_addr_hd0),
        .datain_b(8'h00),
        .dataout_b(OAMRAM_Drawer_data_hd0),
        .be_b(4'b0), .we_b(1'b0), .re_b(1'b1)
    );
            
    // 4 x SyncRamDualNotPow2 #(8, 256)
    dpram32_block oamram_hd1 (
        .clka(mclk), .clkb(fclk),
        
        .addr_a(OAMRAM_PROC_addr),
        .datain_a(OAMRAM_PROC_datain),
        .dataout_a(),
        .be_a(OAMRAM_PROC_we),
        .we_a(OAMRAM_PROC_we != 4'b0), .re_a(1'b0),
        
        .addr_b(OAMRAM_Drawer_addr_hd1),
        .datain_b(8'h00),
        .dataout_b(OAMRAM_Drawer_data_hd1),
        .be_b(4'b0), .we_b(1'b0), .re_b(1'b1)
    );
            
    // 4 x SyncRamDualNotPow2 #(8, 128)
    dpram32_block paletteram_bg (
        .clka(mclk), .clkb(fclk),
        
        .addr_a(PALETTE_BG_addr[6:0]),
        .datain_a(PALETTE_BG_datain),
        .dataout_a(PALETTE_BG_dataout),
        .be_a(PALETTE_BG_we),
        .we_a(PALETTE_BG_we != 4'b0), .re_a(1'b1),
        
        .addr_b(PALETTE_BG_Drawer_addr),
        .datain_b(8'h00),
        .dataout_b(PALETTE_BG_Drawer_data),
        .be_b(4'b0), .we_b(1'b0), .re_b(1'b1)
    );
            
    // 4 x SyncRamDualNotPow2 #(8, 128)
    dpram32_block paletteram_oam (
        .clka(mclk), .clkb(fclk),
        
        .addr_a(PALETTE_OAM_addr[6:0]),
        .datain_a(PALETTE_OAM_datain),
        .dataout_a(PALETTE_OAM_dataout),
        .be_a(PALETTE_OAM_we),
        .we_a(PALETTE_OAM_we != 4'b0), .re_a(1'b1),
        
        .addr_b(PALETTE_OAM_Drawer_addr),
        .datain_b(8'h00),
        .dataout_b(PALETTE_OAM_Drawer_data),
        .be_b(4'b0), .we_b(1'b0), .re_b(1'b1)
    );
            
    // 4 x SyncRamDualNotPow2 #(8, 128)
    dpram32_block paletteram_oam_hd0 (
        .clka(mclk), .clkb(fclk),

        .addr_a(PALETTE_OAM_addr[6:0]),
        .datain_a(PALETTE_OAM_datain),
        .dataout_a(),
        .be_a(PALETTE_OAM_we),
        .we_a(PALETTE_OAM_we != 4'b0), .re_a(1'b0),
        
        .addr_b(PALETTE_OAM_Drawer_addr_hd0),
        .datain_b(8'h00),
        .dataout_b(PALETTE_OAM_Drawer_data_hd0),
        .be_b(4'b0), .we_b(1'b0), .re_b(1'b1)
    );

    // 4 x SyncRamDualNotPow2 #(8, 128)
    dpram32_block paletteram_oam_hd1 (
        .clka(mclk), .clkb(fclk),
        
        .addr_a(PALETTE_OAM_addr[6:0]),
        .datain_a(PALETTE_OAM_datain),
        .dataout_a(),
        .be_a(PALETTE_OAM_we),
        .we_a(PALETTE_OAM_we != 4'b0), .re_a(1'b0),
        
        .addr_b(PALETTE_OAM_Drawer_addr_hd1),
        .datain_b(8'h00),
        .dataout_b(PALETTE_OAM_Drawer_data_hd1),
        .be_b(4'b0), .we_b(1'b0), .re_b(1'b1)
    );
    
    gba_drawer_mode0 igba_drawer_mode0_0(
        .fclk(fclk),
        .drawline(drawline_mode0_0),
        .busy(busy_mode0_0),
        .lockspeed(lockspeed),
        .pixelpos(pixelpos),
        .ypos(linecounter_int),
        .ypos_mosaic(linecounter_mosaic_bg),
        .mapbase(REG_BG0CNT_Screen_Base_Block),
        .tilebase(REG_BG0CNT_Character_Base_Block),
        .hicolor(REG_BG0CNT_Colors_Palettes[BG0CNT_Colors_Palettes.upper]),
        .mosaic(REG_BG0CNT_Mosaic[BG0CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .screensize(REG_BG0CNT_Screen_Size),
        .scrollX((REG_BG0HOFS[8:0])),
        .scrollY((REG_BG0VOFS[24:16])),
        .pixel_we(pixel_we_mode0_0),
        .pixeldata(pixeldata_mode0_0),
        .pixel_x(pixel_x_mode0_0),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode0_0),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[0]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode0_0),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[0])
    );
    
    
    gba_drawer_mode0 igba_drawer_mode0_1(
        .fclk(fclk),
        .drawline(drawline_mode0_1),
        .busy(busy_mode0_1),
        .lockspeed(lockspeed),
        .pixelpos(pixelpos),
        .ypos(linecounter_int),
        .ypos_mosaic(linecounter_mosaic_bg),
        .mapbase(REG_BG1CNT_Screen_Base_Block),
        .tilebase(REG_BG1CNT_Character_Base_Block),
        .hicolor(REG_BG1CNT_Colors_Palettes[BG1CNT_Colors_Palettes.upper]),
        .mosaic(REG_BG1CNT_Mosaic[BG1CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .screensize(REG_BG1CNT_Screen_Size),
        .scrollX((REG_BG1HOFS[8:0])),
        .scrollY((REG_BG1VOFS[24:16])),
        .pixel_we(pixel_we_mode0_1),
        .pixeldata(pixeldata_mode0_1),
        .pixel_x(pixel_x_mode0_1),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode0_1),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[1]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode0_1),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[1])
    );
    
    
    gba_drawer_mode0 igba_drawer_mode0_2(
        .fclk(fclk),
        .drawline(drawline_mode0_2),
        .busy(busy_mode0_2),
        .lockspeed(lockspeed),
        .pixelpos(pixelpos),
        .ypos(linecounter_int),
        .ypos_mosaic(linecounter_mosaic_bg),
        .mapbase(REG_BG2CNT_Screen_Base_Block),
        .tilebase(REG_BG2CNT_Character_Base_Block),
        .hicolor(REG_BG2CNT_Colors_Palettes[BG2CNT_Colors_Palettes.upper]),
        .mosaic(REG_BG2CNT_Mosaic[BG2CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .screensize(REG_BG2CNT_Screen_Size),
        .scrollX((REG_BG2HOFS[8:0])),
        .scrollY((REG_BG2VOFS[24:16])),
        .pixel_we(pixel_we_mode0_2),
        .pixeldata(pixeldata_mode0_2),
        .pixel_x(pixel_x_mode0_2),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode0_2),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[2]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode0_2),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[2])
    );
    
    
    gba_drawer_mode0 igba_drawer_mode0_3(
        .fclk(fclk),
        .drawline(drawline_mode0_3),
        .busy(busy_mode0_3),
        .lockspeed(lockspeed),
        .pixelpos(pixelpos),
        .ypos(linecounter_int),
        .ypos_mosaic(linecounter_mosaic_bg),
        .mapbase(REG_BG3CNT_Screen_Base_Block),
        .tilebase(REG_BG3CNT_Character_Base_Block),
        .hicolor(REG_BG3CNT_Colors_Palettes[BG3CNT_Colors_Palettes.upper]),
        .mosaic(REG_BG3CNT_Mosaic[BG3CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .screensize(REG_BG3CNT_Screen_Size),
        .scrollX((REG_BG3HOFS[8:0])),
        .scrollY((REG_BG3VOFS[24:16])),
        .pixel_we(pixel_we_mode0_3),
        .pixeldata(pixeldata_mode0_3),
        .pixel_x(pixel_x_mode0_3),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode0_3),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[3]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode0_3),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[3])
    );
    
    
    gba_drawer_mode2 igba_drawer_mode2_2(
        .fclk(fclk),
        .line_trigger(line_trigger),
        .drawline(drawline_mode2_2),
        .busy(busy_mode2_2),
        .mapbase(REG_BG2CNT_Screen_Base_Block),
        .tilebase(REG_BG2CNT_Character_Base_Block),
        .screensize(REG_BG2CNT_Screen_Size),
        .wrapping(REG_BG2CNT_Display_Area_Overflow[BG2CNT_Display_Area_Overflow.upper]),
        .mosaic(REG_BG2CNT_Mosaic[BG2CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .refX(ref2_x),
        .refY(ref2_y),
        .refX_mosaic(mosaic_ref2_x),
        .refY_mosaic(mosaic_ref2_y),
        .dx(REG_BG2RotScaleParDX),
        .dy(REG_BG2RotScaleParDY),
        .pixel_we(pixel_we_mode2_2),
        .pixeldata(pixeldata_mode2_2),
        .pixel_x(pixel_x_mode2_2),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode2_2),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[2]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode2_2),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[2])
    );
    
    gba_drawer_mode2 #(17, 30, 480, 29) igba_drawer_mode2_2_hd0(
        .fclk(fclk),
        .line_trigger(line_trigger_1),
        .drawline(drawline_mode2_2_hd0),
        .busy(busy_mode2_2_hd0),
        .mapbase(REG_BG2CNT_Screen_Base_Block),
        .tilebase(REG_BG2CNT_Character_Base_Block),
        .screensize(REG_BG2CNT_Screen_Size),
        .wrapping(REG_BG2CNT_Display_Area_Overflow[BG2CNT_Display_Area_Overflow.upper]),
        .mosaic(REG_BG2CNT_Mosaic[BG2CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .refX(ref2_x_hd0),
        .refY(ref2_y_hd0),
        .refX_mosaic(mosaic_ref2_x),
        .refY_mosaic(mosaic_ref2_y),
        .dx(dx2_hd0),
        .dy(dy2_hd0),
        .pixel_we(pixel_we_mode2_2_hd0),
        .pixeldata(pixeldata_mode2_2_hd0),
        .pixel_x(pixel_x_mode2_2_hd0),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode2_2_hd0),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[2]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode2_2_hd0),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[2])
    );
    
    gba_drawer_mode2 #(17, 30, 480, 29) igba_drawer_mode2_2_hd1(
        .fclk(fclk),
        .line_trigger(line_trigger_1),
        .drawline(drawline_mode2_2_hd1),
        .busy(busy_mode2_2_hd1),
        .mapbase(REG_BG2CNT_Screen_Base_Block),
        .tilebase(REG_BG2CNT_Character_Base_Block),
        .screensize(REG_BG2CNT_Screen_Size),
        .wrapping(REG_BG2CNT_Display_Area_Overflow[BG2CNT_Display_Area_Overflow.upper]),
        .mosaic(REG_BG2CNT_Mosaic[BG2CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .refX(ref2_x_hd1),
        .refY(ref2_y_hd1),
        .refX_mosaic(mosaic_ref2_x),
        .refY_mosaic(mosaic_ref2_y),
        .dx(dx2_hd1),
        .dy(dy2_hd1),
        .pixel_we(pixel_we_mode2_2_hd1),
        .pixeldata(pixeldata_mode2_2_hd1),
        .pixel_x(pixel_x_mode2_2_hd1),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode2_2_hd1),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[3]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode2_2_hd1),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[3])
    );
    
    
    gba_drawer_mode2 igba_drawer_mode2_3(
        .fclk(fclk),
        .line_trigger(line_trigger),
        .drawline(drawline_mode2_3),
        .busy(busy_mode2_3),
        .mapbase(REG_BG3CNT_Screen_Base_Block),
        .tilebase(REG_BG3CNT_Character_Base_Block),
        .screensize(REG_BG3CNT_Screen_Size),
        .wrapping(REG_BG3CNT_Display_Area_Overflow[BG3CNT_Display_Area_Overflow.upper]),
        .mosaic(REG_BG2CNT_Mosaic[BG2CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .refX(ref3_x),
        .refY(ref3_y),
        .refX_mosaic(mosaic_ref3_x),
        .refY_mosaic(mosaic_ref3_y),
        .dx(REG_BG3RotScaleParDX),
        .dy(REG_BG3RotScaleParDY),
        .pixel_we(pixel_we_mode2_3),
        .pixeldata(pixeldata_mode2_3),
        .pixel_x(pixel_x_mode2_3),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode2_3),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[3]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode2_3),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[3])
    );
    
    gba_drawer_mode2 #(17, 30, 480, 29) igba_drawer_mode2_3_hd0(
        .fclk(fclk),
        .line_trigger(line_trigger_1),
        .drawline(drawline_mode2_3_hd0),
        .busy(busy_mode2_3_hd0),
        .mapbase(REG_BG3CNT_Screen_Base_Block),
        .tilebase(REG_BG3CNT_Character_Base_Block),
        .screensize(REG_BG3CNT_Screen_Size),
        .wrapping(REG_BG3CNT_Display_Area_Overflow[BG3CNT_Display_Area_Overflow.upper]),
        .mosaic(REG_BG3CNT_Mosaic[BG3CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .refX(ref3_x_hd0),
        .refY(ref3_y_hd0),
        .refX_mosaic(mosaic_ref3_x),
        .refY_mosaic(mosaic_ref3_y),
        .dx(dx3_hd0),
        .dy(dy3_hd0),
        .pixel_we(pixel_we_mode2_3_hd0),
        .pixeldata(pixeldata_mode2_3_hd0),
        .pixel_x(pixel_x_mode2_3_hd0),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode2_3_hd0),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[0]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode2_3_hd0),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[0])
    );
    
    gba_drawer_mode2 #(17, 30, 480, 29) igba_drawer_mode2_3_hd1(
        .fclk(fclk),
        .line_trigger(line_trigger_1),
        .drawline(drawline_mode2_3_hd1),
        .busy(busy_mode2_3_hd1),
        .mapbase(REG_BG3CNT_Screen_Base_Block),
        .tilebase(REG_BG3CNT_Character_Base_Block),
        .screensize(REG_BG3CNT_Screen_Size),
        .wrapping(REG_BG3CNT_Display_Area_Overflow[BG3CNT_Display_Area_Overflow.upper]),
        .mosaic(REG_BG3CNT_Mosaic[BG3CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .refX(ref3_x_hd1),
        .refY(ref3_y_hd1),
        .refX_mosaic(mosaic_ref3_x),
        .refY_mosaic(mosaic_ref3_y),
        .dx(dx3_hd1),
        .dy(dy3_hd1),
        .pixel_we(pixel_we_mode2_3_hd1),
        .pixeldata(pixeldata_mode2_3_hd1),
        .pixel_x(pixel_x_mode2_3_hd1),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode2_3_hd1),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[1]),
        .VRAM_Drawer_addr(VRAM_Drawer_addr_mode2_3_hd1),
        .VRAM_Drawer_data(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Lo[1])
    );
    
    
    gba_drawer_mode345 igba_drawer_mode345(
        .fclk(fclk),
        .BG_Mode(BG_Mode),
        .line_trigger(line_trigger),
        .drawline(drawline_mode345),
        .busy(busy_mode345),
        .second_frame(REG_DISPCNT_Display_Frame_Select[DISPCNT_Display_Frame_Select.upper]),
        .mosaic(REG_BG2CNT_Mosaic[BG2CNT_Mosaic.upper]),
        .Mosaic_H_Size(REG_MOSAIC_BG_Mosaic_H_Size),
        .refX(ref2_x),
        .refY(ref2_y),
        .refX_mosaic(mosaic_ref2_x),
        .refY_mosaic(mosaic_ref2_y),
        .dx(REG_BG2RotScaleParDX),
        .dy(REG_BG2RotScaleParDY),
        .pixel_we(pixel_we_mode345),
        .pixeldata(pixeldata_mode345),
        .pixel_x(pixel_x_mode345),
        .PALETTE_Drawer_addr(PALETTE_Drawer_addr_mode345),
        .PALETTE_Drawer_data(PALETTE_BG_Drawer_data),
        .PALETTE_Drawer_valid(PALETTE_BG_Drawer_valid[2]),
        .VRAM_Drawer_addr_Lo(VRAM_Drawer_addr_345_Lo),
        .VRAM_Drawer_addr_Hi(VRAM_Drawer_addr_345_Hi),
        .VRAM_Drawer_data_Lo(VRAM_Drawer_data_Lo),
        .VRAM_Drawer_data_Hi(VRAM_Drawer_data_Hi),
        .VRAM_Drawer_valid_Lo(VRAM_Drawer_valid_Lo[2]),
        .VRAM_Drawer_valid_Hi(VRAM_Drawer_valid_Hi[0])
    );
    
    
    gba_drawer_obj igba_drawer_obj(
        .fclk(fclk),
        
        .hblank(hblank_trigger),
        .lockspeed(lockspeed),
        .busy(busy_modeobj),
        
        .drawline(drawline_obj),
        .ypos(linecounter_int),
        .ypos_mosaic(linecounter_mosaic_obj),
        
        .BG_Mode(BG_Mode),
        .one_dim_mapping(REG_DISPCNT_OBJ_Char_VRAM_Map[DISPCNT_OBJ_Char_VRAM_Map.upper]),
        .Mosaic_H_Size(REG_MOSAIC_OBJ_Mosaic_H_Size),
        
        .hblankfree(REG_DISPCNT_H_Blank_IntervalFree[DISPCNT_H_Blank_IntervalFree.upper]),
        .maxpixels(maxpixels),
        
        .pixel_we_color(pixel_we_modeobj_color),
        .pixeldata_color(pixeldata_modeobj_color),
        .pixel_we_settings(pixel_we_modeobj_settings),
        .pixeldata_settings(pixeldata_modeobj_settings),
        .pixel_x(pixel_x_modeobj),
        .pixel_objwnd(pixel_objwnd),
        
        .OAMRAM_Drawer_addr(OAMRAM_Drawer_addr),
        .OAMRAM_Drawer_data(OAMRAM_Drawer_data),
        
        .PALETTE_Drawer_addr(PALETTE_OAM_Drawer_addr),
        .PALETTE_Drawer_data(PALETTE_OAM_Drawer_data),
        
        .VRAM_Drawer_addr(VRAM_Drawer_addrobj),
        .VRAM_Drawer_data(VRAM_Drawer_data_Hi),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Hi[1])
    );
    
    gba_drawer_obj #(2, 480) igba_drawer_obj_hd0(
        .fclk(fclk),
        
        .hblank(hblank_trigger),
        .lockspeed(lockspeed),
        .busy(busy_modeobj_hd0),
        
        .drawline(drawline_obj_hd0),
        .ypos(linecounter_int),
        .ypos_mosaic(linecounter_mosaic_obj),
        
        .BG_Mode(BG_Mode),
        .one_dim_mapping(REG_DISPCNT_OBJ_Char_VRAM_Map[DISPCNT_OBJ_Char_VRAM_Map.upper]),
        .Mosaic_H_Size(REG_MOSAIC_OBJ_Mosaic_H_Size),
        
        .hblankfree(REG_DISPCNT_H_Blank_IntervalFree[DISPCNT_H_Blank_IntervalFree.upper]),
        .maxpixels(maxpixels),
        
        .pixel_we_color(pixel_we_modeobj_color_hd0),
        .pixeldata_color(pixeldata_modeobj_color_hd0),
        .pixel_we_settings(pixel_we_modeobj_settings_hd0),
        .pixeldata_settings(pixeldata_modeobj_settings_hd0),
        .pixel_x(pixel_x_modeobj_hd0),
        .pixel_objwnd(pixel_objwnd_hd0),
        
        .OAMRAM_Drawer_addr(OAMRAM_Drawer_addr_hd0),
        .OAMRAM_Drawer_data(OAMRAM_Drawer_data_hd0),
        
        .PALETTE_Drawer_addr(PALETTE_OAM_Drawer_addr_hd0),
        .PALETTE_Drawer_data(PALETTE_OAM_Drawer_data_hd0),
        
        .VRAM_Drawer_addr(VRAM_Drawer_addrobj_hd0),
        .VRAM_Drawer_data(VRAM_Drawer_data_Hi),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Hi[1])
    );
    
    gba_drawer_obj #(2, 480, 1) igba_drawer_obj_hd1(
        .fclk(fclk),
        
        .hblank(hblank_trigger),
        .lockspeed(lockspeed),
        .busy(busy_modeobj_hd1),
        
        .drawline(drawline_obj_hd1),
        .ypos(linecounter_int),
        .ypos_mosaic(linecounter_mosaic_obj),
        
        .BG_Mode(BG_Mode),
        .one_dim_mapping(REG_DISPCNT_OBJ_Char_VRAM_Map[DISPCNT_OBJ_Char_VRAM_Map.upper]),
        .Mosaic_H_Size(REG_MOSAIC_OBJ_Mosaic_H_Size),
        
        .hblankfree(REG_DISPCNT_H_Blank_IntervalFree[DISPCNT_H_Blank_IntervalFree.upper]),
        .maxpixels(maxpixels),
        
        .pixel_we_color(pixel_we_modeobj_color_hd1),
        .pixeldata_color(pixeldata_modeobj_color_hd1),
        .pixel_we_settings(pixel_we_modeobj_settings_hd1),
        .pixeldata_settings(pixeldata_modeobj_settings_hd1),
        .pixel_x(pixel_x_modeobj_hd1),
        .pixel_objwnd(pixel_objwnd_hd1),
        
        .OAMRAM_Drawer_addr(OAMRAM_Drawer_addr_hd1),
        .OAMRAM_Drawer_data(OAMRAM_Drawer_data_hd1),
        
        .PALETTE_Drawer_addr(PALETTE_OAM_Drawer_addr_hd1),
        .PALETTE_Drawer_data(PALETTE_OAM_Drawer_data_hd1),
        
        .VRAM_Drawer_addr(VRAM_Drawer_addrobj_hd1),
        .VRAM_Drawer_data(VRAM_Drawer_data_Hi),
        .VRAM_Drawer_valid(VRAM_Drawer_valid_Hi[0])
    );
    
    assign drawline_mode0_0 = (BG_Mode == 3'b000 | BG_Mode == 3'b001) ? on_delay_bg0[2] & start_draw : 1'b0;
    assign drawline_mode0_1 = (BG_Mode == 3'b000 | BG_Mode == 3'b001) ? on_delay_bg1[2] & start_draw : 1'b0;
    assign drawline_mode0_2 = (BG_Mode == 3'b000) ? on_delay_bg2[2] & start_draw : 1'b0;
    assign drawline_mode0_3 = (BG_Mode == 3'b000) ? on_delay_bg3[2] & start_draw : 1'b0;
    assign drawline_mode2_2 = ((hdmode2x_bg == 1'b0 & (BG_Mode == 3'b001 | BG_Mode == 3'b010))) ? 
                                        on_delay_bg2[2] & start_draw : 1'b0;
    assign drawline_mode2_2_hd0 = ((hdmode2x_bg & (BG_Mode == 3'b001 | BG_Mode == 3'b010))) ? 
                                        on_delay_bg2[2] & start_draw : 1'b0;
    assign drawline_mode2_2_hd1 = ((hdmode2x_bg & (BG_Mode == 3'b001 | BG_Mode == 3'b010))) ? 
                                        on_delay_bg2[2] & start_draw : 1'b0;
    assign drawline_mode2_3 = ((hdmode2x_bg == 1'b0 & BG_Mode == 3'b010)) ? on_delay_bg3[2] & start_draw : 1'b0;
    assign drawline_mode2_3_hd0 = ((hdmode2x_bg & BG_Mode == 3'b010)) ? on_delay_bg3[2] & start_draw : 1'b0;
    assign drawline_mode2_3_hd1 = ((hdmode2x_bg & BG_Mode == 3'b010)) ? on_delay_bg3[2] & start_draw : 1'b0;
    assign drawline_mode345 = (BG_Mode == 3'b011 | BG_Mode == 3'b100 | BG_Mode == 3'b101) ? 
                                        on_delay_bg2[2] & start_draw : 1'b0;
    assign drawline_obj = (hdmode2x_obj == 1'b0) ? Screen_Display_OBJ[DISPCNT_Screen_Display_OBJ.upper] & start_draw : 1'b0;
    assign drawline_obj_hd0 = (hdmode2x_obj) ? Screen_Display_OBJ[DISPCNT_Screen_Display_OBJ.upper] & start_draw : 1'b0;
    assign drawline_obj_hd1 = (hdmode2x_obj & BG_Mode < 3) ? 
                                        Screen_Display_OBJ[DISPCNT_Screen_Display_OBJ.upper] & start_draw : 1'b0;
    
    assign PALETTE_BG_Drawer_addr0 = ((hdmode2x_bg & BG_Mode == 3'b010)) ? PALETTE_Drawer_addr_mode2_3_hd0 : PALETTE_Drawer_addr_mode0_0;
    assign PALETTE_BG_Drawer_addr1 = ((hdmode2x_bg & BG_Mode == 3'b010)) ? PALETTE_Drawer_addr_mode2_3_hd1 : PALETTE_Drawer_addr_mode0_1;
    assign PALETTE_BG_Drawer_addr2 = (BG_Mode == 3'b000) ? PALETTE_Drawer_addr_mode0_2 : 
                                     (((BG_Mode == 3'b001 | BG_Mode == 3'b010) & hdmode2x_bg == 1'b0)) ? PALETTE_Drawer_addr_mode2_2 : 
                                     (BG_Mode == 3'b001 | BG_Mode == 3'b010) ? PALETTE_Drawer_addr_mode2_2_hd0 : 
                                     PALETTE_Drawer_addr_mode345;
    assign PALETTE_BG_Drawer_addr3 = (BG_Mode == 3'b000) ? PALETTE_Drawer_addr_mode0_3 : 
                                     (hdmode2x_bg) ? PALETTE_Drawer_addr_mode2_2_hd1 : 
                                     PALETTE_Drawer_addr_mode2_3;
    
    assign VRAM_Drawer_addr0 = ((hdmode2x_bg & BG_Mode == 3'b010)) ? VRAM_Drawer_addr_mode2_3_hd0 : VRAM_Drawer_addr_mode0_0;
    assign VRAM_Drawer_addr1 = ((hdmode2x_bg & BG_Mode == 3'b010)) ? VRAM_Drawer_addr_mode2_3_hd1 : VRAM_Drawer_addr_mode0_1;
    assign VRAM_Drawer_addr2 = (BG_Mode == 3'b000) ? VRAM_Drawer_addr_mode0_2 : 
                               (((BG_Mode == 3'b001 | BG_Mode == 3'b010) & hdmode2x_bg == 1'b0)) ? VRAM_Drawer_addr_mode2_2 : 
                               (BG_Mode == 3'b001 | BG_Mode == 3'b010) ? VRAM_Drawer_addr_mode2_2_hd0 : 
                               VRAM_Drawer_addr_345_Lo;
    assign VRAM_Drawer_addr3 = (BG_Mode == 3'b000) ? VRAM_Drawer_addr_mode0_3 : 
                               (hdmode2x_bg) ? VRAM_Drawer_addr_mode2_2_hd1 : 
                               VRAM_Drawer_addr_mode2_3;
    
    assign busy_allmod[0] = busy_mode0_0;
    assign busy_allmod[1] = busy_mode0_1;
    assign busy_allmod[2] = busy_mode0_2;
    assign busy_allmod[3] = busy_mode0_3;
    assign busy_allmod[4] = busy_mode2_2 | busy_mode2_2_hd0 | busy_mode2_2_hd1;
    assign busy_allmod[5] = busy_mode2_3 | busy_mode2_3_hd0 | busy_mode2_3_hd1;
    assign busy_allmod[6] = busy_mode345;
    assign busy_allmod[7] = busy_modeobj | busy_modeobj_hd0 | busy_modeobj_hd1;
    
    // memory mapping
    always @(posedge mclk) begin
        if (PALETTE_BG_addr == 0 & PALETTE_BG_we[1])
            pixeldata_back_next <= PALETTE_BG_datain[15:0];        
    end


    always @(posedge fclk)
         begin
            
            bitmapdrawmode <= 1'b0;
            if (BG_Mode >= 3)
                bitmapdrawmode <= 1'b1;
            
            vram_block_mode <= 1'b0;
            if (BG_Mode == 2 & on_delay_bg2[2] & on_delay_bg3[2])
                vram_block_mode <= 1'b1;
            
            PALETTE_BG_Drawer_cnt <= PALETTE_BG_Drawer_cnt + 1;
            case (PALETTE_BG_Drawer_cnt)
                0 : begin
                        PALETTE_BG_Drawer_addr <= PALETTE_BG_Drawer_addr0;
                        PALETTE_BG_Drawer_valid <= 4'b1000;
                    end
                1 : begin
                        PALETTE_BG_Drawer_addr <= PALETTE_BG_Drawer_addr1;
                        PALETTE_BG_Drawer_valid <= 4'b0001;
                    end
                2 : begin
                        PALETTE_BG_Drawer_addr <= PALETTE_BG_Drawer_addr2;
                        PALETTE_BG_Drawer_valid <= 4'b0010;
                    end
                3 : begin
                        PALETTE_BG_Drawer_addr <= PALETTE_BG_Drawer_addr3;
                        PALETTE_BG_Drawer_valid <= 4'b0100;
                    end
                default : ;
            endcase
            
            VRAM_Drawer_cnt_Lo <= VRAM_Drawer_cnt_Lo + 1;
            case (VRAM_Drawer_cnt_Lo)
                0 : begin
                        VRAM_Drawer_addr_Lo <= VRAM_Drawer_addr0;
                        VRAM_Drawer_valid_Lo <= 4'b1000;
                    end
                1 : begin
                        VRAM_Drawer_addr_Lo <= VRAM_Drawer_addr1;
                        VRAM_Drawer_valid_Lo <= 4'b0001;
                    end
                2 : begin
                        VRAM_Drawer_addr_Lo <= VRAM_Drawer_addr2;
                        VRAM_Drawer_valid_Lo <= 4'b0010;
                    end
                3 : begin
                        VRAM_Drawer_addr_Lo <= VRAM_Drawer_addr3;
                        VRAM_Drawer_valid_Lo <= 4'b0100;
                    end
                default : ;
            endcase
            
            VRAM_Drawer_cnt_Hi <= (~VRAM_Drawer_cnt_Hi);
            case (VRAM_Drawer_cnt_Hi)
                1'b0: begin
                        VRAM_Drawer_valid_Hi <= 2'b10;
                        if (hdmode2x_obj & BG_Mode < 3)
                            VRAM_Drawer_addr_Hi <= VRAM_Drawer_addrobj_hd1;
                        else
                            VRAM_Drawer_addr_Hi <= VRAM_Drawer_addr_345_Hi;
                    end
                
                1'b1: begin
                        VRAM_Drawer_valid_Hi <= 2'b01;
                        if (hdmode2x_obj)
                            VRAM_Drawer_addr_Hi <= VRAM_Drawer_addrobj_hd0;
                        else
                            VRAM_Drawer_addr_Hi <= VRAM_Drawer_addrobj;
                    end
                default : ;
            endcase
            
            // wait with delete for 2 clock cycles
            clear_trigger_1 <= clear_trigger;
            if (clear_trigger_1) begin
                clear_addr <= 0;
                clear_enable <= 1'b1;
            end 
            
            if (clear_enable) begin
                if (((hdmode2x_bg | hdmode2x_obj) & clear_addr < 479) | (hdmode2x_bg == 1'b0 & hdmode2x_obj == 1'b0 & clear_addr < 239))
                    clear_addr <= clear_addr + 1;
                else
                    clear_enable <= 1'b0;
                
                pixel_we_bg0 <= 1'b1;
                pixel_we_bg1 <= 1'b1;
                pixel_we_bg2 <= 1'b1;
                pixel_we_bg2_hd0 <= 1'b1;
                pixel_we_bg2_hd1 <= 1'b1;
                pixel_we_bg3 <= 1'b1;
                pixel_we_bg3_hd0 <= 1'b1;
                pixel_we_bg3_hd1 <= 1'b1;
                pixel_we_obj_color <= 1'b1;
                pixel_we_obj_color_hd0 <= 1'b1;
                pixel_we_obj_color_hd1 <= 1'b1;
                pixel_we_obj_settings <= 1'b1;
                pixel_we_obj_settings_hd0 <= 1'b1;
                pixel_we_obj_settings_hd1 <= 1'b1;
                
                pixeldata_bg0 <= 16'h8000;
                pixeldata_bg1 <= 16'h8000;
                pixeldata_bg2 <= 16'h8000;
                pixeldata_bg2_hd0 <= 16'h8000;
                pixeldata_bg2_hd1 <= 16'h8000;
                pixeldata_bg3 <= 16'h8000;
                pixeldata_bg3_hd0 <= 16'h8000;
                pixeldata_bg3_hd1 <= 16'h8000;
                pixeldata_obj_color <= 16'h8000;
                pixeldata_obj_color_hd0 <= 16'h8000;
                pixeldata_obj_color_hd1 <= 16'h8000;
                pixeldata_obj_settings <= 3'b000;
                pixeldata_obj_settings_hd0 <= 3'b000;
                pixeldata_obj_settings_hd1 <= 3'b000;
                
                if (clear_addr <= 239) begin
                    pixel_x_bg0 <= clear_addr;
                    pixel_x_bg1 <= clear_addr;
                    pixel_x_bg2 <= clear_addr;
                    pixel_x_bg3 <= clear_addr;
                    pixel_x_obj <= clear_addr;
                end 
                
                pixel_x_bg2_hd0 <= clear_addr;
                pixel_x_bg2_hd1 <= clear_addr;
                pixel_x_bg3_hd0 <= clear_addr;
                pixel_x_bg3_hd1 <= clear_addr;
                pixel_x_obj_hd0 <= clear_addr;
                pixel_x_obj_hd1 <= clear_addr;
            end else begin
                
                pixel_we_bg0 <= pixel_we_mode0_0;
                pixel_we_bg1 <= pixel_we_mode0_1;
                pixel_we_obj_color <= pixel_we_modeobj_color;
                pixel_we_obj_color_hd0 <= pixel_we_modeobj_color_hd0;
                pixel_we_obj_color_hd1 <= pixel_we_modeobj_color_hd1;
                pixel_we_obj_settings <= pixel_we_modeobj_settings;
                pixel_we_obj_settings_hd0 <= pixel_we_modeobj_settings_hd0;
                pixel_we_obj_settings_hd1 <= pixel_we_modeobj_settings_hd1;
                
                pixeldata_bg0 <= pixeldata_mode0_0;
                pixeldata_bg1 <= pixeldata_mode0_1;
                pixeldata_obj_color <= pixeldata_modeobj_color;
                pixeldata_obj_color_hd0 <= pixeldata_modeobj_color_hd0;
                pixeldata_obj_color_hd1 <= pixeldata_modeobj_color_hd1;
                pixeldata_obj_settings <= pixeldata_modeobj_settings;
                pixeldata_obj_settings_hd0 <= pixeldata_modeobj_settings_hd0;
                pixeldata_obj_settings_hd1 <= pixeldata_modeobj_settings_hd1;
                
                pixel_x_bg0 <= pixel_x_mode0_0;
                pixel_x_bg1 <= pixel_x_mode0_1;
                pixel_x_obj <= pixel_x_modeobj;
                pixel_x_obj_hd0 <= pixel_x_modeobj_hd0;
                pixel_x_obj_hd1 <= pixel_x_modeobj_hd1;
                
                if (BG_Mode == 3'b000) begin
                    pixel_we_bg2 <= pixel_we_mode0_2;
                    pixeldata_bg2 <= pixeldata_mode0_2;
                    pixel_x_bg2 <= pixel_x_mode0_2;
                end else if (BG_Mode == 3'b001 | BG_Mode == 3'b010) begin
                    pixel_we_bg2 <= pixel_we_mode2_2;
                    pixel_we_bg2_hd0 <= pixel_we_mode2_2_hd0;
                    pixel_we_bg2_hd1 <= pixel_we_mode2_2_hd1;
                    pixeldata_bg2 <= pixeldata_mode2_2;
                    pixeldata_bg2_hd0 <= pixeldata_mode2_2_hd0;
                    pixeldata_bg2_hd1 <= pixeldata_mode2_2_hd1;
                    pixel_x_bg2 <= pixel_x_mode2_2;
                    pixel_x_bg2_hd0 <= pixel_x_mode2_2_hd0;
                    pixel_x_bg2_hd1 <= pixel_x_mode2_2_hd1;
                end else begin
                    pixel_we_bg2 <= pixel_we_mode345;
                    pixeldata_bg2 <= pixeldata_mode345;
                    pixel_x_bg2 <= pixel_x_mode345;
                end
                
                if (BG_Mode == 3'b000) begin
                    pixel_we_bg3 <= pixel_we_mode0_3;
                    pixeldata_bg3 <= pixeldata_mode0_3;
                    pixel_x_bg3 <= pixel_x_mode0_3;
                end else begin
                    pixel_we_bg3 <= pixel_we_mode2_3;
                    pixel_we_bg3_hd0 <= pixel_we_mode2_3_hd0;
                    pixel_we_bg3_hd1 <= pixel_we_mode2_3_hd1;
                    pixeldata_bg3 <= pixeldata_mode2_3;
                    pixeldata_bg3_hd0 <= pixeldata_mode2_3_hd0;
                    pixeldata_bg3_hd1 <= pixeldata_mode2_3_hd1;
                    pixel_x_bg3 <= pixel_x_mode2_3;
                    pixel_x_bg3_hd0 <= pixel_x_mode2_3_hd0;
                    pixel_x_bg3_hd1 <= pixel_x_mode2_3_hd1;
                end
            end
        end 
    
    // line buffers
    // SyncRamDual #(16, 8) ilinebuffer_bg0(
    //     .clk(fclk),
    dpram_block #(16, 8) ilinebuffer_bg0(
        .clka(fclk), .clkb(fclk),

        .addr_a(pixel_x_bg0),
        .datain_a(pixeldata_bg0),
        .dataout_a(),
        .we_a(pixel_we_bg0),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr),
        .datain_b(16'h0000),
        .dataout_b(linebuffer_bg0_data),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 8) ilinebuffer_bg1(
    //     .clk(fclk),
    dpram_block #(16, 8) ilinebuffer_bg1(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_bg1),
        .datain_a(pixeldata_bg1),
        .dataout_a(),
        .we_a(pixel_we_bg1),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr),
        .datain_b(16'h0000),
        .dataout_b(linebuffer_bg1_data),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 8) ilinebuffer_bg2(
    //     .clk(fclk),
    dpram_block #(16, 8) ilinebuffer_bg2(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_bg2),
        .datain_a(pixeldata_bg2),
        .dataout_a(),
        .we_a(pixel_we_bg2),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr),
        .datain_b(16'h0000),
        .dataout_b(linebuffer_bg2_data),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 9) ilinebuffer_bg2_hd0(
    //     .clk(fclk),
    dpram_block #(16, 9) ilinebuffer_bg2_hd0(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_bg2_hd0),
        .datain_a(pixeldata_bg2_hd0),
        .dataout_a(),
        .we_a(pixel_we_bg2_hd0),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr_hd),
        .datain_b(16'h0000),
        .dataout_b(linebuffer_bg2_data_hd0),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 9) ilinebuffer_bg2_hd1(
    //     .clk(fclk),
    dpram_block #(16, 9) ilinebuffer_bg2_hd1(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_bg2_hd1),
        .datain_a(pixeldata_bg2_hd1),
        .dataout_a(),
        .we_a(pixel_we_bg2_hd1),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr_hd),
        .datain_b(16'h0000),
        .dataout_b(linebuffer_bg2_data_hd1),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 8) ilinebuffer_bg3(
    //     .clk(fclk),
    dpram_block #(16, 8) ilinebuffer_bg3(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_bg3),
        .datain_a(pixeldata_bg3),
        .dataout_a(),
        .we_a(pixel_we_bg3),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr),
        .datain_b(16'h0000),
        .dataout_b(linebuffer_bg3_data),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 9) ilinebuffer_bg3_hd0(
    //     .clk(fclk),
    dpram_block #(16, 9) ilinebuffer_bg3_hd0(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_bg3_hd0),
        .datain_a(pixeldata_bg3_hd0),
        .dataout_a(),
        .we_a(pixel_we_bg3_hd0),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr_hd),
        .datain_b(16'h0000),
        .dataout_b(linebuffer_bg3_data_hd0),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 9) ilinebuffer_bg3_hd1(
    //     .clk(fclk),
    dpram_block #(16, 9) ilinebuffer_bg3_hd1(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_bg3_hd1),
        .datain_a(pixeldata_bg3_hd1),
        .dataout_a(),
        .we_a(pixel_we_bg3_hd1),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr_hd),
        .datain_b(16'h0000),
        .dataout_b(linebuffer_bg3_data_hd1),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 8) ilinebuffer_obj_color(
    //     .clk(fclk),
    dpram_block #(16, 8) ilinebuffer_obj_color(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_obj),
        .datain_a(pixeldata_obj_color),
        .dataout_a(),
        .we_a(pixel_we_obj_color),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr),
        .datain_b(16'b0),
        .dataout_b(linebuffer_obj_color),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 9) ilinebuffer_obj_color_hd0(
    //     .clk(fclk),
    dpram_block #(16, 9) ilinebuffer_obj_color_hd0(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_obj_hd0),
        .datain_a(pixeldata_obj_color_hd0),
        .dataout_a(),
        .we_a(pixel_we_obj_color_hd0),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr_hd),
        .datain_b(16'b0),
        .dataout_b(linebuffer_obj_color_hd0),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(16, 9) ilinebuffer_obj_color_hd1(
    //     .clk(fclk),
    dpram_block #(16, 9) ilinebuffer_obj_color_hd1(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_obj_hd1),
        .datain_a(pixeldata_obj_color_hd1),
        .dataout_a(),
        .we_a(pixel_we_obj_color_hd1),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr_hd),
        .datain_b(16'b0),
        .dataout_b(linebuffer_obj_color_hd1),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    
    // SyncRamDual #(3, 8) ilinebuffer_obj_settings(
    //     .clk(fclk),
    dpram_block #(4, 9) ilinebuffer_obj_settings(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_obj),
        .datain_a(pixeldata_obj_settings),
        .dataout_a(),
        .we_a(pixel_we_obj_settings),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr),
        .datain_b(3'b0),
        .dataout_b(linebuffer_obj_setting),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(3, 9) ilinebuffer_obj_settings_hd0(
    //     .clk(fclk),
    dpram_block #(4, 9) ilinebuffer_obj_settings_hd0(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_obj_hd0),
        .datain_a(pixeldata_obj_settings_hd0),
        .dataout_a(),
        .we_a(pixel_we_obj_settings_hd0),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr_hd),
        .datain_b(3'b0),
        .dataout_b(linebuffer_obj_setting_hd0),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    // SyncRamDual #(3, 9) ilinebuffer_obj_settings_hd1(
    //     .clk(fclk),
    dpram_block #(4, 9) ilinebuffer_obj_settings_hd1(
        .clka(fclk), .clkb(fclk),
        
        .addr_a(pixel_x_obj_hd1),
        .datain_a(pixeldata_obj_settings_hd1),
        .dataout_a(),
        .we_a(pixel_we_obj_settings_hd1),
        .re_a(1'b0),
        
        .addr_b(linebuffer_addr_hd),
        .datain_b(3'b0),
        .dataout_b(linebuffer_obj_setting_hd1),
        .we_b(1'b0),
        .re_b(1'b1)
    );
    
    assign linebuffer_obj_data = {linebuffer_obj_setting, linebuffer_obj_color};
    assign linebuffer_obj_data_hd0 = {linebuffer_obj_setting_hd0, linebuffer_obj_color_hd0};
    assign linebuffer_obj_data_hd1 = {linebuffer_obj_setting_hd1, linebuffer_obj_color_hd1};
    
    // line buffer readout
    always @(posedge fclk)
         begin
            
            if (pixel_objwnd)
                linebuffer_objwindow[pixel_x_obj] <= 1'b1;
            if (pixel_objwnd_hd0)
                linebuffer_objwindow_hd0[pixel_x_obj_hd0] <= 1'b1;
            if (pixel_objwnd_hd1)
                linebuffer_objwindow_hd1[pixel_x_obj_hd1] <= 1'b1;
            
            // if (linecounter < 160)
                nextLineDrawn <= lineUpToDate[linecounter];
            
            if (hblank_trigger) begin
                if (Screen_Display_BG0[DISPCNT_Screen_Display_BG0.upper] == 1'b0)
                    on_delay_bg0 <= {3{1'b0}};
                if (Screen_Display_BG1[DISPCNT_Screen_Display_BG1.upper] == 1'b0)
                    on_delay_bg1 <= {3{1'b0}};
                if (Screen_Display_BG2[DISPCNT_Screen_Display_BG2.upper] == 1'b0)
                    on_delay_bg2 <= {3{1'b0}};
                if (Screen_Display_BG3[DISPCNT_Screen_Display_BG3.upper] == 1'b0)
                    on_delay_bg3 <= {3{1'b0}};
            end 
            
            if (drawline | newline_invsync) begin
                if (Screen_Display_BG0[DISPCNT_Screen_Display_BG0.upper])
                    on_delay_bg0 <= {on_delay_bg0[1:0], 1'b1};
                if (Screen_Display_BG1[DISPCNT_Screen_Display_BG1.upper])
                    on_delay_bg1 <= {on_delay_bg1[1:0], 1'b1};
                if (Screen_Display_BG2[DISPCNT_Screen_Display_BG2.upper])
                    on_delay_bg2 <= {on_delay_bg2[1:0], 1'b1};
                if (Screen_Display_BG3[DISPCNT_Screen_Display_BG3.upper])
                    on_delay_bg3 <= {on_delay_bg3[1:0], 1'b1};
            end 
            
            drawline_1 <= drawline;
            hblank_trigger_1 <= hblank_trigger;
            start_draw <= 1'b0;
            
            // count and track if all lines have been drawn for fastforward mode
            if (vblank_trigger) begin
                if (linesDrawn == 160)
                    lineUpToDate <= {160{1'b0}};
                linesDrawn <= 0;
            end 
            if (drawline_1 & linesDrawn < 160 & (drawstate == tdrawstate_IDLE | nextLineDrawn))
                linesDrawn <= linesDrawn + 1;
            
            clear_trigger <= 1'b0;
            
            pixelmult <= ~pixelmult;
            
            case (drawstate)
                tdrawstate_IDLE :
                    if (drawline_1 & linesDrawn < 160) begin
                        if (nextLineDrawn == 1'b0) begin
                            drawstate <= tdrawstate_WAITHBLANK;
                            start_draw <= 1'b1;
                            linecounter_int <= linecounter;
                            lineUpToDate[linecounter] <= 1'b1;
                            linebuffer_objwindow <= {240{1'b0}};
                            linebuffer_objwindow_hd0 <= {480{1'b0}};
                            linebuffer_objwindow_hd1 <= {480{1'b0}};
                        end 
                    end 
                
                tdrawstate_WAITHBLANK :
                    if (hblank_trigger)
                        drawstate <= tdrawstate_DRAWING;
                
                tdrawstate_DRAWING :
                    if (busy_allmod == 8'h00) begin
                        drawstate <= tdrawstate_MERGING;
                        linebuffer_addr <= 0;
                        linebuffer_addr_hd <= 0;
                        pixelmult <= 1'b0;
                        merge_enable <= 1'b1;
                        if (hdmode2x_bg == 1'b0 & hdmode2x_obj == 1'b0)
                            clear_trigger <= 1'b1;
                    end 
                
                tdrawstate_MERGING :
                    begin
                        if (linebuffer_addr_hd < 479)
                            linebuffer_addr_hd <= linebuffer_addr_hd + 1;
                        if (pixelmult | (hdmode2x_bg == 1'b0 & hdmode2x_obj == 1'b0)) begin
                            if (linebuffer_addr < 239) begin
                                linebuffer_addr <= linebuffer_addr + 1;
                                if ((hdmode2x_bg | hdmode2x_obj) & linebuffer_addr == 120)
                                    clear_trigger <= 1'b1;
                            end else begin
                                merge_enable <= 1'b0;
                                drawstate <= tdrawstate_IDLE;
                            end
                        end 
                    end
            endcase
            
            linebuffer_addr_1 <= linebuffer_addr;
            merge_enable_1 <= merge_enable;
            
            objwindow_merge <= linebuffer_objwindow[linebuffer_addr];
            objwindow_merge_hd0 <= linebuffer_objwindow_hd0[linebuffer_addr_hd];
            objwindow_merge_hd1 <= linebuffer_objwindow_hd1[linebuffer_addr_hd];
            
            //merger 1   
            // cycle 1
            pixel_out_x_1 <= merge_pixel_x;
            pixel_out_y_1 <= merge_pixel_y;
            pixelout_addr_1 <= merge_pixel_x + merge_pixel_y * 240;
            if (frameselect == 1'b0 | interframe_blend != 2'b10)
                merge_pixel_we_1 <= merge_pixel_we;
            if (Forced_Blank)
                merge_pixeldata_out_1 <= 16'h7FFF;
            else
                merge_pixeldata_out_1 <= {1'b0, merge_pixeldata_out[4:0], merge_pixeldata_out[9:5], merge_pixeldata_out[14:10]};
            
            // cycle 2
            if (merge_pixel_we_1)
                PixelArraySmooth[pixelout_addr_1] <= merge_pixeldata_out_1[14:0];
            pixel_smooth <= PixelArraySmooth[pixelout_addr_1];
            
            pixel_out_x_2 <= pixel_out_x_1;
            pixel_out_y_2 <= pixel_out_y_1;
            pixelout_addr_2 <= pixelout_addr_1;
            merge_pixel_we_2 <= merge_pixel_we_1;
            merge_pixeldata_out_2 <= merge_pixeldata_out_1;
            
            // cycle 3
            pixel_out_x <= pixel_out_x_2;
            pixel_out_y <= pixel_out_y_2;
            pixel_out_addr <= pixelout_addr_2;
            pixel_out_we <= merge_pixel_we_2;
            if (Forced_Blank)
                pixel_out_data <= {3'b111, 12'hFFF};
            else if (interframe_blend == 2'b01) begin
                pixel_out_data[14:10] <= (((((merge_pixeldata_out_2[14:10])) + ((pixel_smooth[14:10])))/2));
                pixel_out_data[9:5] <= (((((merge_pixeldata_out_2[9:5])) + ((pixel_smooth[9:5])))/2));
                pixel_out_data[4:0] <= (((((merge_pixeldata_out_2[4:0])) + ((pixel_smooth[4:0])))/2));
            end 
            else
                pixel_out_data <= merge_pixeldata_out_2[14:0];
            
            //merger 2   
            if (pixelmult == 1'b0) begin
                pixel_out_2x <= pixel_out_x_2 * 2;
                pixel2_out_x <= merge2_pixel_x * 2;
            end else begin
                pixel_out_2x <= pixel_out_x_2 * 2 + 1;
                pixel2_out_x <= merge2_pixel_x * 2 + 1;
            end
            
            if (frameselect == 1'b0 | interframe_blend != 2'b10)
                pixel2_out_we <= merge2_pixel_we;
            if (Forced_Blank)
                pixel2_out_data <= {3'b111, 12'hFFF};
            else
                pixel2_out_data <= {merge2_pixeldata_out[4:0], merge2_pixeldata_out[9:5], merge2_pixeldata_out[14:10]};
        end 
    
    assign enables_wnd0 = {REG_WININ_Window_0_Special_Effect, REG_WININ_Window_0_OBJ_Enable, REG_WININ_Window_0_BG3_Enable, REG_WININ_Window_0_BG2_Enable, REG_WININ_Window_0_BG1_Enable, REG_WININ_Window_0_BG0_Enable};
    assign enables_wnd1 = {REG_WININ_Window_1_Special_Effect, REG_WININ_Window_1_OBJ_Enable, REG_WININ_Window_1_BG3_Enable, REG_WININ_Window_1_BG2_Enable, REG_WININ_Window_1_BG1_Enable, REG_WININ_Window_1_BG0_Enable};
    assign enables_wndobj = {REG_WINOUT_Objwnd_Special_Effect, REG_WINOUT_Objwnd_OBJ_Enable, REG_WINOUT_Objwnd_BG3_Enable, REG_WINOUT_Objwnd_BG2_Enable, REG_WINOUT_Objwnd_BG1_Enable, REG_WINOUT_Objwnd_BG0_Enable};
    assign enables_wndout = {REG_WINOUT_Outside_Special_Effect, REG_WINOUT_Outside_OBJ_Enable, REG_WINOUT_Outside_BG3_Enable, REG_WINOUT_Outside_BG2_Enable, REG_WINOUT_Outside_BG1_Enable, REG_WINOUT_Outside_BG0_Enable};
    
    assign merge_in_bg2 = ((hdmode2x_bg == 1'b0 | BG_Mode == 3'b000 | BG_Mode > 2)) ? linebuffer_bg2_data : 
                          linebuffer_bg2_data_hd0;
    assign merge_in_bg3 = ((hdmode2x_bg == 1'b0 | BG_Mode != 3'b010)) ? linebuffer_bg3_data : 
                          linebuffer_bg3_data_hd0;
    assign merge_in_obj = (hdmode2x_obj == 1'b0) ? linebuffer_obj_data : 
                          linebuffer_obj_data_hd0;
    
    assign objwindow_merge_in = (hdmode2x_obj == 1'b0) ? objwindow_merge : 
                                objwindow_merge_hd0;
    
    
    gba_drawer_merge igba_drawer_merge(
        .fclk(fclk),
        
        .enable(merge_enable_1),
        .hblank(hblank_trigger_1),		// delayed 1 cycle because background is switched off at hblank                  
        .xpos(linebuffer_addr_1),
        .ypos(linecounter_int),
        
        .in_wnd0_on(REG_DISPCNT_Window_0_Display_Flag[DISPCNT_Window_0_Display_Flag.upper]),
        .in_wnd1_on(REG_DISPCNT_Window_1_Display_Flag[DISPCNT_Window_1_Display_Flag.upper]),
        .in_wndobj_on(REG_DISPCNT_OBJ_Wnd_Display_Flag[DISPCNT_OBJ_Wnd_Display_Flag.upper]),
        
        .in_wnd0_x1(REG_WIN0H_X1),
        .in_wnd0_x2(REG_WIN0H_X2),
        .in_wnd0_y1(REG_WIN0V_Y1),
        .in_wnd0_y2(REG_WIN0V_Y2),
        .in_wnd1_x1(REG_WIN1H_X1),
        .in_wnd1_x2(REG_WIN1H_X2),
        .in_wnd1_y1(REG_WIN1V_Y1),
        .in_wnd1_y2(REG_WIN1V_Y2),
        
        .in_enables_wnd0(enables_wnd0),
        .in_enables_wnd1(enables_wnd1),
        .in_enables_wndobj(enables_wndobj),
        .in_enables_wndout(enables_wndout),
        
        .in_special_effect_in(REG_BLDCNT_Color_Special_Effect),
        .in_effect_1st_bg0(REG_BLDCNT_BG0_1st_Target_Pixel[BLDCNT_BG0_1st_Target_Pixel.upper]),
        .in_effect_1st_bg1(REG_BLDCNT_BG1_1st_Target_Pixel[BLDCNT_BG1_1st_Target_Pixel.upper]),
        .in_effect_1st_bg2(REG_BLDCNT_BG2_1st_Target_Pixel[BLDCNT_BG2_1st_Target_Pixel.upper]),
        .in_effect_1st_bg3(REG_BLDCNT_BG3_1st_Target_Pixel[BLDCNT_BG3_1st_Target_Pixel.upper]),
        .in_effect_1st_obj(REG_BLDCNT_OBJ_1st_Target_Pixel[BLDCNT_OBJ_1st_Target_Pixel.upper]),
        .in_effect_1st_bd(REG_BLDCNT_BD_1st_Target_Pixel[BLDCNT_BD_1st_Target_Pixel.upper]),
        .in_effect_2nd_bg0(REG_BLDCNT_BG0_2nd_Target_Pixel[BLDCNT_BG0_2nd_Target_Pixel.upper]),
        .in_effect_2nd_bg1(REG_BLDCNT_BG1_2nd_Target_Pixel[BLDCNT_BG1_2nd_Target_Pixel.upper]),
        .in_effect_2nd_bg2(REG_BLDCNT_BG2_2nd_Target_Pixel[BLDCNT_BG2_2nd_Target_Pixel.upper]),
        .in_effect_2nd_bg3(REG_BLDCNT_BG3_2nd_Target_Pixel[BLDCNT_BG3_2nd_Target_Pixel.upper]),
        .in_effect_2nd_obj(REG_BLDCNT_OBJ_2nd_Target_Pixel[BLDCNT_OBJ_2nd_Target_Pixel.upper]),
        .in_effect_2nd_bd(REG_BLDCNT_BD_2nd_Target_Pixel[BLDCNT_BD_2nd_Target_Pixel.upper]),
        
        .in_prio_bg0(REG_BG0CNT_BG_Priority),
        .in_prio_bg1(REG_BG1CNT_BG_Priority),
        .in_prio_bg2(REG_BG2CNT_BG_Priority),
        .in_prio_bg3(REG_BG3CNT_BG_Priority),
        
        .in_eva(REG_BLDALPHA_EVA_Coefficient),
        .in_evb(REG_BLDALPHA_EVB_Coefficient),
        .in_bldy(REG_BLDY),
        
        .in_ena_bg0(on_delay_bg0[2]),
        .in_ena_bg1(on_delay_bg1[2]),
        .in_ena_bg2(on_delay_bg2[2]),
        .in_ena_bg3(on_delay_bg3[2]),
        .in_ena_obj(Screen_Display_OBJ[DISPCNT_Screen_Display_OBJ.upper]),
        
        .pixeldata_bg0(linebuffer_bg0_data),
        .pixeldata_bg1(linebuffer_bg1_data),
        .pixeldata_bg2(merge_in_bg2),
        .pixeldata_bg3(merge_in_bg3),
        .pixeldata_obj(merge_in_obj),
        .pixeldata_back(pixeldata_back),
        .objwindow_in(objwindow_merge_in),
        
        .pixeldata_out(merge_pixeldata_out),
        .pixel_x(merge_pixel_x),
        .pixel_y(merge_pixel_y),
        .pixel_we(merge_pixel_we)
    );
    
    assign merge2_in_bg2 = ((hdmode2x_bg == 1'b0 | BG_Mode == 3'b000 | BG_Mode > 2)) ? linebuffer_bg2_data : 
                           linebuffer_bg2_data_hd1;
    assign merge2_in_bg3 = ((hdmode2x_bg == 1'b0 | BG_Mode != 3'b010)) ? linebuffer_bg3_data : 
                           linebuffer_bg3_data_hd1;
    assign merge2_in_obj = (hdmode2x_obj == 1'b0) ? linebuffer_obj_data : 
                           (BG_Mode < 3) ? linebuffer_obj_data_hd1 : 
                           linebuffer_obj_data_hd0;
    
    assign objwindow_merge2_in = (hdmode2x_obj == 1'b0) ? objwindow_merge : 
                                 (BG_Mode < 3) ? objwindow_merge_hd1 : 
                                 objwindow_merge_hd0;
    
    
    gba_drawer_merge igba_drawer_merge2(
        .fclk(fclk),
        
        .enable(merge_enable_1),
        .hblank(hblank_trigger_1),		// delayed 1 cycle because background is switched off at hblank                  
        .xpos(linebuffer_addr_1),
        .ypos(linecounter_int),
        
        .in_wnd0_on(REG_DISPCNT_Window_0_Display_Flag[DISPCNT_Window_0_Display_Flag.upper]),
        .in_wnd1_on(REG_DISPCNT_Window_1_Display_Flag[DISPCNT_Window_1_Display_Flag.upper]),
        .in_wndobj_on(REG_DISPCNT_OBJ_Wnd_Display_Flag[DISPCNT_OBJ_Wnd_Display_Flag.upper]),
        
        .in_wnd0_x1(REG_WIN0H_X1),
        .in_wnd0_x2(REG_WIN0H_X2),
        .in_wnd0_y1(REG_WIN0V_Y1),
        .in_wnd0_y2(REG_WIN0V_Y2),
        .in_wnd1_x1(REG_WIN1H_X1),
        .in_wnd1_x2(REG_WIN1H_X2),
        .in_wnd1_y1(REG_WIN1V_Y1),
        .in_wnd1_y2(REG_WIN1V_Y2),
        
        .in_enables_wnd0(enables_wnd0),
        .in_enables_wnd1(enables_wnd1),
        .in_enables_wndobj(enables_wndobj),
        .in_enables_wndout(enables_wndout),
        
        .in_special_effect_in(REG_BLDCNT_Color_Special_Effect),
        .in_effect_1st_bg0(REG_BLDCNT_BG0_1st_Target_Pixel[BLDCNT_BG0_1st_Target_Pixel.upper]),
        .in_effect_1st_bg1(REG_BLDCNT_BG1_1st_Target_Pixel[BLDCNT_BG1_1st_Target_Pixel.upper]),
        .in_effect_1st_bg2(REG_BLDCNT_BG2_1st_Target_Pixel[BLDCNT_BG2_1st_Target_Pixel.upper]),
        .in_effect_1st_bg3(REG_BLDCNT_BG3_1st_Target_Pixel[BLDCNT_BG3_1st_Target_Pixel.upper]),
        .in_effect_1st_obj(REG_BLDCNT_OBJ_1st_Target_Pixel[BLDCNT_OBJ_1st_Target_Pixel.upper]),
        .in_effect_1st_bd(REG_BLDCNT_BD_1st_Target_Pixel[BLDCNT_BD_1st_Target_Pixel.upper]),
        .in_effect_2nd_bg0(REG_BLDCNT_BG0_2nd_Target_Pixel[BLDCNT_BG0_2nd_Target_Pixel.upper]),
        .in_effect_2nd_bg1(REG_BLDCNT_BG1_2nd_Target_Pixel[BLDCNT_BG1_2nd_Target_Pixel.upper]),
        .in_effect_2nd_bg2(REG_BLDCNT_BG2_2nd_Target_Pixel[BLDCNT_BG2_2nd_Target_Pixel.upper]),
        .in_effect_2nd_bg3(REG_BLDCNT_BG3_2nd_Target_Pixel[BLDCNT_BG3_2nd_Target_Pixel.upper]),
        .in_effect_2nd_obj(REG_BLDCNT_OBJ_2nd_Target_Pixel[BLDCNT_OBJ_2nd_Target_Pixel.upper]),
        .in_effect_2nd_bd(REG_BLDCNT_BD_2nd_Target_Pixel[BLDCNT_BD_2nd_Target_Pixel.upper]),
        
        .in_prio_bg0(REG_BG0CNT_BG_Priority),
        .in_prio_bg1(REG_BG1CNT_BG_Priority),
        .in_prio_bg2(REG_BG2CNT_BG_Priority),
        .in_prio_bg3(REG_BG3CNT_BG_Priority),
        
        .in_eva(REG_BLDALPHA_EVA_Coefficient),
        .in_evb(REG_BLDALPHA_EVB_Coefficient),
        .in_bldy(REG_BLDY),
        
        .in_ena_bg0(on_delay_bg0[2]),
        .in_ena_bg1(on_delay_bg1[2]),
        .in_ena_bg2(on_delay_bg2[2]),
        .in_ena_bg3(on_delay_bg3[2]),
        .in_ena_obj(Screen_Display_OBJ[DISPCNT_Screen_Display_OBJ.upper]),
        
        .pixeldata_bg0(linebuffer_bg0_data),
        .pixeldata_bg1(linebuffer_bg1_data),
        .pixeldata_bg2(merge2_in_bg2),
        .pixeldata_bg3(merge2_in_bg3),
        .pixeldata_obj(merge2_in_obj),
        .pixeldata_back(pixeldata_back),
        .objwindow_in(objwindow_merge2_in),
        
        .pixeldata_out(merge2_pixeldata_out),
        .pixel_x(merge2_pixel_x),
        .pixel_y(),
        .pixel_we(merge2_pixel_we)
    );
    
    // affine + mosaik
    always @(posedge fclk)
         begin
            
            // ref point written
            if (refpoint_update | ref2_x_written) begin
                ref2_x <= (REG_BG2RefX);
                mosaic_ref2_x <= (REG_BG2RefX);
            end 
            if (refpoint_update | ref2_y_written) begin
                ref2_y <= (REG_BG2RefY);
                mosaic_ref2_y <= (REG_BG2RefY);
            end 
            if (refpoint_update | ref3_x_written) begin
                ref3_x <= (REG_BG3RefX);
                mosaic_ref3_x <= (REG_BG3RefX);
            end 
            if (refpoint_update | ref3_y_written) begin
                ref3_y <= (REG_BG3RefY);
                mosaic_ref3_y <= (REG_BG3RefY);
            end 
            
            // hd d(m)x/y
            if (drawline_mode2_2_hd0 & (REG_BG2RotScaleParDX > 0 | REG_BG2RotScaleParDY > 0)) begin
                new_dx2 <= 1'b0;
                new_dy2 <= 1'b0;
                if (new_dx2) begin
                    dx2_last <= (REG_BG2RotScaleParDX);
                    dy2_last <= (REG_BG2RotScaleParDY);
                end 
            end 
            if (drawline_mode2_3_hd0 & (REG_BG3RotScaleParDX > 0 | REG_BG3RotScaleParDY > 0)) begin
                new_dx3 <= 1'b0;
                new_dy3 <= 1'b0;
                if (new_dx3) begin
                    dx3_last <= (REG_BG3RotScaleParDX);
                    dy3_last <= (REG_BG3RotScaleParDY);
                end 
            end 
            
            line_trigger_1 <= line_trigger;
            if (line_trigger) begin
                ref2_x_last <= ref2_x;
                if (new_dx2)
                    ref2_x_hd0 <= {ref2_x, 1'b0};
                else
                    ref2_x_hd0 <= 29'(ref2_x_last) + 29'(ref2_x);
                ref2_x_hd1 <= {ref2_x, 1'b0};
                
                ref2_y_last <= ref2_y;
                if (new_dy2)
                    ref2_y_hd0 <= {ref2_y, 1'b0};
                else
                    ref2_y_hd0 <= 29'(ref2_y_last) + 29'(ref2_y);
                ref2_y_hd1 <= {ref2_y, 1'b0};
                
                ref3_x_last <= ref3_x;
                if (new_dx3)
                    ref3_x_hd0 <= {ref3_x, 1'b0};
                else
                    ref3_x_hd0 <= 29'(ref3_x_last) + 29'(ref3_x);
                ref3_x_hd1 <= {ref3_x, 1'b0};
                
                ref3_y_last <= ref3_y;
                if (new_dy3)
                    ref3_y_hd0 <= {ref3_y, 1'b0};
                else
                    ref3_y_hd0 <= 29'(ref3_y_last) + 29'(ref3_y);
                ref3_y_hd1 <= {ref3_y, 1'b0};
            end 
            
            if (drawline) begin
                dx2_last <= signed'(REG_BG2RotScaleParDX);
                if (new_dx2)
                    dx2_hd0 <= {signed'(REG_BG2RotScaleParDX), 1'b0};
                else
                    dx2_hd0 <= dx2_last + signed'(REG_BG2RotScaleParDX);
                dx2_hd1 <= {REG_BG2RotScaleParDX, 1'b0};
                
                dy2_last <= REG_BG2RotScaleParDY;
                if (new_dy2)
                    dy2_hd0 <= {REG_BG2RotScaleParDY, 1'b0};
                else
                    dy2_hd0 <= dy2_last + signed'(REG_BG2RotScaleParDY);
                dy2_hd1 <= {signed'(REG_BG2RotScaleParDY), 1'b0};
                
                dx3_last <= signed'(REG_BG3RotScaleParDX);
                if (new_dx3)
                    dx3_hd0 <= {signed'(REG_BG3RotScaleParDX), 1'b0};
                else
                    dx3_hd0 <= dx3_last + signed'(REG_BG3RotScaleParDX);
                dx3_hd1 <= {signed'(REG_BG3RotScaleParDX), 1'b0};
                
                dy3_last <= signed'(REG_BG3RotScaleParDY);
                if (new_dy3)
                    dy3_hd0 <= {signed'(REG_BG3RotScaleParDY), 1'b0};
                else
                    dy3_hd0 <= dy3_last + signed'(REG_BG3RotScaleParDY);
                dy3_hd1 <= {signed'(REG_BG3RotScaleParDY), 1'b0};
            end 
            
            if (hblank_trigger) begin
                
                pixeldata_back <= pixeldata_back_next;
                
                if (BG_Mode != 3'd0 & on_delay_bg2[2]) begin
                    ref2_x <= ref2_x + signed'(REG_BG2RotScaleParDMX);
                    ref2_y <= ref2_y + signed'(REG_BG2RotScaleParDMY);
                end 
                if (BG_Mode == 3'd2 & on_delay_bg3[2]) begin
                    ref3_x <= ref3_x + signed'(REG_BG3RotScaleParDMX);
                    ref3_y <= ref3_y + signed'(REG_BG3RotScaleParDMY);
                end 
            end 
            
            if (vblank_trigger) begin
                mosaik_vcnt_bg <= 0;
                mosaik_vcnt_obj <= 0;
                linecounter_mosaic_bg <= 0;
                linecounter_mosaic_obj <= 0;
                new_dx2 <= 1'b1;
                new_dy2 <= 1'b1;
                new_dx3 <= 1'b1;
                new_dy3 <= 1'b1;
                if (interframe_blend == 2'b10)		// by toggling only when option is on, even/odd picture can be selected with multiple switch on/off
                    frameselect <= (~frameselect);
            end else if (hblank_trigger_1) begin
                
                // background
                if (mosaik_vcnt_bg >= REG_MOSAIC_BG_Mosaic_V_Size) begin
                    mosaik_vcnt_bg <= 0;
                    if (linecounter < 159)
                        linecounter_mosaic_bg <= linecounter + 1;
                    mosaic_ref2_x <= ref2_x;
                    mosaic_ref2_y <= ref2_y;
                    mosaic_ref3_x <= ref3_x;
                    mosaic_ref3_y <= ref3_y;
                end else
                    mosaik_vcnt_bg <= mosaik_vcnt_bg + 1;
                
                // sprite
                if (mosaik_vcnt_obj >= REG_MOSAIC_OBJ_Mosaic_V_Size) begin
                    mosaik_vcnt_obj <= 0;
                    if (linecounter < 159)
                        linecounter_mosaic_obj <= linecounter + 1;
                end else
                    mosaik_vcnt_obj <= mosaik_vcnt_obj + 1;
            end 
        end 
    
endmodule
`undef pproc_bus_gba
`undef preg_gba_display
