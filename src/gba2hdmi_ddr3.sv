// GBA video and sound to HDMI converter with DDR3 framebuffer
// nand2mario, 2025.3

module gba2hdmi_ddr3 (
    input clk27,         // 27Mhz for generating HDMI and DDR3 clocks
	input resetn,
    output clk_pixel,    // 74.25Mhz pixel clock output
    input [5:0] ddr_prefetch_delay,
    output init_calib_complete,

    // gba video signals
	input clk,           // 50Mhz for gba and overlay video/audio input
    input [17:0] pixel_data,    // RGB6
    input [7:0] pixel_x,
    input [7:0] pixel_y,
    input pixel_we,
    input freeze,        // freeze video output (for debug)

    // audio input
    input [15:0] sound_left,
    input [15:0] sound_right,

    // overlay interface
    input overlay,
    output reg [7:0] overlay_x,
    output reg [7:0] overlay_y,
    input [15:0] overlay_color,

    // DDR3 interface
    output [14:0]       ddr_addr,   
    output [2:0]        ddr_bank,       
    output              ddr_cs,
    output              ddr_ras,
    output              ddr_cas,
    output              ddr_we,
    output              ddr_ck,
    output              ddr_ck_n,
    output              ddr_cke,
    output              ddr_odt,
    output              ddr_reset_n,
    output [1:0]        ddr_dm,
    inout  [15:0]       ddr_dq,
    inout  [1:0]        ddr_dqs,     
    inout  [1:0]        ddr_dqs_n, 

	// output signals
	output       tmds_clk_n,
	output       tmds_clk_p,
	output [2:0] tmds_d_n,
	output [2:0] tmds_d_p
);

// 240x160 RGB6 GBA video
// 256x224 BGR5 overlay 

reg frame_end, frame_end_r;
reg overlay_r;
reg overlay_we;
reg vsync;
reg [3:0] overlay_cnt;
reg [17:0] overlay_data;
// BGR5 to RGB6

always @(posedge clk) begin
    overlay_r <= overlay;
    vsync <= 0;
    overlay_we <= 0;
    frame_end <= 0;
    frame_end_r <= frame_end;

    if (~freeze) begin
        if (!overlay) begin
            // generate vsync for GBA video
            if (pixel_we && pixel_x == 239 && pixel_y == 159)
                frame_end <= 1;
            vsync <= frame_end_r;
        end else if (overlay && !overlay_r) begin
            // init overlay display
            overlay_x <= 0;
            overlay_y <= 0;
            overlay_we <= 0;
            overlay_cnt <= 0;
        end else if (overlay) begin
            // send overlay data to framebuffer
            // overlay runs at clk50
            // 15 clk50 cycles per pixel, 57.3K pixels -> 58fps
            overlay_cnt <= overlay_cnt == 14 ? 0 : overlay_cnt + 1;
            case (overlay_cnt)
            0: begin
                if (overlay_x == 0 && overlay_y == 0)
                    vsync <= 1;
            end

            12: begin
                overlay_data <= {overlay_color[4:0], 1'b0, overlay_color[9:5], 1'b0, overlay_color[14:10], 1'b0};
                overlay_we <= 1;
            end

            14: begin
                overlay_x <= overlay_x + 1;
                if (overlay_x == 255) begin
                    overlay_y <= overlay_y + 1;
                    if (overlay_y == 223) 
                        overlay_y <= 0;
                end
            end
            default: ;
            endcase
        end
    end
end

ddr3_framebuffer #(
    .WIDTH(256),
    .HEIGHT(224),
    .COLOR_BITS(18),
    .PREFETCH_DELAY(44)
) fb (
    .clk_27(clk27),
    .pll_lock_27(1'b1),
    .clk_g(clk),
    .clk_out(clk_pixel),
    .rst_n(resetn),
    .ddr_rst(),
    .init_calib_complete(init_calib_complete),
    .ddr_prefetch_delay(ddr_prefetch_delay),
    
    // Framebuffer interface
    .clk(clk),
    .fb_width(overlay ? 256 : 240),
    .fb_height(overlay ? 224 : 160),
    .disp_width(overlay ? 960 : 1080),
    .fb_vsync(vsync),
    .fb_we(overlay ? overlay_we : pixel_we),
    .fb_data(overlay ? overlay_data : pixel_data),
    
    .sound_left(sound_left),
    .sound_right(sound_right),

    // DDR3 interface
    .ddr_addr(ddr_addr),
    .ddr_bank(ddr_bank),
    .ddr_cs(ddr_cs),
    .ddr_ras(ddr_ras),
    .ddr_cas(ddr_cas),
    .ddr_we(ddr_we),
    .ddr_ck(ddr_ck),
    .ddr_ck_n(ddr_ck_n),
    .ddr_cke(ddr_cke),
    .ddr_odt(ddr_odt),
    .ddr_reset_n(ddr_reset_n),
    .ddr_dm(ddr_dm),
    .ddr_dq(ddr_dq),
    .ddr_dqs(ddr_dqs),
    .ddr_dqs_n(ddr_dqs_n),
    
    // HDMI output
    .tmds_clk_n(tmds_clk_n),
    .tmds_clk_p(tmds_clk_p),
    .tmds_d_n(tmds_d_n),
    .tmds_d_p(tmds_d_p)
);

endmodule
