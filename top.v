`timescale 1ns / 1ps

module top (
    input wire clk_100mhz,        // Main 100 MHz clock from Basys 3
    input wire btnC,              // Center button on Basys 3 for Reset

    // OV7670 Camera Data Signals
    input wire ov7670_pclk,       // Pixel clock from camera
    input wire ov7670_vsync,      // Vertical sync from camera
    input wire ov7670_href,       // Horizontal reference from camera
    input wire [7:0] ov7670_d,    // 8-bit data bus from camera
    output wire ov7670_xclk,      // 25 MHz system clock sent TO the camera
    output wire ov7670_pwdn,      // Power down signal
    output wire ov7670_reset,     // Camera reset signal

    // OV7670 Camera SCCB (I2C) Signals
    output wire ov7670_sioc,      // SCCB Clock
    inout wire ov7670_siod,       // SCCB Data (Must be inout)

    // Debugging
    output wire led_config_done,  // Connect to Basys 3 LED[0] to verify startup

    // VGA Output Signals
    output wire [3:0] vgaRed,     // VGA Red 4-bit
    output wire [3:0] vgaGreen,   // VGA Green 4-bit
    output wire [3:0] vgaBlue,    // VGA Blue 4-bit
    output wire Hsync,            // VGA Horizontal Sync
    output wire Vsync             // VGA Vertical Sync
);

    // -----------------------------------------------------------------
    // Internal Wires
    // -----------------------------------------------------------------
    wire clk_25mhz;               // 25 MHz clock for VGA, Camera XCLK, and SCCB

    // Wires between Capture Module and BRAM (Port A)
    wire [16:0] capture_addr;
    wire [11:0] capture_data;
    wire capture_we;

    // Wires between VGA Module and BRAM (Port B)
    wire [16:0] vga_addr;
    wire [11:0] vga_data;

    // -----------------------------------------------------------------
    // Camera Hardware Power/Reset Setup
    // -----------------------------------------------------------------
    // PWDN is active high (0 = normal operation)
    // RESET is active low (1 = normal operation)
    assign ov7670_pwdn = 1'b0;
    assign ov7670_reset = 1'b1;

    // Send our clean 25 MHz clock directly to the camera's XCLK pin
    assign ov7670_xclk = clk_25mhz;

    // -----------------------------------------------------------------
    // 1. Clocking Wizard IP
    // -----------------------------------------------------------------
    clk_wiz_0 clock_generator (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_25mhz),
        .reset(btnC)
    );

    // -----------------------------------------------------------------
    // 2. SCCB / I2C Configuration Module
    // -----------------------------------------------------------------
    sccb camera_setup_inst (
        .clk_25mhz(clk_25mhz),
        .reset(btnC),
        .sioc(ov7670_sioc),
        .siod(ov7670_siod),
        .config_done(led_config_done) // Lights up an LED when ROM finishes sending
    );

    // -----------------------------------------------------------------
    // 3. Camera Capture Module
    // -----------------------------------------------------------------
    cameracontroll camera_capture_inst (
        .pclk(ov7670_pclk),
        .vsync(ov7670_vsync),
        .href(ov7670_href),
        .d(ov7670_d),

        .addr(capture_addr),
        .dout(capture_data),
        .we(capture_we)
    );

    // -----------------------------------------------------------------
    // 4. Block RAM IP (The Frame Buffer)
    // -----------------------------------------------------------------
    blk_mem_gen_0 frame_buffer_inst (
        // PORT A: Written by the Camera via PCLK
        .clka(ov7670_pclk),
        .wea(capture_we),
        .addra(capture_addr),
        .dina(capture_data),
        .ena(1),

        // PORT B: Read by the VGA Controller via 25 MHz clock
        .clkb(clk_25mhz),
        .addrb(vga_addr),
        .doutb(vga_data),
        .enb(1)
    );

    // -----------------------------------------------------------------
    // 5. VGA Controller Module
    // -----------------------------------------------------------------
    vgacontroller vga_out_inst (
        .clk_25mhz(clk_25mhz),
        .reset(btnC),
        .bram_data(vga_data),

        .bram_addr(vga_addr),
        .hsync(Hsync),
        .vsync(Vsync),
        .vga_r(vgaRed),
        .vga_g(vgaGreen),
        .vga_b(vgaBlue)
    );

endmodule
