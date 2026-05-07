`timescale 1ns / 1ps

module cameracontroll (
    input wire pclk,          // Pixel clock from the camera
    input wire vsync,         // Vertical sync from the camera
    input wire href,          // Horizontal reference from the camera
    input wire [7:0] d,       // 8-bit data bus from the camera

    output reg [16:0] addr,   // BRAM write address (17 bits covers up to 320x240)
    output reg [11:0] dout,   // 12-bit pixel data for BRAM (Basys 3 DAC format)
    output reg we             // Write enable for BRAM
);

    reg [7:0] d_latch;        // Register to hold the first byte
    reg byte_state;           // State tracker: 0 = First byte, 1 = Second byte

    // Initialization
    initial begin
        addr = 17'd0;
        dout = 12'd0;
        we = 1'b0;
        d_latch = 8'd0;
        byte_state = 1'b0;
    end

    // All logic is driven by the camera's Pixel Clock (PCLK)
    always @(posedge pclk) begin

        // VSYNC signals a new frame is starting.
        // We reset the address to 0 so we start drawing at the top-left corner.
        if (vsync == 1'b1) begin
            addr <= 17'd0;
            byte_state <= 1'b0;
            we <= 1'b0;
        end else begin
            // Default write enable to 0
            we <= 1'b0;

            // If a write occurred in the previous cycle, move to the next memory address
            if (we == 1'b1) begin
                addr <= addr + 1;
            end

            // Only capture data when HREF is high (we are in an active video row)
            if (href == 1'b1) begin
                if (byte_state == 1'b0) begin
                    // ---- BYTE 1 (High Byte) ----
                    d_latch <= d;       // Save the first byte
                    byte_state <= 1'b1; // Move to next state
                end else begin
                    // ---- BYTE 2 (Low Byte) ----
                    // The camera sends RGB565:
                    // Byte 1: {R4, R3, R2, R1, R0, G5, G4, G3}
                    // Byte 2: {G2, G1, G0, B4, B3, B2, B1, B0}
                    //
                    // We extract the top 4 bits of each color for the 12-bit Basys 3 DAC:
                    // RED:   d_latch[7:4]
                    // GREEN: {d_latch[2:0], d[7]}
                    // BLUE:  d[4:1]

                    dout <= {d_latch[7:4], d_latch[2:0], d[7], d[4:1]};

                    we <= 1'b1;         // Trigger BRAM to save this pixel
                    byte_state <= 1'b0; // Reset state for the next pixel
                end
            end
        end
    end

endmodule
