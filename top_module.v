module top_module(
    input clk100,
    input btnC,        // Reset
    input [2:0] sw,    // Filter selection
    // Camera Pins
    input  ov7670_pclk,
    input  ov7670_vsync,
    input  ov7670_href,
    input  [7:0] ov7670_d,
    output ov7670_xclk,
    output ov7670_pwdn,
    output ov7670_reset,
    output ov7670_scl,
    inout  ov7670_sda,
    // VGA Pins
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output vga_hsync,
    output vga_vsync
    );

    wire clk_vga, clk_camera, config_finished;
    wire [16:0] frame_addr, vga_addr;
    wire [11:0] frame_pixel, vga_pixel;
    wire [9:0] x, y;
    wire video_on, we;
    reg [11:0] processed_pixel;

    assign ov7670_pwdn = 0;
    assign ov7670_reset = 1;

    // 1. Clocks
    clk_wiz_0 clk_gen (
        .clk_out1(clk_vga), 
        .clk_out2(clk_camera), 
        .clk_in1(clk100)
    );
    assign ov7670_xclk = clk_camera;

    // 2. Camera Configuration (SCCB)
    ov7670_setup cam_cfg (
        .clk(clk100),
        .scl(ov7670_scl),
        .sda(ov7670_sda),
        .ready(config_finished)
    );

    // 3. Camera Capture
    ov7670_capture cap (
        .pclk(ov7670_pclk),
        .vsync(ov7670_vsync),
        .href(ov7670_href),
        .d(ov7670_d),
        .addr(frame_addr),
        .dout(frame_pixel),
        .we(we)
    );

    // 4. Frame Buffer (BRAM)
    blk_mem_gen_0 buffer (
        .clka(ov7670_pclk),
        .ena(1'b1),
        .wea(we),
        .addra(frame_addr),
        .dina(frame_pixel),

        .clkb(clk_vga),
        .enb(1'b1),
        .addrb(vga_addr),
        .doutb(vga_pixel)
    );

    // 5. VGA Control & Addressing
    vga_sync vga_ctrl (
        .clk(clk_vga),
        .h_sync(vga_hsync),
        .v_sync(vga_vsync),
        .video_on(video_on),
        .x(x),
        .y(y)
    );

    address_gen addr_ctrl (
        .x(x),
        .y(y),
        .addr(vga_addr)
    );

    // 6. Image Processing Filters
    wire [7:0] gray = (vga_pixel[11:8] + vga_pixel[7:4] + vga_pixel[3:0]) / 3;

    always @(*) begin
        case(sw)
            3'b001: processed_pixel = ~vga_pixel;                        // Inversion
            3'b010: processed_pixel = {3{gray[3:0]}};                   // Grayscale
            3'b011: processed_pixel = (gray > 7) ? 12'hFFF : 12'h000;   // Threshold
            3'b100: processed_pixel = {vga_pixel[11:8], 8'h0};          // Red Channel
            default: processed_pixel = vga_pixel;                       // Raw
        endcase
    end

    assign {vga_r, vga_g, vga_b} = (video_on) ? processed_pixel : 12'h000;

endmodule