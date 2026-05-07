`timescale 1ns / 1ps

module vgacontroller (
    input wire clk_25mhz,       // 25 MHz clock for 640x480 @ 60Hz
    input wire reset,           // Active-high reset
    input wire [11:0] bram_data,// 12-bit pixel data from BRAM Read Port (Port B)

    output reg [16:0] bram_addr,// Address to request from BRAM
    output reg hsync,           // VGA Horizontal Sync
    output reg vsync,           // VGA Vertical Sync
    output reg [3:0] vga_r,     // 4-bit VGA Red
    output reg [3:0] vga_g,     // 4-bit VGA Green
    output reg [3:0] vga_b      // 4-bit VGA Blue
);

    // VGA Timing Constants (640x480 @ 60Hz)
    parameter H_DISPLAY       = 640;
    parameter H_FRONT_PORCH   = 16;
    parameter H_SYNC_PULSE    = 96;
    parameter H_BACK_PORCH    = 48;
    parameter H_TOTAL         = 800;

    parameter V_DISPLAY       = 480;
    parameter V_FRONT_PORCH   = 10;
    parameter V_SYNC_PULSE    = 2;
    parameter V_BACK_PORCH    = 33;
    parameter V_TOTAL         = 525;

    // Counters for the VGA electron beam position
    reg [9:0] h_count;
    reg [9:0] v_count;

    // Signals for pixel coordinate calculations and latency
    wire active_video;
    reg active_video_delay; // Used to account for 1-clock BRAM delay
    reg hsync_delay;
    reg vsync_delay;

    wire [8:0] x_qvga;
    wire [8:0] y_qvga;

    // -----------------------------------------------------------------
    // 1. Horizontal and Vertical Counters
    // -----------------------------------------------------------------
    always @(posedge clk_25mhz or posedge reset) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // -----------------------------------------------------------------
    // 2. Sync Signal Generation
    // -----------------------------------------------------------------
    // Sync pulses are active-low for standard 640x480 VGA
    wire hsync_next = ~((h_count >= H_DISPLAY + H_FRONT_PORCH) &&
                        (h_count < H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE));

    wire vsync_next = ~((v_count >= V_DISPLAY + V_FRONT_PORCH) &&
                        (v_count < V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE));

    assign active_video = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

    // -----------------------------------------------------------------
    // 3. Address Calculation (Pixel Doubling & Math Trick)
    // -----------------------------------------------------------------
    // We drop the lowest bit (divide by 2) to scale 320x240 up to 640x480
    assign x_qvga = h_count[9:1];
    assign y_qvga = v_count[9:1];

    // Calculate BRAM Address: Address = (Y * 320) + X
    // Hardware Trick: (Y * 320) = (Y * 256) + (Y * 64) = (Y << 8) + (Y << 6)
    // This avoids using heavy DSP multiplier blocks!
    always @(*) begin
        if (active_video) begin
            bram_addr = (y_qvga << 8) + (y_qvga << 6) + x_qvga;
        end else begin
            bram_addr = 17'd0;
        end
    end

    // -----------------------------------------------------------------
    // 4. BRAM Latency Compensation & Color Output
    // -----------------------------------------------------------------
    // BRAM takes 1 clock cycle to output data after receiving an address.
    // We must delay the active video and sync signals by 1 clock cycle
    // so the monitor gets the color perfectly aligned with the syncs.
    always @(posedge clk_25mhz) begin
        active_video_delay <= active_video;
        hsync_delay        <= hsync_next;
        vsync_delay        <= vsync_next;

        // Output syncs
        hsync <= hsync_delay;
        vsync <= vsync_delay;

        // Output colors: Only draw when in the active region
        if (active_video_delay) begin
            vga_r <= bram_data[11:8];
            vga_g <= bram_data[7:4];
            vga_b <= bram_data[3:0];
        end else begin
            // Output black during front porch, sync pulse, and back porch
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end
    end

endmodule
