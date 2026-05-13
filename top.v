`timescale 1ns / 1ps

module top(
    input clk_100mhz,
    input reset,
    input [4:0] sw,
    inout ov7670_siod,
    input ov7670_pclk,
    input ov7670_vsync,
    input ov7670_href,
    input [7:0] ov7670_data,
    output ov7670_xclk,
    output ov7670_sioc,
    output ov7670_pwdn,
    output ov7670_rst,
    output [3:0] vga_r, vga_g, vga_b,
    output vga_hsync, vga_vsync
);

    wire clk_25m;
    wire clk_24m;
    wire [16:0] frame_addr;
    wire [11:0] pixel_12bit;
    wire [16:0] capture_addr;
    wire [11:0] capture_data;
    wire capture_we;
    wire [3:0] raw_r, raw_g, raw_b;
    wire video_active;
    wire [9:0] video_x;
    wire [9:0] video_y;
    wire [11:0] edge_pixel;

    reg [3:0] r_out, g_out, b_out;

    clk_wiz_0 clock_gen (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_25m),
        .clk_out2(clk_24m)
    );

    sccb_config config_inst (
        .clk(clk_25m),
        .sioc(ov7670_sioc),
        .siod(ov7670_siod)
        // .clk(clk_25m),
        // .sccb_scl(ov7670_sioc),
        // .sccb_sda(ov7670_siod)
    );

    camera_capture_640x320 capture_inst (
        .pclk(ov7670_pclk),
        .href(ov7670_href),
        .vsync(ov7670_vsync),
        .d(ov7670_data),
        .addr(capture_addr),
        .data_out(capture_data),
        .we(capture_we)
    );

    blk_mem_gen_0 ram_inst (
        .addra(capture_addr),
        .clka(ov7670_pclk),
        .dina(capture_data),
        .wea(capture_we),
        .addrb(frame_addr),
        .clkb(clk_25m),
        .doutb(pixel_12bit)
    );

    vga_640x320_display vga_inst (
        .clk_25mhz(clk_25m),
        .bram_data(pixel_12bit),
        .bram_addr(frame_addr),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .vga_r(raw_r),
        .vga_g(raw_g),
        .vga_b(raw_b)
    );

    wire [3:0] gray;

    assign ov7670_xclk = clk_24m;
    assign ov7670_pwdn = 1'b0;
    assign ov7670_rst  = 1'b1;

    assign vga_r = r_out;
    assign vga_g = g_out;
    assign vga_b = b_out;

    assign gray = (raw_r * 5 + raw_g * 9 + raw_b * 2) >> 4;

    wire [3:0] brightness;

    assign brightness = (raw_r + raw_g + raw_b) / 3;

    always @(posedge clk_25m) begin
        case (sw[4:0])
            5'b00000: begin
                r_out = raw_r;
                g_out = raw_g;
                b_out = raw_b;
            end
            5'b00001: begin
                if ((raw_r > raw_g + 2) &&
                    (raw_r > raw_b + 2)) begin

                    // keep red objects colored
                    r_out = raw_r;
                    g_out = raw_g;
                    b_out = raw_b;

                end else begin
                    r_out = gray;
                    g_out = gray;
                    b_out = gray;
                end
            end
            5'b00010: begin
                if ((raw_g > raw_r + 2) &&
                    (raw_g > raw_b + 2)) begin

                    // keep green objects colored
                    r_out = raw_r;
                    g_out = raw_g;
                    b_out = raw_b;

                end else begin
                    r_out = gray;
                    g_out = gray;
                    b_out = gray;
                end
            end
            5'b00100: begin
                if ((raw_b > raw_r) &&
                    (raw_b > raw_g - 1)) begin

                    // keep blue objects colored
                    r_out = raw_r;
                    g_out = raw_g;
                    b_out = raw_b;

                end else begin
                    r_out = gray;
                    g_out = gray;
                    b_out = gray;
                end
            end
            5'b01000: begin
                r_out = gray;
                g_out = gray;
                b_out = gray;
            end
            5'b10000: begin
                if (gray > 4'd8) begin
                    r_out = 4'hF;
                    g_out = 4'hF;
                    b_out = 4'hF;
                end
                else begin
                    r_out = 4'h0;
                    g_out = 4'h0;
                    b_out = 4'h0;
                end
            end

            default: begin
                r_out = 4'hF;
                g_out = 4'h0;
                b_out = 4'h0;
            end
        endcase
    end

endmodule
