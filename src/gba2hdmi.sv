// GBA video and sound to HDMI converter
// nand2mario, 2024.7

module gba2hdmi (
	input clk,      // clock
	input resetn,

    // gba video signals
    input [17:0] pixel_data,    // RGB6
    input [7:0] pixel_x,
    input [7:0] pixel_y,
    input pixel_we,

    // audio input
    input [15:0] sound_left,
    input [15:0] sound_right,

    // overlay interface
    input overlay,
    output [10:0] overlay_x,
    output [9:0] overlay_y,
    input [15:0] overlay_color,

	// video clocks
	input clk_pixel,
	input clk_5x_pixel,

    // output [7:0] led,

	// output signals
	output       tmds_clk_n,
	output       tmds_clk_p,
	output [2:0] tmds_d_n,
	output [2:0] tmds_d_p
);

// include from tang_primer_25k/config.sv and tang_nano_20k/config.sv

localparam FRAMEWIDTH = 1280;
localparam FRAMEHEIGHT = 720;
localparam TOTALWIDTH = 1650;
localparam TOTALHEIGHT = 750;
localparam SCALE = 5;
localparam VIDEOID = 4;
localparam VIDEO_REFRESH = 60.0;

localparam IDIV_SEL_X5 = 3;
localparam FBDIV_SEL_X5 = 54;
localparam ODIV_SEL_X5 = 2;
localparam DUTYDA_SEL_X5 = "1000";
localparam DYN_SDIV_SEL_X5 = 2;
  
localparam CLKFRQ = 74250;

localparam COLLEN = 80;
localparam AUDIO_BIT_WIDTH = 16;

localparam POWERUPNS = 100000000.0;
localparam CLKPERNS = (1.0/CLKFRQ)*1000000.0;
localparam int POWERUPCYCLES = $rtoi($ceil( POWERUPNS/CLKPERNS ));

// video stuff
wire [9:0] cy, frameHeight;
wire [10:0] cx, frameWidth;

assign overlay_x = cx;
assign overlay_y = cy;

//
// BRAM frame buffer
//
localparam MEM_DEPTH=240*160;       // 38400, 37K words, 16-bit address

logic [17:0] mem [0:MEM_DEPTH-1];
logic [$clog2(MEM_DEPTH)-1:0] mem_portA_addr;
logic [17:0] mem_portA_wdata;
logic mem_portA_we;

logic [$clog2(MEM_DEPTH)-1:0] mem_portB_addr;
logic [17:0] mem_portB_rdata;

logic initializing = 1;
logic [7:0] init_y = 0;
logic [7:0] init_x = 0; 

// BRAM port A read/write
always_ff @(posedge clk) begin
    if (mem_portA_we) begin
        mem[mem_portA_addr] <= mem_portA_wdata;
    end
end

// BRAM port B read
always_ff @(posedge clk_pixel) begin
    mem_portB_rdata <= mem[mem_portB_addr];
end

initial begin
    // $readmemb("background.txt", mem);
end


// 
// Data input and initial background loading
//
logic [8:0] r_scanline;
logic [8:0] r_cycle;
always @(posedge clk) begin
    if (~resetn) begin
        initializing <= 1;
        init_y <= 0;
        init_x <= 0;
        mem_portA_we <= 0;
    end else if (initializing) begin    // setup background at initialization
        init_x <= init_x == 239 ? 0 : init_x + 1;
        init_y <= init_x == 239 ? init_y + 1 : init_y;
        if (init_y == 160) begin
            initializing <= 0;
            mem_portA_we <= 0;
        end else begin
            mem_portA_we <= 1;
            mem_portA_addr <= init_y * 240 + init_x;
            mem_portA_wdata <= 17'b100000_100000_100000;          // grey
        end
    end else begin
        // debug: leave out 
        mem_portA_we <= //pixel_x[2:0] != 0 || pixel_y[2:0] != 0 ? 
                        pixel_we;  // : 0;
        mem_portA_addr <= pixel_y * 240 + pixel_x;
        mem_portA_wdata <= pixel_data;
    end
end

// audio stuff
//    localparam AUDIO_RATE=32000;        // weird only 32K sampling rate works
//    localparam AUDIO_RATE=96000;
localparam AUDIO_RATE=48000;
localparam AUDIO_CLK_DELAY = CLKFRQ * 1000 / AUDIO_RATE / 2;
logic [$clog2(AUDIO_CLK_DELAY)-1:0] audio_divider;
logic clk_audio;

always_ff@(posedge clk_pixel) 
begin
    if (audio_divider != AUDIO_CLK_DELAY - 1) 
        audio_divider++;
    else begin 
        clk_audio <= ~clk_audio; 
        audio_divider <= 0; 
    end
end

