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

//
// BRAM frame buffer
//
logic [17:0] mem_portA_wdata;

localparam WIDTH=240, width=240;
localparam HEIGHT=160, height=160;
localparam COLOR_BITS=6;

localparam FB_DEPTH = WIDTH * HEIGHT;
localparam COLOR_WIDTH = COLOR_BITS * 3;
localparam FB_AWIDTH = $clog2(FB_DEPTH);
// reg [COLOR_WIDTH-1:0] mem [0:FB_DEPTH-1];
reg [FB_AWIDTH-1:0] mem_portA_addr;
reg mem_portA_we;

wire [FB_AWIDTH-1:0] mem_portB_addr;
reg [COLOR_WIDTH-1:0] mem_portB_rdata;

fb u_fb(
    .clka(clk), .clkb(clk_pixel), .reseta('b0), .resetb(1'b0), .cea('b1), .ceb('b1), 
    // port A write
    .ada(mem_portA_addr), .douta(), .ocea(1'b0), .wrea(mem_portA_we), .dina(mem_portA_wdata),
    // port B read
    .adb(mem_portB_addr), .doutb(mem_portB_rdata), .oceb(1'b1), .wreb('b0), .dinb('b0)
);

// 
// Data input and initial background loading
//
logic [8:0] r_scanline;
logic [8:0] r_cycle;
always @(posedge clk) begin
    mem_portA_we <= pixel_we;
    mem_portA_addr <= pixel_y * 240 + pixel_x;
    mem_portA_wdata <= pixel_data;
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
    audio_sample_word0[0] <= sound_left;
    audio_sample_word[0] <= audio_sample_word0[0];
    audio_sample_word0[1] <= sound_right;
    audio_sample_word[1] <= audio_sample_word0[1];
end

//
// Video
// Scale to 1080x720 for GBA video, 960x720 for overlay
//
reg [23:0] rgb;             // actual RGB output
reg active                  /* xsynthesis syn_keep=1 */;
reg [$clog2(WIDTH)-1:0] xx  /* xsynthesis syn_keep=1 */; // scaled-down pixel position
reg [$clog2(HEIGHT)-1:0] yy /* xsynthesis syn_keep=1 */;
reg [10:0] xcnt             /* xsynthesis syn_keep=1 */;
reg [10:0] ycnt             /* xsynthesis syn_keep=1 */;                  // fractional scaling counters
reg [9:0] cy_r;
assign mem_portB_addr = yy * WIDTH + xx;
assign overlay_x = xx;
assign overlay_y = yy;
localparam XSTART = (1280 - 1080) / 2;   // 1080:720 = 3:2
localparam XSTOP = (1280 + 1080) / 2;
localparam XSTART_O = (1280 - 960) / 2;   // 960:720 = 4:3
localparam XSTOP_O = (1280 + 960) / 2;

// address calculation
// Assume the video occupies fully on the Y direction, we are upscaling the video by `720/height`.
// xcnt and ycnt are fractional scaling counters.
always @(posedge clk_pixel) begin
    reg active_t;
    reg [10:0] xcnt_next;
    reg [10:0] ycnt_next;
    xcnt_next = xcnt + (overlay ? 256 : width);
    ycnt_next = ycnt + (overlay ? 224 : height);

    active_t = 0;
    if (~overlay && cx == XSTART - 1 || overlay && cx == XSTART_O - 1) begin
        active_t = 1;
        active <= 1;
    end else if (~overlay && cx == XSTOP - 1 || overlay && cx == XSTOP_O - 1) begin
        active_t = 0;
        active <= 0;
    end

    if (active_t | active) begin        // increment xx
        xcnt <= xcnt_next;
        if (overlay) begin
            if (xcnt_next >= 960) begin
                xcnt <= xcnt_next - 960;
                xx <= xx + 1;
            end
        end else begin
            if (xcnt_next >= 1080) begin
                xcnt <= xcnt_next - 1080;
                xx <= xx + 1;
            end
        end
    end

    cy_r <= cy;
    if (cy[0] != cy_r[0]) begin         // increment yy at new lines
        ycnt <= ycnt_next;
        if (ycnt_next >= 720) begin
            ycnt <= ycnt_next - 720;
            yy <= yy + 1;
        end
    end

    if (cx == 0) begin
        xx <= 0;
        xcnt <= 0;
    end
    
    if (cy == 0) begin
        yy <= 0;
        ycnt <= 0;
    end 

end

// calc rgb value to hdmi
always @(posedge clk_pixel) begin
    if (active) begin
        if (overlay)
            rgb <= {overlay_color[4:0],3'b0,overlay_color[9:5],3'b0,overlay_color[14:10],3'b0};       // BGR5 to RGB8
        else
            rgb <= {mem_portB_rdata[COLOR_BITS*2 +: COLOR_BITS], {(8-COLOR_BITS){1'b0}},
                    mem_portB_rdata[COLOR_BITS   +: COLOR_BITS], {(8-COLOR_BITS){1'b0}},
                    mem_portB_rdata[0            +: COLOR_BITS], {(8-COLOR_BITS){1'b0}}};    // RGB4 to RGB8
    end else
        rgb <= 24'h303030;
end

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
        .reset( 0 ),
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
