`timescale 1ns / 1ps

module top(
    input clk_100mhz,
    input reset,
    inout ov7670_siod,
    input ov7670_pclk,
    input ov7670_vsync,
    input ov7670_href,
    input [7:0] ov7670_data,
    input [4:0] sw,
    output ov7670_sioc,
    output ov7670_xclk,
    output ov7670_pwdn,
    output ov7670_rst,
    output reg [3:0] vga_r, vga_g, vga_b,
    output vga_hsync,
    output vga_vsync
);

    wire clk_25m;
    wire clk_24m;

    wire [11:0] capture_data;

    wire [16:0] addra;
    wire [16:0] addrb;
    wire [11:0] pixel_from_bram;
    wire we;

    wire [3:0] r_raw, g_raw, b_raw;
    wire [3:0] gray;

    clk_wiz_0 clock_gen (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_25m),
        .clk_out2(clk_24m)
    );

    sccb config_inst (
        .clk(clk_25m),
        .sioc(ov7670_sioc),
        .siod(ov7670_siod)
    );

    cameraCapture capture_inst (
        .pclk(ov7670_pclk),
        .href(ov7670_href),
        .vsync(ov7670_vsync),
        .d(ov7670_data),
        .addr(addra),
        .data_out(capture_data),
        .we(we)
    );

    blk_mem_gen_0 ram_inst (
        .addra(addra),
        .clka(ov7670_pclk),
        .dina(capture_data),
        .wea(we),
        .addrb(addrb),
        .clkb(clk_25m),
        .doutb(pixel_from_bram)
    );

    vga vga_inst (
        .clk_25mhz(clk_25m),
        .bram_data(pixel_from_bram),
        .bram_addr(addrb),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .vga_r(r_raw),
        .vga_g(g_raw),
        .vga_b(b_raw)
    );

    assign ov7670_xclk = clk_24m;
    assign ov7670_pwdn = 1'b0;
    assign ov7670_rst  = 1'b1;

    //Calculate gray pixel
    assign gray = (r_raw * 5 + g_raw * 9 + b_raw * 2) >> 4;

    always @(posedge clk_25m) begin
        case (sw[4:0])
            5'b00000: begin //No filter
                vga_r = r_raw;
                vga_g = g_raw;
                vga_b = b_raw;
            end
            5'b00001: begin //Red color isolation filter
                if ((r_raw > g_raw + 2) && (r_raw > b_raw + 2)) begin
                    vga_r = r_raw;
                    vga_g = g_raw;
                    vga_b = b_raw;
                end else begin
                    vga_r = gray;
                    vga_g = gray;
                    vga_b = gray;
                end
            end
            5'b00010: begin //Green color isolation filter
                if ((g_raw > r_raw + 2) && (g_raw > b_raw + 2)) begin
                    vga_r = r_raw;
                    vga_g = g_raw;
                    vga_b = b_raw;
                end else begin
                    vga_r = gray;
                    vga_g = gray;
                    vga_b = gray;
                end
            end
            5'b00100: begin //Blue color isolation filter
                if ((b_raw > r_raw) && (b_raw > g_raw - 1)) begin
                    vga_r = r_raw;
                    vga_g = g_raw;
                    vga_b = b_raw;
                end else begin
                    vga_r = gray;
                    vga_g = gray;
                    vga_b = gray;
                end
            end
            5'b01000: begin //Grayscale filter
                vga_r = gray;
                vga_g = gray;
                vga_b = gray;
            end
            5'b10000: begin //Thresholding filter
                if (gray > 4'd8) begin
                    vga_r = 4'hF;
                    vga_g = 4'hF;
                    vga_b = 4'hF;
                end
                else begin
                    vga_r = 4'h0;
                    vga_g = 4'h0;
                    vga_b = 4'h0;
                end
            end
            default: begin //Black screen when turning more than one switch on
                vga_r = 4'h0;
                vga_g = 4'h0;
                vga_b = 4'h0;
            end
        endcase
    end
endmodule