reg [15:0] audio_sample_word [1:0], audio_sample_word0 [1:0];
always @(posedge clk_pixel) begin       // crossing clock domain
    audio_sample_word0[0] <= sound_right;
    audio_sample_word[0] <= audio_sample_word0[0];
    audio_sample_word0[1] <= sound_left;
    audio_sample_word[1] <= audio_sample_word0[1];
end

//
// Video
//

// address generation
// reg [8:0] cx2_orig;
// reg [7:0] cy2_orig;
// reg [15:0] line_start;
// reg [7:0] line_off;

reg [3:0] xcnt, ycnt;        // 0 to 8, advance on 4 and 8, scale up by 4.5
reg [15:0] gba_addr;
reg active, active_gba_p, active_overlay_p;

// scale 240x160 4.5x to 1080*720
// this is basically the faster version of: mem_portB_addr = cy / 4.5 * 240 + (cx - 100) / 4.5; 
always @(posedge clk_pixel) begin
    // increment address: 104+ 108+ 113+ 117+ ... 1175+ 1179+, 240 advances
    xcnt <= xcnt == 8 ? 0 : xcnt + 1;
    if (active && (xcnt == 4 || xcnt == 8)) 
        gba_addr <= gba_addr + 1;

    if (cx == 99) begin
        xcnt <= 0;
        active <= 1;
        if (cy == 0) begin
            gba_addr <= 0;
            ycnt <= 0;
        end
    end
    if (cx == 1179) 
        active <= 0;
    if (cx == 1180) begin
        ycnt <= ycnt == 8 ? 0 : ycnt + 1;
        if (ycnt != 4 & ycnt != 8)      // repeat lines 4 or 5 times
            gba_addr <= gba_addr - 240;
    end

    active_gba_p <= active & ~overlay;
    active_overlay_p <= cx[10:8] != 0 & ~cx[10] & cy >= 24 & cy < 696 & overlay;


    // this is the slower 4.5x scaler
    // stage 1: calc div 4.5
    // cy2_orig <= {cy, 1'b0} / 9;
    // cx2_orig <= {cx + 2 - 100, 1'b0} / 9;
    // stage 2: calc line start address and offset
    // line_start <= {cy2_div45, 8'b0} - {cy2_div45, 4'b0};        // * 240
    // line_off <= cx2_div45;
    // active_p <= cx >= 100 & cx < 1180 & ~overlay;
    // active_overlay_p <= cx[10:8] != 0 & ~cx[10] & cy >= 24 & cy < 696 & overlay;

    // this is the faster 4x scaler
    // cy2_orig <= (cy - 40) >> 2;
    // cx2_orig <= (cx + 2 - 160) >> 2;
    // line_start <= {cy2_orig, 8'b0} - {cy2_orig, 4'b0};        // * 240
    // line_off <= cx2_orig;
    // active_p <= cx >= 160 & cx < 1120 & cy >= 40 & cy < 680 & ~overlay;
    // active_overlay_p <= cx[10:8] != 0 & ~cx[10] & cy >= 24 & cy < 696 & overlay;
end

// assign mem_portB_addr = line_start + line_off;
assign mem_portB_addr = gba_addr;

wire [23:0] rgb = active_gba_p ? {mem_portB_rdata[17:12], 2'b0,      // RGB6 to RGB8
                                         mem_portB_rdata[11:6], 2'b0, 
                                         mem_portB_rdata[5:0], 2'b0} : 
                  active_overlay_p ? {overlay_color[4:0], 3'b0,         // BGR5 to RGB8
                                        overlay_color[9:5], 3'b0,
                                        overlay_color[14:10], 3'b0} :
                  24'h303030;     // grey bars on the sides

// HDMI output.
logic[2:0] tmds;

hdmi #( .VIDEO_ID_CODE(VIDEOID), 
        .DVI_OUTPUT(0), 
        .VIDEO_REFRESH_RATE(VIDEO_REFRESH),
        .IT_CONTENT(1),
        .AUDIO_RATE(AUDIO_RATE), 
        .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
        .START_X(0),
        .START_Y(0) )

hdmi( .clk_pixel_x5(clk_5x_pixel), 
        .clk_pixel(clk_pixel), 
        .clk_audio(clk_audio),
        .rgb(rgb), 
        .reset( ~resetn ),
        .audio_sample_word(audio_sample_word),
        .tmds(tmds), 
        .tmds_clock(tmdsClk), 
        .cx(cx), 
        .cy(cy),
        .frame_width( frameWidth ),
        .frame_height( frameHeight ) );

// Gowin LVDS output buffer
ELVDS_OBUF tmds_bufds [3:0] (
    .I({clk_pixel, tmds}),
    .O({tmds_clk_p, tmds_d_p}),
    .OB({tmds_clk_n, tmds_d_n})
);


endmodule
