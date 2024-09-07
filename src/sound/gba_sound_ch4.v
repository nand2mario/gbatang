
// Channel 4 is white noise
module gba_sound_ch4(clk, reset, gb_on, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
            sound_out, sound_on);
    `include "pproc_bus_gba.sv"
    `include "preg_gba_sound.sv"
    input                      clk;
    input                      reset;
    input                      gb_on;
    
    `GB_BUS_PORTS_DECL;

    output [15:0]              sound_out;
    reg [15:0]                 sound_out;
    output                     sound_on;
    reg                        sound_on;
    
    
    wire [SOUND4CNT_L_Sound_length              .upper : SOUND4CNT_L_Sound_length              .lower] REG_Sound_length;
    wire [SOUND4CNT_L_Envelope_Step_Time        .upper : SOUND4CNT_L_Envelope_Step_Time        .lower] REG_Envelope_Step_Time;
    wire [SOUND4CNT_L_Envelope_Direction        .upper : SOUND4CNT_L_Envelope_Direction        .lower] REG_Envelope_Direction;
    wire [SOUND4CNT_L_Initial_Volume_of_envelope.upper : SOUND4CNT_L_Initial_Volume_of_envelope.lower] REG_Initial_Volume_of_envelope;
    
    wire [SOUND4CNT_H_Dividing_Ratio_of_Freq    .upper : SOUND4CNT_H_Dividing_Ratio_of_Freq    .lower] REG_Dividing_Ratio_of_Freq;
    wire [SOUND4CNT_H_Counter_Step_Width        .upper : SOUND4CNT_H_Counter_Step_Width        .lower] REG_Counter_Step_Width;
    wire [SOUND4CNT_H_Shift_Clock_Frequency     .upper : SOUND4CNT_H_Shift_Clock_Frequency     .lower] REG_Shift_Clock_Frequency;
    wire [SOUND4CNT_H_Length_Flag               .upper : SOUND4CNT_H_Length_Flag               .lower] REG_Length_Flag;
    wire [SOUND4CNT_H_Initial                   .upper : SOUND4CNT_H_Initial                   .lower] REG_Initial;
    
    wire                       Sound_length_written;
    wire                       Initial_Volume_of_envelope_written;
    wire                       Dividing_Ratio_of_Freq_written;
    wire                       Initial_written;
    
    reg [6:0]                  length_left;
    
    reg [5:0]                  envelope_cnt;
    reg [5:0]                  envelope_add;
    
    reg [3:0]                  volume;
    reg                        wave_on;
    
    reg [23:0]                 freq_divider;
    reg                        length_on;
    reg                        ch_on;
    
    reg                        lfsr7bit;
    reg [14:0]                 lfsr;
    
    reg [23:0]                 soundcycles_freq;
    reg [17:0]                 soundcycles_envelope;
    reg [16:0]                 soundcycles_length;
    
    
    eProcReg_gba #(SOUND4CNT_L_Sound_length) iREG_Sound_length(clk, `GB_BUS_PORTS_LIST, 6'b000000, REG_Sound_length, Sound_length_written);
    eProcReg_gba #(SOUND4CNT_L_Envelope_Step_Time) iREG_Envelope_Step_Time(clk, `GB_BUS_PORTS_LIST, REG_Envelope_Step_Time, REG_Envelope_Step_Time);
    eProcReg_gba #(SOUND4CNT_L_Envelope_Direction) iREG_Envelope_Direction(clk, `GB_BUS_PORTS_LIST, REG_Envelope_Direction, REG_Envelope_Direction);
    eProcReg_gba #(SOUND4CNT_L_Initial_Volume_of_envelope) iREG_Initial_Volume_of_envelope(clk, `GB_BUS_PORTS_LIST, REG_Initial_Volume_of_envelope, REG_Initial_Volume_of_envelope, Initial_Volume_of_envelope_written);
    
    eProcReg_gba #(SOUND4CNT_H_Dividing_Ratio_of_Freq) iREG_Dividing_Ratio_of_Freq(clk, `GB_BUS_PORTS_LIST, REG_Dividing_Ratio_of_Freq, REG_Dividing_Ratio_of_Freq, Dividing_Ratio_of_Freq_written);
    eProcReg_gba #(SOUND4CNT_H_Counter_Step_Width) iREG_Counter_Step_Width(clk, `GB_BUS_PORTS_LIST, REG_Counter_Step_Width, REG_Counter_Step_Width);
    eProcReg_gba #(SOUND4CNT_H_Shift_Clock_Frequency) iREG_Shift_Clock_Frequency(clk, `GB_BUS_PORTS_LIST, REG_Shift_Clock_Frequency, REG_Shift_Clock_Frequency);
    eProcReg_gba #(SOUND4CNT_H_Length_Flag) iREG_Length_Flag(clk, `GB_BUS_PORTS_LIST, REG_Length_Flag, REG_Length_Flag);
    eProcReg_gba #(SOUND4CNT_H_Initial) iREG_Initial(clk, `GB_BUS_PORTS_LIST, 1'b0, REG_Initial, Initial_written);
    
    eProcReg_gba #(SOUND4CNT_LHighZero) iSOUND4CNT_LHighZero(clk, `GB_BUS_PORTS_LIST, 16'h0000);
    eProcReg_gba #(SOUND4CNT_HHighZero) iSOUND4CNT_HHighZero(clk, `GB_BUS_PORTS_LIST, 16'h0000);
    
    // MMIO reg reads
    reg [31:0] reg_dout;
    reg reg_dout_en;
    assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};

    always @(posedge clk) begin
        reg_dout_en <= 0;

        if (gb_bus_ena & gb_bus_rnw) begin
            reg_dout_en <= 1;
            case (gb_bus_adr)
            SOUND4CNT_L_Sound_length.Adr:               // 078
                reg_dout <= {16'b0, REG_Initial_Volume_of_envelope, REG_Envelope_Direction, REG_Envelope_Step_Time, 2'b0, 6'b0 /*REG_Sound_length*/};
            
            SOUND4CNT_H_Dividing_Ratio_of_Freq.Adr:     // 07C
                reg_dout <= {16'b0, 1'b0 /*REG_Initial*/, REG_Length_Flag, 6'b0, 
                    REG_Shift_Clock_Frequency, REG_Counter_Step_Width, REG_Dividing_Ratio_of_Freq};

            default: reg_dout_en <= 0;
            endcase
        end
    end



    always @(posedge clk) begin
        reg [4:0] divider_raw;

        if (gb_on == 1'b0) begin
            
            sound_out <= {16{1'b0}};
            sound_on <= 1'b0;
            
            length_left <= {7{1'b0}};
            envelope_cnt <= {6{1'b0}};
            envelope_add <= {6{1'b0}};
            volume <= 0;
            wave_on <= 1'b0;
            freq_divider <= {24{1'b0}};
            length_on <= 1'b0;
            ch_on <= 1'b0;
            lfsr7bit <= 1'b0;
            lfsr <= {15{1'b0}};
            soundcycles_freq <= {24{1'b0}};
            soundcycles_envelope <= {18{1'b0}};
            soundcycles_length <= {17{1'b0}};
        
        end else if (reset) begin
            
            sound_out <= {16{1'b0}};
            ch_on <= 1;

        end  else begin
            
            // register write triggers
            if (Sound_length_written)
                length_left <= 64 - REG_Sound_length;
            
            if (Initial_Volume_of_envelope_written) begin
                envelope_cnt <= {6{1'b0}};
                envelope_add <= {6{1'b0}};
                volume <= REG_Initial_Volume_of_envelope;
            end 
            
            if (Dividing_Ratio_of_Freq_written) begin
                divider_raw = 8;
                case (REG_Dividing_Ratio_of_Freq)
                    0 : divider_raw = 8;
                    1 : divider_raw = 16;
                    2 : divider_raw = 32;
                    3 : divider_raw = 48;
                    4 : divider_raw = 64;
                    5 : divider_raw = 80;
                    6 : divider_raw = 96;
                    7 : divider_raw = 112;
                    default : ;
                endcase
                
                lfsr7bit <= REG_Counter_Step_Width[SOUND4CNT_H_Counter_Step_Width.upper];
                freq_divider <= divider_raw << REG_Shift_Clock_Frequency;
            end 
            
            if (Initial_written) begin
                length_on <= REG_Length_Flag[SOUND4CNT_H_Length_Flag.upper];
                if (REG_Initial) begin
                    envelope_cnt <= {6{1'b0}};
                    envelope_add <= {6{1'b0}};
                    ch_on <= 1;
                    
                    wave_on <= 1'b1;		// 1 because negative output
                    lfsr <= {15{1'b1}};
                    if (REG_Counter_Step_Width)
                        lfsr[14:7] <= {15{1'b0}};
                end 
            end 
            
            if (ch_on) begin
                // cpu cycle trigger
                soundcycles_freq <= soundcycles_freq + 1;
                soundcycles_envelope <= soundcycles_envelope + 1;
                soundcycles_length <= soundcycles_length + 1;
                
                wave_on <= (~lfsr[0]);
                
                // freq / wavetable
                if (soundcycles_freq >= freq_divider) begin
                    soundcycles_freq <= soundcycles_freq - freq_divider;
                    if (lfsr7bit)
                        lfsr <= {8'h00, (lfsr[1] ^ lfsr[0]), lfsr[6:1]};
                    else
                        lfsr <= {(lfsr[1] ^ lfsr[0]), lfsr[14:1]};
                end 
                
                // envelope
                if (soundcycles_envelope >= 65536) begin		// 64 Hz
                    soundcycles_envelope <= soundcycles_envelope - 65536;
                    if (REG_Envelope_Step_Time != 3'b000)
                        envelope_cnt <= envelope_cnt + 1;
                end 
                
                if (REG_Envelope_Step_Time != 3'b000) begin
                    if (envelope_cnt >= REG_Envelope_Step_Time) begin
                        envelope_cnt <= {6{1'b0}};
                        if (envelope_add < 15)
                            envelope_add <= envelope_add + 1;
                    end 
                    
                    if (REG_Envelope_Direction == 1'b0) begin		// decrease
                        if (REG_Initial_Volume_of_envelope >= envelope_add)
                            volume <= REG_Initial_Volume_of_envelope - envelope_add;
                        else
                            volume <= 0;
                    end else
                        if (REG_Initial_Volume_of_envelope + envelope_add <= 15)
                            volume <= REG_Initial_Volume_of_envelope + envelope_add;
                        else
                            volume <= 15;
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
                
                // sound out
                if (wave_on)
                    sound_out <= signed'(volume);
                else
                    sound_out <= -1 * signed'(volume);
            end else
                sound_out <= {16{1'b0}};
            
            sound_on <= ch_on;
        end
    end
    
endmodule
`undef pproc_bus_gba
`undef preg_gba_sound