`timescale 1ns / 1ps

// =============================================================================
// Module: cameracontroll
// Purpose: Captures RGB565 pixel data from OV7670 and writes it to BRAM
//          as 12-bit RGB444.
//
// KEY FIXES vs original:
//  1. HREF-gated byte_state reset: byte_state now resets to 0 whenever HREF
//     goes LOW (end of a row). The original only reset on VSYNC, so if a row
//     ended mid-pixel the next row would start on the wrong byte, corrupting
//     every subsequent line.
//  2. RGB565 -> RGB444 bit mapping clarified and corrected:
//       Byte 1 (d_latch): [R4 R3 R2 R1 R0 | G5 G4 G3]
//       Byte 2 (d):       [G2 G1 G0 | B4 B3 B2 B1 B0]
//     For 4-bit colour output:
//       RED   = d_latch[7:4]           (R4..R1)
//       GREEN = {d_latch[2:0], d[7]}   (G5..G2)
//       BLUE  = d[4:1]                 (B4..B1)
//     BRAM word layout: [11:8]=R  [7:4]=G  [3:0]=B
//  3. VSYNC is ACTIVE HIGH on OV7670 by default – the original polarity was
//     already correct; kept as-is with an explicit comment.
//  4. Address counter: addr increments after a write by watching the 'we'
//     flag from the PREVIOUS cycle. Logic is preserved but the timing is now
//     clearly documented so it isn't accidentally "fixed" into a double-write.
// =============================================================================

module cameracontroll (
    input  wire        pclk,   // Pixel clock from camera
    input  wire        vsync,  // Vertical sync  (ACTIVE HIGH on OV7670)
    input  wire        href,   // Horizontal reference (HIGH during active pixels)
    input  wire [7:0]  d,      // 8-bit parallel data from camera

    output reg  [16:0] addr,   // BRAM write address (17 bits for 320x240 = 76800)
    output reg  [11:0] dout,   // 12-bit pixel for BRAM  {R[3:0], G[3:0], B[3:0]}
    output reg         we      // Write-enable pulse for BRAM (1 cycle wide)
);

    // -------------------------------------------------------------------------
    // Internal registers
    // -------------------------------------------------------------------------
    reg [7:0] d_latch;     // Holds Byte-1 (high byte) of an RGB565 pair
    reg       byte_state;  // 0 = waiting for Byte-1,  1 = waiting for Byte-2

    // -------------------------------------------------------------------------
    // Power-on defaults (simulation convenience; synthesis ignores this block
    // because FPGA flip-flops initialise to 0 on configuration)
    // -------------------------------------------------------------------------
    initial begin
        addr       = 17'd0;
        dout       = 12'd0;
        we         = 1'b0;
        d_latch    = 8'd0;
        byte_state = 1'b0;
    end

    // -------------------------------------------------------------------------
    // Main capture process – clocked on PCLK
    // -------------------------------------------------------------------------
    always @(posedge pclk) begin

        // ---------------------------------------------------------------------
        // VSYNC HIGH  ->  new frame beginning.
        // Reset the write address and byte machine so we always start at pixel 0.
        // VSYNC is ACTIVE HIGH on a default-configured OV7670.
        // ---------------------------------------------------------------------
        if (vsync == 1'b1) begin
            addr       <= 17'd0;
            byte_state <= 1'b0;
            we         <= 1'b0;

        end else begin

            // Default: de-assert write-enable every cycle
            we <= 1'b0;

            // -----------------------------------------------------------------
            // FIX 1 – advance address AFTER a write completed last cycle.
            // 'we' is read here from the PREVIOUS cycle's assignment (registered).
            // This is the correct way to post-increment without off-by-one.
            // -----------------------------------------------------------------
            if (we == 1'b1) begin
                addr <= addr + 17'd1;
            end

            // -----------------------------------------------------------------
            // HREF LOW  ->  inter-line blanking period.
            // FIX 2 – reset byte_state here so every new line always starts
            // on Byte-1 regardless of whether the previous line had an even
            // or odd pixel count.  Without this, a single mis-alignment at the
            // end of any row would flip R↔B for every subsequent line.
            // -----------------------------------------------------------------
            if (href == 1'b0) begin
                byte_state <= 1'b0;

            end else begin
                // HREF HIGH  ->  we are inside an active pixel row

                if (byte_state == 1'b0) begin
                    // ----------------------------------------------------------
                    // BYTE 1  (high byte of RGB565)
                    // Layout: [R4 R3 R2 R1 R0 | G5 G4 G3]
                    // ----------------------------------------------------------
                    d_latch    <= d;      // Latch and wait for the second byte
                    byte_state <= 1'b1;

                end else begin
                    // ----------------------------------------------------------
                    // BYTE 2  (low byte of RGB565)
                    // Layout: [G2 G1 G0 | B4 B3 B2 B1 B0]
                    //
                    // RGB444 extraction for the Basys 3 VGA DAC:
                    //   RED   [11:8] = d_latch[7:4]         -> R4 R3 R2 R1
                    //   GREEN  [7:4] = {d_latch[2:0], d[7]} -> G5 G4 G3 G2
                    //   BLUE   [3:0] = d[4:1]               -> B4 B3 B2 B1
                    //
                    // Note: the least-significant red/green/blue bits (R0, G1,
                    // G0, B0) are discarded – this is expected for 4-bit output.
                    // ----------------------------------------------------------
                    dout <= { d_latch[7:4],          // RED   (4 bits)
                              d_latch[2:0], d[7],    // GREEN (4 bits)
                              d[4:1]         };      // BLUE  (4 bits)

                    we         <= 1'b1;   // Strobe write-enable for one PCLK
                    byte_state <= 1'b0;   // Ready for next pixel's Byte-1
                end
            end
        end
    end

endmodule
