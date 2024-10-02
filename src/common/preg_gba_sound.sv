
`ifndef preg_gba_sound
`define preg_gba_sound

`include "pproc_bus_gba.sv"

// range 0x60 .. 0xA8
// (                                                   adr      upper    lower    size   default   accesstype)
localparam regmap_type SOUND1CNT_L                              = '{28'h060,   6,  0, 1, 0, readwrite}; // Channel 1 Sweep register       (NR10)   
localparam regmap_type SOUND1CNT_L_Number_of_sweep_shift        = '{28'h060,   2,  0, 1, 0, readwrite}; // 0-2   R/W  (n=0-7)
localparam regmap_type SOUND1CNT_L_Sweep_Frequency_Direction    = '{28'h060,   3,  3, 1, 0, readwrite}; // 3     R/W  (0=Increase, 1=Decrease)
localparam regmap_type SOUND1CNT_L_Sweep_Time                   = '{28'h060,   6,  4, 1, 0, readwrite}; // 4-6   R/W  units of 7.8ms (0-7, min=7.8ms, max=54.7ms)
                                          
localparam regmap_type SOUND1CNT_H                              = '{28'h060,  31, 16, 1, 0, writeonly}; // Channel 1 Duty/Length/Envelope (NR11, NR12)  
localparam regmap_type SOUND1CNT_H_Sound_length                 = '{28'h060,  21, 16, 1, 0, writeonly}; // 0-5   W    units of (64-n)/256s  (0-63)
localparam regmap_type SOUND1CNT_H_Wave_Pattern_Duty            = '{28'h060,  23, 22, 1, 0, readwrite}; // 6-7   R/W  (0-3, see below)
localparam regmap_type SOUND1CNT_H_Envelope_Step_Time           = '{28'h060,  26, 24, 1, 0, readwrite}; // 8-10  R/W  units of n/64s  (1-7, 0=No Envelope)
localparam regmap_type SOUND1CNT_H_Envelope_Direction           = '{28'h060,  27, 27, 1, 0, readwrite}; // 11    R/W  (0=Decrease, 1=Increase)
localparam regmap_type SOUND1CNT_H_Initial_Volume_of_envelope   = '{28'h060,  31, 28, 1, 0, readwrite}; // 12-15 R/W  (1-15, 0=No Sound)

localparam regmap_type SOUND1CNT_X                              = '{28'h064,  15,  0, 1, 0, writeonly}; // Channel 1 Frequency/Control    (NR13, NR14)  
localparam regmap_type SOUND1CNT_X_Frequency                    = '{28'h064,  10,  0, 1, 0, writeDone}; // 0-10  W    131072/(2048-n)Hz  (0-2047)  
localparam regmap_type SOUND1CNT_X_Length_Flag                  = '{28'h064,  14, 14, 1, 0, readwrite}; // 14    R/W  (1=Stop output when length in NR11 expires)  
localparam regmap_type SOUND1CNT_X_Initial                      = '{28'h064,  15, 15, 1, 0, writeonly}; // 15    W    (1=Restart Sound)                        

localparam regmap_type SOUND1CNT_XHighZero                      = '{28'h064,  31, 16, 1, 0, readonly}; // must return zero                                

localparam regmap_type SOUND2CNT_L                              = '{28'h068,  15,  0, 1, 0, writeonly}; // Channel 2 Duty/Length/Envelope (NR21, NR22) 
localparam regmap_type SOUND2CNT_L_Sound_length                 = '{28'h068,   5,  0, 1, 0, writeDone}; // 0-5   W    units of (64-n)/256s  (0-63)
localparam regmap_type SOUND2CNT_L_Wave_Pattern_Duty            = '{28'h068,   7,  6, 1, 0, readwrite}; // 6-7   R/W  (0-3, see below)
localparam regmap_type SOUND2CNT_L_Envelope_Step_Time           = '{28'h068,  10,  8, 1, 0, readwrite}; // 8-10  R/W  units of n/64s  (1-7, 0=No Envelope)
localparam regmap_type SOUND2CNT_L_Envelope_Direction           = '{28'h068,  11, 11, 1, 0, readwrite}; // 11    R/W  (0=Decrease, 1=Increase)
localparam regmap_type SOUND2CNT_L_Initial_Volume_of_envelope   = '{28'h068,  15, 12, 1, 0, readwrite}; // 12-15 R/W  (1-15, 0=No Sound)

localparam regmap_type SOUND2CNT_H                              = '{28'h06C,  15,  0, 1, 0, writeonly}; // Channel 2 Frequency/Control    (NR23, NR24)
localparam regmap_type SOUND2CNT_H_Frequency                    = '{28'h06C,  10,  0, 1, 0, writeDone}; // 0-10  W    131072/(2048-n)Hz  (0-2047)  
localparam regmap_type SOUND2CNT_H_Length_Flag                  = '{28'h06C,  14, 14, 1, 0, readwrite}; // 14    R/W  (1=Stop output when length in NR11 expires)  
localparam regmap_type SOUND2CNT_H_Initial                      = '{28'h06C,  15, 15, 1, 0, writeonly}; // 15    W    (1=Restart Sound)                        

localparam regmap_type SOUND2CNT_HHighZero                      = '{28'h06C,  31, 16, 1, 0, readonly }; // must return zero                                

localparam regmap_type SOUND3CNT_L                              = '{28'h070,  15,  0, 1, 0, writeonly}; // Channel 3 Stop/Wave RAM select (NR30)  
localparam regmap_type SOUND3CNT_L_Wave_RAM_Dimension           = '{28'h070,   5,  5, 1, 0, readwrite}; // 5     R/W   (0=One bank/32 digits, 1=Two banks/64 digits)
localparam regmap_type SOUND3CNT_L_Wave_RAM_Bank_Number         = '{28'h070,   6,  6, 1, 0, readwrite}; // 6     R/W   (0-1, see below)
localparam regmap_type SOUND3CNT_L_Sound_Channel_3_Off          = '{28'h070,   7,  7, 1, 0, readwrite}; // 7     R/W   (0=Stop, 1=Playback)  

localparam regmap_type SOUND3CNT_H                              = '{28'h070,  31, 16, 1, 0, writeonly}; // Channel 3 Length/Volume        (NR31, NR32)  
localparam regmap_type SOUND3CNT_H_Sound_length                 = '{28'h070,  23, 16, 1, 0, writeonly}; // 0-7   W   units of (256-n)/256s  (0-255)
localparam regmap_type SOUND3CNT_H_Sound_Volume                 = '{28'h070,  30, 29, 1, 0, readwrite}; // 13-14 R/W (0=Mute/Zero, 1=100%, 2=50%, 3=25%)
localparam regmap_type SOUND3CNT_H_Force_Volume                 = '{28'h070,  31, 31, 1, 0, readwrite}; // 15    R/W (0=Use above, 1=Force 75% regardless of above)

localparam regmap_type SOUND3CNT_X                              = '{28'h074,  15,  0, 1, 0, writeonly}; // Channel 3 Frequency/Control    (NR33, NR34)  
localparam regmap_type SOUND3CNT_X_Sample_Rate                  = '{28'h074,  10,  0, 1, 0, writeDone}; // 0-10  W   2097152/(2048-n) Hz   (0-2047)
localparam regmap_type SOUND3CNT_X_Length_Flag                  = '{28'h074,  14, 14, 1, 0, readwrite}; // 14    R/W (1=Stop output when length in NR31 expires)
localparam regmap_type SOUND3CNT_X_Initial                      = '{28'h074,  15, 15, 1, 0, writeonly}; // 15    W   (1=Restart Sound)regmap_type 
localparam regmap_type SOUND3CNT_XHighZero                      = '{28'h074,  31, 16, 1, 0, readonly }; // must return zero                                 

localparam regmap_type SOUND4CNT_L                              = '{28'h078,  15,  0, 1, 0, writeonly}; // Channel 4 Length/Envelope      (NR41, NR42)  
localparam regmap_type SOUND4CNT_L_Sound_length                 = '{28'h078,   5,  0, 1, 0, writeDone}; // 0-5   W    units of (64-n)/256s  (0-63)
localparam regmap_type SOUND4CNT_L_Envelope_Step_Time           = '{28'h078,  10,  8, 1, 0, readwrite}; // 8-10  R/W  units of n/64s  (1-7, 0=No Envelope)
localparam regmap_type SOUND4CNT_L_Envelope_Direction           = '{28'h078,  11, 11, 1, 0, readwrite}; // 11    R/W  (0=Decrease, 1=Increase)
localparam regmap_type SOUND4CNT_L_Initial_Volume_of_envelope   = '{28'h078,  15, 12, 1, 0, readwrite}; // 12-15 R/W  (1-15, 0=No Sound)

localparam regmap_type SOUND4CNT_LHighZero                      = '{28'h078,  31, 16, 1, 0, readonly }; // must return zero                                 

localparam regmap_type SOUND4CNT_H                              = '{28'h07C,  15,  0, 1, 0, writeonly}; // Channel 4 Frequency/Control    (NR43, NR44)  
localparam regmap_type SOUND4CNT_H_Dividing_Ratio_of_Freq       = '{28'h07C,   2,  0, 1, 0, readwrite}; // 0-2   R/W   (r)     524288 Hz / r / 2^(s+1) ;For r=0 assume r=0.5 instead
localparam regmap_type SOUND4CNT_H_Counter_Step_Width           = '{28'h07C,   3,  3, 1, 0, readwrite}; // 3     R/W   (0=15 bits, 1=7 bits)
localparam regmap_type SOUND4CNT_H_Shift_Clock_Frequency        = '{28'h07C,   7,  4, 1, 0, readwrite}; // 4-7   R/W   (s)     524288 Hz / r / 2^(s+1) ;For r=0 assume r=0.5 instead
localparam regmap_type SOUND4CNT_H_Length_Flag                  = '{28'h07C,  14, 14, 1, 0, readwrite}; // 14    R/W   (1=Stop output when length in NR41 expires)
localparam regmap_type SOUND4CNT_H_Initial                      = '{28'h07C,  15, 15, 1, 0, writeonly}; // 15    W     (1=Restart Sound)regmap_type 
localparam regmap_type SOUND4CNT_HHighZero                      = '{28'h07C,  31, 16, 1, 0, readonly }; // must return zero                                  

localparam regmap_type SOUNDCNT_L                               = '{28'h080,  15,  0, 1, 0, writeonly}; // Control Stereo/Volume/Enable   (NR50, NR51)  
localparam regmap_type SOUNDCNT_L_Sound_1_4_Master_Volume_RIGHT = '{28'h080,   2,  0, 1, 0, readwrite}; // 0-2    (0-7)
localparam regmap_type SOUNDCNT_L_Sound_1_4_Master_Volume_LEFT  = '{28'h080,   6,  4, 1, 0, readwrite}; // 4-6    (0-7)
localparam regmap_type SOUNDCNT_L_Sound_1_Enable_Flags_RIGHT    = '{28'h080,   8,  8, 1, 0, readwrite}; // 8-11   (each Bit 8-11, 0=Disable, 1=Enable)
localparam regmap_type SOUNDCNT_L_Sound_2_Enable_Flags_RIGHT    = '{28'h080,   9,  9, 1, 0, readwrite}; // 8-11   (each Bit 8-11, 0=Disable, 1=Enable)
localparam regmap_type SOUNDCNT_L_Sound_3_Enable_Flags_RIGHT    = '{28'h080,  10, 10, 1, 0, readwrite}; // 8-11   (each Bit 8-11, 0=Disable, 1=Enable)
localparam regmap_type SOUNDCNT_L_Sound_4_Enable_Flags_RIGHT    = '{28'h080,  11, 11, 1, 0, readwrite}; // 8-11   (each Bit 8-11, 0=Disable, 1=Enable)
localparam regmap_type SOUNDCNT_L_Sound_1_Enable_Flags_LEFT     = '{28'h080,  12, 12, 1, 0, readwrite}; // 12-15  (each Bit 12-15, 0=Disable, 1=Enable)
localparam regmap_type SOUNDCNT_L_Sound_2_Enable_Flags_LEFT     = '{28'h080,  13, 13, 1, 0, readwrite}; // 12-15  (each Bit 12-15, 0=Disable, 1=Enable)
localparam regmap_type SOUNDCNT_L_Sound_3_Enable_Flags_LEFT     = '{28'h080,  14, 14, 1, 0, readwrite}; // 12-15  (each Bit 12-15, 0=Disable, 1=Enable)
localparam regmap_type SOUNDCNT_L_Sound_4_Enable_Flags_LEFT     = '{28'h080,  15, 15, 1, 0, readwrite}; // 12-15  (each Bit 12-15, 0=Disable, 1=Enable)

localparam regmap_type SOUNDCNT_H                               = '{28'h080,  31, 16, 1, 0, readwrite}; // Control Mixing/DMA Control  
localparam regmap_type SOUNDCNT_H_Sound_1_4_Volume              = '{28'h080,  17, 16, 1, 0, readwrite}; // 0-1   Sound # 1-4 Volume   (0=25%, 1=50%, 2=100%, 3=Prohibited)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_A_Volume            = '{28'h080,  18, 18, 1, 0, readwrite}; // 2     DMA Sound A Volume   (0=50%, 1=100%)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_B_Volume            = '{28'h080,  19, 19, 1, 0, readwrite}; // 3     DMA Sound B Volume   (0=50%, 1=100%)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_A_Enable_RIGHT      = '{28'h080,  24, 24, 1, 0, readwrite}; // 8     DMA Sound A Enable RIGHT (0=Disable, 1=Enable)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_A_Enable_LEFT       = '{28'h080,  25, 25, 1, 0, readwrite}; // 9     DMA Sound A Enable LEFT  (0=Disable, 1=Enable)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_A_Timer_Select      = '{28'h080,  26, 26, 1, 0, readwrite}; // 10    DMA Sound A Timer Select (0=Timer 0, 1=Timer 1)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_A_Reset_FIFO        = '{28'h080,  27, 27, 1, 0, readwrite}; // 11    DMA Sound A Reset FIFO   (1=Reset)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_B_Enable_RIGHT      = '{28'h080,  28, 28, 1, 0, readwrite}; // 12    DMA Sound B Enable RIGHT (0=Disable, 1=Enable)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_B_Enable_LEFT       = '{28'h080,  29, 29, 1, 0, readwrite}; // 13    DMA Sound B Enable LEFT  (0=Disable, 1=Enable)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_B_Timer_Select      = '{28'h080,  30, 30, 1, 0, readwrite}; // 14    DMA Sound B Timer Select (0=Timer 0, 1=Timer 1)  
localparam regmap_type SOUNDCNT_H_DMA_Sound_B_Reset_FIFO        = '{28'h080,  31, 31, 1, 0, readwrite}; // 15    DMA Sound B Reset FIFO   (1=Reset)  

localparam regmap_type SOUNDCNT_X                               = '{28'h084,   7,  0, 1, 0, readwrite}; // Control Sound on/off           (NR52)   
localparam regmap_type SOUNDCNT_X_Sound_1_ON_flag               = '{28'h084,   0,  0, 1, 0, readonly }; // 0 (Read Only) 
localparam regmap_type SOUNDCNT_X_Sound_2_ON_flag               = '{28'h084,   1,  1, 1, 0, readonly }; // 1 (Read Only) 
localparam regmap_type SOUNDCNT_X_Sound_3_ON_flag               = '{28'h084,   2,  2, 1, 0, readonly }; // 2 (Read Only) 
localparam regmap_type SOUNDCNT_X_Sound_4_ON_flag               = '{28'h084,   3,  3, 1, 0, readonly }; // 3 (Read Only) 
localparam regmap_type SOUNDCNT_X_PSG_FIFO_Master_Enable        = '{28'h084,   7,  7, 1, 0, readwrite}; // 7 (0=Disable, 1=Enable) (Read/Write) 

localparam regmap_type SOUNDCNT_XHighZero                       = '{28'h084,  31, 16, 1, 0, readonly }; // must return zero                                  

localparam regmap_type SOUNDBIAS                                = '{28'h088,  15,  0, 1, 32'h0200, readwrite}; // Sound PWM Control (R/W)
localparam regmap_type SOUNDBIAS_Bias_Level                     = '{28'h088,   9,  0, 1, 32'h0200, readwrite}; // 0-9    (Default=200h, converting signed samples into unsigned) 
localparam regmap_type SOUNDBIAS_Amp_Res_Sampling_Cycle         = '{28'h088,  15, 14, 1,  0, readwrite}; // 14-15  (Default=0, see below) regmap_type 
localparam regmap_type SOUNDBIAS_HighZero                       = '{28'h088,  31, 16, 1,  0, readonly }; // must return zero                                  regmap_type 
localparam regmap_type WAVE_RAM                                 = '{28'h090,  31,  0, 4,  0, readwrite}; // Channel 3 Wave Pattern RAM (2 banks!!)
localparam regmap_type WAVE_RAM2                                = '{28'h094,  31,  0, 1,  0, readwrite}; // Channel 3 Wave Pattern RAM (2 banks!!)
localparam regmap_type WAVE_RAM3                                = '{28'h098,  31,  0, 1,  0, readwrite}; // Channel 3 Wave Pattern RAM (2 banks!!)
localparam regmap_type WAVE_RAM4                                = '{28'h09C,  31,  0, 1,  0, readwrite}; // Channel 3 Wave Pattern RAM (2 banks!!)regmap_type 
localparam regmap_type FIFO_A                                   = '{28'h0A0,  31,  0, 1,  0, writeonly}; // Channel A FIFO, Data 0-3  
localparam regmap_type FIFO_B                                   = '{28'h0A4,  31,  0, 1,  0, writeonly}; // Channel B FIFO, Data 0-3  

`endif
