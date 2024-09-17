
module gba_drawer_obj (fclk, hblank, lockspeed, busy, drawline, ypos, ypos_mosaic, BG_Mode, one_dim_mapping, Mosaic_H_Size, hblankfree, maxpixels, pixel_we_color, pixeldata_color, pixel_we_settings, pixeldata_settings, pixel_x, pixel_objwnd, OAMRAM_Drawer_addr, OAMRAM_Drawer_data, PALETTE_Drawer_addr, PALETTE_Drawer_data, VRAM_Drawer_addr, VRAM_Drawer_data, VRAM_Drawer_valid);

    `include "pproc_bus_gba.sv"
    input            fclk;
    
    input            hblank;
    input            lockspeed;
    output reg       busy;
    
    input            drawline;
    input [7:0]      ypos;
    input [7:0]      ypos_mosaic;
    
    input [2:0]      BG_Mode;
    input            one_dim_mapping;
    input [3:0]      Mosaic_H_Size;
    
    input            hblankfree;
    input            maxpixels;
    
    output reg       pixel_we_color;
    output reg [15:0] pixeldata_color;
    output reg       pixel_we_settings;
    output reg [2:0] pixeldata_settings;
    output reg [7:0] pixel_x;
    output reg       pixel_objwnd;
    
    output reg [7:0] OAMRAM_Drawer_addr;
    input [31:0]     OAMRAM_Drawer_data;
    
    output [6:0]     PALETTE_Drawer_addr;
    input [31:0]     PALETTE_Drawer_data;
    
    output [12:0]    VRAM_Drawer_addr;
    input [31:0]     VRAM_Drawer_data;
    input            VRAM_Drawer_valid;
    
    parameter           RESMULT = 1;                    // 1 or 2
    parameter           PIXELCOUNT = 240;
    parameter           YMULTOFFSET = 0;
    
    localparam          RESMULTACCDIV = 256 * RESMULT;  // 256 or 512
    
    // Atr0
    localparam          OAM_Y_HI = 7;
    localparam          OAM_Y_LO = 0;
    localparam          OAM_AFFINE = 8;
    localparam          OAM_DBLSIZE = 9;
    localparam          OAM_OFF_HI = 9;
    localparam          OAM_OFF_LO = 8;
    localparam          OAM_MODE_HI = 11;
    localparam          OAM_MODE_LO = 10;
    localparam          OAM_MOSAIC = 12;
    localparam          OAM_HICOLOR = 13;
    localparam          OAM_OBJSHAPE_HI = 15;
    localparam          OAM_OBJSHAPE_LO = 14;
    
    // Atr1      
    localparam          OAM_X_HI = 8;
    localparam          OAM_X_LO = 0;
    localparam          OAM_AFF_HI = 13;
    localparam          OAM_AFF_LO = 9;
    localparam          OAM_HFLIP = 12;
    localparam          OAM_VFLIP = 13;
    localparam          OAM_OBJSIZE_HI = 15;
    localparam          OAM_OBJSIZE_LO = 14;
    
    // Atr2
    localparam          OAM_TILE_HI = 9;
    localparam          OAM_TILE_LO = 0;
    localparam          OAM_PRIO_HI = 11;
    localparam          OAM_PRIO_LO = 10;
    localparam          OAM_PALETTE_HI = 15;
    localparam          OAM_PALETTE_LO = 12;
    
    localparam [3:0]    IDLE = 0,
                        WAITFIRST = 1,
                        WAITSECOND = 2,
                        WAITAFFINE1 = 3,
                        WAITAFFINE2 = 4,
                        WAITAFFINE3 = 5,
                        WAITAFFINE4 = 6,
                        EVALOAM = 7,
                        DONE = 8;
    reg [3:0]           OAMFetch;
    
    reg                 output_ok;
    
    reg [2:0]           wait_busydone;
    
    reg [6:0]           OAM_currentobj;
    
    reg [15:0]          OAM_data0;
    reg [15:0]          OAM_data1;
    reg [15:0]          OAM_data2;
    
    reg [15:0]          OAM_data_aff0;
    reg [15:0]          OAM_data_aff1;
    reg [15:0]          OAM_data_aff2;
    reg [15:0]          OAM_data_aff3;
    
    localparam [2:0]    WAITOAM = 0,
                        CALCMOSAIC = 1,
                        BASEADDR_PRE = 2,
                        BASEADDR = 3,
                        NEXTADDR = 4,
                        PIXELISSUE = 5;
    reg [2:0]           PIXELGen;
    
    reg [15:0]          Pixel_data0;        // OAM Atr0
    reg [15:0]          Pixel_data1;        // OAM Atr1
    reg [15:0]          Pixel_data2;        // OAM Atr2
    reg signed [15:0]   dx;                 // affine parameter PA
    reg signed [15:0]   dmx;                // affine parameter PB
    reg signed [15:0]   dy;                 // affine parameter PC
    reg signed [15:0]   dmy;                // affine parameter PD
    
    reg signed [8:0]    ty;                 // y position in tile
    reg signed [9:0]    posx;               // screen position of current tile
    reg [6:0]           sizeX;              // 8, 16, 32, 64
    reg [6:0]           sizeY;              // 8, 16, 32, 64
    reg [14:0]          pixeladdr_pre;      // tile address base
    reg signed [15:0]   pixeladdr;          // tile address of current pixel
    
    reg [9:0]           sizemult;
    
    reg [2:0]           x_flip_offset;
    reg [5:0]           y_flip_offset;
    reg [1:0]           x_div;
    reg [3:0]           x_size;

    wire [4:0]          mosaik_h_cnt;
    reg [7:0]           x;
    reg signed [23:0]   realX;
    reg signed [23:0]   realY;
    reg [7:0]           target;
    reg                 second_pix;
    reg                 skippixel;
    reg                 issue_pixel;
    reg [14:0]          pixeladdr_x;
    reg [14:0]          pixeladdr_x_noaff;
    
    reg [1:0]           rescounter;
    reg [1:0]           rescounter_current;

    reg [14:0]          pixeladdr_x_aff0;
    reg [14:0]          pixeladdr_x_aff1;
    reg [14:0]          pixeladdr_x_aff2;
    reg [14:0]          pixeladdr_x_aff3;
    reg [14:0]          pixeladdr_x_aff4;
    reg [14:0]          pixeladdr_x_aff5;
    
    // Pixel Pipeline
    reg [8:0]           PALETTE_byteaddr;
    
    typedef struct packed {
        reg              transparent;
        reg [1:0]        prio;
        reg              alpha;
        reg              objwnd;
    } tpixel;
    typedef tpixel t_pixelarray [0:PIXELCOUNT-1];

    t_pixelarray        pixelarray;

    tpixel              pixel_wait;
    tpixel              pixel_readback;
    tpixel              pixel_merge;

    reg [7:0]           target_start;      // range 0 to (PIXELCOUNT-1)
    reg [7:0]           target_eval;
    reg [7:0]           target_wait;
    reg [7:0]           target_merge;
    
    reg                 enable_start;
    reg                 enable_eval;
    reg                 enable_wait;
    reg                 enable_merge;
    
    reg                 second_pix_start;
    reg                 second_pix_eval;
    
    reg                 zeroread_start;
    reg                 zeroread_eval;
    
    reg [1:0]           readaddr_mux;
    reg [1:0]           readaddr_mux_eval;
    
    reg [1:0]           prio_eval;
    reg [1:0]           mode_eval;
    reg                 hicolor_eval;
    reg                 affine_eval;
    reg                 hflip_eval;
    reg [3:0]           palette_eval;
    reg                 mosaic_eval;
    reg                 mosaic_wait;
    
    reg [3:0]           mosaik_cnt;
    reg                 mosaik_merge;
    
    reg [14:0]          pixeltime;		// high number to support free drawing
    reg [14:0]          pixeltime_current;
    reg [10:0]          maxpixeltime;
    
    assign VRAM_Drawer_addr = (pixeladdr_x[14:2]);
    assign PALETTE_Drawer_addr = ((PALETTE_byteaddr[8:2]));
    
    // OAM Fetch
    always @(posedge fclk) begin
        
        if (hblankfree)
            maxpixeltime <= 954;
        else
            maxpixeltime <= 1210;
        
        if (hblank & lockspeed) begin		// immidiatly stop drawing with hblank, ignore in fastforward mode
            
            output_ok <= 1'b0;
            OAMFetch <= IDLE;
            busy <= 1'b0;
        end else
            
            case (OAMFetch)
                
                IDLE :
                    begin
                        if (PIXELGen == WAITOAM) begin
                            if (wait_busydone > 0)
                                wait_busydone <= wait_busydone - 1;
                            else
                                busy <= 1'b0;
                        end else
                            wait_busydone <= 7;
                        if (drawline) begin
                            busy <= 1'b1;
                            OAM_currentobj <= 0;
                            OAMFetch <= WAITFIRST;
                            OAMRAM_Drawer_addr <= 0;
                            output_ok <= 1'b1;
                        end 
                    end
                
                WAITFIRST :
                    begin
                        OAMRAM_Drawer_addr <= OAMRAM_Drawer_addr + 1;
                        OAMFetch <= WAITSECOND;
                    end
                
                WAITSECOND :
                    begin
                        OAM_data0 <= OAMRAM_Drawer_data[15:0];
                        OAM_data1 <= OAMRAM_Drawer_data[31:16];
                        if (OAMRAM_Drawer_data[OAM_AFFINE]) begin
                            OAMFetch <= WAITAFFINE1;
                            OAMRAM_Drawer_addr <= (OAMRAM_Drawer_data[16 + OAM_AFF_HI:16 + OAM_AFF_LO] * 8) + 1;
                        end else
                            OAMFetch <= EVALOAM;
                    end
                
                WAITAFFINE1 :
                    begin
                        OAMFetch <= WAITAFFINE2;
                        OAMRAM_Drawer_addr <= OAMRAM_Drawer_addr + 2;
                        OAM_data2 <= OAMRAM_Drawer_data[15:0];
                    end
                
                WAITAFFINE2 :
                    begin
                        OAMFetch <= WAITAFFINE3;
                        OAMRAM_Drawer_addr <= OAMRAM_Drawer_addr + 2;
                        OAM_data_aff0 <= OAMRAM_Drawer_data[31:16];
                    end
                
                WAITAFFINE3 :
                    begin
                        OAMFetch <= WAITAFFINE4;
                        OAMRAM_Drawer_addr <= OAMRAM_Drawer_addr + 2;
                        OAM_data_aff1 <= OAMRAM_Drawer_data[31:16];
                    end
                
                WAITAFFINE4 :
                    begin
                        OAMFetch <= EVALOAM;
                        OAM_data_aff2 <= OAMRAM_Drawer_data[31:16];
                    end
                
                EVALOAM :
                    begin
                        if (OAM_data0[OAM_AFFINE])
                            OAM_data_aff3 <= OAMRAM_Drawer_data[31:16];
                        else
                            OAM_data2 <= OAMRAM_Drawer_data[15:0];
                        
                        // skip if
                        if (OAM_data0[OAM_OFF_HI:OAM_OFF_LO] == 2'b10 |                 // sprite is off
                            OAM_data0[OAM_OBJSHAPE_HI:OAM_OBJSHAPE_LO] == 2'b11) begin	// obj shape prohibited
                            if (OAM_currentobj == 127) begin
                                OAMFetch <= IDLE;
                                wait_busydone <= 7;
                            end else begin
                                OAMFetch <= WAITFIRST;
                                OAMRAM_Drawer_addr <= (OAM_currentobj * 2) + 2;
                                OAM_currentobj <= OAM_currentobj + 1;
                            end
                        end else
                            OAMFetch <= DONE;
                    end
                
                DONE :
                    if (maxpixels & pixeltime >= maxpixeltime)
                        OAMFetch <= IDLE;
                    else if (PIXELGen == WAITOAM) begin
                        if (OAM_currentobj == 127) begin
                            OAMFetch <= IDLE;
                            wait_busydone <= 7;
                        end else begin
                            OAMFetch <= WAITFIRST;
                            OAMRAM_Drawer_addr <= (OAM_currentobj * 2) + 2;
                            OAM_currentobj <= OAM_currentobj + 1;
                        end
                    end 

                default: ;

            endcase
    end 
    
    // Pixelgen
    always @(posedge fclk) begin

        reg [8:0]        posy;
        reg [7:0]        fieldX;
        reg [7:0]        fieldY;
        reg [5:0]        xxx;
        reg [5:0]        yyy;
        integer          pixeladdr_calc;
        
        issue_pixel <= 1'b0;
        
        if (drawline)
            pixeltime <= 0;
        
        case (PIXELGen)
            
            WAITOAM : begin
                reg [6:0] sizeX_var, sizeY_var;
                rescounter <= 0;
                if (OAMFetch == DONE) begin
                    PIXELGen <= BASEADDR;
                    // PIXELGen <= CALCMOSAIC;
                    Pixel_data0 <= OAM_data0;
                    Pixel_data1 <= OAM_data1;
                    Pixel_data2 <= OAM_data2;
                    dx <= OAM_data_aff0;
                    dmx <= OAM_data_aff1;
                    dy <= OAM_data_aff2;
                    dmy <= OAM_data_aff3;
                    
                    posx <= OAM_data1[OAM_X_HI:OAM_X_LO];
                    
                    if (OAM_data0[OAM_HICOLOR] & one_dim_mapping == 1'b0)
                        pixeladdr_pre <= 32 * {OAM_data2[OAM_TILE_HI:OAM_TILE_LO + 1], 1'b0};
                    else
                        pixeladdr_pre <= 32 * OAM_data2[OAM_TILE_HI:OAM_TILE_LO];
                    
                    case (OAM_data0[OAM_OBJSHAPE_HI:OAM_OBJSHAPE_LO])
                        0 :		// square
                            case (OAM_data1[OAM_OBJSIZE_HI:OAM_OBJSIZE_LO])
                            0 : begin sizeX_var = 8;  sizeY_var = 8;  end
                            1 : begin sizeX_var = 16; sizeY_var = 16; end
                            2 : begin sizeX_var = 32; sizeY_var = 32; end
                            3 : begin sizeX_var = 64; sizeY_var = 64; end
                            default : ;
                            endcase
                        
                        1 :		// hor
                            case (((OAM_data1[OAM_OBJSIZE_HI:OAM_OBJSIZE_LO])))
                            0 : begin sizeX_var = 16; sizeY_var = 8;  end
                            1 : begin sizeX_var = 32; sizeY_var = 8;  end
                            2 : begin sizeX_var = 32; sizeY_var = 16; end
                            3 : begin sizeX_var = 64; sizeY_var = 32; end
                            default : ;
                            endcase
                        
                        2 :		// vert
                            case (((OAM_data1[OAM_OBJSIZE_HI:OAM_OBJSIZE_LO])))
                            0 : begin sizeX_var = 8;  sizeY_var = 16; end
                            1 : begin sizeX_var = 8;  sizeY_var = 32; end
                            2 : begin sizeX_var = 16; sizeY_var = 32; end
                            3 : begin sizeX_var = 32; sizeY_var = 64; end
                            default : ;
                            endcase
                        
                        default : ;
                    endcase
                    sizeX <= sizeX_var; sizeY <= sizeY_var;
                    
                    if (OAM_data0[OAM_HICOLOR] == 1'b0) begin
                        //tilemult      <= 32;
                        x_flip_offset <= 3;
                        y_flip_offset <= 28;
                        x_div <= 2;
                        x_size <= 4;
                    end else begin
                        //tilemult      <= 64;
                        x_flip_offset <= 7;
                        y_flip_offset <= 56;
                        x_div <= 1;
                        x_size <= 8;
                    end

                    // CALCMOSAIC
                    if (OAM_data0[OAM_AFFINE] & OAM_data0[OAM_DBLSIZE]) begin
                        fieldX = 2 * sizeX_var;
                        fieldY = 2 * sizeY_var;
                    end else begin
                        fieldX = sizeX_var;
                        fieldY = sizeY_var;
                    end
                    
                    posy = OAM_data0[OAM_Y_HI:OAM_Y_LO];
                    if (posy > (12'h100 - fieldY))
                        posy = posy - 12'h100;
                    if (OAM_data0[OAM_MOSAIC])
                        ty <= ypos_mosaic - posy;
                    else
                        ty <= ypos - posy;
                    
                    if (OAM_data0[OAM_HICOLOR] == 1'b0)
                        sizemult <= sizeX_var * 4;
                    else
                        sizemult <= sizeX_var * 8;                    
                end 
            end
            
            // CALCMOSAIC : begin
            //     PIXELGen <= BASEADDR_PRE;
            //     if (Pixel_data0[OAM_AFFINE] & Pixel_data0[OAM_DBLSIZE]) begin
            //         fieldX = 2 * sizeX;
            //         fieldY = 2 * sizeY;
            //     end else begin
            //         fieldX = sizeX;
            //         fieldY = sizeY;
            //     end
                
            //     posy = Pixel_data0[OAM_Y_HI:OAM_Y_LO];
            //     if (posy > (12'h100 - fieldY))
            //         posy = posy - 12'h100;
            //     if (Pixel_data0[OAM_MOSAIC])
            //         ty <= ypos_mosaic - posy;
            //     else
            //         ty <= ypos - posy;
                
            //     if (Pixel_data0[OAM_HICOLOR] == 1'b0)
            //         sizemult <= sizeX * 4;
            //     else
            //         sizemult <= sizeX * 8;
            // end
            
            // BASEADDR_PRE : begin
            //     if (ty < 0 | ty >= fieldY)		// not in current line -> skip
            //         PIXELGen <= WAITOAM;
            //     else begin
            //         PIXELGen <= BASEADDR;
            //         x <= 0;
            //     end
                
            //     if (posx > 12'h100)
            //         posx <= posx - 12'h200;
                
            //     //mosaik_h_cnt <= 0;
                
            //     // affine
            //     pixeladdr_pre_a0 <= sizeX * 128;        
            //     pixeladdr_pre_a1 <= signed'({1'b0, fieldX >> 1}) * dx; 
            //     pixeladdr_pre_a2 <= signed'({1'b0, fieldY >> 1}) * dmx;
            //     pixeladdr_pre_a3 <= ty * dmx;       
            //     pixeladdr_pre_a4 <= sizeY * 128;        
            //     pixeladdr_pre_a5 <= signed'({1'b0, fieldX >> 1}) * dy;
            //     pixeladdr_pre_a6 <= signed'({1'b0, fieldY >> 1}) * dmy;
            //     pixeladdr_pre_a7 <= ty * dmy;
                
            //     // non affine
            //     pixeladdr_pre_0 <= y_flip_offset - ty % 8 * x_size;
            //     pixeladdr_pre_1 <= (sizeY/8 - 1 - ty/8) * sizemult;
                
            //     pixeladdr_pre_2 <= y_flip_offset - ty % 8 * x_size;
            //     pixeladdr_pre_3 <= (sizeY/8 - 1 - ty/8) * 1024;
                
            //     pixeladdr_pre_4 <= ty % 8 * x_size;
            //     pixeladdr_pre_5 <= ty / 8 * sizemult;
                
            //     pixeladdr_pre_6 <= ty % 8 * x_size;
            //     pixeladdr_pre_7 <= ty / 8 * 1024;
            // end
            
            BASEADDR : begin
                reg signed [23:0]   pixeladdr_pre_a0;        // work-around for weird Gowin synthesis bug
                reg signed [23:0]   pixeladdr_pre_a1;        // if not syn_keep, sprites are drawn at wrong offsets
                reg signed [23:0]   pixeladdr_pre_a2;
                reg signed [23:0]   pixeladdr_pre_a3;
                reg signed [23:0]   pixeladdr_pre_a4;
                reg signed [23:0]   pixeladdr_pre_a5;
                reg signed [23:0]   pixeladdr_pre_a6;
                reg signed [23:0]   pixeladdr_pre_a7;
                
                reg signed [15:0]   pixeladdr_pre_0;
                reg signed [15:0]   pixeladdr_pre_1;
                reg signed [15:0]   pixeladdr_pre_2;
                reg signed [15:0]   pixeladdr_pre_3;
                reg signed [15:0]   pixeladdr_pre_4;
                reg signed [15:0]   pixeladdr_pre_5;
                reg signed [15:0]   pixeladdr_pre_6;
                reg signed [15:0]   pixeladdr_pre_7;

                if (ty < 0 | ty >= fieldY)		// not in current line -> skip
                    PIXELGen <= WAITOAM;
                else begin
                    PIXELGen <= NEXTADDR;
                    x <= 0;
                end

                // PIXELGen <= NEXTADDR;
                
                if (posx > 12'h100)
                    posx <= posx - 12'h200;
                
                // affine
                pixeladdr_pre_a0 = sizeX * 128;        
                pixeladdr_pre_a1 = signed'({1'b0, fieldX >> 1}) * dx; 
                pixeladdr_pre_a2 = signed'({1'b0, fieldY >> 1}) * dmx;
                pixeladdr_pre_a3 = ty * dmx;       
                pixeladdr_pre_a4 = sizeY * 128;        
                pixeladdr_pre_a5 = signed'({1'b0, fieldX >> 1}) * dy;
                pixeladdr_pre_a6 = signed'({1'b0, fieldY >> 1}) * dmy;
                pixeladdr_pre_a7 = ty * dmy;
                
                // non affine
                pixeladdr_pre_0 = y_flip_offset - ty % 8 * x_size;
                pixeladdr_pre_1 = (sizeY/8 - 1 - ty/8) * sizemult;
                
                pixeladdr_pre_2 = y_flip_offset - ty % 8 * x_size;
                pixeladdr_pre_3 = (sizeY/8 - 1 - ty/8) * 1024;
                
                pixeladdr_pre_4 = ty % 8 * x_size;
                pixeladdr_pre_5 = ty / 8 * sizemult;
                
                pixeladdr_pre_6 = ty % 8 * x_size;
                pixeladdr_pre_7 = ty / 8 * 1024;

                if (Pixel_data0[OAM_AFFINE]) begin
                    pixeltime <= pixeltime + 10 + fieldX * 2;       // total rendering time for this sprite line
                    pixeltime_current <= pixeltime + 10;
                end else begin
                    pixeltime <= pixeltime + fieldX;
                    pixeltime_current <= pixeltime;
                end
                
                // affine
                realX <= (pixeladdr_pre_a0 - pixeladdr_pre_a1 - pixeladdr_pre_a2 + pixeladdr_pre_a3) * RESMULT;
                realY <= (pixeladdr_pre_a4 - pixeladdr_pre_a5 - pixeladdr_pre_a6 + pixeladdr_pre_a7) * RESMULT;
                if (YMULTOFFSET == 1) begin
                    realX <= ((pixeladdr_pre_a0 - pixeladdr_pre_a1 - pixeladdr_pre_a2 + pixeladdr_pre_a3) * RESMULT) + dmx;
                    realY <= ((pixeladdr_pre_a4 - pixeladdr_pre_a5 - pixeladdr_pre_a6 + pixeladdr_pre_a7) * RESMULT) + dmy;
                end 
                
                // non affine
                if (Pixel_data1[OAM_VFLIP]) begin
                    if (one_dim_mapping)
                        pixeladdr <= pixeladdr_pre + pixeladdr_pre_0 + pixeladdr_pre_1;
                    else
                        pixeladdr <= pixeladdr_pre + pixeladdr_pre_2 + pixeladdr_pre_3;
                end else
                    if (one_dim_mapping)
                        pixeladdr <= pixeladdr_pre + pixeladdr_pre_4 + pixeladdr_pre_5;
                    else
                        pixeladdr <= pixeladdr_pre + pixeladdr_pre_6 + pixeladdr_pre_7;
            end
            
            NEXTADDR : begin
                if (maxpixels & pixeltime_current >= maxpixeltime)
                    PIXELGen <= WAITOAM;
                else if (x >= fieldX)
                    PIXELGen <= WAITOAM;
                else begin
                    rescounter_current <= rescounter;
                    if (rescounter == RESMULT - 1) begin
                        x <= x + 1;
                        rescounter <= 0;
                    end else
                        rescounter <= rescounter + 1;
                    if (signed'({1'b0, x}) + posx > 239)		// end of line already reached
                        PIXELGen <= WAITOAM;
                    else
                        PIXELGen <= PIXELISSUE;
                end
                
                if (Pixel_data0[OAM_AFFINE])
                    pixeltime_current <= pixeltime_current + 2;
                else
                    pixeltime_current <= pixeltime_current + 1;
                
                skippixel <= 1'b0;
                
                // x 8-bit unsigned, posx 10-bit signed
                if ((signed'({1'b0, x}) + posx) < 240 && (signed'({1'b0, x}) + posx) >= 0)        
                    target <= x + posx;
                else
                    skippixel <= 1'b1;
                
                if (Pixel_data0[OAM_AFFINE]) begin
                    if (realX < 0 || realX/RESMULTACCDIV >= sizeX || 
                        realY < 0 || realY/RESMULTACCDIV >= sizeY)
                        skippixel <= 1'b1;
                    
                    xxx = realX/RESMULTACCDIV;          // integer in-tile coord
                    yyy = realY/RESMULTACCDIV;
                    if (xxx % 2 == 1)
                        second_pix <= 1'b1;
                    else
                        second_pix <= 1'b0;
                    
                    pixeladdr_x_aff0 <= (yyy % 8) * x_size;
                    pixeladdr_x_aff1 <= (yyy/8) * sizemult;
                    
                    pixeladdr_x_aff2 <= (yyy % 8) * x_size;
                    pixeladdr_x_aff3 <= (yyy/8) * 1024;
                    
                    pixeladdr_x_aff4 <= (xxx % 8)/x_div;
                    if (Pixel_data0[OAM_HICOLOR] == 1'b0)
                        pixeladdr_x_aff5 <= (xxx/8) * 32;
                    else
                        pixeladdr_x_aff5 <= (xxx/8) * 64;
                end else begin
                    
                    if (x % 2 == 1)
                        second_pix <= 1'b1;
                    else
                        second_pix <= 1'b0;
                    
                    pixeladdr_calc = pixeladdr;
                    if (Pixel_data1[OAM_HFLIP]) begin
                        pixeladdr_calc = pixeladdr_calc + (x_flip_offset - ((x % 8)/x_div));
                        if (Pixel_data0[OAM_HICOLOR] == 1'b0)
                            pixeladdr_calc = pixeladdr_calc - (((x/8) - ((sizeX/8) - 1)) * 32);
                        else
                            pixeladdr_calc = pixeladdr_calc - (((x/8) - ((sizeX/8) - 1)) * 64);
                    end else begin
                        pixeladdr_calc = pixeladdr_calc + ((x % 8)/x_div);
                        if (Pixel_data0[OAM_HICOLOR] == 1'b0)
                            pixeladdr_calc = pixeladdr_calc + ((x/8) * 32);
                        else
                            pixeladdr_calc = pixeladdr_calc + ((x/8) * 64);
                    end
                    
                    pixeladdr_x_noaff <= pixeladdr_calc;
                end
                
                realX <= realX + dx;
                realY <= realY + dy;
            end
            
            PIXELISSUE :
                if (VRAM_Drawer_valid == 1'b0) begin		// sync on vram mux
                    PIXELGen <= NEXTADDR;
                    
                    issue_pixel <= ~skippixel;
                    if (skippixel == 1'b0) begin
                        if (Pixel_data0[OAM_AFFINE]) begin
                            if (one_dim_mapping)
                                pixeladdr_x <= pixeladdr_pre + pixeladdr_x_aff0 + pixeladdr_x_aff1 + pixeladdr_x_aff4 + pixeladdr_x_aff5;
                            else
                                pixeladdr_x <= pixeladdr_pre + pixeladdr_x_aff2 + pixeladdr_x_aff3 + pixeladdr_x_aff4 + pixeladdr_x_aff5;
                        end else
                            pixeladdr_x <= pixeladdr_x_noaff;
                    end 
                end 

            default: ;

        endcase
    end
    
    // Pixel Pipeline
    always @(posedge fclk) begin

        reg [7:0]        colorbyte;
        reg [3:0]        colordata;
        
        if (busy == 1'b0)
            pixelarray <= '{PIXELCOUNT{{1'b1, 2'b11, 1'b0, 1'b0}}};
        
        // zero cycle - address for vram is written in this cycle
        enable_start <= issue_pixel;
        target_start <= (target * RESMULT) + rescounter_current;
        readaddr_mux <= pixeladdr_x[1:0];
        second_pix_start <= second_pix;
        
        zeroread_start <= 1'b0;
        if (BG_Mode >= 3 & pixeladdr_x < 16'h4000)		// bitmapmode is on and address in the vram area of bitmap
            zeroread_start <= 1'b1;
        
        // first cycle - wait for vram to deliver data
        readaddr_mux_eval <= readaddr_mux;
        target_eval <= target_start;
        enable_eval <= enable_start;
        second_pix_eval <= second_pix_start;
        zeroread_eval <= zeroread_start;
        
        // must save those here, as pixeldata will be overwritten in next cycle
        prio_eval <= Pixel_data2[OAM_PRIO_HI:OAM_PRIO_LO];
        mode_eval <= Pixel_data0[OAM_MODE_HI:OAM_MODE_LO];
        hicolor_eval <= Pixel_data0[OAM_HICOLOR];
        affine_eval <= Pixel_data0[OAM_AFFINE];
        hflip_eval <= Pixel_data1[OAM_HFLIP];
        palette_eval <= Pixel_data2[OAM_PALETTE_HI:OAM_PALETTE_LO];
        mosaic_eval <= Pixel_data0[OAM_MOSAIC];
        
        // second cycle - eval vram
        target_wait <= target_eval;
        enable_wait <= enable_eval;
        mosaic_wait <= mosaic_eval;
        
        pixel_wait.prio <= prio_eval;
        if (mode_eval == 2'b01)
            pixel_wait.alpha <= 1'b1;
        else
            pixel_wait.alpha <= 1'b0;
        if (mode_eval == 2'b10)
            pixel_wait.objwnd <= 1'b1;
        else
            pixel_wait.objwnd <= 1'b0;
        
        colorbyte = 8'h00;
        if (zeroread_eval == 1'b0)
            case (readaddr_mux_eval[1:0])
                2'b00 :
                    colorbyte = VRAM_Drawer_data[7:0];
                2'b01 :
                    colorbyte = VRAM_Drawer_data[15:8];
                2'b10 :
                    colorbyte = VRAM_Drawer_data[23:16];
                2'b11 :
                    colorbyte = VRAM_Drawer_data[31:24];
                default :
                    ;
            endcase
        
        if (enable_eval) begin
            if (hicolor_eval == 1'b0) begin
                if (affine_eval) begin
                    if (second_pix_eval)
                        colordata = colorbyte[7:4];
                    else
                        colordata = colorbyte[3:0];
                end else
                    if ((hflip_eval & second_pix_eval == 1'b0) | (hflip_eval == 1'b0 & second_pix_eval))
                        colordata = colorbyte[7:4];
                    else
                        colordata = colorbyte[3:0];
                
                if (colordata == 4'h0)
                    pixel_wait.transparent <= 1'b1;
                else
                    pixel_wait.transparent <= 1'b0;
                
                PALETTE_byteaddr <= {palette_eval, colordata, 1'b0};
            end else begin
                
                if (colorbyte == 8'h00)
                    pixel_wait.transparent <= 1'b1;
                else
                    pixel_wait.transparent <= 1'b0;
                
                PALETTE_byteaddr <= {colorbyte, 1'b0};
            end
        end 
        
        // third cycle - wait palette + mosaic
        enable_merge <= enable_wait;
        target_merge <= target_wait;
        pixel_readback <= pixelarray[target_wait];
        
        // reset mosaic for each line and each sprite turning mosaic it off, maybe needs to reset for each new sprite...
        if (drawline | mosaic_wait == 1'b0)
            mosaik_cnt <= 15;
        
        mosaik_merge <= 1'b0;
        if (enable_wait) begin
            if (mosaik_cnt < Mosaic_H_Size & mosaic_wait) begin
                mosaik_cnt <= mosaik_cnt + 1;
                mosaik_merge <= 1'b1;
            end else begin
                mosaik_cnt <= 0;
                pixel_merge <= pixel_wait;
            end
        end 
        
        // fourth cycle
        pixel_we_color <= 1'b0;
        pixel_we_settings <= 1'b0;
        pixel_objwnd <= 1'b0;
        pixel_x <= target_merge;
        
        if (enable_merge & mosaik_merge == 1'b0) begin
            if (PALETTE_byteaddr[1])
                pixeldata_color <= {1'b0, PALETTE_Drawer_data[30:16]};
            else
                pixeldata_color <= {1'b0, PALETTE_Drawer_data[14:0]};
            pixeldata_settings <= {pixel_merge.prio, pixel_merge.alpha};
        end 
        
        if (enable_merge & output_ok) begin
            
            if (pixel_merge.transparent == 1'b0 & pixel_merge.objwnd)
                pixel_objwnd <= 1'b1;
            
            if (pixel_merge.objwnd == 1'b0) begin
                if (pixel_readback.transparent | pixel_merge.prio < pixel_readback.prio) begin
                    pixel_we_settings <= 1'b1;
                    pixelarray[target_merge].prio <= pixel_merge.prio;
                    if (pixel_merge.transparent == 1'b0) begin
                        pixel_we_color <= 1'b1;
                        pixelarray[target_merge].transparent <= 1'b0;
                    end 
                end 
            end 
        end 
    end
    
endmodule
`undef pproc_bus_gba