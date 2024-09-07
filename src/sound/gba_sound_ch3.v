// Channel 3 is Wave Output
module gba_sound_ch3(clk, reset, gb_on, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
            sound_out, sound_on);
    `include "pproc_bus_gba.sv"
    `include "preg_gba_sound.sv"
    input                      clk;
    input                      reset;
    input                      gb_on;
    
    `GB_BUS_PORTS_DECL;
    
    output reg [15:0]          sound_out;
    output reg                 sound_on;
    
    wire [SOUND3CNT_L_Wave_RAM_Dimension   .upper : SOUND3CNT_L_Wave_RAM_Dimension   .lower]  REG_SOUND3CNT_L_Wave_RAM_Dimension;
    wire [SOUND3CNT_L_Wave_RAM_Bank_Number .upper : SOUND3CNT_L_Wave_RAM_Bank_Number .lower]  REG_SOUND3CNT_L_Wave_RAM_Bank_Number;
    wire [SOUND3CNT_L_Sound_Channel_3_Off  .upper : SOUND3CNT_L_Sound_Channel_3_Off  .lower]  REG_SOUND3CNT_L_Sound_Channel_3_Off;
    
    wire [SOUND3CNT_H_Sound_length         .upper : SOUND3CNT_H_Sound_length         .lower]  REG_SOUND3CNT_H_Sound_length;
    wire [SOUND3CNT_H_Sound_Volume         .upper : SOUND3CNT_H_Sound_Volume         .lower]  REG_SOUND3CNT_H_Sound_Volume;
    wire [SOUND3CNT_H_Force_Volume         .upper : SOUND3CNT_H_Force_Volume         .lower]  REG_SOUND3CNT_H_Force_Volume;
    
    wire [SOUND3CNT_X_Sample_Rate          .upper : SOUND3CNT_X_Sample_Rate          .lower]  REG_SOUND3CNT_X_Sample_Rate;
    wire [SOUND3CNT_X_Length_Flag          .upper : SOUND3CNT_X_Length_Flag          .lower]  REG_SOUND3CNT_X_Length_Flag;
    wire [SOUND3CNT_X_Initial              .upper : SOUND3CNT_X_Initial              .lower]  REG_SOUND3CNT_X_Initial;
    
    wire [WAVE_RAM .upper : WAVE_RAM .lower] REG_WAVE_RAM;
    wire [WAVE_RAM2.upper : WAVE_RAM2.lower] REG_WAVE_RAM2;
    wire [WAVE_RAM3.upper : WAVE_RAM3.lower] REG_WAVE_RAM3;
    wire [WAVE_RAM4.upper : WAVE_RAM4.lower] REG_WAVE_RAM4;
    
    wire       SOUND3CNT_L_Wave_RAM_Bank_Number_written;
    wire       SOUND3CNT_L_Sound_Channel_3_Off_written;
    wire       SOUND3CNT_H_Sound_length_written;
    wire       SOUND3CNT_H_Sound_Volume_written;
    wire       SOUND3CNT_X_Sample_Rate_written;
    
    wire       waveram_written;
    wire       waveram_written2;
    wire       waveram_written3;
    wire       waveram_written4;
    
    reg [3:0]  waveram[0:1][0:31];
    
    wire       bank_access;
    reg        bank_play;
    
    reg        choutput_on;
    
    reg [4:0]  wavetable_ptr;
    reg signed [4:0] wave_vol;
    
    reg [8:0]  length_left;
    
    reg [1:0]  volume_shift;
    reg signed [4:0]  wave_vol_shifted;
    
    reg [11:0]  freq_divider;
    reg [11:0]  freq_check;
    reg        length_on;
    reg        ch_on;
    reg [11:0]  freq_cnt;
    
    reg [7:0]  soundcycles_freq;
    reg [16:0]  soundcycles_length;
    
    eProcReg_gba #(SOUND3CNT_L_Wave_RAM_Dimension) iREG_SOUND3CNT_L_Wave_RAM_Dimension(clk, `GB_BUS_PORTS_LIST, REG_SOUND3CNT_L_Wave_RAM_Dimension, REG_SOUND3CNT_L_Wave_RAM_Dimension);
    eProcReg_gba #(SOUND3CNT_L_Wave_RAM_Bank_Number) iREG_SOUND3CNT_L_Wave_RAM_Bank_Number(clk, `GB_BUS_PORTS_LIST, REG_SOUND3CNT_L_Wave_RAM_Bank_Number, REG_SOUND3CNT_L_Wave_RAM_Bank_Number, SOUND3CNT_L_Wave_RAM_Bank_Number_written);
    eProcReg_gba #(SOUND3CNT_L_Sound_Channel_3_Off) iREG_SOUND3CNT_L_Sound_Channel_3_Off(clk, `GB_BUS_PORTS_LIST, REG_SOUND3CNT_L_Sound_Channel_3_Off, REG_SOUND3CNT_L_Sound_Channel_3_Off, SOUND3CNT_L_Sound_Channel_3_Off_written);
    eProcReg_gba #(SOUND3CNT_H_Sound_length) iREG_SOUND3CNT_H_Sound_length(clk, `GB_BUS_PORTS_LIST, 8'b00000000, REG_SOUND3CNT_H_Sound_length, SOUND3CNT_H_Sound_length_written);
    eProcReg_gba #(SOUND3CNT_H_Sound_Volume) iREG_SOUND3CNT_H_Sound_Volume(clk, `GB_BUS_PORTS_LIST, REG_SOUND3CNT_H_Sound_Volume, REG_SOUND3CNT_H_Sound_Volume, SOUND3CNT_H_Sound_Volume_written);
    eProcReg_gba #(SOUND3CNT_H_Force_Volume) iREG_SOUND3CNT_H_Force_Volume(clk, `GB_BUS_PORTS_LIST, REG_SOUND3CNT_H_Force_Volume, REG_SOUND3CNT_H_Force_Volume);

    eProcReg_gba #(SOUND3CNT_X_Sample_Rate) iREG_SOUND3CNT_X_Sample_Rate(clk, `GB_BUS_PORTS_LIST, 11'b00000000000, REG_SOUND3CNT_X_Sample_Rate, SOUND3CNT_X_Sample_Rate_written);
    eProcReg_gba #(SOUND3CNT_X_Length_Flag) iREG_SOUND3CNT_X_Length_Flag(clk, `GB_BUS_PORTS_LIST, REG_SOUND3CNT_X_Length_Flag, REG_SOUND3CNT_X_Length_Flag);
    eProcReg_gba #(SOUND3CNT_X_Initial) iREG_SOUND3CNT_X_Initial(clk, `GB_BUS_PORTS_LIST, 1'b0, REG_SOUND3CNT_X_Initial);
    eProcReg_gba #(SOUND3CNT_XHighZero) iREG_SOUND3CNT_XHighZero(clk, `GB_BUS_PORTS_LIST, 0);
    
    eProcReg_gba #(WAVE_RAM) iREG_WAVE_RAM(clk, `GB_BUS_PORTS_LIST, REG_WAVE_RAM, REG_WAVE_RAM, waveram_written);
    eProcReg_gba #(WAVE_RAM2) iREG_WAVE_RAM2(clk, `GB_BUS_PORTS_LIST, REG_WAVE_RAM2, REG_WAVE_RAM2, waveram_written2);
    eProcReg_gba #(WAVE_RAM3) iREG_WAVE_RAM3(clk, `GB_BUS_PORTS_LIST, REG_WAVE_RAM3, REG_WAVE_RAM3, waveram_written3);
    eProcReg_gba #(WAVE_RAM4) iREG_WAVE_RAM4(clk, `GB_BUS_PORTS_LIST, REG_WAVE_RAM4, REG_WAVE_RAM4, waveram_written4);
    
    //correct readback logic would need to implemented it as a shift register
    
    assign bank_access = 1 - bank_play;
    
    // MMIO reg reads
    reg [31:0] reg_dout;
    reg reg_dout_en;
    assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};
    
    always @(posedge clk) begin
        reg_dout_en <= 0;

        if (gb_bus_ena & gb_bus_rnw) begin
            reg_dout_en <= 1;
            case (gb_bus_adr)
            SOUND3CNT_L_Wave_RAM_Dimension.Adr:     // 070
                reg_dout <= {REG_SOUND3CNT_H_Force_Volume, REG_SOUND3CNT_H_Sound_Volume, 13'b0,      // [31:16]
                    8'b0, REG_SOUND3CNT_L_Sound_Channel_3_Off, REG_SOUND3CNT_L_Wave_RAM_Bank_Number, REG_SOUND3CNT_L_Wave_RAM_Dimension, 5'b0};
        
            SOUND3CNT_X_Sample_Rate.Adr:            // 074
                reg_dout <= {1'b0 /*REG_SOUND3CNT_X_Initial*/, REG_SOUND3CNT_X_Length_Flag, 3'b0, 11'b0 /*REG_SOUND3CNT_X_Sample_Rate*/};

            // Data is played back ordered as follows: MSBs of 1st byte, followed by LSBs of 1st byte, 
            // followed by MSBs of 2nd byte, and so on
            WAVE_RAM.Adr:                           // 090
                reg_dout <= REG_WAVE_RAM;
            WAVE_RAM2.Adr:                          // 094
                reg_dout <= REG_WAVE_RAM2;
            WAVE_RAM3.Adr:                          // 098
                reg_dout <= REG_WAVE_RAM3;
            WAVE_RAM4.Adr:                          // 09C
                reg_dout <= REG_WAVE_RAM4;

            default: reg_dout_en <= 0;
            endcase
        end
    end

    always @(posedge clk) begin
        integer i;
        // waveram
        if (waveram_written) begin
            waveram[bank_access][0] <= REG_WAVE_RAM[7:4];
            waveram[bank_access][1] <= REG_WAVE_RAM[3:0];
            waveram[bank_access][2] <= REG_WAVE_RAM[15:12];
            waveram[bank_access][3] <= REG_WAVE_RAM[11:8];
            waveram[bank_access][4] <= REG_WAVE_RAM[23:20];
            waveram[bank_access][5] <= REG_WAVE_RAM[19:16];
            waveram[bank_access][6] <= REG_WAVE_RAM[31:28];
            waveram[bank_access][7] <= REG_WAVE_RAM[27:24];
        end
        
        if (waveram_written2) begin
            waveram[bank_access][8]  <= REG_WAVE_RAM2[7:4];
            waveram[bank_access][9]  <= REG_WAVE_RAM2[3:0];
            waveram[bank_access][10] <= REG_WAVE_RAM2[15:12];
            waveram[bank_access][11] <= REG_WAVE_RAM2[11:8];
            waveram[bank_access][12] <= REG_WAVE_RAM2[23:20];
            waveram[bank_access][13] <= REG_WAVE_RAM2[19:16];
            waveram[bank_access][14] <= REG_WAVE_RAM2[31:28];
            waveram[bank_access][15] <= REG_WAVE_RAM2[27:24];            
        end
        
        if (waveram_written3) begin
            waveram[bank_access][16] <= REG_WAVE_RAM3[7:4];
            waveram[bank_access][17] <= REG_WAVE_RAM3[3:0];
            waveram[bank_access][18] <= REG_WAVE_RAM3[15:12];
            waveram[bank_access][19] <= REG_WAVE_RAM3[11:8];
            waveram[bank_access][20] <= REG_WAVE_RAM3[23:20];
            waveram[bank_access][21] <= REG_WAVE_RAM3[19:16];
            waveram[bank_access][22] <= REG_WAVE_RAM3[31:28];
            waveram[bank_access][23] <= REG_WAVE_RAM3[27:24];            
        end
        
        if (waveram_written4) begin
            waveram[bank_access][24] <= REG_WAVE_RAM4[7:4];
            waveram[bank_access][25] <= REG_WAVE_RAM4[3:0];
            waveram[bank_access][26] <= REG_WAVE_RAM4[15:12];
            waveram[bank_access][27] <= REG_WAVE_RAM4[11:8];
            waveram[bank_access][28] <= REG_WAVE_RAM4[23:20];
            waveram[bank_access][29] <= REG_WAVE_RAM4[19:16];
            waveram[bank_access][30] <= REG_WAVE_RAM4[31:28];
            waveram[bank_access][31] <= REG_WAVE_RAM4[27:24];            
        end
        
        if (gb_on == 1'b0) begin
            
            sound_out <= {16{1'b0}};
            sound_on <= 1'b0;
            
            bank_play <= 0;
            choutput_on <= 1'b0;
            wavetable_ptr <= {5{1'b0}};
            wave_vol <= 0;
            length_left <= {9{1'b0}};
            volume_shift <= 0;
            wave_vol_shifted <= 0;
            freq_divider <= {12{1'b0}};
            freq_check <= {12{1'b0}};
            length_on <= 1'b0;
            ch_on <= 1'b0;
            freq_cnt <= {12{1'b0}};
            soundcycles_freq <= {8{1'b0}};
            soundcycles_length <= {17{1'b0}};
        
        end else if (reset) begin
            
            sound_out <= {16{1'b0}};
            ch_on <= 1;
            
        end  else begin
            
            // other regs
            if (SOUND3CNT_L_Sound_Channel_3_Off_written)
                choutput_on <= REG_SOUND3CNT_L_Sound_Channel_3_Off[SOUND3CNT_L_Sound_Channel_3_Off.upper];
            
            if (SOUND3CNT_H_Sound_length_written)
                length_left <= 256 - REG_SOUND3CNT_H_Sound_length;
            
            if (SOUND3CNT_H_Sound_Volume_written)
                volume_shift <= REG_SOUND3CNT_H_Sound_Volume;
            
            if (SOUND3CNT_X_Sample_Rate_written) begin
                freq_divider <= {1'b0, REG_SOUND3CNT_X_Sample_Rate};
                length_on <= REG_SOUND3CNT_X_Length_Flag[SOUND3CNT_X_Length_Flag.upper];
                if (REG_SOUND3CNT_X_Initial) begin
                    ch_on <= 1;
                    freq_cnt <= {12{1'b0}};
                    wavetable_ptr <= {5{1'b0}};
                end 
            end 
            
            // setting bank from reg
            if (SOUND3CNT_L_Wave_RAM_Bank_Number_written)
                bank_play <= REG_SOUND3CNT_L_Wave_RAM_Bank_Number;
            
            if (ch_on) begin
                // cpu cycle trigger
                soundcycles_freq <= soundcycles_freq + 1;
                soundcycles_length <= soundcycles_length + 1;
                
                if (soundcycles_freq >= 2) begin		// freq / wavetable
                    freq_cnt <= freq_cnt + 1;
                    soundcycles_freq <= soundcycles_freq - 2;
                end 
                
                freq_check <= 2048 - freq_divider;
                
                if (freq_cnt >= freq_check) begin
                    freq_cnt <= freq_cnt - freq_check;
                    wavetable_ptr <= wavetable_ptr + 1;
                    if (wavetable_ptr == 31 & REG_SOUND3CNT_L_Wave_RAM_Dimension & SOUND3CNT_L_Wave_RAM_Bank_Number_written == 1'b0)
                        bank_play <= 1 - bank_play;
                end 
                
                // length
                if (soundcycles_length >= 16384) begin		// 256 Hz
                    soundcycles_length <= soundcycles_length - 16384;
                    if (length_left > 0 & length_on) begin
                        length_left <= length_left - 1;
                        if (length_left == 1)
                            ch_on <= 1'b0;
                    end 
                end 
                
                // wavetable
                wave_vol <= (waveram[bank_play][wavetable_ptr[4:0]] - 8) * 2;
                
                if (REG_SOUND3CNT_H_Force_Volume)
                    wave_vol_shifted <= wave_vol * 3/4;
                else
                    case (volume_shift)
                        0 : wave_vol_shifted <= 0;
                        1 : wave_vol_shifted <= wave_vol;
                        2 : wave_vol_shifted <= wave_vol/2;
                        3 : wave_vol_shifted <= wave_vol/4;
                        default : ;
                    endcase
                
                if (choutput_on) begin
                    // sound out
                    sound_out <= signed'(wave_vol_shifted);       // nand2mario: range is -16 ~ 15?
                    sound_on <= 1'b1;
                end else begin
                    sound_out <= {16{1'b0}};
                    sound_on <= 1'b0;
                end
            end else begin
                sound_out <= {16{1'b0}};
                sound_on <= 1'b0;
            end
        end
    end 
    
endmodule
`undef pproc_bus_gba
`undef preg_gba_sound