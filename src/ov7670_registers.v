module ov7670_registers(
    input [7:0] index,
    output reg [15:0] command
    );
    // always @(*) begin
    //     case(index)
    //         8'h00: command = 16'h1280; // Reset
    //         8'h01: command = 16'h1204; // QVGA, RGB
    //         8'h02: command = 16'h40D0; // RGB565
    //         8'h03: command = 16'h1101; // Prescaler
    //         8'h04: command = 16'h0C00; // COM3: default
    //         8'h05: command = 16'h3E00; // COM14: no scaling
    //         default: command = 16'hFFFF;
    //     endcase
    // end

    always @(*) begin
        case(index)
            // Initial Reset
            8'h00: command = 16'h1280; // COM7: Reset all registers

            // Delay / Setup (Allowing reset to settle)
            8'h01: command = 16'h1280; 
            8'h02: command = 16'h1204; // COM7: QVGA, RGB mode

            // Color Format Settings
            8'h03: command = 16'h40D0; // COM15: RGB565, Full Range [0-255]
            8'h04: command = 16'h1101; // CLKRC: Internal Clock Prescaler

            // Hardware Windowing (Helps with the "Overlay/Ghosting" issue)
            8'h05: command = 16'h1713; // HSTART
            8'h06: command = 16'h1801; // HSTOP
            8'h07: command = 16'h32B6; // HREF Control
            8'h08: command = 16'h1902; // VSTART
            8'h09: command = 16'h1A7A; // VSTOP
            8'h0A: command = 16'h030A; // VREF

            // Clock and Scaling
            8'h0B: command = 16'h0C00; // COM3: Normal operation
            8'h0C: command = 16'h3E00; // COM14: Scaling disabled

            // Color Matrix (Crucial to prevent Red saturation)
            8'h0D: command = 16'h4F80; // MTX1
            8'h0E: command = 16'h5080; // MTX2
            8'h0F: command = 16'h5400; // MTX6 (Brightness/Contrast balance)

            default: command = 16'hFFFF;
        endcase
    end

endmodule