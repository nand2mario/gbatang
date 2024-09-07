
`ifndef preg_gba_dma
`define preg_gba_dma

`include "pproc_bus_gba.sv"

// range 0xB0 .. 0xE0
//   (                                       adr     upper    lower    size   default   accesstype)                                     
localparam regmap_type DMA0SAD                      = '{28'hB0,  31,      0,        1,        0,   writeonly}; // Source Address       4    W  
localparam regmap_type DMA0DAD                      = '{28'hB4,  31,      0,        1,        0,   writeonly}; // Destination Address  4    W  
localparam regmap_type DMA0CNT_L                    = '{28'hB8,  15,      0,        1,        0,   writeDone}; // Word Count           2    W  
localparam regmap_type DMA0CNT_H                    = '{28'hB8,  31,     16,        1,        0,   writeonly}; // Control              2    R/W
localparam regmap_type DMA0CNT_H_Dest_Addr_Control  = '{28'hB8,  22,     21,        1,        0,   readwrite}; // 5-6   Dest Addr Control  (0=Increment,1=Decrement,2=Fixed,3=Increment/Reload)
localparam regmap_type DMA0CNT_H_Source_Adr_Control = '{28'hB8,  24,     23,        1,        0,   readwrite}; // 7-8   Source Adr Control (0=Increment,1=Decrement,2=Fixed,3=Prohibited)
localparam regmap_type DMA0CNT_H_DMA_Repeat         = '{28'hB8,  25,     25,        1,        0,   readwrite}; // 9     DMA Repeat                   (0=Off, 1=On) (Must be zero if Bit 11 set)
localparam regmap_type DMA0CNT_H_DMA_Transfer_Type  = '{28'hB8,  26,     26,        1,        0,   readwrite}; // 10    DMA Transfer Type            (0=16bit, 1=32bit)
localparam regmap_type DMA0CNT_H_DMA_Start_Timing   = '{28'hB8,  29,     28,        1,        0,   readwrite}; // 12-13 DMA Start Timing  (0=Immediately, 1=VBlank, 2=HBlank, 3=Special) The 'Special' setting (Start Timing=3) depends on the DMA channel: DMA0=Prohibited, DMA1/DMA2=Sound FIFO, DMA3=Video Capture
localparam regmap_type DMA0CNT_H_IRQ_on             = '{28'hB8,  30,     30,        1,        0,   readwrite}; // 14    IRQ upon end of Word Count   (0=Disable, 1=Enable)
localparam regmap_type DMA0CNT_H_DMA_Enable         = '{28'hB8,  31,     31,        1,        0,   readwrite}; // 15    DMA Enable                   (0=Off, 1=On)
  
localparam regmap_type DMA1SAD                      = '{28'hBC,  31,      0,        1,        0,   writeonly}; // Source Address       4    W  
localparam regmap_type DMA1DAD                      = '{28'hC0,  31,      0,        1,        0,   writeonly}; // Destination Address  4    W  
localparam regmap_type DMA1CNT_L                    = '{28'hC4,  15,      0,        1,        0,   writeDone}; // Word Count           2    W  
localparam regmap_type DMA1CNT_H                    = '{28'hC4,  31,     16,        1,        0,   writeonly}; // Control              2    R/W
localparam regmap_type DMA1CNT_H_Dest_Addr_Control  = '{28'hC4,  22,     21,        1,        0,   readwrite}; // 5-6   Dest Addr Control  (0=Increment,1=Decrement,2=Fixed,3=Increment/Reload)
localparam regmap_type DMA1CNT_H_Source_Adr_Control = '{28'hC4,  24,     23,        1,        0,   readwrite}; // 7-8   Source Adr Control (0=Increment,1=Decrement,2=Fixed,3=Prohibited)
localparam regmap_type DMA1CNT_H_DMA_Repeat         = '{28'hC4,  25,     25,        1,        0,   readwrite}; // 9     DMA Repeat                   (0=Off, 1=On) (Must be zero if Bit 11 set)
localparam regmap_type DMA1CNT_H_DMA_Transfer_Type  = '{28'hC4,  26,     26,        1,        0,   readwrite}; // 10    DMA Transfer Type            (0=16bit, 1=32bit)
localparam regmap_type DMA1CNT_H_DMA_Start_Timing   = '{28'hC4,  29,     28,        1,        0,   readwrite}; // 12-13 DMA Start Timing  (0=Immediately, 1=VBlank, 2=HBlank, 3=Special) The 'Special' setting (Start Timing=3) depends on the DMA channel: DMA0=Prohibited, DMA1/DMA2=Sound FIFO, DMA3=Video Capture
localparam regmap_type DMA1CNT_H_IRQ_on             = '{28'hC4,  30,     30,        1,        0,   readwrite}; // 14    IRQ upon end of Word Count   (0=Disable, 1=Enable)
localparam regmap_type DMA1CNT_H_DMA_Enable         = '{28'hC4,  31,     31,        1,        0,   readwrite}; // 15    DMA Enable                   (0=Off, 1=On)
  
localparam regmap_type DMA2SAD                      = '{28'hC8,  31,      0,        1,        0,   writeonly}; // Source Address       4    W  
localparam regmap_type DMA2DAD                      = '{28'hCC,  31,      0,        1,        0,   writeonly}; // Destination Address  4    W  
localparam regmap_type DMA2CNT_L                    = '{28'hD0,  15,      0,        1,        0,   writeDone}; // Word Count           2    W  
localparam regmap_type DMA2CNT_H                    = '{28'hD0,  31,     16,        1,        0,   writeonly}; // Control              2    R/W
localparam regmap_type DMA2CNT_H_Dest_Addr_Control  = '{28'hD0,  22,     21,        1,        0,   readwrite}; // 5-6   Dest Addr Control  (0=Increment,1=Decrement,2=Fixed,3=Increment/Reload)
localparam regmap_type DMA2CNT_H_Source_Adr_Control = '{28'hD0,  24,     23,        1,        0,   readwrite}; // 7-8   Source Adr Control (0=Increment,1=Decrement,2=Fixed,3=Prohibited)
localparam regmap_type DMA2CNT_H_DMA_Repeat         = '{28'hD0,  25,     25,        1,        0,   readwrite}; // 9     DMA Repeat                   (0=Off, 1=On) (Must be zero if Bit 11 set)
localparam regmap_type DMA2CNT_H_DMA_Transfer_Type  = '{28'hD0,  26,     26,        1,        0,   readwrite}; // 10    DMA Transfer Type            (0=16bit, 1=32bit)
localparam regmap_type DMA2CNT_H_DMA_Start_Timing   = '{28'hD0,  29,     28,        1,        0,   readwrite}; // 12-13 DMA Start Timing  (0=Immediately, 1=VBlank, 2=HBlank, 3=Special) The 'Special' setting (Start Timing=3) depends on the DMA channel: DMA0=Prohibited, DMA1/DMA2=Sound FIFO, DMA3=Video Capture
localparam regmap_type DMA2CNT_H_IRQ_on             = '{28'hD0,  30,     30,        1,        0,   readwrite}; // 14    IRQ upon end of Word Count   (0=Disable, 1=Enable)
localparam regmap_type DMA2CNT_H_DMA_Enable         = '{28'hD0,  31,     31,        1,        0,   readwrite}; // 15    DMA Enable                   (0=Off, 1=On)
  
localparam regmap_type DMA3SAD                      = '{28'hD4,  31,      0,        1,        0,   writeonly}; // Source Address       4    W  
localparam regmap_type DMA3DAD                      = '{28'hD8,  31,      0,        1,        0,   writeonly}; // Destination Address  4    W  
localparam regmap_type DMA3CNT_L                    = '{28'hDC,  15,      0,        1,        0,   writeDone}; // Word Count           2    W  
localparam regmap_type DMA3CNT_H                    = '{28'hDC,  31,     16,        1,        0,   writeonly}; // Control              2    R/W
localparam regmap_type DMA3CNT_H_Dest_Addr_Control  = '{28'hDC,  22,     21,        1,        0,   readwrite}; // 5-6   Dest Addr Control  (0=Increment,1=Decrement,2=Fixed,3=Increment/Reload)
localparam regmap_type DMA3CNT_H_Source_Adr_Control = '{28'hDC,  24,     23,        1,        0,   readwrite}; // 7-8   Source Adr Control (0=Increment,1=Decrement,2=Fixed,3=Prohibited)
localparam regmap_type DMA3CNT_H_DMA_Repeat         = '{28'hDC,  25,     25,        1,        0,   readwrite}; // 9     DMA Repeat                   (0=Off, 1=On) (Must be zero if Bit 11 set)
localparam regmap_type DMA3CNT_H_DMA_Transfer_Type  = '{28'hDC,  26,     26,        1,        0,   readwrite}; // 10    DMA Transfer Type            (0=16bit, 1=32bit)
localparam regmap_type DMA3CNT_H_Game_Pak_DRQ       = '{28'hDC,  27,     27,        1,        0,   readwrite}; // 11    Game Pak DRQ  - DMA3 only -  (0=Normal, 1=DRQ <from> Game Pak, DMA3)
localparam regmap_type DMA3CNT_H_DMA_Start_Timing   = '{28'hDC,  29,     28,        1,        0,   readwrite}; // 12-13 DMA Start Timing  (0=Immediately, 1=VBlank, 2=HBlank, 3=Special) The 'Special' setting (Start Timing=3) depends on the DMA channel: DMA0=Prohibited, DMA1/DMA2=Sound FIFO, DMA3=Video Capture
localparam regmap_type DMA3CNT_H_IRQ_on             = '{28'hDC,  30,     30,        1,        0,   readwrite}; // 14    IRQ upon end of Word Count   (0=Disable, 1=Enable)
localparam regmap_type DMA3CNT_H_DMA_Enable         = '{28'hDC,  31,     31,        1,        0,   readwrite}; // 15    DMA Enable                   (0=Off, 1=On)

`endif
