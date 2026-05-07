`timescale 1ns / 1ps

// =============================================================================
// Module: top  (Basys 3  OV7670 -> VGA passthrough)
//
// Block diagram:
//
//   clk_100mhz
//       |
//   [clk_wiz_0] --> clk_25mhz ---+---> ov7670_xclk
//                                 |
//                          [sccb] (runs once at startup to configure OV7670)
//                                 |
//                    OV7670 ----> [cameracontroll] --write--> [BRAM] --read--> [vgacontroller] -> VGA
//                    (PCLK)           (Port A)                (Port B)         (clk_25mhz)
//
// KEY FIXES vs original:
//  1. blk_mem_gen_0 port enables use explicit 1'b1 literals rather than
//     the integer literal '1' to avoid width-mismatch warnings.  Some
//     Vivado BRAM IP versions will generate a warning or even mis-elaborate
//     when a 1-bit enable port is driven by an unsized integer.
//
//  2. The frame buffer BRAM IP must be configured in Vivado as follows:
//       - True Dual Port RAM
//       - Port A width: 12 bits,  depth: 76800  (or next power-of-2: 131072)
//       - Port B width: 12 bits,  depth: 76800
//       - Port A address width: 17 bits  (log2(131072) = 17)
//       - Output register: Port B ONLY (gives the 1-cycle latency the VGA
//         controller compensates for; do NOT enable output register on Port A)
//       - Write mode Port A: Write First (or No Change)
//       - Collision: the BRAM spec says writes from Port A and reads from
//         Port B on different addresses are safe; no extra logic needed.
//
//  3. Reset polarity note: clk_wiz_0 may require an active-LOW reset on some
//     Vivado versions.  Check the IP customisation:  if the wizard uses
//     'reset' (active high), this file is correct.  If it uses 'resetn'
//     (active low), change .reset(btnC) to .resetn(~btnC) below.
// =============================================================================

module top (
    input  wire        clk_100mhz,    // 100 MHz oscillator on Basys 3

    // Centre button – used as global reset (active HIGH)
    input  wire        btnC,

    // OV7670 pixel data interface
    input  wire        ov7670_pclk,   // Pixel clock (driven by camera)
    input  wire        ov7670_vsync,  // Vertical sync   (active HIGH by default)
    input  wire        ov7670_href,   // Horizontal ref  (HIGH during active pixels)
    input  wire [7:0]  ov7670_d,      // 8-bit parallel data

    // OV7670 control outputs
    output wire        ov7670_xclk,   // 25 MHz clock supplied to camera XCLK pin
    output wire        ov7670_pwdn,   // Power-down  (active HIGH – 0 = normal op)
    output wire        ov7670_reset,  // Hardware reset (active LOW – 1 = normal op)

    // SCCB (I2C) configuration bus
    output wire        ov7670_sioc,   // SCCB clock
    inout  wire        ov7670_siod,   // SCCB data (bidirectional – needs pull-up)

    // Status LED
    output wire        led_config_done, // HIGH when camera configuration is done

    // VGA output  (Basys 3 Pmod VGA or on-board DAC resistor network)
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    output wire        Hsync,
    output wire        Vsync
);

    // -------------------------------------------------------------------------
    // Internal wires
    // -------------------------------------------------------------------------
    wire clk_25mhz;          // 25 MHz from Clocking Wizard

    // Camera -> BRAM (Port A)
    wire [16:0] capture_addr;
    wire [11:0] capture_data;
    wire        capture_we;

    // BRAM -> VGA (Port B)
    wire [16:0] vga_addr;
    wire [11:0] vga_data;

    // -------------------------------------------------------------------------
    // Camera hardware control
    // PWDN: active HIGH -> drive 0 for normal operation
    // RESET: active LOW -> drive 1 for normal operation
    // -------------------------------------------------------------------------
    assign ov7670_pwdn  = 1'b0;
    assign ov7670_reset = 1'b1;

    // Feed our 25 MHz clock to the camera XCLK pin
    assign ov7670_xclk = clk_25mhz;

    // -------------------------------------------------------------------------
    // 1.  Clocking Wizard IP  (100 MHz -> 25 MHz)
    //
    //     Vivado IP settings required:
    //       Input:  100 MHz
    //       Output: 25.000 MHz  (or 25.175 MHz for pixel-perfect VGA; the
    //               difference is < 1% and typical monitors tolerate it)
    //     FIX note: if your IP uses 'resetn' change .reset(btnC) to
    //               .resetn(~btnC).
    // -------------------------------------------------------------------------
    clk_wiz_0 clock_generator (
        .clk_in1  (clk_100mhz),
        .clk_out1 (clk_25mhz),
        .reset    (btnC)
    );

    // -------------------------------------------------------------------------
    // 2.  SCCB configuration module
    //     Sends the OV7670 register table once at startup.
    // -------------------------------------------------------------------------
    sccb camera_setup_inst (
        .clk_25mhz  (clk_25mhz),
        .reset      (btnC),
        .sioc       (ov7670_sioc),
        .siod       (ov7670_siod),
        .config_done(led_config_done)
    );

    // -------------------------------------------------------------------------
    // 3.  Camera capture  –  RGB565 -> RGB444, written into BRAM via Port A
    // -------------------------------------------------------------------------
    cameracontroll camera_capture_inst (
        .pclk  (ov7670_pclk),
        .vsync (ov7670_vsync),
        .href  (ov7670_href),
        .d     (ov7670_d),
        .addr  (capture_addr),
        .dout  (capture_data),
        .we    (capture_we)
    );

    // -------------------------------------------------------------------------
    // 4.  Frame buffer BRAM
    //     True Dual-Port Block RAM generated by Vivado blk_mem_gen_0.
    //
    //     Required IP configuration (Vivado Block Memory Generator):
    //       Memory Type:          True Dual Port RAM
    //       Port A / Port B
    //         Data Width:         12
    //         Depth:              131072  (2^17, >= 320*240 = 76800)
    //         Address Width:      17
    //       Port A Write Mode:    Write First  (or No Change)
    //       Port B Write Mode:    Read First
    //       Port A Output Regs:  DISABLED  (camera side – we just write)
    //       Port B Output Regs:  ENABLED   (gives the 1-cycle read latency
    //                                       the VGA controller expects)
    //       Fill Remaining:       0
    //
    //     FIX 1: enable signals now use explicit 1'b1 to avoid width warnings.
    // -------------------------------------------------------------------------
    blk_mem_gen_0 frame_buffer_inst (
        // Port A – written by camera (pclk domain)
        .clka  (ov7670_pclk),
        .ena   (1'b1),
        .wea   (capture_we),
        .addra (capture_addr),
        .dina  (capture_data),

        // Port B – read by VGA controller (25 MHz domain)
        .clkb  (clk_25mhz),
        .enb   (1'b1),
        .web   (1'b0),            // Port B is read-only
        .addrb (vga_addr),
        .doutb (vga_data)
    );

    // -------------------------------------------------------------------------
    // 5.  VGA controller
    //     Reads from BRAM Port B and drives the 640x480 @ 60 Hz display.
    // -------------------------------------------------------------------------
    vgacontroller vga_out_inst (
        .clk_25mhz (clk_25mhz),
        .reset     (btnC),
        .bram_data (vga_data),
        .bram_addr (vga_addr),
        .hsync     (Hsync),
        .vsync     (Vsync),
        .vga_r     (vgaRed),
        .vga_g     (vgaGreen),
        .vga_b     (vgaBlue)
    );

endmodule
