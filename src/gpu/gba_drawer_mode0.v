
module gba_drawer_mode0(fclk, drawline, busy, lockspeed, pixelpos, ypos, ypos_mosaic, mapbase, tilebase, hicolor, mosaic, Mosaic_H_Size, screensize, scrollX, scrollY, pixel_we, pixeldata, pixel_x, PALETTE_Drawer_addr, PALETTE_Drawer_data, PALETTE_Drawer_valid, VRAM_Drawer_addr, VRAM_Drawer_data, VRAM_Drawer_valid);
    input            fclk;
    
    input            drawline;
    output           busy;
    reg              busy;
    
    input            lockspeed;
    input [8:0]      pixelpos;
    
    input [7:0]      ypos;
    input [7:0]      ypos_mosaic;
    input [4:0]      mapbase;
    input [1:0]      tilebase;
    input            hicolor;
    input            mosaic;
    input [3:0]      Mosaic_H_Size;
    input [1:0]      screensize;
    input [8:0]      scrollX;
    input [8:0]      scrollY;
    
    output           pixel_we;
    reg              pixel_we;
    output reg [15:0]    pixeldata;
    output reg [7:0]     pixel_x;
    
    output [6:0]     PALETTE_Drawer_addr;
    input [31:0]     PALETTE_Drawer_data;
    input            PALETTE_Drawer_valid;
    
    output [13:0]    VRAM_Drawer_addr;
    input [31:0]     VRAM_Drawer_data;
    input            VRAM_Drawer_valid;
    
    
    localparam [2:0] IDLE = 0,
                     CALCBASE = 1,
                     CALCADDR1 = 2,
                     CALCADDR2 = 3,
                     WAITREAD_TILE = 4,
                     CALCCOLORADDR = 5,
                     WAITREAD_COLOR = 6,
                     FETCHDONE = 7;
    reg [2:0]        vramfetch;
    
    parameter [1:0]  tPALETTEState_IDLE = 0,
                     tPALETTEState_STARTREAD = 1,
                     tPALETTEState_WAITREAD = 2;
    reg [1:0]        palettefetch;
    
    reg [16:0]       VRAM_byteaddr;
    reg [1:0]        vram_readwait;
    
    reg [8:0]        PALETTE_byteaddr;
    reg [1:0]        palette_readwait;
    
    wire [15:0]      mapbaseaddr;           // both in vramlo
    wire [15:0]      tilebaseaddr;
    
    reg [7:0]        x_cnt;
    reg [9:0]        y_scrolled;
    reg [9:0]        offset_y;
    reg [9:0]        scroll_x_mod;
    reg [9:0]        scroll_y_mod;
    
    reg [2:0]        x_flip_offset;
    reg [1:0]        x_div;
    
    reg [9:0]        x_scrolled;
    wire [11:0]      tileindex;
    
    reg [15:0]       tileinfo;
    reg [18:0]       pixeladdr_base;
    
    reg [7:0]        colordata;
    reg [14:0]       VRAM_lastcolor_addr;
    reg [31:0]       VRAM_lastcolor_data;
    reg              VRAM_lastcolor_valid;
    
    reg [3:0]        mosaik_cnt;
    
    assign mapbaseaddr = {mapbase, 11'b0};      // 2KB increments 
    assign tilebaseaddr = {tilebase, 14'b0};    // 16KB increments
    
    assign VRAM_Drawer_addr = VRAM_byteaddr[15:2];
    assign PALETTE_Drawer_addr = PALETTE_byteaddr[8:2];
    
    // vramfetch
    always @(posedge fclk) begin
        reg [11:0]       tileindex_var;
        reg [9:0]        x_scrolled_var;
        reg [18:0]       pixeladdr;
            
        case (vramfetch)
            IDLE :
                if (drawline) begin
                    busy <= 1'b1;
                    vramfetch <= CALCBASE;
                    if (mosaic)
                        y_scrolled <= ypos_mosaic + scrollY;
                    else
                        y_scrolled <= ypos + scrollY;
                    offset_y <= 32;
                    scroll_x_mod <= 256;
                    scroll_y_mod <= 256;
                    case (screensize)
                        1 : scroll_x_mod <= 512;
                        2 : scroll_y_mod <= 512;
                        3 : begin
                                scroll_x_mod <= 512;
                                scroll_y_mod <= 512;
                            end
                        default : ;
                    endcase
                    x_cnt <= 0;
                    VRAM_lastcolor_valid <= 1'b0;		// invalidate fetch cache
                end else if (palettefetch == IDLE)
                    busy <= 1'b0;
            
            CALCBASE :
                begin
                    vramfetch <= CALCADDR1;
                    y_scrolled <= y_scrolled % scroll_y_mod;
                    offset_y <= ((y_scrolled % 256)/8) * offset_y;
                    if (hicolor == 1'b0) begin
                        //tilemult      <= 32;
                        x_flip_offset <= 3;
                        x_div <= 2;
                        //x_size        <= 4;
                    end else begin
                        //tilemult      <= 64;
                        x_flip_offset <= 7;
                        x_div <= 1;
                        //x_size        <= 8;
                    end
                end
            
            CALCADDR1 :
                if (pixelpos >= x_cnt | lockspeed == 1'b0) begin
                    vramfetch <= CALCADDR2;
                    x_scrolled <= (x_cnt + scrollX) % scroll_x_mod;
                end 
            
            CALCADDR2 :
                begin
                    tileindex_var = 0;
                    x_scrolled_var = x_scrolled;
                    if (x_scrolled >= 256 | (y_scrolled >= 256 & screensize == 2)) begin
                        tileindex_var = tileindex_var + 1024;
                        x_scrolled_var = x_scrolled % 256;
                        x_scrolled <= x_scrolled % 256;
                    end 
                    if (y_scrolled >= 256 & screensize == 3)
                        tileindex_var = tileindex_var + 2048;
                    tileindex_var = tileindex_var + offset_y + (x_scrolled_var/8);
                    VRAM_byteaddr <= (mapbaseaddr + (tileindex_var * 2));
                    vramfetch <= WAITREAD_TILE;
                    vram_readwait <= 2;
                end
            
            WAITREAD_TILE :
                if (vram_readwait > 0)
                    vram_readwait <= vram_readwait - 2'b1;
                else if (VRAM_Drawer_valid) begin
                    if (VRAM_byteaddr[1]) begin
                        tileinfo <= VRAM_Drawer_data[31:16];
                        if (hicolor == 1'b0)
                            pixeladdr_base <= tilebaseaddr + VRAM_Drawer_data[25:16] * 32;
                        else
                            pixeladdr_base <= tilebaseaddr + VRAM_Drawer_data[25:16] * 64;
                    end else begin
                        tileinfo <= VRAM_Drawer_data[15:0];
                        if (hicolor == 1'b0)
                            pixeladdr_base <= tilebaseaddr + VRAM_Drawer_data[9:0] * 32;
                        else
                            pixeladdr_base <= tilebaseaddr + VRAM_Drawer_data[9:0] * 64;
                    end
                    vramfetch <= CALCCOLORADDR;
                end 
            
            CALCCOLORADDR :
                begin
                    vramfetch <= WAITREAD_COLOR;
                    if (tileinfo[10])		// hoz flip
                        pixeladdr = pixeladdr_base + (x_flip_offset - ((x_scrolled % 8)/x_div));
                    else
                        pixeladdr = pixeladdr_base + (x_scrolled % 8)/x_div;
                    if (tileinfo[11]) begin		// vert flip
                        if (hicolor == 1'b0)
                            pixeladdr = pixeladdr + ((7 - (y_scrolled % 8)) * 4);
                        else
                            pixeladdr = pixeladdr + ((7 - (y_scrolled % 8)) * 8);
                    end else
                        if (hicolor == 1'b0)
                            pixeladdr = pixeladdr + (y_scrolled % 8 * 4);
                        else
                            pixeladdr = pixeladdr + (y_scrolled % 8 * 8);
                    VRAM_byteaddr <= pixeladdr;
                    vramfetch <= WAITREAD_COLOR;
                    vram_readwait <= 2;
                end
            
            WAITREAD_COLOR :
                if (VRAM_lastcolor_valid & VRAM_lastcolor_addr == VRAM_byteaddr[16:2]) begin
                    case (VRAM_byteaddr[1:0])
                        2'b00 :
                            colordata <= VRAM_lastcolor_data[7:0];
                        2'b01 :
                            colordata <= VRAM_lastcolor_data[15:8];
                        2'b10 :
                            colordata <= VRAM_lastcolor_data[23:16];
                        2'b11 :
                            colordata <= VRAM_lastcolor_data[31:24];
                        default :
                            ;
                    endcase
                    vramfetch <= FETCHDONE;
                end else if (vram_readwait > 0)
                    vram_readwait <= vram_readwait - 2'b1;
                else if (VRAM_Drawer_valid) begin
                    VRAM_lastcolor_addr <= VRAM_byteaddr[16:2];
                    VRAM_lastcolor_data <= VRAM_Drawer_data;
                    VRAM_lastcolor_valid <= 1'b1;
                    case (VRAM_byteaddr[1:0])
                        2'b00 :
                            colordata <= VRAM_Drawer_data[7:0];
                        2'b01 :
                            colordata <= VRAM_Drawer_data[15:8];
                        2'b10 :
                            colordata <= VRAM_Drawer_data[23:16];
                        2'b11 :
                            colordata <= VRAM_Drawer_data[31:24];
                        default :
                            ;
                    endcase
                    vramfetch <= FETCHDONE;
                end 
            
            FETCHDONE :
                if (palettefetch == IDLE) begin
                    if (x_cnt < 239) begin
                        vramfetch <= CALCADDR1;
                        x_cnt <= x_cnt + 1;
                    end else
                        vramfetch <= IDLE;
                end 

            default: ;
        endcase
    end
    
    // palette
    always @(posedge fclk)
         begin
            
            pixel_we <= 1'b0;
            
            if (drawline) begin
                mosaik_cnt <= 15;		// first pixel must fetch new data
                pixeldata[15] <= 1'b1;
            end 
            
            case (palettefetch)
                
                tPALETTEState_IDLE :
                    if (vramfetch == FETCHDONE) begin
                        
                        pixel_x <= x_cnt;
                        
                        if (mosaik_cnt < Mosaic_H_Size & mosaic) begin
                            mosaik_cnt <= mosaik_cnt + 1;
                            pixel_we <= (~pixeldata[15]);
                        end else begin
                            mosaik_cnt <= 0;
                            
                            palettefetch <= tPALETTEState_STARTREAD;
                            if (hicolor == 1'b0) begin
                                if ((tileinfo[10] & (x_scrolled % 2) == 0) | (tileinfo[10] == 1'b0 & (x_scrolled % 2) == 1)) begin
                                    PALETTE_byteaddr <= {tileinfo[15:12], colordata[7:4], 1'b0};
                                    if (colordata[7:4] == 4'h0) begin		// transparent
                                        palettefetch <= tPALETTEState_IDLE;
                                        pixeldata[15] <= 1'b1;
                                    end 
                                end else begin
                                    PALETTE_byteaddr <= {tileinfo[15:12], colordata[3:0], 1'b0};
                                    if (colordata[3:0] == 4'h0) begin		// transparent
                                        palettefetch <= tPALETTEState_IDLE;
                                        pixeldata[15] <= 1'b1;
                                    end 
                                end
                            end else begin
                                PALETTE_byteaddr <= {colordata, 1'b0};
                                if (colordata == 8'h00) begin		// transparent
                                    palettefetch <= tPALETTEState_IDLE;
                                    pixeldata[15] <= 1'b1;
                                end 
                            end
                        end
                    end 
                
                tPALETTEState_STARTREAD :
                    begin
                        palettefetch <= tPALETTEState_WAITREAD;
                        palette_readwait <= 2;
                    end
                
                tPALETTEState_WAITREAD :
                    if (palette_readwait > 0)
                        palette_readwait <= palette_readwait - 1;
                    else if (PALETTE_Drawer_valid) begin
                        palettefetch <= tPALETTEState_IDLE;
                        pixel_we <= 1'b1;
                        if (PALETTE_byteaddr[1])
                            pixeldata <= {1'b0, PALETTE_Drawer_data[30:16]};
                        else
                            pixeldata <= {1'b0, PALETTE_Drawer_data[14:0]};
                    end 
                
                default: ;
            endcase
        end 
    
endmodule
