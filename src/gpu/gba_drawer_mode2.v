
module gba_drawer_mode2(fclk, line_trigger, drawline, busy, mapbase, tilebase, screensize, wrapping, mosaic, Mosaic_H_Size, refX, refY, refX_mosaic, refY_mosaic, dx, dy, pixel_we, pixeldata, pixel_x, PALETTE_Drawer_addr, PALETTE_Drawer_data, PALETTE_Drawer_valid, VRAM_Drawer_addr, VRAM_Drawer_data, VRAM_Drawer_valid);
    parameter              DXYBITS = 16;
    parameter              ACCURACYBITS = 28;
    parameter              PIXELCOUNT = 240;
    parameter              REFBITS = 28;

    input                  fclk;
    
    input                  line_trigger;
    input                  drawline;
    output reg             busy;
    
    input [4:0]            mapbase;
    input [1:0]            tilebase;
    input [1:0]            screensize;
    input                  wrapping;
    input                  mosaic;
    input [3:0]            Mosaic_H_Size;
    input signed [REFBITS-1:0]    refX;
    input signed [REFBITS-1:0]    refY;
    input signed [27:0]           refX_mosaic;
    input signed [27:0]           refY_mosaic;
    input signed [DXYBITS-1:0]    dx;
    input signed [DXYBITS-1:0]    dy;
    
    output reg             pixel_we;
    output reg [15:0]      pixeldata;
    output reg [7:0]       pixel_x;
    
    output [6:0]           PALETTE_Drawer_addr;
    input [31:0]           PALETTE_Drawer_data;
    input                  PALETTE_Drawer_valid;
    
    output [13:0]          VRAM_Drawer_addr;
    input [31:0]           VRAM_Drawer_data;
    input                  VRAM_Drawer_valid;
    
    
    parameter [2:0]        IDLE = 0,
                           CALCADDR1 = 1,
                           CALCADDR2 = 2,
                           WAITREAD_TILE = 3,
                           EVALTILE = 4,
                           WAITREAD_COLOR = 5,
                           FETCHDONE = 6;
    reg [2:0]              vramfetch;
    
    parameter [1:0]        tPALETTEState_IDLE = 0,
                           tPALETTEState_STARTREAD = 1,
                           tPALETTEState_WAITREAD = 2;
    reg [1:0]              palettefetch;
    
    reg [16:0]             VRAM_byteaddr;
    reg [1:0]              vram_readwait;
    reg [14:0]             VRAM_lasttile_addr;
    reg [31:0]             VRAM_lasttile_data;
    reg                    VRAM_lasttile_valid;
    
    reg [8:0]              PALETTE_byteaddr;
    reg [1:0]              palette_readwait;
    
    wire [31:0]            mapbaseaddr;
    wire [31:0]            tilebaseaddr;
    
    reg signed [ACCURACYBITS-1:0] realX;
    reg signed [ACCURACYBITS-1:0] realY;
    reg signed [19:0]             xxx;
    reg signed [19:0]             yyy;
    wire signed [19:0]            xxx_pre;
    wire signed [19:0]            yyy_pre;
    
    reg [7:0]              x_cnt;
    reg [10:0]             scroll_mod;
    reg [7:0]              tileinfo;
    
    reg [7:0]              colordata;
    reg [14:0]             VRAM_lastcolor_addr;
    reg [31:0]             VRAM_lastcolor_data;
    reg                    VRAM_lastcolor_valid;
    
    reg [3:0]              mosaik_cnt;
    
    assign mapbaseaddr = mapbase * 2048;
    assign tilebaseaddr = tilebase * 16'h4000;
    
    assign VRAM_Drawer_addr = (VRAM_byteaddr[15:2]);
    assign PALETTE_Drawer_addr = ((PALETTE_byteaddr[8:2]));
    
    assign xxx_pre = realX[ACCURACYBITS-1:ACCURACYBITS-1 - 19];
    assign yyy_pre = realY[ACCURACYBITS-1:ACCURACYBITS-1 - 19];
    
    // vramfetch
    always @(posedge fclk)
    begin: xhdl0
        reg [13:0]             tileindex_var;
        reg [18:0]             pixeladdr;
        
        
        case (vramfetch)
            
            IDLE :
                if (line_trigger) begin
                    realX <= {ACCURACYBITS{1'b0}};
                    realY <= {ACCURACYBITS{1'b0}};
                    if (mosaic & Mosaic_H_Size > 0) begin
                        realX[ACCURACYBITS-1:ACCURACYBITS-1 - 28 + 1] <= refX_mosaic;
                        realY[ACCURACYBITS-1:ACCURACYBITS-1 - 28 + 1] <= refY_mosaic;
                    end else begin
                        realX[ACCURACYBITS-1:ACCURACYBITS-1 - REFBITS + 1] <= refX;
                        realY[ACCURACYBITS-1:ACCURACYBITS-1 - REFBITS + 1] <= refY;
                    end
                end else if (drawline) begin
                    busy <= 1'b1;
                    vramfetch <= CALCADDR1;
                    case (screensize)
                        0 : scroll_mod <= 128;
                        1 : scroll_mod <= 256;
                        2 : scroll_mod <= 512;
                        3 : scroll_mod <= 1024;
                        default : ;
                    endcase
                    x_cnt <= 0;
                    VRAM_lasttile_valid <= 1'b0;		// invalidate fetch cache
                    VRAM_lastcolor_valid <= 1'b0;
                end else if (palettefetch == IDLE)
                    busy <= 1'b0;
            
            CALCADDR1 :
                begin
                    vramfetch <= CALCADDR2;
                    if (wrapping)
                        case (screensize)
                            0 : begin
                                    xxx <= xxx_pre % 128;
                                    yyy <= yyy_pre % 128;
                                end
                            1 : begin
                                    xxx <= xxx_pre % 256;
                                    yyy <= yyy_pre % 256;
                                end
                            2 : begin
                                    xxx <= xxx_pre % 512;
                                    yyy <= yyy_pre % 512;
                                end
                            3 : begin
                                    xxx <= xxx_pre % 1024;
                                    yyy <= yyy_pre % 1024;
                                end
                            default : ;
                        endcase
                    else begin
                        xxx <= xxx_pre;
                        yyy <= yyy_pre;
                        if (xxx_pre < 0 | yyy_pre < 0 | xxx_pre >= scroll_mod | yyy_pre >= scroll_mod) begin
                            if (x_cnt < (PIXELCOUNT - 1)) begin
                                vramfetch <= CALCADDR1;
                                x_cnt <= x_cnt + 1;
                            end else
                                vramfetch <= IDLE;
                        end 
                    end
                    realX <= realX + dx;
                    realY <= realY + dy;
                end
            
            CALCADDR2 :
                begin
                    case (screensize)
                        0 :		// << 4
                            tileindex_var = ((xxx/8) + ((yyy/8) * 16));
                        1 :		// << 5
                            tileindex_var = ((xxx/8) + ((yyy/8) * 32));
                        2 :		// << 6
                            tileindex_var = ((xxx/8) + ((yyy/8) * 64));
                        3 :		// << 7
                            tileindex_var = ((xxx/8) + ((yyy/8) * 128));
                        default : ;
                    endcase
                    VRAM_byteaddr <= mapbaseaddr + tileindex_var;
                    vramfetch <= WAITREAD_TILE;
                    vram_readwait <= 2;
                end
            
            WAITREAD_TILE :
                if (VRAM_lasttile_valid & VRAM_lasttile_addr == VRAM_byteaddr[16:2]) begin
                    case ((VRAM_byteaddr[1:0]))
                        0 : tileinfo <= VRAM_lasttile_data[7:0];
                        1 : tileinfo <= VRAM_lasttile_data[15:8];
                        2 : tileinfo <= VRAM_lasttile_data[23:16];
                        3 : tileinfo <= VRAM_lasttile_data[31:24];
                        default : ;
                    endcase
                    vramfetch <= EVALTILE;
                end else if (vram_readwait > 0)
                    vram_readwait <= vram_readwait - 1;
                else if (VRAM_Drawer_valid) begin
                    VRAM_lasttile_addr <= VRAM_byteaddr[16:2];
                    VRAM_lasttile_data <= VRAM_Drawer_data;
                    VRAM_lasttile_valid <= 1'b1;
                    case ((VRAM_byteaddr[1:0]))
                        0 : tileinfo <= VRAM_Drawer_data[7:0];
                        1 : tileinfo <= VRAM_Drawer_data[15:8];
                        2 : tileinfo <= VRAM_Drawer_data[23:16];
                        3 : tileinfo <= VRAM_Drawer_data[31:24];
                        default : ;
                    endcase
                    vramfetch <= EVALTILE;
                end 
            
            EVALTILE :
                begin
                    vramfetch <= WAITREAD_COLOR;
                    pixeladdr = tilebaseaddr + ({tileinfo, (yyy[2:0]), (xxx[2:0])});		// (tileinfo << 6) + ((yyy & 7) * 8) + xxx & 7;
                    VRAM_byteaddr <= pixeladdr;
                    vramfetch <= WAITREAD_COLOR;
                    vram_readwait <= 2;
                end
            
            WAITREAD_COLOR :
                if (VRAM_lastcolor_valid & VRAM_lastcolor_addr == VRAM_byteaddr[16:2]) begin
                    case (VRAM_byteaddr[1:0])
                        2'b00 : colordata <= VRAM_lastcolor_data[7:0];
                        2'b01 : colordata <= VRAM_lastcolor_data[15:8];
                        2'b10 : colordata <= VRAM_lastcolor_data[23:16];
                        2'b11 : colordata <= VRAM_lastcolor_data[31:24];
                        default : ;
                    endcase
                    vramfetch <= FETCHDONE;
                end else if (vram_readwait > 0)
                    vram_readwait <= vram_readwait - 1;
                else if (VRAM_Drawer_valid) begin
                    VRAM_lastcolor_addr <= VRAM_byteaddr[16:2];
                    VRAM_lastcolor_data <= VRAM_Drawer_data;
                    VRAM_lastcolor_valid <= 1'b1;
                    case (VRAM_byteaddr[1:0])
                        2'b00 : colordata <= VRAM_Drawer_data[7:0];
                        2'b01 : colordata <= VRAM_Drawer_data[15:8];
                        2'b10 : colordata <= VRAM_Drawer_data[23:16];
                        2'b11 : colordata <= VRAM_Drawer_data[31:24];
                        default : ;
                    endcase
                    vramfetch <= FETCHDONE;
                end 
            
            FETCHDONE :
                if (palettefetch == IDLE) begin
                    if (x_cnt < (PIXELCOUNT - 1)) begin
                        vramfetch <= CALCADDR1;
                        x_cnt <= x_cnt + 1;
                    end else
                        vramfetch <= IDLE;
                end 

            default: ;

        endcase
    end
    
    // palette -> convert to pipeline and remove fetchdone state for further speedup
    always @(posedge fclk)  begin
            
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
                        pixel_we <= ~pixeldata[15];
                    end else begin
                        
                        mosaik_cnt <= 0;
                        
                        palettefetch <= tPALETTEState_STARTREAD;
                        PALETTE_byteaddr <= {colordata, 1'b0};
                        if (colordata == 8'h00) begin		// transparent
                            palettefetch <= tPALETTEState_IDLE;
                            pixeldata[15] <= 1'b1;
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
