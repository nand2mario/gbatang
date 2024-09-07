
// Channel 1 is Tone & Sweep
// Channel 2 is Tone only
module gba_sound_ch1(clk, reset, gb_on, gb_bus_din, gb_bus_dout, gb_bus_adr, gb_bus_rnw, gb_bus_ena, gb_bus_done, gb_bus_acc, gb_bus_be, gb_bus_rst, 
            sound_out, sound_on);

    `include "pproc_bus_gba.sv"
    `include "preg_gba_sound.sv"

    parameter                 has_sweep = 0;
    parameter    regmap_type  Reg_Number_of_sweep_shift     ;
    parameter    regmap_type  Reg_Sweep_Frequency_Direction ;
    parameter    regmap_type  Reg_Sweep_Time                ;
    parameter    regmap_type  Reg_Sound_length              ;
    parameter    regmap_type  Reg_Wave_Pattern_Duty         ;
    parameter    regmap_type  Reg_Envelope_Step_Time        ;
    parameter    regmap_type  Reg_Envelope_Direction        ;
    parameter    regmap_type  Reg_Initial_Volume_of_envelope;
    parameter    regmap_type  Reg_Frequency                 ;
    parameter    regmap_type  Reg_Length_Flag               ;
    parameter    regmap_type  Reg_Initial                   ;
    parameter    regmap_type  Reg_HighZero                  ;

    input                     clk;
    input                     reset;
    input                     gb_on;
    
    `GB_BUS_PORTS_DECL;
        
    output reg [15:0]         sound_out;
    output reg                sound_on;
    
    
    wire [Reg_Number_of_sweep_shift     .upper : Reg_Number_of_sweep_shift     .lower] Channel_Number_of_sweep_shift;
    wire [Reg_Sweep_Frequency_Direction .upper : Reg_Sweep_Frequency_Direction .lower] Channel_Sweep_Frequency_Direction;
    wire [Reg_Sweep_Time                .upper : Reg_Sweep_Time                .lower] Channel_Sweep_Time;
    wire [Reg_Sound_length              .upper : Reg_Sound_length              .lower] Channel_Sound_length;
    wire [Reg_Wave_Pattern_Duty         .upper : Reg_Wave_Pattern_Duty         .lower] Channel_Wave_Pattern_Duty;
    wire [Reg_Envelope_Step_Time        .upper : Reg_Envelope_Step_Time        .lower] Channel_Envelope_Step_Time;
    wire [Reg_Envelope_Direction        .upper : Reg_Envelope_Direction        .lower] Channel_Envelope_Direction;
    wire [Reg_Initial_Volume_of_envelope.upper : Reg_Initial_Volume_of_envelope.lower] Channel_Initial_Volume_of_envelope;
    wire [Reg_Frequency                 .upper : Reg_Frequency                 .lower] Channel_Frequency;
    wire [Reg_Length_Flag               .upper : Reg_Length_Flag               .lower] Channel_Length_Flag;
    wire [Reg_Initial                   .upper : Reg_Initial                   .lower] Channel_Initial;
    wire [Reg_HighZero                  .upper : Reg_HighZero                  .lower] Channel_HighZero;
    
    wire       Channel_Sound_length_written;
    wire       Channel_Wave_Pattern_Duty_written;
    wire       Channel_Initial_Volume_of_envelope_written;
    wire       Channel_Frequency_written;
    
    reg [2:0]  wavetable_ptr;
    reg [7:0]  wavetable;
    reg        wave_on;
    
    reg [7:0]  sweepcnt;
    
    reg [6:0]  length_left;
    
    reg [5:0]  envelope_cnt;
    reg [5:0]  envelope_add;
    
    reg [3:0]  volume;
    
    reg [11:0] freq_divider;
    reg [11:0] freq_check;
    reg        length_on;
    reg        ch_on;
    reg [11:0] freq_cnt;
    reg [11:0] sweep_next;
    
    reg [7:0]  soundcycles_freq;
    reg [16:0] soundcycles_sweep;
    reg [17:0] soundcycles_envelope;
    reg [16:0] soundcycles_length;
    
    generate
    if (has_sweep) begin : gsweep
        eProcReg_gba #(Reg_Number_of_sweep_shift) iReg_Channel_Number_of_sweep_shift(clk, `GB_BUS_PORTS_LIST, Channel_Number_of_sweep_shift, Channel_Number_of_sweep_shift);
        eProcReg_gba #(Reg_Sweep_Frequency_Direction) iReg_Channel_Sweep_Frequency_Direction(clk, `GB_BUS_PORTS_LIST, Channel_Sweep_Frequency_Direction, Channel_Sweep_Frequency_Direction);
        eProcReg_gba #(Reg_Sweep_Time) iReg_Channel_Sweep_Time(clk, `GB_BUS_PORTS_LIST, Channel_Sweep_Time, Channel_Sweep_Time);
    end
    endgenerate
    
    eProcReg_gba #(Reg_Sound_length) iReg_Channel_Sound_length(clk, `GB_BUS_PORTS_LIST, 6'b0, Channel_Sound_length, Channel_Sound_length_written);
    eProcReg_gba #(Reg_Wave_Pattern_Duty) iReg_Channel_Wave_Pattern_Duty(clk, `GB_BUS_PORTS_LIST, , Channel_Wave_Pattern_Duty, Channel_Wave_Pattern_Duty_written);
    eProcReg_gba #(Reg_Envelope_Step_Time) iReg_Channel_Envelope_Step_Time(clk, `GB_BUS_PORTS_LIST, Channel_Envelope_Step_Time, Channel_Envelope_Step_Time);
    eProcReg_gba #(Reg_Envelope_Direction) iReg_Channel_Envelope_Direction(clk, `GB_BUS_PORTS_LIST, Channel_Envelope_Direction, Channel_Envelope_Direction);
    eProcReg_gba #(Reg_Initial_Volume_of_envelope) iReg_Channel_Initial_Volume_of_envelope(clk, `GB_BUS_PORTS_LIST, Channel_Initial_Volume_of_envelope, Channel_Initial_Volume_of_envelope, Channel_Initial_Volume_of_envelope_written);

    eProcReg_gba #(Reg_Frequency) iReg_Channel_Frequency(clk, `GB_BUS_PORTS_LIST, 11'b0, Channel_Frequency, Channel_Frequency_written);
    eProcReg_gba #(Reg_Length_Flag) iReg_Channel_Length_Flag(clk, `GB_BUS_PORTS_LIST, Channel_Length_Flag, Channel_Length_Flag);
    eProcReg_gba #(Reg_Initial) iReg_Channel_Initial(clk, `GB_BUS_PORTS_LIST, 1'b0, Channel_Initial);
    eProcReg_gba #(Reg_HighZero) iReg_Channel_HighZero(clk, `GB_BUS_PORTS_LIST, Channel_HighZero);
    
    // MMIO reg reads
    reg [31:0] reg_dout;
    reg reg_dout_en;
    assign gb_bus_dout = reg_dout_en ? reg_dout : {32{1'bZ}};

    always @(posedge clk) begin
        reg_dout_en <= 0;

        if (gb_bus_ena & gb_bus_rnw) begin
            reg_dout_en <= 1;
            case (gb_bus_adr)
            Reg_Sound_length.Adr:         // 060 / 068
                reg_dout <= {Channel_Initial_Volume_of_envelope, Channel_Envelope_Direction, Channel_Envelope_Step_Time, // [31:24]
                Channel_Wave_Pattern_Duty, 6'b0 /* write-only Channel_Sound_length */,    // [23:16]
                8'b0,   // [15:8]
                1'b0, Channel_Sweep_Time,  Channel_Sweep_Frequency_Direction, Channel_Number_of_sweep_shift};   // [7:0]
            
            Reg_Frequency.Adr:            // 064 / 06C
                reg_dout <= {1'b0 /*Channel_Initial*/, Channel_Length_Flag, 3'b0, 11'b0 /*Channel_Frequency*/}; 

            default: reg_dout_en <= 0;
            endcase
        end
    end

    always @(posedge clk) begin
        
        if (gb_on == 1'b0) begin
            
            sound_out <= {16{1'b0}};
            sound_on <= 1'b0;
            
            wavetable_ptr <= {3{1'b0}};
            wavetable <= {8{1'b0}};
            wave_on <= 1'b0;
            sweepcnt <= {8{1'b0}};
            length_left <= {7{1'b0}};
            envelope_cnt <= {6{1'b0}};
            envelope_add <= {6{1'b0}};
            volume <= 0;
            freq_divider <= {12{1'b0}};
            freq_check <= {12{1'b0}};
            length_on <= 1'b0;
            ch_on <= 1'b0;
            freq_cnt <= {12{1'b0}};
            soundcycles_freq <= {8{1'b0}};
            soundcycles_sweep <= {17{1'b0}};
            soundcycles_envelope <= {18{1'b0}};
            soundcycles_length <= {17{1'b0}};
        
        end else if (reset) begin
            
            sound_out <= {16{1'b0}};
            ch_on <= 1;
        end  else begin
            
            // register write triggers
            if (Channel_Wave_Pattern_Duty_written)
                sweepcnt <= {8{1'b0}};
            
            if (Channel_Sound_length_written)
                length_left <= 64 - Channel_Sound_length;
            
            if (Channel_Initial_Volume_of_envelope_written) begin
                envelope_cnt <= {6{1'b0}};
                envelope_add <= {6{1'b0}};
                volume <= Channel_Initial_Volume_of_envelope;
            end 
            
            if (Channel_Frequency_written) begin
                freq_divider <= {1'b0, Channel_Frequency};
                length_on <= Channel_Length_Flag[Reg_Length_Flag.upper];
                if (Channel_Initial) begin
                    sweepcnt <= {8{1'b0}};
                    envelope_cnt <= {6{1'b0}};
                    envelope_add <= {6{1'b0}};
                    ch_on <= 1;
                    freq_cnt <= {12{1'b0}};
                    wavetable_ptr <= {3{1'b0}};
                end 
            end 
            
            if (ch_on) begin
                // cpu cycle trigger
                soundcycles_freq <= soundcycles_freq + 1;
                soundcycles_sweep <= soundcycles_sweep + 1;
                soundcycles_envelope <= soundcycles_envelope + 1;
                soundcycles_length <= soundcycles_length + 1;
                
                // freq / wavetable
                if (soundcycles_freq >= 4) begin
                    freq_cnt <= freq_cnt + 1;
                    soundcycles_freq <= soundcycles_freq - 4;
                end 
                
                freq_check <= 2048 - freq_divider;
                
                if (freq_cnt >= freq_check) begin
                    freq_cnt <= freq_cnt - freq_check;
                    wavetable_ptr <= wavetable_ptr + 1;
                end 
                
                // sweep
                sweep_next <= freq_divider >> Channel_Number_of_sweep_shift;
                
                if (has_sweep) begin
                    if (soundcycles_sweep >= 32768) begin		// 128 Hz
                        soundcycles_sweep <= soundcycles_sweep - 32768;
                        if (Channel_Sweep_Time != 3'b000)
                            sweepcnt <= sweepcnt + 1;
                    end 
                    
                    if (Channel_Sweep_Time != 3'b000) begin
                        if (sweepcnt >= Channel_Sweep_Time) begin
                            sweepcnt <= {8{1'b0}};
                            if (Channel_Sweep_Frequency_Direction == 1'b0) begin		// increase
                                freq_divider <= freq_divider + sweep_next;
                                if (freq_divider + sweep_next >= 2048)
                                    ch_on <= 1'b0;
                            end else begin
                                freq_divider <= freq_divider - sweep_next;
                                if (sweep_next > freq_divider)
                                    ch_on <= 1'b0;
                            end
                        end 
                    end 
                end 
                
                // envelope
                if (soundcycles_envelope >= 65536) begin		// 64 Hz
                    soundcycles_envelope <= soundcycles_envelope - 65536;
                    if (Channel_Envelope_Step_Time != 3'b000)
                        envelope_cnt <= envelope_cnt + 1;
                end 
                
                if (Channel_Envelope_Step_Time != 3'b000) begin
                    if (envelope_cnt >= Channel_Envelope_Step_Time) begin
                        envelope_cnt <= {6{1'b0}};
                        if (envelope_add < 15)
                            envelope_add <= envelope_add + 1;
                    end 
                    
                    if (Channel_Envelope_Direction == 1'b0) begin		// decrease
                        if (Channel_Initial_Volume_of_envelope >= envelope_add)
                            volume <= Channel_Initial_Volume_of_envelope - envelope_add;
                        else
                            volume <= 0;
                    end else
                        if (Channel_Initial_Volume_of_envelope + envelope_add <= 15)
                            volume <= Channel_Initial_Volume_of_envelope + envelope_add;
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
                
                // duty
                case (Channel_Wave_Pattern_Duty)
                    0 : wavetable <= 8'b00000001;           // nand2mario: wavetable is std_logic_vector(0 to 7)
                    1 : wavetable <= 8'b10000001;
                    2 : wavetable <= 8'b10000111;
                    3 : wavetable <= 8'b01111110;
                    default : ;
                endcase
                
                wave_on <= wavetable[wavetable_ptr];
                
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