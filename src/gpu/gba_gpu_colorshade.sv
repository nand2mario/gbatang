
module gba_gpu_colorshade(
    input            fclk,
    
    input [2:0]      shade_mode,		// 0 = off, 1..4 modes
    
    input [7:0]      pixel_in_x,
    input [8:0]      pixel_in_2x,
    input [7:0]      pixel_in_y,
    input [15:0]     pixel_in_addr,
    input [14:0]     pixel_in_data,     // RGB5 color input
    input            pixel_in_we,
    
    output reg [7:0]     pixel_out_x,
    output reg [8:0]     pixel_out_2x,
    output reg [7:0]     pixel_out_y,
    output reg [15:0]    pixel_out_addr,
    output reg [17:0]    pixel_out_data,    // RGB6 color output
    output reg           pixel_out_we
);
    
    parameter [9:0]  shade_lookup_linear_ram[0:127] = {
        // 2.2
        0, 1, 2, 6, 11, 17, 26, 36, 
        49, 63, 79, 98, 118, 141, 166, 193, 
        223, 255, 289, 325, 364, 405, 449, 495, 
        544, 595, 649, 705, 763, 825, 888, 955, 
        
        // 1.6
        0, 4, 12, 23, 37, 53, 70, 90, 
        111, 135, 159, 185, 213, 242, 273, 305, 
        338, 372, 408, 445, 483, 522, 562, 604, 
        646, 690, 735, 780, 827, 875, 924, 973, 
        
        // 1.6
        0, 4, 12, 23, 37, 53, 70, 90, 
        111, 135, 159, 185, 213, 242, 273, 305, 
        338, 372, 408, 445, 483, 522, 562, 604, 
        646, 690, 735, 780, 827, 875, 924, 973, 
        
        // 1.4
        0, 8, 21, 37, 56, 76, 98, 122, 
        147, 173, 201, 230, 259, 290, 322, 355, 
        388, 422, 458, 494, 530, 568, 606, 645, 
        685, 725, 766, 807, 849, 892, 936, 979
    };
    
    parameter signed [10:0] shade_mult_ram[0:35] = {
        // shader gba-color
        865, 174, -015, 
        92, 696, 236, 
        164, 87, 773, 
        
        // shader gba-color
        865, 174, -015, 
        92, 696, 236, 
        164, 87, 773, 
        
        // shader nds-color
        850, 205, -031, 
        107, 666, 251, 
        107, 134, 783, 
        
        // shader vba-color (supposed to be done at 1.4 gamma not 1.6)
        758, 266, 0, 
        82, 696, 246, 
        82, 246, 696
    };
    
    parameter [9:0]  shade_lookup_rgb_border_ram[0:255] = {
        // 2.2
        0, 1, 2, 3, 4, 5, 6, 8, 
        11, 14, 17, 21, 26, 31, 36, 42, 
        49, 55, 63, 71, 79, 88, 98, 108, 
        118, 129, 141, 153, 166, 179, 193, 208, 
        223, 238, 255, 271, 289, 307, 325, 344, 
        364, 384, 405, 427, 449, 472, 495, 519, 
        544, 569, 595, 621, 649, 676, 705, 734, 
        763, 794, 825, 856, 888, 921, 955, 989, 
        
        // 1.6
        0, 1, 4, 8, 12, 17, 23, 30, 
        37, 44, 53, 61, 70, 80, 90, 100, 
        111, 123, 135, 147, 159, 172, 185, 199, 
        213, 228, 242, 257, 273, 289, 305, 321, 
        338, 355, 372, 390, 408, 426, 445, 464, 
        483, 502, 522, 542, 562, 583, 604, 625, 
        646, 668, 690, 712, 735, 757, 780, 804, 
        827, 851, 875, 899, 924, 948, 973, 999, 
        
        // 1.6
        0, 1, 4, 8, 12, 17, 23, 30, 
        37, 44, 53, 61, 70, 80, 90, 100, 
        111, 123, 135, 147, 159, 172, 185, 199, 
        213, 228, 242, 257, 273, 289, 305, 321, 
        338, 355, 372, 390, 408, 426, 445, 464, 
        483, 502, 522, 542, 562, 583, 604, 625, 
        646, 668, 690, 712, 735, 757, 780, 804, 
        827, 851, 875, 899, 924, 948, 973, 999, 
        
        // 1.4
        0, 3, 8, 14, 21, 29, 37, 46, 
        56, 66, 76, 87, 98, 110, 122, 134, 
        147, 160, 173, 187, 201, 215, 230, 244, 
        259, 275, 290, 306, 322, 338, 355, 371, 
        388, 405, 422, 440, 458, 475, 494, 512, 
        530, 549, 568, 587, 606, 625, 645, 665, 
        685, 705, 725, 745, 766, 786, 807, 828, 
        849, 871, 892, 914, 936, 957, 979, 1002
    };
    
    reg [9:0]        shade_lookup_linear[0:31];
    reg signed [10:0]       shade_mult[0:8];
    reg [9:0]        shade_lookup_rgb_border[0:63];
    
    // shade loading
    reg              shade_on;
    reg [2:0]        shade_mode_act;
    
    parameter [1:0]  tstate_IDLE = 0,
                     tstate_READ_VALUE = 1,
                     tstate_WRITE_VALUE = 2;
    reg [1:0]        state;
    
    reg [4:0]        linear_count;
    reg [3:0]        mult_count;
    reg [5:0]        rgb_count;
    
    reg [6:0]        linear_address;
    reg [5:0]        mult_address;
    reg [7:0]        rgb_address;
    
    reg [9:0]        linear_value;
    reg signed [10:0]       mult_value;
    reg [9:0]        rgb_value;
    
    // shade processing
    reg [7:0]        pixel_1_x;
    reg [8:0]        pixel_1_2x;
    reg [7:0]        pixel_1_y;
    reg [15:0]       pixel_1_addr;
    reg              pixel_1_we;
    reg [9:0]        color_linear_1;
    reg [9:0]        color_linear_2;
    reg [9:0]        color_linear_3;
    
    reg [7:0]        pixel_2_x;
    reg [8:0]        pixel_2_2x;
    reg [7:0]        pixel_2_y;
    reg [15:0]       pixel_2_addr;
    reg              pixel_2_we;
    reg signed [20:0]       shade_precalc[1:3][1:3];
    
    reg [7:0]        pixel_3_x;
    reg [8:0]        pixel_3_2x;
    reg [7:0]        pixel_3_y;
    reg [15:0]       pixel_3_addr;
    reg              pixel_3_we;
    reg signed [11:0]       shade_linear[1:3];
    
    reg [7:0]        pixel_4_x;
    reg [8:0]        pixel_4_2x;
    reg [7:0]        pixel_4_y;
    reg [15:0]       pixel_4_addr;
    reg              pixel_4_we;
    reg [9:0]        clip_linear[1:3];
    
    reg [7:0]        pixel_5_x;
    reg [8:0]        pixel_5_2x;
    reg [7:0]        pixel_5_y;
    reg [15:0]       pixel_5_addr;
    reg              pixel_5_we;
    reg [9:0]        clip_linear_1[1:3];
    reg [2:0]        color_upper[1:3];
    reg [9:0]        colorlimitnext[1:3][1:7];
    
    // load shading
    always @(posedge fclk) begin

        shade_on <= 1'b0;
        if (shade_mode != 3'b000)
            shade_on <= 1'b1;
        
        case (state)
            
            tstate_IDLE :
                if (shade_mode_act != shade_mode) begin
                    shade_mode_act <= shade_mode;
                    if (shade_mode != 3'b000) begin
                        state <= tstate_READ_VALUE;
                        linear_count <= 0;
                        mult_count <= 0;
                        rgb_count <= 0;
                        linear_address <= (shade_mode - 1) * 32;
                        mult_address <= (shade_mode - 1) * 9;
                        rgb_address <= (shade_mode - 1) * 64;
                    end 
                end 
            
            tstate_READ_VALUE :
                begin
                    state <= tstate_WRITE_VALUE;
                    linear_value <= shade_lookup_linear_ram[linear_address];
                    mult_value <= shade_mult_ram[mult_address];
                    rgb_value <= shade_lookup_rgb_border_ram[rgb_address];
                end
            
            tstate_WRITE_VALUE :
                begin
                    shade_lookup_linear[linear_count] <= linear_value;
                    shade_mult[mult_count] <= mult_value;
                    shade_lookup_rgb_border[rgb_count] <= rgb_value;
                    if (rgb_count < 63) begin
                        state <= tstate_READ_VALUE;
                        if (linear_count < 31) begin
                            linear_count <= linear_count + 1;
                            linear_address <= linear_address + 1;
                        end 
                        if (mult_count < 8) begin
                            mult_count <= mult_count + 1;
                            mult_address <= mult_address + 1;
                        end 
                        rgb_address <= rgb_address + 1;
                        rgb_count <= rgb_count + 1;
                    end else
                        state <= tstate_IDLE;
                end

            default: ;

        endcase
    end 
    
    // process shading
    always @(posedge fclk) begin
        integer          c;
        integer          j;
        integer          i;
            
        // clock 1 - lookup linear color
        pixel_1_x <= pixel_in_x;
        pixel_1_2x <= pixel_in_2x;
        pixel_1_y <= pixel_in_y;
        pixel_1_addr <= pixel_in_addr;
        pixel_1_we <= pixel_in_we;
        
        color_linear_1 <= shade_lookup_linear[((pixel_in_data[14:10]))];
        color_linear_2 <= shade_lookup_linear[((pixel_in_data[9:5]))];
        color_linear_3 <= shade_lookup_linear[((pixel_in_data[4:0]))];
        
        // clock 2 - precalc shades
        pixel_2_x <= pixel_1_x;
        pixel_2_2x <= pixel_1_2x;
        pixel_2_y <= pixel_1_y;
        pixel_2_addr <= pixel_1_addr;
        pixel_2_we <= pixel_1_we;
        
        //shade_linear(1) <=  (865 * color_linear_1 + 174 * color_linear_2 - 015 * color_linear_3) / 1024;
        //shade_linear(2) <=  ( 92 * color_linear_1 + 696 * color_linear_2 + 236 * color_linear_3) / 1024;
        //shade_linear(3) <=  (164 * color_linear_1 +  87 * color_linear_2 + 773 * color_linear_3) / 1024;
        
        shade_precalc[1][1] <= 865 * color_linear_1;
        shade_precalc[2][1] <= 92 * color_linear_1;
        shade_precalc[3][1] <= 164 * color_linear_1;
        shade_precalc[1][2] <= 174 * color_linear_2;
        shade_precalc[2][2] <= 696 * color_linear_2;
        shade_precalc[3][2] <= 87 * color_linear_2;
        shade_precalc[1][3] <= 015 * color_linear_3;
        shade_precalc[2][3] <= 236 * color_linear_3;
        shade_precalc[3][3] <= 773 * color_linear_3;
        
        shade_precalc[1][1] <= shade_mult[0] * signed'({1'b0, color_linear_1});
        shade_precalc[1][2] <= shade_mult[1] * signed'({1'b0, color_linear_2});
        shade_precalc[1][3] <= shade_mult[2] * signed'({1'b0, color_linear_3});
        shade_precalc[2][1] <= shade_mult[3] * signed'({1'b0, color_linear_1});
        shade_precalc[2][2] <= shade_mult[4] * signed'({1'b0, color_linear_2});
        shade_precalc[2][3] <= shade_mult[5] * signed'({1'b0, color_linear_3});
        shade_precalc[3][1] <= shade_mult[6] * signed'({1'b0, color_linear_1});
        shade_precalc[3][2] <= shade_mult[7] * signed'({1'b0, color_linear_2});
        shade_precalc[3][3] <= shade_mult[8] * signed'({1'b0, color_linear_3});
        
        // clock 3 - apply shading
        pixel_3_x <= pixel_2_x;
        pixel_3_2x <= pixel_2_2x;
        pixel_3_y <= pixel_2_y;
        pixel_3_addr <= pixel_2_addr;
        pixel_3_we <= pixel_2_we;

        // shade_linear[1] <= (shade_precalc[1][1] + shade_precalc[1][2] + shade_precalc[1][3])/1024;        
        shade_linear[1] <= (shade_precalc[1][1] + shade_precalc[1][2] + shade_precalc[1][3]) >>> 10;    // arith shift right to preserve sign
        shade_linear[2] <= (shade_precalc[2][1] + shade_precalc[2][2] + shade_precalc[2][3]) >>> 10;
        shade_linear[3] <= (shade_precalc[3][1] + shade_precalc[3][2] + shade_precalc[3][3]) >>> 10;
        
        // clock 4 - clip
        pixel_4_x <= pixel_3_x;
        pixel_4_2x <= pixel_3_2x;
        pixel_4_y <= pixel_3_y;
        pixel_4_addr <= pixel_3_addr;
        pixel_4_we <= pixel_3_we;
        
        for (c = 1; c <= 3; c = c + 1)
            if (shade_linear[c] < 0)
                clip_linear[c] <= 0;
            else if (shade_linear[c] > 1023)
                clip_linear[c] <= 1023;
            else
                clip_linear[c] <= shade_linear[c];
        
        // clock 5 - lookup upper 3 bits of color
        pixel_5_x <= pixel_4_x;
        pixel_5_2x <= pixel_4_2x;
        pixel_5_y <= pixel_4_y;
        pixel_5_addr <= pixel_4_addr;
        pixel_5_we <= pixel_4_we;
        clip_linear_1 <= clip_linear;
        
        color_upper[1] <= 3'b0;
        color_upper[2] <= 3'b0;
        color_upper[3] <= 3'b0;
        for (c = 1; c <= 3; c = c + 1) begin
            for (j = 1; j <= 7; j = j + 1)
                colorlimitnext[c][j] <= shade_lookup_rgb_border[j];
            for (i = 1; i <= 7; i = i + 1)
                if (clip_linear[c] > shade_lookup_rgb_border[i * 8]) begin
                    color_upper[c] <= i;
                    for (j = 1; j <= 7; j = j + 1)
                        colorlimitnext[c][j] <= shade_lookup_rgb_border[i * 8 + j];
                end 
        end
        
        if (shade_on == 1'b1) begin
            
            // clock 6 - lookup lower 3 bits of color
            pixel_out_x <= pixel_5_x;
            pixel_out_2x <= pixel_5_2x;
            pixel_out_y <= pixel_5_y;
            pixel_out_addr <= pixel_5_addr;
            pixel_out_we <= pixel_5_we;
            
            pixel_out_data[17:12] <= {color_upper[1], 3'b000};
            pixel_out_data[11:6] <= {color_upper[2], 3'b000};
            pixel_out_data[5:0] <= {color_upper[3], 3'b000};
            for (c = 1; c <= 3; c = c + 1)
                for (i = 1; i <= 7; i = i + 1) begin
                    if (clip_linear_1[c] > colorlimitnext[c][i])
                        case (c)
                        1: pixel_out_data[14:12] <= i;
                        2: pixel_out_data[8:6] <= i;
                        3: pixel_out_data[2:0] <= i;
                        default: ;
                        endcase
                end
        end else begin
            
            pixel_out_x <= pixel_in_x;
            pixel_out_2x <= pixel_in_2x;
            pixel_out_y <= pixel_in_y;
            pixel_out_addr <= pixel_in_addr;
            pixel_out_we <= pixel_in_we;
            pixel_out_data <= {pixel_in_data[14:10], pixel_in_data[14], pixel_in_data[9:5], pixel_in_data[9], pixel_in_data[4:0], pixel_in_data[4]};
        end
    end
    
endmodule
