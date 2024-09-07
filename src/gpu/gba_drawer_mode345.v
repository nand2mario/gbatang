
module gba_drawer_mode345(fclk, BG_Mode, line_trigger, drawline, busy, second_frame, mosaic, Mosaic_H_Size, refX, refY, refX_mosaic, refY_mosaic, dx, dy, pixel_we, pixeldata, pixel_x, PALETTE_Drawer_addr, PALETTE_Drawer_data, PALETTE_Drawer_valid, VRAM_Drawer_addr_Lo, VRAM_Drawer_addr_Hi, VRAM_Drawer_data_Lo, VRAM_Drawer_data_Hi, VRAM_Drawer_valid_Lo, VRAM_Drawer_valid_Hi);
    input            fclk;
    input [2:0]      BG_Mode;
    
    input            line_trigger;
    input            drawline;
    output reg       busy;
    
    input            second_frame;
    input            mosaic;
    input [3:0]      Mosaic_H_Size;
    input signed [27:0]     refX;
    input signed [27:0]     refY;
    input signed [27:0]     refX_mosaic;
    input signed [27:0]     refY_mosaic;
    input signed [15:0]     dx;
    input signed [15:0]     dy;
    
    output reg       pixel_we;
    output reg [15:0] pixeldata;
    output reg [7:0] pixel_x;
    
    output [6:0]     PALETTE_Drawer_addr;
    input [31:0]     PALETTE_Drawer_data;
    input            PALETTE_Drawer_valid;
    
    output [13:0]    VRAM_Drawer_addr_Lo;
    output [12:0]    VRAM_Drawer_addr_Hi;
    input [31:0]     VRAM_Drawer_data_Lo;
    input [31:0]     VRAM_Drawer_data_Hi;
    input            VRAM_Drawer_valid_Lo;
    input            VRAM_Drawer_valid_Hi;
    
    
    parameter [1:0]  tFetchState_IDLE = 0,
                     tFetchState_STARTREAD = 1,
                     tFetchState_WAITREAD = 2,
                     tFetchState_FETCHDONE = 3;
    reg [1:0]        vramfetch;
    
    parameter [1:0]  tDrawState_NEXTPIXEL = 0,
                     tDrawState_WAITREAD = 1;
    reg [1:0]        DrawState;
    
    reg [7:0]        x_cnt;
    reg signed [27:0]       realX;
    reg signed [27:0]       realY;
    wire signed [19:0]      xxx;
    wire signed [19:0]      yyy;
    
    reg [16:0]       VRAM_byteaddr;
    reg [1:0]        vram_readwait;
    reg [15:0]       vram_data;
    reg [14:0]       VRAM_last_addr;
    reg [31:0]       VRAM_last_data;
    reg              VRAM_last_valid;
    
    reg [8:0]        PALETTE_byteaddr;
    reg [1:0]        palette_readwait;
    
    reg [3:0]        mosaik_cnt;
    reg              skip_data;
    
    assign VRAM_Drawer_addr_Lo = (VRAM_byteaddr[15:2]);
    assign VRAM_Drawer_addr_Hi = (VRAM_byteaddr[14:2]);
    
    assign PALETTE_Drawer_addr = (PALETTE_byteaddr[8:2]);
    
    assign xxx = realX[27:8];
    assign yyy = realY[27:8];
    
    // vramfetch
    always @(posedge fclk)
    begin: xhdl0
        integer          byteaddr;
         begin
            
            skip_data <= 1'b0;
            
            case (vramfetch)
                
                tFetchState_IDLE :
                    if (line_trigger) begin
                        if (mosaic) begin
                            realX <= refX_mosaic;
                            realY <= refY_mosaic;
                        end else begin
                            realX <= refX;
                            realY <= refY;
                        end
                    end else if (drawline) begin
                        busy <= 1'b1;
                        vramfetch <= tFetchState_STARTREAD;
                        x_cnt <= 0;
                        VRAM_last_valid <= 1'b0;
                    end else if (DrawState == tDrawState_NEXTPIXEL)
                        busy <= 1'b0;
                
                tFetchState_STARTREAD :
                    begin
                        if (BG_Mode == 3'b011)      byteaddr = yyy * 480 + xxx * 2;
                        else if (BG_Mode == 3'b100) byteaddr = yyy * 240 + xxx;
                        else                        byteaddr = yyy * 320 + xxx * 2;
                        
                        if (second_frame & BG_Mode != 3'b011)
                            byteaddr = byteaddr + 16'hA000;
                        
                        VRAM_byteaddr <= byteaddr;
                        
                        if ((BG_Mode == 3'b101 & (xxx >= 0 & yyy >= 0 & xxx < 160 & yyy < 128)) | 
                            (BG_Mode != 3'b101 & (xxx >= 0 & yyy >= 0 & xxx < 240 & yyy < 160))) begin
                            vramfetch <= tFetchState_WAITREAD;
                            vram_readwait <= 2;
                        end else begin
                            if (x_cnt < 239) begin
                                x_cnt <= x_cnt + 1;
                                skip_data <= 1'b1;
                            end else
                                vramfetch <= tFetchState_IDLE;
                            realX <= realX + dx;
                            realY <= realY + dy;
                        end
                    end
                
                tFetchState_WAITREAD :
                    if (VRAM_last_valid & VRAM_last_addr == VRAM_byteaddr[16:2]) begin
                        if (VRAM_byteaddr[1])
                            vram_data <= VRAM_last_data[31:16];
                        else
                            vram_data <= VRAM_last_data[15:0];
                        vramfetch <= tFetchState_FETCHDONE;
                    end else if (vram_readwait > 0)
                        vram_readwait <= vram_readwait - 1;
                    else
                        if (VRAM_byteaddr[16] & VRAM_Drawer_valid_Hi) begin
                            VRAM_last_addr <= VRAM_byteaddr[16:2];
                            VRAM_last_valid <= 1'b1;
                            VRAM_last_data <= VRAM_Drawer_data_Hi;
                            if (VRAM_byteaddr[1])
                                vram_data <= VRAM_Drawer_data_Hi[31:16];
                            else
                                vram_data <= VRAM_Drawer_data_Hi[15:0];
                            vramfetch <= tFetchState_FETCHDONE;
                        end else if (VRAM_byteaddr[16] == 1'b0 & VRAM_Drawer_valid_Lo) begin
                            VRAM_last_addr <= VRAM_byteaddr[16:2];
                            VRAM_last_valid <= 1'b1;
                            VRAM_last_data <= VRAM_Drawer_data_Lo;
                            if (VRAM_byteaddr[1])
                                vram_data <= VRAM_Drawer_data_Lo[31:16];
                            else
                                vram_data <= VRAM_Drawer_data_Lo[15:0];
                            vramfetch <= tFetchState_FETCHDONE;
                        end 
                
                tFetchState_FETCHDONE :
                    if (DrawState == tDrawState_NEXTPIXEL) begin
                        if (x_cnt < 239) begin
                            vramfetch <= tFetchState_STARTREAD;
                            x_cnt <= x_cnt + 1;
                        end else
                            vramfetch <= tFetchState_IDLE;
                        realX <= realX + dx;
                        realY <= realY + dy;
                    end 
            endcase
        end 
    end
    
    // draw
    always @(posedge fclk)
         begin
            
            pixel_we <= 1'b0;
            
            if (drawline) begin
                mosaik_cnt <= 15;		// first pixel must fetch new data
                pixeldata[15] <= 1'b1;
            end else if (skip_data | (DrawState == tDrawState_NEXTPIXEL & vramfetch == tFetchState_FETCHDONE)) begin
                if (mosaik_cnt < Mosaic_H_Size & mosaic)
                    mosaik_cnt <= mosaik_cnt + 1;
                else begin
                    mosaik_cnt <= 0;
                    if (skip_data)
                        pixeldata[15] <= 1'b1;
                end
            end 
            
            case (DrawState)
                
                tDrawState_NEXTPIXEL :
                    if (vramfetch == tFetchState_FETCHDONE) begin
                        
                        pixel_x <= x_cnt;
                        
                        if (mosaik_cnt < Mosaic_H_Size & mosaic)
                            pixel_we <= (~pixeldata[15]);
                        else
                            if (BG_Mode == 3'b100) begin
                                DrawState <= tDrawState_WAITREAD;
                                palette_readwait <= 2;
                                if (VRAM_byteaddr[0])
                                    PALETTE_byteaddr <= {(vram_data[15:8]), 1'b0};
                                else
                                    PALETTE_byteaddr <= {(vram_data[7:0]), 1'b0};
                            end else begin
                                pixel_we <= 1'b1;
                                pixeldata <= {1'b0, vram_data[14:0]};
                            end
                    end 
                
                tDrawState_WAITREAD :
                    if (palette_readwait > 0)
                        palette_readwait <= palette_readwait - 1;
                    else if (PALETTE_Drawer_valid) begin
                        if (PALETTE_byteaddr[1])
                            pixeldata <= {1'b0, PALETTE_Drawer_data[30:16]};
                        else
                            pixeldata <= {1'b0, PALETTE_Drawer_data[14:0]};
                        if (PALETTE_byteaddr == 0)
                            pixeldata[15] <= 1'b1;
                        pixel_we <= 1'b1;
                        DrawState <= tDrawState_NEXTPIXEL;
                    end 

                default: ;

            endcase
        end 
    
endmodule
