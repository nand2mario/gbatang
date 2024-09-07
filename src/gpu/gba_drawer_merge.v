
module gba_drawer_merge(fclk, enable, hblank, xpos, ypos, in_wnd0_on, in_wnd1_on, in_wndobj_on, in_wnd0_x1, in_wnd0_x2, in_wnd0_y1, in_wnd0_y2, in_wnd1_x1, in_wnd1_x2, in_wnd1_y1, in_wnd1_y2, in_enables_wnd0, in_enables_wnd1, in_enables_wndobj, in_enables_wndout, in_special_effect_in, in_effect_1st_bg0, in_effect_1st_bg1, in_effect_1st_bg2, in_effect_1st_bg3, in_effect_1st_obj, in_effect_1st_bd, in_effect_2nd_bg0, in_effect_2nd_bg1, in_effect_2nd_bg2, in_effect_2nd_bg3, in_effect_2nd_obj, in_effect_2nd_bd, in_prio_bg0, in_prio_bg1, in_prio_bg2, in_prio_bg3, in_eva, in_evb, in_bldy, in_ena_bg0, in_ena_bg1, in_ena_bg2, in_ena_bg3, in_ena_obj, pixeldata_bg0, pixeldata_bg1, pixeldata_bg2, pixeldata_bg3, pixeldata_obj, pixeldata_back, objwindow_in, pixeldata_out, pixel_x, pixel_y, pixel_we);
    input         fclk;
    
    input         enable;
    input         hblank;
    input [7:0]   xpos;
    input [7:0]   ypos;
    
    input         in_wnd0_on;
    input         in_wnd1_on;
    input         in_wndobj_on;
    
    input [7:0]   in_wnd0_x1;
    input [7:0]   in_wnd0_x2;
    input [7:0]   in_wnd0_y1;
    input [7:0]   in_wnd0_y2;
    input [7:0]   in_wnd1_x1;
    input [7:0]   in_wnd1_x2;
    input [7:0]   in_wnd1_y1;
    input [7:0]   in_wnd1_y2;
    
    input [5:0]   in_enables_wnd0;
    input [5:0]   in_enables_wnd1;
    input [5:0]   in_enables_wndobj;
    input [5:0]   in_enables_wndout;
    
    input [1:0]   in_special_effect_in;
    input         in_effect_1st_bg0;
    input         in_effect_1st_bg1;
    input         in_effect_1st_bg2;
    input         in_effect_1st_bg3;
    input         in_effect_1st_obj;
    input         in_effect_1st_bd;
    input         in_effect_2nd_bg0;
    input         in_effect_2nd_bg1;
    input         in_effect_2nd_bg2;
    input         in_effect_2nd_bg3;
    input         in_effect_2nd_obj;
    input         in_effect_2nd_bd;
    
    input [1:0]   in_prio_bg0;
    input [1:0]   in_prio_bg1;
    input [1:0]   in_prio_bg2;
    input [1:0]   in_prio_bg3;
    
    input [4:0]   in_eva;
    input [4:0]   in_evb;
    input [4:0]   in_bldy;
    
    input         in_ena_bg0;
    input         in_ena_bg1;
    input         in_ena_bg2;
    input         in_ena_bg3;
    input         in_ena_obj;
    
    input [15:0]  pixeldata_bg0;
    input [15:0]  pixeldata_bg1;
    input [15:0]  pixeldata_bg2;
    input [15:0]  pixeldata_bg3;
    input [18:0]  pixeldata_obj;
    input [15:0]  pixeldata_back;
    input         objwindow_in;
    
    output reg [15:0] pixeldata_out;
    output reg [7:0]  pixel_x;
    output reg [7:0]  pixel_y;
    output reg        pixel_we;


    parameter     BG0 = 0;
    parameter     BG1 = 1;
    parameter     BG2 = 2;
    parameter     BG3 = 3;
    parameter     OBJ = 4;
    parameter     BD = 5;
    
    parameter     TRANSPARENT = 15;
    parameter     OBJALPHA = 16;
    parameter     OBJPRIOH = 18;
    parameter     OBJPRIOL = 17;
    
    // latch on hblank
    reg           WND0_on;
    reg           WND1_on;
    reg           WNDOBJ_on;
    
    reg [7:0]     WND0_X1;
    reg [7:0]     WND0_X2;
    reg [7:0]     WND0_Y1;
    reg [7:0]     WND0_Y2;
    reg [7:0]     WND1_X1;
    reg [7:0]     WND1_X2;
    reg [7:0]     WND1_Y1;
    reg [7:0]     WND1_Y2;
    
    reg [5:0]     enables_wnd0;
    reg [5:0]     enables_wnd1;
    reg [5:0]     enables_wndobj;
    reg [5:0]     enables_wndout;
    
    reg [1:0]     special_effect_in;
    reg           effect_1st_bg0;
    reg           effect_1st_bg1;
    reg           effect_1st_bg2;
    reg           effect_1st_bg3;
    reg           effect_1st_obj;
    reg           effect_1st_BD;
    reg           effect_2nd_bg0;
    reg           effect_2nd_bg1;
    reg           effect_2nd_bg2;
    reg           effect_2nd_bg3;
    reg           effect_2nd_obj;
    reg           effect_2nd_BD;
    
    reg [1:0]     Prio_BG0;
    reg [1:0]     Prio_BG1;
    reg [1:0]     Prio_BG2;
    reg [1:0]     Prio_BG3;
    
    reg [4:0]     EVA;
    reg [4:0]     EVB;
    reg [4:0]     BLDY;
    
    reg           ena_bg0;
    reg           ena_bg1;
    reg           ena_bg2;
    reg           ena_bg3;
    reg           ena_obj;
    
    // common for whole line
    reg [4:0]     EVA_MAXED;
    reg [4:0]     EVB_MAXED;
    reg [4:0]     BLDY_MAXED;
    
    reg           anywindow;
    reg           inwin_0y;
    reg           inwin_1y;
    
    wire [5:0]    first_target;
    wire [5:0]    second_target;
    
    // ####################################
    // #### clock cycle one
    // ####################################
    reg           enable_cycle1;
    reg [7:0]     xpos_cycle1;
    reg [7:0]     ypos_cycle1;
    reg [15:0]    pixeldata_bg0_cycle1;
    reg [15:0]    pixeldata_bg1_cycle1;
    reg [15:0]    pixeldata_bg2_cycle1;
    reg [15:0]    pixeldata_bg3_cycle1;
    reg [18:0]    pixeldata_obj_cycle1;
    // new  
    reg [5:0]     enables_cycle1;
    reg           special_enable_cycle1;
    
    // ####################################
    // #### clock cycle two
    // ####################################
    reg           enable_cycle2;
    reg [7:0]     xpos_cycle2;
    reg [7:0]     ypos_cycle2;
    reg [15:0]    pixeldata_bg0_cycle2;
    reg [15:0]    pixeldata_bg1_cycle2;
    reg [15:0]    pixeldata_bg2_cycle2;
    reg [15:0]    pixeldata_bg3_cycle2;
    reg [18:0]    pixeldata_obj_cycle2;
    reg [5:0]     enables_cycle2;
    reg           special_enable_cycle2;
    // new
    reg [5:0]     topprio_cycle2;
    
    // ####################################
    // #### clock cycle three
    // ####################################
    reg           enable_cycle3;
    reg [7:0]     xpos_cycle3;
    reg [7:0]     ypos_cycle3;
    reg [15:0]    pixeldata_bg0_cycle3;
    reg [15:0]    pixeldata_bg1_cycle3;
    reg [15:0]    pixeldata_bg2_cycle3;
    reg [15:0]    pixeldata_bg3_cycle3;
    reg [18:0]    pixeldata_obj_cycle3;
    reg [5:0]     topprio_cycle3;
    reg           special_enable_cycle3;
    // new
    reg [5:0]     firstprio_cycle3;
    reg [5:0]     secondprio_cycle3;
    reg [14:0]    firstpixel_cycle3;
    
    // ####################################
    // #### clock cycle four
    // ####################################
    reg           enable_cycle4;
    reg [7:0]     xpos_cycle4;
    reg [7:0]     ypos_cycle4;
    reg [15:0]    pixeldata_bg0_cycle4;
    reg [15:0]    pixeldata_bg1_cycle4;
    reg [15:0]    pixeldata_bg2_cycle4;
    reg [15:0]    pixeldata_bg3_cycle4;
    reg [18:0]    pixeldata_obj_cycle4;
    reg [5:0]     topprio_cycle4;
    // new
    reg [1:0]     special_effect_cycle4;
    reg           special_out_cycle4;
    reg [8:0]     alpha_red;
    reg [8:0]     alpha_green;
    reg [8:0]     alpha_blue;
    reg [8:0]     whiter_red;
    reg [8:0]     whiter_green;
    reg [8:0]     whiter_blue;
    reg signed [8:0]     blacker_red;
    reg signed [8:0]     blacker_green;
    reg signed [8:0]     blacker_blue;
    
    // ####################################
    // #### latch on hsync
    // ####################################
    
    always @(posedge fclk)
         begin
            if (hblank) begin
                WND0_on <= in_wnd0_on;
                WND1_on <= in_wnd1_on;
                WNDOBJ_on <= in_wndobj_on;
                
                WND0_X1 <= in_wnd0_x1;
                WND0_X2 <= in_wnd0_x2;
                WND0_Y1 <= in_wnd0_y1;
                WND0_Y2 <= in_wnd0_y2;
                WND1_X1 <= in_wnd1_x1;
                WND1_X2 <= in_wnd1_x2;
                WND1_Y1 <= in_wnd1_y1;
                WND1_Y2 <= in_wnd1_y2;
                
                enables_wnd0 <= in_enables_wnd0;
                enables_wnd1 <= in_enables_wnd1;
                enables_wndobj <= in_enables_wndobj;
                enables_wndout <= in_enables_wndout;
                
                special_effect_in <= in_special_effect_in;
                effect_1st_bg0 <= in_effect_1st_bg0;
                effect_1st_bg1 <= in_effect_1st_bg1;
                effect_1st_bg2 <= in_effect_1st_bg2;
                effect_1st_bg3 <= in_effect_1st_bg3;
                effect_1st_obj <= in_effect_1st_obj;
                effect_1st_BD <= in_effect_1st_bd;
                effect_2nd_bg0 <= in_effect_2nd_bg0;
                effect_2nd_bg1 <= in_effect_2nd_bg1;
                effect_2nd_bg2 <= in_effect_2nd_bg2;
                effect_2nd_bg3 <= in_effect_2nd_bg3;
                effect_2nd_obj <= in_effect_2nd_obj;
                effect_2nd_BD <= in_effect_2nd_bd;
                
                Prio_BG0 <= in_prio_bg0;
                Prio_BG1 <= in_prio_bg1;
                Prio_BG2 <= in_prio_bg2;
                Prio_BG3 <= in_prio_bg3;
                
                EVA <= in_eva;
                EVB <= in_evb;
                BLDY <= in_bldy;
                
                ena_bg0 <= in_ena_bg0;
                ena_bg1 <= in_ena_bg1;
                ena_bg2 <= in_ena_bg2;
                ena_bg3 <= in_ena_bg3;
                ena_obj <= in_ena_obj;
            end 
        end 
    
    // ####################################
    // #### pipeline independent
    // ####################################
    assign first_target = {effect_1st_BD, effect_1st_obj, effect_1st_bg3, effect_1st_bg2, effect_1st_bg1, effect_1st_bg0};
    assign second_target = {effect_2nd_BD, effect_2nd_obj, effect_2nd_bg3, effect_2nd_bg2, effect_2nd_bg1, effect_2nd_bg0};
    
    always @(posedge fclk)
         begin
            
            if (EVA < 16)
                EVA_MAXED <= EVA;
            else
                EVA_MAXED <= 16;
            if (EVB < 16)
                EVB_MAXED <= EVB;
            else
                EVB_MAXED <= 16;
            if (BLDY < 16)
                BLDY_MAXED <= BLDY;
            else
                BLDY_MAXED <= 16;
            
            // windowcheck
            anywindow <= WND0_on | WND1_on | WNDOBJ_on;
            
            inwin_0y <= 1'b0;
            if (WND0_on) begin
                if ((WND0_Y1 <= WND0_Y2 & ypos >= WND0_Y1 & ypos < WND0_Y2) | (WND0_Y1 > WND0_Y2 & (ypos >= WND0_Y1 | ypos < WND0_Y2)))
                    inwin_0y <= 1'b1;
            end 
            inwin_1y <= 1'b0;
            if (WND1_on) begin
                if ((WND1_Y1 <= WND1_Y2 & ypos >= WND1_Y1 & ypos < WND1_Y2) | (WND1_Y1 > WND1_Y2 & (ypos >= WND1_Y1 | ypos < WND1_Y2)))
                    inwin_1y <= 1'b1;
            end 
        end 
    
    // ####################################
    // #### clock cycle zero
    // ####################################
    
    always @(posedge fclk)  begin
        reg [4:0]     enables_var;
            
        enable_cycle1 <= enable;
        xpos_cycle1 <= xpos;
        ypos_cycle1 <= ypos;
        pixeldata_bg0_cycle1 <= pixeldata_bg0;
        pixeldata_bg1_cycle1 <= pixeldata_bg1;
        pixeldata_bg2_cycle1 <= pixeldata_bg2;
        pixeldata_bg3_cycle1 <= pixeldata_bg3;
        pixeldata_obj_cycle1 <= pixeldata_obj;
        
        // base
        enables_var = {~pixeldata_obj[TRANSPARENT], ~pixeldata_bg3[TRANSPARENT], ~pixeldata_bg2[TRANSPARENT], 
                       ~pixeldata_bg1[TRANSPARENT], ~pixeldata_bg0[TRANSPARENT]};
        
        // window select
        special_enable_cycle1 <= 1'b1;
        if (anywindow) begin
            if (inwin_0y & ((WND0_X1 <= WND0_X2 & xpos >= WND0_X1 & xpos < WND0_X2) | (WND0_X1 > WND0_X2 & (xpos >= WND0_X1 | xpos < WND0_X2)))) begin
                special_enable_cycle1 <= enables_wnd0[5];
                enables_var = enables_var & enables_wnd0[4:0];
            end else if (inwin_1y & ((WND1_X1 <= WND1_X2 & xpos >= WND1_X1 & xpos < WND1_X2) | (WND1_X1 > WND1_X2 & (xpos >= WND1_X1 | xpos < WND1_X2)))) begin
                special_enable_cycle1 <= enables_wnd1[5];
                enables_var = enables_var & enables_wnd1[4:0];
            end else if (objwindow_in) begin
                special_enable_cycle1 <= enables_wndobj[5];
                enables_var = enables_var & enables_wndobj[4:0];
            end 
            else begin
                special_enable_cycle1 <= enables_wndout[5];
                enables_var = enables_var & enables_wndout[4:0];
            end
        end 
        enables_cycle1 <= {1'b1, enables_var};		// backdrop is always on
        
        if (ena_bg0 == 1'b0)
            enables_cycle1[0] <= 1'b0;
        if (ena_bg1 == 1'b0)
            enables_cycle1[1] <= 1'b0;
        if (ena_bg2 == 1'b0)
            enables_cycle1[2] <= 1'b0;
        if (ena_bg3 == 1'b0)
            enables_cycle1[3] <= 1'b0;
        if (ena_obj == 1'b0)
            enables_cycle1[4] <= 1'b0;
    end
    
    // ####################################
    // #### clock cycle one
    // ####################################
    
    always @(posedge fclk) begin
        reg [5:0]     topprio_var;
        
        enable_cycle2 <= enable_cycle1;
        xpos_cycle2 <= xpos_cycle1;
        ypos_cycle2 <= ypos_cycle1;
        pixeldata_bg0_cycle2 <= pixeldata_bg0_cycle1;
        pixeldata_bg1_cycle2 <= pixeldata_bg1_cycle1;
        pixeldata_bg2_cycle2 <= pixeldata_bg2_cycle1;
        pixeldata_bg3_cycle2 <= pixeldata_bg3_cycle1;
        pixeldata_obj_cycle2 <= pixeldata_obj_cycle1;
        enables_cycle2 <= enables_cycle1;
        special_enable_cycle2 <= special_enable_cycle1;
        
        // priority
        topprio_var = enables_cycle1;
        
        if (topprio_var[BG0] & topprio_var[OBJ] & pixeldata_obj_cycle1[OBJPRIOH:OBJPRIOL] > Prio_BG0)
            topprio_var[OBJ] = 1'b0;
        if (topprio_var[BG1] & topprio_var[OBJ] & pixeldata_obj_cycle1[OBJPRIOH:OBJPRIOL] > Prio_BG1)
            topprio_var[OBJ] = 1'b0;
        if (topprio_var[BG2] & topprio_var[OBJ] & pixeldata_obj_cycle1[OBJPRIOH:OBJPRIOL] > Prio_BG2)
            topprio_var[OBJ] = 1'b0;
        if (topprio_var[BG3] & topprio_var[OBJ] & pixeldata_obj_cycle1[OBJPRIOH:OBJPRIOL] > Prio_BG3)
            topprio_var[OBJ] = 1'b0;
        
        if (topprio_var[BG0] & topprio_var[BG1] & Prio_BG0 > Prio_BG1)
            topprio_var[BG0] = 1'b0;
        if (topprio_var[BG0] & topprio_var[BG2] & Prio_BG0 > Prio_BG2)
            topprio_var[BG0] = 1'b0;
        if (topprio_var[BG0] & topprio_var[BG3] & Prio_BG0 > Prio_BG3)
            topprio_var[BG0] = 1'b0;
        if (topprio_var[BG1] & topprio_var[BG2] & Prio_BG1 > Prio_BG2)
            topprio_var[BG1] = 1'b0;
        if (topprio_var[BG1] & topprio_var[BG3] & Prio_BG1 > Prio_BG3)
            topprio_var[BG1] = 1'b0;
        if (topprio_var[BG2] & topprio_var[BG3] & Prio_BG2 > Prio_BG3)
            topprio_var[BG2] = 1'b0;
        
        if (topprio_var[OBJ])       topprio_var = 6'b010000;
        else if (topprio_var[BG0])  topprio_var = 6'b000001;
        else if (topprio_var[BG1])  topprio_var = 6'b000010;
        else if (topprio_var[BG2])  topprio_var = 6'b000100;
        else if (topprio_var[BG3])  topprio_var = 6'b001000;
        else                        topprio_var = 6'b100000;
        
        topprio_cycle2 <= topprio_var;
    end
    
    // ####################################
    // #### clock cycle two
    // ####################################
    
    always @(posedge fclk) begin
        reg [5:0]     firstprio_var;
        reg [5:0]     secondprio_var;
        
        enable_cycle3           <= enable_cycle2;
        xpos_cycle3             <= xpos_cycle2;
        ypos_cycle3             <= ypos_cycle2;
        pixeldata_bg0_cycle3    <= pixeldata_bg0_cycle2;
        pixeldata_bg1_cycle3    <= pixeldata_bg1_cycle2;
        pixeldata_bg2_cycle3    <= pixeldata_bg2_cycle2;
        pixeldata_bg3_cycle3    <= pixeldata_bg3_cycle2;
        pixeldata_obj_cycle3    <= pixeldata_obj_cycle2;
        topprio_cycle3          <= topprio_cycle2;
        special_enable_cycle3   <= special_enable_cycle2;
        
        // priority first + second
        firstprio_var = enables_cycle2 & first_target;
        if (pixeldata_obj_cycle2[OBJALPHA])
            firstprio_var[OBJ] = 1'b1;
        firstprio_var = firstprio_var & topprio_cycle2;
        
        firstprio_cycle3 <= firstprio_var;
        
        secondprio_var = enables_cycle2 & ~firstprio_var;
        
        if (secondprio_var[BG0] & secondprio_var[OBJ] & pixeldata_obj_cycle2[OBJPRIOH:OBJPRIOL] > Prio_BG0)
            secondprio_var[OBJ] = 1'b0;
        if (secondprio_var[BG1] & secondprio_var[OBJ] & pixeldata_obj_cycle2[OBJPRIOH:OBJPRIOL] > Prio_BG1)
            secondprio_var[OBJ] = 1'b0;
        if (secondprio_var[BG2] & secondprio_var[OBJ] & pixeldata_obj_cycle2[OBJPRIOH:OBJPRIOL] > Prio_BG2)
            secondprio_var[OBJ] = 1'b0;
        if (secondprio_var[BG3] & secondprio_var[OBJ] & pixeldata_obj_cycle2[OBJPRIOH:OBJPRIOL] > Prio_BG3)
            secondprio_var[OBJ] = 1'b0;
        
        if (secondprio_var[BG0] & secondprio_var[BG1] & Prio_BG0 > Prio_BG1)
            secondprio_var[BG0] = 1'b0;
        if (secondprio_var[BG0] & secondprio_var[BG2] & Prio_BG0 > Prio_BG2)
            secondprio_var[BG0] = 1'b0;
        if (secondprio_var[BG0] & secondprio_var[BG3] & Prio_BG0 > Prio_BG3)
            secondprio_var[BG0] = 1'b0;
        if (secondprio_var[BG1] & secondprio_var[BG2] & Prio_BG1 > Prio_BG2)
            secondprio_var[BG1] = 1'b0;
        if (secondprio_var[BG1] & secondprio_var[BG3] & Prio_BG1 > Prio_BG3)
            secondprio_var[BG1] = 1'b0;
        if (secondprio_var[BG2] & secondprio_var[BG3] & Prio_BG2 > Prio_BG3)
            secondprio_var[BG2] = 1'b0;
        
        if (secondprio_var[OBJ])        secondprio_var = 6'b010000;
        else if (secondprio_var[BG0])   secondprio_var = 6'b000001;
        else if (secondprio_var[BG1])   secondprio_var = 6'b000010;
        else if (secondprio_var[BG2])   secondprio_var = 6'b000100;
        else if (secondprio_var[BG3])   secondprio_var = 6'b001000;
        else                            secondprio_var = 6'b100000;
        
        secondprio_cycle3 <= secondprio_var & second_target;
        
        // special effect data
        firstpixel_cycle3 <= {15{1'b0}};
        if (firstprio_var[OBJ])         firstpixel_cycle3 <= pixeldata_obj_cycle2[14:0];
        else if (firstprio_var[BG0])    firstpixel_cycle3 <= pixeldata_bg0_cycle2[14:0];
        else if (firstprio_var[BG1])    firstpixel_cycle3 <= pixeldata_bg1_cycle2[14:0];
        else if (firstprio_var[BG2])    firstpixel_cycle3 <= pixeldata_bg2_cycle2[14:0];
        else if (firstprio_var[BG3])    firstpixel_cycle3 <= pixeldata_bg3_cycle2[14:0];
        else                            firstpixel_cycle3 <= pixeldata_back[14:0];
    end
    
    // ####################################
    // #### clock cycle three
    // ####################################
    always @(posedge fclk)  begin
        reg [1:0]     special_effect_var;
        reg [14:0]    secondpixel;
            
        enable_cycle4           <= enable_cycle3;
        xpos_cycle4             <= xpos_cycle3;
        ypos_cycle4             <= ypos_cycle3;
        pixeldata_bg0_cycle4    <= pixeldata_bg0_cycle3;
        pixeldata_bg1_cycle4    <= pixeldata_bg1_cycle3;
        pixeldata_bg2_cycle4    <= pixeldata_bg2_cycle3;
        pixeldata_bg3_cycle4    <= pixeldata_bg3_cycle3;
        pixeldata_obj_cycle4    <= pixeldata_obj_cycle3;
        topprio_cycle4          <= topprio_cycle3;
        
        // special effect control
        special_effect_var = special_effect_in;
        special_out_cycle4 <= 1'b0;
        
        if (special_enable_cycle3 & special_effect_in > 0) begin
            if (firstprio_cycle3 != 6'b0) begin
                if (special_effect_in == 2'b01) begin
                    if (secondprio_cycle3 != 6'b0)
                        special_out_cycle4 <= 1'b1;
                end else
                    special_out_cycle4 <= 1'b1;
            end 
        end 
        
        if (pixeldata_obj_cycle3[OBJALPHA] & firstprio_cycle3[4:0] == 5'b10000 & secondprio_cycle3 != 6'b0) begin
            special_effect_var = 2'b01;
            special_out_cycle4 <= 1'b1;
        end 
        
        if (special_effect_var > 1 & firstprio_cycle3[4:0] == 5'b10000 & effect_1st_obj == 1'b0)
            special_out_cycle4 <= 1'b0;
        
        special_effect_cycle4 <= special_effect_var;
        
        // special effect data
        secondpixel = {15{1'b0}};
        if (secondprio_cycle3[OBJ])         secondpixel = pixeldata_obj_cycle3[14:0];
        else if (secondprio_cycle3[BG0])    secondpixel = pixeldata_bg0_cycle3[14:0];
        else if (secondprio_cycle3[BG1])    secondpixel = pixeldata_bg1_cycle3[14:0];
        else if (secondprio_cycle3[BG2])    secondpixel = pixeldata_bg2_cycle3[14:0];
        else if (secondprio_cycle3[BG3])    secondpixel = pixeldata_bg3_cycle3[14:0];
        else                                secondpixel = pixeldata_back[14:0];
        
        alpha_blue      <= (firstpixel_cycle3[14:10] * EVA_MAXED + secondpixel[14:10] * EVB_MAXED)/16;
        alpha_green     <= (firstpixel_cycle3[9:5]   * EVA_MAXED + secondpixel[9:5]   * EVB_MAXED)/16;
        alpha_red       <= (firstpixel_cycle3[4:0]   * EVA_MAXED + secondpixel[4:0]   * EVB_MAXED)/16;
        
        whiter_blue     <= firstpixel_cycle3[14:10]  + (31 - firstpixel_cycle3[14:10]) * BLDY_MAXED/16;
        whiter_green    <= firstpixel_cycle3[9:5]    + (31 - firstpixel_cycle3[9:5]) * BLDY_MAXED/16;
        whiter_red      <= firstpixel_cycle3[4:0]    + (31 - firstpixel_cycle3[4:0]) * BLDY_MAXED/16;
        
        blacker_blue    <= firstpixel_cycle3[14:10]  - firstpixel_cycle3[14:10] * BLDY_MAXED/16;
        blacker_green   <= firstpixel_cycle3[9:5]    - firstpixel_cycle3[9:5] * BLDY_MAXED/16;
        blacker_red     <= firstpixel_cycle3[4:0]    - firstpixel_cycle3[4:0] * BLDY_MAXED/16;
    end
    
    // ####################################
    // #### clock cycle four
    // ####################################
    
    always @(posedge fclk) begin
        reg [14:0]     special_pixel;
            
        pixel_we <= 1'b0;
        
        if (enable_cycle4) begin
            if (special_out_cycle4)
                case (special_effect_cycle4)
                    1 :		// alpha
                        begin
                            if (alpha_blue < 31)    pixeldata_out[14:10] <= alpha_blue;
                            else                    pixeldata_out[14:10] <= 5'b11111;
                            if (alpha_green < 31)   pixeldata_out[9:5] <= alpha_green;
                            else                    pixeldata_out[9:5] <= 5'b11111;
                            if (alpha_red < 31)     pixeldata_out[4:0] <= alpha_red;
                            else                    pixeldata_out[4:0] <= 5'b11111;
                        end
                    
                    2 :		// whiter
                        begin
                            if (whiter_blue < 31)   pixeldata_out[14:10] <= whiter_blue;
                            else                    pixeldata_out[14:10] <= 5'b11111;
                            if (whiter_green < 31)  pixeldata_out[9:5] <= whiter_green;
                            else                    pixeldata_out[9:5] <= 5'b11111;
                            if (whiter_red < 31)    pixeldata_out[4:0] <= whiter_red;
                            else                    pixeldata_out[4:0] <= 5'b11111;
                        end
                    
                    3 :		// blacker
                        begin
                            if (blacker_blue > 0)   pixeldata_out[14:10] <= blacker_blue;
                            else                    pixeldata_out[14:10] <= 5'b00000;
                            if (blacker_green > 0)  pixeldata_out[9:5] <= blacker_green;
                            else                    pixeldata_out[9:5] <= 5'b00000;
                            if (blacker_red > 0)    pixeldata_out[4:0] <= blacker_red;
                            else                    pixeldata_out[4:0] <= 5'b00000;
                        end
                    
                    default :
                        ;
                endcase
            
            else if (topprio_cycle4[OBJ])
                pixeldata_out <= pixeldata_obj_cycle4[15:0];
            else if (topprio_cycle4[BG0])
                pixeldata_out <= pixeldata_bg0_cycle4;
            else if (topprio_cycle4[BG1])
                pixeldata_out <= pixeldata_bg1_cycle4;
            else if (topprio_cycle4[BG2])
                pixeldata_out <= pixeldata_bg2_cycle4;
            else if (topprio_cycle4[BG3])
                pixeldata_out <= pixeldata_bg3_cycle4;
            else
                pixeldata_out <= pixeldata_back;
            
            pixel_x     <= xpos_cycle4;
            pixel_y     <= ypos_cycle4;
            pixel_we    <= 1'b1;
        end 
    end
    
endmodule
