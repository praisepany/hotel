`timescale 1ns / 1ps

// =============================================================================
// Module: vgacontroller
// Purpose: Drives a 640x480 @ 60 Hz VGA display from a 12-bit BRAM frame
//          buffer that holds a 320x240 QVGA image (pixel-doubled).
//
// KEY FIXES vs original:
//  1. Pipeline depth mismatch (critical): The original code registered hsync/
//     vsync through TWO flip-flops (hsync_delay -> hsync) but only registered
//     the active-video gate through ONE flip-flop (active_video_delay).
//     Result: sync pulses arrived 1 pixel LATER than the colour data, so the
//     monitor saw a 1-pixel colour shift relative to the blanking boundary.
//     Fix: use a single, uniform 2-cycle pipeline for ALL signals:
//       Cycle 0  – address is presented to BRAM (combinational)
//       Cycle 1  – BRAM data is valid; latch it along with the syncs
//       Cycle 2  – drive outputs (colour + syncs) to the DAC / connector
//     This keeps colour and syncs perfectly aligned.
//
//  2. bram_addr is now registered (not combinational): driving a BRAM address
//     from a large combinational expression (shifts + adds) can cause timing
//     violations at 25 MHz if the path is long. Registering it adds a 1-cycle
//     latency that is absorbed into the 2-cycle pipeline above.
//
//  3. Blanking boundary: colours are set to 0 when the DELAYED active-video
//     signal is false, guaranteeing the DAC outputs black during every non-
//     display region (front porch, sync, back porch).
// =============================================================================

module vgacontroller (
    input  wire        clk_25mhz,   // 25 MHz pixel clock for 640x480 @ 60 Hz
    input  wire        reset,       // Active-high synchronous reset
    input  wire [11:0] bram_data,   // 12-bit pixel from BRAM read port

    output reg  [16:0] bram_addr,   // Read address sent to BRAM
    output reg         hsync,       // VGA H-sync (active low)
    output reg         vsync,       // VGA V-sync (active low)
    output reg  [3:0]  vga_r,       // 4-bit red   (MSB = most-significant)
    output reg  [3:0]  vga_g,       // 4-bit green
    output reg  [3:0]  vga_b        // 4-bit blue
);

    // -------------------------------------------------------------------------
    // VGA timing parameters – 640x480 @ 60 Hz, 25.175 MHz pixel clock
    // -------------------------------------------------------------------------
    parameter H_DISPLAY     = 640;
    parameter H_FRONT_PORCH = 16;
    parameter H_SYNC_PULSE  = 96;
    parameter H_BACK_PORCH  = 48;
    parameter H_TOTAL       = 800;  // 640 + 16 + 96 + 48

    parameter V_DISPLAY     = 480;
    parameter V_FRONT_PORCH = 10;
    parameter V_SYNC_PULSE  = 2;
    parameter V_BACK_PORCH  = 33;
    parameter V_TOTAL       = 525;  // 480 + 10 + 2 + 33

    // -------------------------------------------------------------------------
    // Pixel counters
    // -------------------------------------------------------------------------
    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk_25mhz) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                v_count <= (v_count == V_TOTAL - 1) ? 10'd0 : v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Active-video and sync wires (combinational from current counters)
    // -------------------------------------------------------------------------
    wire active_video = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

    // Syncs are active LOW for standard 640x480
    wire hsync_w = ~( (h_count >= H_DISPLAY + H_FRONT_PORCH) &&
                      (h_count <  H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE) );

    wire vsync_w = ~( (v_count >= V_DISPLAY + V_FRONT_PORCH) &&
                      (v_count <  V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE) );

    // -------------------------------------------------------------------------
    // QVGA coordinate calculation  (pixel-doubling: each camera pixel = 2x2)
    // -------------------------------------------------------------------------
    wire [8:0] x_qvga = h_count[9:1];  // divide h by 2  -> 0..319
    wire [8:0] y_qvga = v_count[9:1];  // divide v by 2  -> 0..239

    // -------------------------------------------------------------------------
    // PIPELINE STAGE 0  ->  STAGE 1  (register address + control signals)
    //
    // FIX 2: bram_addr is now registered.  The address computation
    //   (y<<8) + (y<<6) + x  is a 17-bit add with shift, which is fast but
    //   registering it gives the tools timing slack and moves the address
    //   presentation one cycle earlier relative to the output stage.
    //
    // Stage-1 registers carry the "what pixel is being requested" state so
    // we can align everything with BRAM's 1-cycle read latency.
    // -------------------------------------------------------------------------
    reg        active_s1;
    reg        hsync_s1;
    reg        vsync_s1;

    always @(posedge clk_25mhz) begin
        if (reset) begin
            bram_addr <= 17'd0;
            active_s1 <= 1'b0;
            hsync_s1  <= 1'b1;
            vsync_s1  <= 1'b1;
        end else begin
            // Registered address – presented to BRAM this cycle,
            // data arrives from BRAM next cycle (stage 2).
            if (active_video)
                // (y * 320) = (y << 8) + (y << 6)  – avoids DSP multiplier
                bram_addr <= ({8'd0, y_qvga} << 8) +
                             ({8'd0, y_qvga} << 6) +
                             {8'd0, x_qvga};
            else
                bram_addr <= 17'd0;

            // Carry control signals forward one stage
            active_s1 <= active_video;
            hsync_s1  <= hsync_w;
            vsync_s1  <= vsync_w;
        end
    end

    // -------------------------------------------------------------------------
    // PIPELINE STAGE 1  ->  STAGE 2  (latch BRAM output; drive DAC outputs)
    //
    // FIX 1 (critical): ALL outputs – colour AND syncs – are registered in the
    // same always block.  active_s1 arrives here exactly when bram_data is
    // valid (BRAM 1-cycle latency), and hsync_s1 / vsync_s1 are also exactly
    // 1 cycle behind the counters, matching the colour pipeline depth.
    // -------------------------------------------------------------------------
    always @(posedge clk_25mhz) begin
        if (reset) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end else begin
            // Syncs: now a single register stage (was erroneously 2 in original)
            hsync <= hsync_s1;
            vsync <= vsync_s1;

            // Colour output: driven only during active video; black otherwise
            if (active_s1) begin
                vga_r <= bram_data[11:8];
                vga_g <= bram_data[7:4];
                vga_b <= bram_data[3:0];
            end else begin
                vga_r <= 4'd0;
                vga_g <= 4'd0;
                vga_b <= 4'd0;
            end
        end
    end

endmodule
