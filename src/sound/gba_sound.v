
module gba_sound(clk, gb_on, reset, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
        timer0_tick, timer1_tick, sound_dma_req, sound_out_left, sound_out_right, debug_fifocount);
    `include "pproc_bus_gba.sv"
    `include "preg_gba_sound.sv"
    input                      clk;
    input                      gb_on;
    input                      reset;
    
    `GB_BUS_PORTS_DECL;
    
    input                      timer0_tick;
    input                      timer1_tick;
    output [1:0]               sound_dma_req;
    output [15:0]              sound_out_left;
    output [15:0]              sound_out_right;
    output [31:0]              debug_fifocount;
    
    wire [SOUNDCNT_L_Sound_1_4_Master_Volume_RIGHT.upper : SOUNDCNT_L_Sound_1_4_Master_Volume_RIGHT.lower]  Sound_1_4_Master_Volume_RIGHT;
    wire [SOUNDCNT_L_Sound_1_4_Master_Volume_LEFT .upper : SOUNDCNT_L_Sound_1_4_Master_Volume_LEFT .lower]  Sound_1_4_Master_Volume_LEFT;
    wire [SOUNDCNT_L_Sound_1_Enable_Flags_RIGHT   .upper : SOUNDCNT_L_Sound_1_Enable_Flags_RIGHT   .lower]  Sound_1_Enable_Flags_RIGHT;
    wire [SOUNDCNT_L_Sound_2_Enable_Flags_RIGHT   .upper : SOUNDCNT_L_Sound_2_Enable_Flags_RIGHT   .lower]  Sound_2_Enable_Flags_RIGHT;
    wire [SOUNDCNT_L_Sound_3_Enable_Flags_RIGHT   .upper : SOUNDCNT_L_Sound_3_Enable_Flags_RIGHT   .lower]  Sound_3_Enable_Flags_RIGHT;
    wire [SOUNDCNT_L_Sound_4_Enable_Flags_RIGHT   .upper : SOUNDCNT_L_Sound_4_Enable_Flags_RIGHT   .lower]  Sound_4_Enable_Flags_RIGHT;
    wire [SOUNDCNT_L_Sound_1_Enable_Flags_LEFT    .upper : SOUNDCNT_L_Sound_1_Enable_Flags_LEFT    .lower]  Sound_1_Enable_Flags_LEFT;
    wire [SOUNDCNT_L_Sound_2_Enable_Flags_LEFT    .upper : SOUNDCNT_L_Sound_2_Enable_Flags_LEFT    .lower]  Sound_2_Enable_Flags_LEFT;
    wire [SOUNDCNT_L_Sound_3_Enable_Flags_LEFT    .upper : SOUNDCNT_L_Sound_3_Enable_Flags_LEFT    .lower]  Sound_3_Enable_Flags_LEFT;
    wire [SOUNDCNT_L_Sound_4_Enable_Flags_LEFT    .upper : SOUNDCNT_L_Sound_4_Enable_Flags_LEFT    .lower]  Sound_4_Enable_Flags_LEFT;
    
    wire [SOUNDCNT_H_Sound_1_4_Volume             .upper : SOUNDCNT_H_Sound_1_4_Volume             .lower]  Sound_1_4_Volume;
    wire [SOUNDCNT_H_DMA_Sound_A_Volume           .upper : SOUNDCNT_H_DMA_Sound_A_Volume           .lower]  DMA_Sound_A_Volume;
    wire [SOUNDCNT_H_DMA_Sound_B_Volume           .upper : SOUNDCNT_H_DMA_Sound_B_Volume           .lower]  DMA_Sound_B_Volume;
    wire [SOUNDCNT_H_DMA_Sound_A_Enable_RIGHT     .upper : SOUNDCNT_H_DMA_Sound_A_Enable_RIGHT     .lower]  DMA_Sound_A_Enable_RIGHT;
    wire [SOUNDCNT_H_DMA_Sound_A_Enable_LEFT      .upper : SOUNDCNT_H_DMA_Sound_A_Enable_LEFT      .lower]  DMA_Sound_A_Enable_LEFT;
    wire [SOUNDCNT_H_DMA_Sound_A_Timer_Select     .upper : SOUNDCNT_H_DMA_Sound_A_Timer_Select     .lower]  DMA_Sound_A_Timer_Select;
    wire [SOUNDCNT_H_DMA_Sound_A_Reset_FIFO       .upper : SOUNDCNT_H_DMA_Sound_A_Reset_FIFO       .lower]  DMA_Sound_A_Reset_FIFO;
    wire [SOUNDCNT_H_DMA_Sound_B_Enable_RIGHT     .upper : SOUNDCNT_H_DMA_Sound_B_Enable_RIGHT     .lower]  DMA_Sound_B_Enable_RIGHT;
    wire [SOUNDCNT_H_DMA_Sound_B_Enable_LEFT      .upper : SOUNDCNT_H_DMA_Sound_B_Enable_LEFT      .lower]  DMA_Sound_B_Enable_LEFT;
    wire [SOUNDCNT_H_DMA_Sound_B_Timer_Select     .upper : SOUNDCNT_H_DMA_Sound_B_Timer_Select     .lower]  DMA_Sound_B_Timer_Select;
    wire [SOUNDCNT_H_DMA_Sound_B_Reset_FIFO       .upper : SOUNDCNT_H_DMA_Sound_B_Reset_FIFO       .lower]  DMA_Sound_B_Reset_FIFO;
    
    wire [SOUNDCNT_X_Sound_1_ON_flag              .upper : SOUNDCNT_X_Sound_1_ON_flag              .lower]  Sound_1_ON_flag;
    wire [SOUNDCNT_X_Sound_2_ON_flag              .upper : SOUNDCNT_X_Sound_2_ON_flag              .lower]  Sound_2_ON_flag;
    wire [SOUNDCNT_X_Sound_3_ON_flag              .upper : SOUNDCNT_X_Sound_3_ON_flag              .lower]  Sound_3_ON_flag;
    wire [SOUNDCNT_X_Sound_4_ON_flag              .upper : SOUNDCNT_X_Sound_4_ON_flag              .lower]  Sound_4_ON_flag;
    wire [SOUNDCNT_X_PSG_FIFO_Master_Enable       .upper : SOUNDCNT_X_PSG_FIFO_Master_Enable       .lower]  PSG_FIFO_Master_Enable;
    
    wire [SOUNDBIAS.upper : SOUNDBIAS.lower]       REG_SOUNDBIAS;       // not actually used
    
    wire            SOUNDCNT_H_DMA_written;
    
    reg             gbsound_on;
    
    reg [2:0]       new_cycles_slow;
    reg             new_cycles_valid;
    reg [2:0]       bus_cycles_sum;
    
    wire signed [15:0]     sound_out_ch1;
    wire signed [15:0]     sound_out_ch2;
    wire signed [15:0]     sound_out_ch3;
    wire signed [15:0]     sound_out_ch4;
    
    wire signed [15:0]     sound_out_dmaA_l;
    wire signed [15:0]     sound_out_dmaA_r;
    wire signed [15:0]     sound_out_dmaB_l;
    wire signed [15:0]     sound_out_dmaB_r;
    
    wire            sound_on_ch1;
    wire            sound_on_ch2;
    wire            sound_on_ch3;
    wire            sound_on_ch4;
    wire            sound_on_dmaA;
    wire            sound_on_dmaB;
    
    wire            dma_new_sample;
    
    reg signed [15:0]      soundmix1_l;
    reg signed [15:0]      soundmix1_r;
    reg signed [15:0]      soundmix2_l;
    reg signed [15:0]      soundmix2_r;
    reg signed [15:0]      soundmix3_l;
    reg signed [15:0]      soundmix3_r;
    reg signed [15:0]      soundmix4_l;
    reg signed [15:0]      soundmix4_r;
    reg signed [15:0]      soundmix14_l;
    reg signed [15:0]      soundmix14_r;
    
    reg signed [15:0]      soundmix5_l;
    reg signed [15:0]      soundmix5_r;
    reg signed [15:0]      soundmix6_l;
    reg signed [15:0]      soundmix6_r;
    reg signed [15:0]      soundmix7_l;
    reg signed [15:0]      soundmix7_r;
    
    reg signed [15:0]      soundmix8_l;
    reg signed [15:0]      soundmix8_r;
    reg signed [9:0]       soundmix9;
    
   
    eProcReg_gba #(SOUNDCNT_L_Sound_1_4_Master_Volume_RIGHT) iSound_1_4_Master_Volume_RIGHT(clk, `GB_BUS_PORTS_LIST, Sound_1_4_Master_Volume_RIGHT, Sound_1_4_Master_Volume_RIGHT );
    eProcReg_gba #(SOUNDCNT_L_Sound_1_4_Master_Volume_LEFT) iSound_1_4_Master_Volume_LEFT(clk, `GB_BUS_PORTS_LIST, Sound_1_4_Master_Volume_LEFT, Sound_1_4_Master_Volume_LEFT );
    eProcReg_gba #(SOUNDCNT_L_Sound_1_Enable_Flags_RIGHT) iSound_1_Enable_Flags_RIGHT(clk, `GB_BUS_PORTS_LIST, Sound_1_Enable_Flags_RIGHT, Sound_1_Enable_Flags_RIGHT );
    eProcReg_gba #(SOUNDCNT_L_Sound_2_Enable_Flags_RIGHT) iSound_2_Enable_Flags_RIGHT(clk, `GB_BUS_PORTS_LIST, Sound_2_Enable_Flags_RIGHT, Sound_2_Enable_Flags_RIGHT );
    eProcReg_gba #(SOUNDCNT_L_Sound_3_Enable_Flags_RIGHT) iSound_3_Enable_Flags_RIGHT(clk, `GB_BUS_PORTS_LIST, Sound_3_Enable_Flags_RIGHT, Sound_3_Enable_Flags_RIGHT );
    eProcReg_gba #(SOUNDCNT_L_Sound_4_Enable_Flags_RIGHT) iSound_4_Enable_Flags_RIGHT(clk, `GB_BUS_PORTS_LIST, Sound_4_Enable_Flags_RIGHT, Sound_4_Enable_Flags_RIGHT );
    eProcReg_gba #(SOUNDCNT_L_Sound_1_Enable_Flags_LEFT) iSound_1_Enable_Flags_LEFT(clk, `GB_BUS_PORTS_LIST, Sound_1_Enable_Flags_LEFT, Sound_1_Enable_Flags_LEFT );
    eProcReg_gba #(SOUNDCNT_L_Sound_2_Enable_Flags_LEFT) iSound_2_Enable_Flags_LEFT(clk, `GB_BUS_PORTS_LIST, Sound_2_Enable_Flags_LEFT, Sound_2_Enable_Flags_LEFT );
    eProcReg_gba #(SOUNDCNT_L_Sound_3_Enable_Flags_LEFT) iSound_3_Enable_Flags_LEFT(clk, `GB_BUS_PORTS_LIST, Sound_3_Enable_Flags_LEFT, Sound_3_Enable_Flags_LEFT );
    eProcReg_gba #(SOUNDCNT_L_Sound_4_Enable_Flags_LEFT) iSound_4_Enable_Flags_LEFT(clk, `GB_BUS_PORTS_LIST, Sound_4_Enable_Flags_LEFT, Sound_4_Enable_Flags_LEFT );

    eProcReg_gba #(SOUNDCNT_H_Sound_1_4_Volume) iSound_1_4_Volume(clk, `GB_BUS_PORTS_LIST, Sound_1_4_Volume, Sound_1_4_Volume );
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_A_Volume) iDMA_Sound_A_Volume(clk, `GB_BUS_PORTS_LIST, DMA_Sound_A_Volume, DMA_Sound_A_Volume );
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_B_Volume) iDMA_Sound_B_Volume(clk, `GB_BUS_PORTS_LIST, DMA_Sound_B_Volume, DMA_Sound_B_Volume );
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_A_Enable_RIGHT) iDMA_Sound_A_Enable_RIGHT(clk, `GB_BUS_PORTS_LIST, DMA_Sound_A_Enable_RIGHT, DMA_Sound_A_Enable_RIGHT, SOUNDCNT_H_DMA_written );
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_A_Enable_LEFT) iDMA_Sound_A_Enable_LEFT(clk, `GB_BUS_PORTS_LIST, DMA_Sound_A_Enable_LEFT, DMA_Sound_A_Enable_LEFT);
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_A_Timer_Select) iDMA_Sound_A_Timer_Select(clk, `GB_BUS_PORTS_LIST, DMA_Sound_A_Timer_Select, DMA_Sound_A_Timer_Select);
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_A_Reset_FIFO) iDMA_Sound_A_Reset_FIFO(clk, `GB_BUS_PORTS_LIST, 0, DMA_Sound_A_Reset_FIFO);
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_B_Enable_RIGHT) iDMA_Sound_B_Enable_RIGHT(clk, `GB_BUS_PORTS_LIST, DMA_Sound_B_Enable_RIGHT, DMA_Sound_B_Enable_RIGHT);
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_B_Enable_LEFT) iDMA_Sound_B_Enable_LEFT(clk, `GB_BUS_PORTS_LIST, DMA_Sound_B_Enable_LEFT, DMA_Sound_B_Enable_LEFT);
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_B_Timer_Select) iDMA_Sound_B_Timer_Select(clk, `GB_BUS_PORTS_LIST, DMA_Sound_B_Timer_Select, DMA_Sound_B_Timer_Select);
    eProcReg_gba #(SOUNDCNT_H_DMA_Sound_B_Reset_FIFO) iDMA_Sound_B_Reset_FIFO(clk, `GB_BUS_PORTS_LIST, 0, DMA_Sound_B_Reset_FIFO);

    eProcReg_gba #(SOUNDCNT_X_Sound_1_ON_flag) iSound_1_ON_flag(clk, `GB_BUS_PORTS_LIST, Sound_1_ON_flag);
    eProcReg_gba #(SOUNDCNT_X_Sound_2_ON_flag) iSound_2_ON_flag(clk, `GB_BUS_PORTS_LIST, Sound_2_ON_flag);
    eProcReg_gba #(SOUNDCNT_X_Sound_3_ON_flag) iSound_3_ON_flag(clk, `GB_BUS_PORTS_LIST, Sound_3_ON_flag);
    eProcReg_gba #(SOUNDCNT_X_Sound_4_ON_flag) iSound_4_ON_flag(clk, `GB_BUS_PORTS_LIST, Sound_4_ON_flag);
    eProcReg_gba #(SOUNDCNT_X_PSG_FIFO_Master_Enable) iPSG_FIFO_Master_Enable(clk, `GB_BUS_PORTS_LIST, PSG_FIFO_Master_Enable, PSG_FIFO_Master_Enable);

    eProcReg_gba #(SOUNDBIAS) iREG_SOUNDBIAS(clk, `GB_BUS_PORTS_LIST, REG_SOUNDBIAS, REG_SOUNDBIAS);

    eProcReg_gba #(SOUNDCNT_XHighZero) iSOUNDCNT_XHighZero(clk, `GB_BUS_PORTS_LIST, 16'h0000);
    eProcReg_gba #(SOUNDBIAS_HighZero) iSOUNDBIAS_HighZero(clk, `GB_BUS_PORTS_LIST, 16'h0000);
    
    assign Sound_1_ON_flag[SOUNDCNT_X_Sound_1_ON_flag.lower] = sound_on_ch1 & (Sound_1_Enable_Flags_LEFT | Sound_1_Enable_Flags_RIGHT);
    assign Sound_2_ON_flag[SOUNDCNT_X_Sound_2_ON_flag.lower] = sound_on_ch2 & (Sound_2_Enable_Flags_LEFT | Sound_2_Enable_Flags_RIGHT);
    assign Sound_3_ON_flag[SOUNDCNT_X_Sound_3_ON_flag.lower] = sound_on_ch3 & (Sound_3_Enable_Flags_LEFT | Sound_3_Enable_Flags_RIGHT);
    assign Sound_4_ON_flag[SOUNDCNT_X_Sound_4_ON_flag.lower] = sound_on_ch4 & (Sound_4_Enable_Flags_LEFT | Sound_4_Enable_Flags_RIGHT);
    
    // MMIO reg reads
    reg [31:0] reg_dout;
    reg reg_dout_en;
    assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};

    always @(posedge clk) begin
        reg_dout_en <= 0;

        if (gb_bus_ena & gb_bus_rnw) begin
            reg_dout_en <= 1;
            case (gb_bus_adr)
            SOUNDCNT_L.Adr:         // 080
                reg_dout <= 
                    {1'b0 /*DMA_Sound_B_Reset_FIFO*/, DMA_Sound_B_Timer_Select, DMA_Sound_B_Enable_LEFT, DMA_Sound_B_Enable_RIGHT,           // [31:28]
                    1'b0 /*DMA_Sound_A_Reset_FIFO*/, DMA_Sound_A_Timer_Select, DMA_Sound_A_Enable_LEFT, DMA_Sound_A_Enable_RIGHT,            // [27:24]
                    4'b0,          // 23:20
                    DMA_Sound_B_Volume, DMA_Sound_A_Volume, Sound_1_4_Volume,  // [19:16]
                    Sound_4_Enable_Flags_LEFT, Sound_3_Enable_Flags_LEFT, Sound_2_Enable_Flags_LEFT, Sound_1_Enable_Flags_LEFT,     // [15:12]
                    Sound_4_Enable_Flags_RIGHT, Sound_3_Enable_Flags_RIGHT, Sound_2_Enable_Flags_RIGHT, Sound_1_Enable_Flags_RIGHT, // [11:8]
                    1'b0, Sound_1_4_Master_Volume_LEFT, // [7:4]
                    1'b0, Sound_1_4_Master_Volume_RIGHT}; // [3:0]

            SOUNDCNT_X.Adr:         // 084
                reg_dout <= {PSG_FIFO_Master_Enable, 3'b0, Sound_4_ON_flag, Sound_3_ON_flag, Sound_2_ON_flag, Sound_1_ON_flag};
            
            SOUNDBIAS.Adr:          // 088
                reg_dout <= REG_SOUNDBIAS;

            FIFO_A.Adr, FIFO_B.Adr, 28'h08C, 28'h0A8, 28'h0AC:
                reg_dout <= 32'hDEADDEAD;

            default:
                reg_dout_en <= 0;
            endcase
        end

    end    

    gba_sound_ch1 #(
        .has_sweep                     (1'b1), 
        .Reg_Number_of_sweep_shift     (SOUND1CNT_L_Number_of_sweep_shift), 
        .Reg_Sweep_Frequency_Direction (SOUND1CNT_L_Sweep_Frequency_Direction), 
        .Reg_Sweep_Time                (SOUND1CNT_L_Sweep_Time), 
        .Reg_Sound_length              (SOUND1CNT_H_Sound_length), 
        .Reg_Wave_Pattern_Duty         (SOUND1CNT_H_Wave_Pattern_Duty), 
        .Reg_Envelope_Step_Time        (SOUND1CNT_H_Envelope_Step_Time), 
        .Reg_Envelope_Direction        (SOUND1CNT_H_Envelope_Direction), 
        .Reg_Initial_Volume_of_envelope(SOUND1CNT_H_Initial_Volume_of_envelope), 
        .Reg_Frequency                 (SOUND1CNT_X_Frequency), 
        .Reg_Length_Flag               (SOUND1CNT_X_Length_Flag), 
        .Reg_Initial                   (SOUND1CNT_X_Initial), 
        .Reg_HighZero                  (SOUND1CNT_XHighZero)
    ) igba_sound_ch1(
        .clk(clk),
        .reset(reset),
        .gb_on(gbsound_on),
        `GB_BUS_PORTS_INST,
        .sound_out(sound_out_ch1),
        .sound_on(sound_on_ch1)
    );
    
    gba_sound_ch1 #(
         .has_sweep                      (1'b0                                  ),  // unused
         .Reg_Number_of_sweep_shift      (SOUND1CNT_L_Number_of_sweep_shift     ),  // unused
         .Reg_Sweep_Frequency_Direction  (SOUND1CNT_L_Sweep_Frequency_Direction ),  // unused
         .Reg_Sweep_Time                 (SOUND1CNT_L_Sweep_Time                ),  
         .Reg_Sound_length               (SOUND2CNT_L_Sound_length              ),
         .Reg_Wave_Pattern_Duty          (SOUND2CNT_L_Wave_Pattern_Duty         ),
         .Reg_Envelope_Step_Time         (SOUND2CNT_L_Envelope_Step_Time        ),
         .Reg_Envelope_Direction         (SOUND2CNT_L_Envelope_Direction        ),
         .Reg_Initial_Volume_of_envelope (SOUND2CNT_L_Initial_Volume_of_envelope),
         .Reg_Frequency                  (SOUND2CNT_H_Frequency                 ),
         .Reg_Length_Flag                (SOUND2CNT_H_Length_Flag               ),
         .Reg_Initial                    (SOUND2CNT_H_Initial                   ),
         .Reg_HighZero                   (SOUND2CNT_HHighZero                   )       
    ) igba_sound_ch2(		
        .clk(clk),
        .reset(reset),
        .gb_on(gbsound_on),
        `GB_BUS_PORTS_INST,
        .sound_out(sound_out_ch2),
        .sound_on(sound_on_ch2)
    );
    
    gba_sound_ch3 igba_sound_ch3(
        .clk(clk),
        .reset(reset),
        .gb_on(gbsound_on),
        `GB_BUS_PORTS_INST,
        .sound_out(sound_out_ch3),
        .sound_on(sound_on_ch3)
    );
    
    gba_sound_ch4 igba_sound_ch4(
        .clk(clk),
        .reset(reset),
        .gb_on(gbsound_on),
        `GB_BUS_PORTS_INST,
        .sound_out(sound_out_ch4),
        .sound_on(sound_on_ch4)
    );
    
    gba_sound_dma #(.REG_FIFO(FIFO_A)) igba_sound_dmaA(
        .clk(clk),
        .reset(reset),
        `GB_BUS_PORTS_INST,
        .settings_new(SOUNDCNT_H_DMA_written),
        .Enable_RIGHT(DMA_Sound_A_Enable_RIGHT[SOUNDCNT_H_DMA_Sound_A_Enable_RIGHT.upper]),
        .Enable_LEFT(DMA_Sound_A_Enable_LEFT[SOUNDCNT_H_DMA_Sound_A_Enable_LEFT.upper]),
        .Timer_Select(DMA_Sound_A_Timer_Select[SOUNDCNT_H_DMA_Sound_A_Timer_Select.upper]),
        .Reset_FIFO(DMA_Sound_A_Reset_FIFO[SOUNDCNT_H_DMA_Sound_A_Reset_FIFO.upper]),
        .volume_high(DMA_Sound_A_Volume[SOUNDCNT_H_DMA_Sound_A_Volume.upper]),

        .timer0_tick(timer0_tick),
        .timer1_tick(timer1_tick),
        .dma_req(sound_dma_req[0]),
        
        .sound_out_left(sound_out_dmaA_l),
        .sound_out_right(sound_out_dmaA_r),
        .sound_on(sound_on_dmaA),
        
        .new_sample_out(dma_new_sample),
        
        .debug_fifocount(debug_fifocount)
    );
    
    gba_sound_dma #(.REG_FIFO(FIFO_B)) igba_sound_dmaB(
        .clk(clk),
        .reset(reset),
        `GB_BUS_PORTS_INST,
        .settings_new(SOUNDCNT_H_DMA_written),
        .Enable_RIGHT(DMA_Sound_B_Enable_RIGHT[SOUNDCNT_H_DMA_Sound_B_Enable_RIGHT.upper]),
        .Enable_LEFT(DMA_Sound_B_Enable_LEFT[SOUNDCNT_H_DMA_Sound_B_Enable_LEFT.upper]),
        .Timer_Select(DMA_Sound_B_Timer_Select[SOUNDCNT_H_DMA_Sound_B_Timer_Select.upper]),
        .Reset_FIFO(DMA_Sound_B_Reset_FIFO[SOUNDCNT_H_DMA_Sound_B_Reset_FIFO.upper]),
        .volume_high(DMA_Sound_B_Volume[SOUNDCNT_H_DMA_Sound_B_Volume.upper]),
        
        .timer0_tick(timer0_tick),
        .timer1_tick(timer1_tick),
        .dma_req(sound_dma_req[1]),
        
        .sound_out_left(sound_out_dmaB_l),
        .sound_out_right(sound_out_dmaB_r),
        .sound_on(sound_on_dmaB),
        
        .new_sample_out(),
        
        .debug_fifocount()
    );
    
    always @(posedge clk) begin
        
        // PSG_FIFO_Master_Enable should usually also reset all sound registers
        gbsound_on <= gb_on & PSG_FIFO_Master_Enable[SOUNDCNT_X_PSG_FIFO_Master_Enable.upper];
                
        // channels 1-4 are from GB, they still work with 4 MHZ

        // sound channel mixing
        
        // channel 1
        if (sound_on_ch1 & Sound_1_Enable_Flags_LEFT)
            soundmix1_l <= sound_out_ch1;
        else
            soundmix1_l <= {16{1'b0}};
        if (sound_on_ch1 & Sound_1_Enable_Flags_RIGHT)
            soundmix1_r <= sound_out_ch1;
        else
            soundmix1_r <= {16{1'b0}};
        
        // channel 2
        if (sound_on_ch2 & Sound_2_Enable_Flags_LEFT)
            soundmix2_l <= soundmix1_l + sound_out_ch2;
        else
            soundmix2_l <= soundmix1_l;
        if (sound_on_ch2 & Sound_2_Enable_Flags_RIGHT)
            soundmix2_r <= soundmix1_r + sound_out_ch2;
        else
            soundmix2_r <= soundmix1_r;
        
        // channel 3
        if (sound_on_ch3 & Sound_3_Enable_Flags_LEFT)
            soundmix3_l <= soundmix2_l + sound_out_ch3;
        else
            soundmix3_l <= soundmix2_l;
        if (sound_on_ch3 & Sound_3_Enable_Flags_RIGHT)
            soundmix3_r <= soundmix2_r + sound_out_ch3;
        else
            soundmix3_r <= soundmix2_r;
        
        // channel 4
        if (sound_on_ch4 & Sound_4_Enable_Flags_LEFT)
            soundmix4_l <= soundmix3_l + sound_out_ch4;
        else
            soundmix4_l <= soundmix3_l;
        if (sound_on_ch4 & Sound_4_Enable_Flags_RIGHT)
            soundmix4_r <= soundmix3_r + sound_out_ch4;
        else
            soundmix4_r <= soundmix3_r;
        
        // sound1-4 volume control
        soundmix14_l <= soundmix4_l * signed'({1'b0, Sound_1_4_Master_Volume_LEFT});
        soundmix14_r <= soundmix4_r * signed'({1'b0, Sound_1_4_Master_Volume_RIGHT});
        
        case (Sound_1_4_Volume)
            0 : begin
                    soundmix5_l <= soundmix14_l/4;
                    soundmix5_r <= soundmix14_r/4;
                end
            1 : begin
                    soundmix5_l <= soundmix14_l/2;
                    soundmix5_r <= soundmix14_r/2;
                end
            2 : begin
                    soundmix5_l <= soundmix14_l;
                    soundmix5_r <= soundmix14_r;
                end
            3 :		// 3 is not allowed
                begin
                    soundmix5_l <= {16{1'b0}};
                    soundmix5_r <= {16{1'b0}};
                end
            default : ;
        endcase
        
        // mix in dma sound
        if (sound_on_dmaA) begin
            soundmix6_l <= soundmix5_l - sound_out_dmaA_l;
            soundmix6_r <= soundmix5_r - sound_out_dmaA_r;
        end else begin
            soundmix6_l <= soundmix5_l;
            soundmix6_r <= soundmix5_r;
        end
        
        if (sound_on_dmaB) begin
            soundmix7_l <= soundmix6_l - sound_out_dmaB_l;
            soundmix7_r <= soundmix6_r - sound_out_dmaB_r;
        end else begin
            soundmix7_l <= soundmix6_l;
            soundmix7_r <= soundmix6_r;
        end
        
        // skip sound bias and clip on signed instead
        soundmix8_l <= clip512(soundmix7_l);		// + to_integer(unsigned(REG_SOUNDBIAS));
        soundmix8_r <= clip512(soundmix7_r);		// + to_integer(unsigned(REG_SOUNDBIAS));

        // clipping, only for turbosound, using left channel only
        // if (soundmix8_l < -512)
        //     soundmix9 <= -512;
        // else if (soundmix8_l > 511)
        //     soundmix9 <= 511;
        // else
        //     soundmix9 <= soundmix8_l[9:0];
    end 
    
    // assign sound_out_left = PSG_FIFO_Master_Enable ? soundmix8_l * 64 : {16{1'b0}};
    // assign sound_out_right = PSG_FIFO_Master_Enable ? soundmix8_r * 64 : {16{1'b0}};
    assign sound_out_left = PSG_FIFO_Master_Enable ? soundmix8_l * 32 : {16{1'b0}};
    assign sound_out_right = PSG_FIFO_Master_Enable ? soundmix8_r * 32 : {16{1'b0}};
    
    function signed [15:0] clip512(signed [15:0] in);
        if (in < -512)
            clip512 = -512;
        else if (in > 511)
            clip512 = 511;
        else
            clip512 = in;
    endfunction

endmodule
`undef pproc_bus_gba
`undef preg_gba_sound