module ov7670_registers(
    input [7:0] index,
    output reg [15:0] command
    );
    always @(*) begin
        case(index)
            8'h00: command = 16'h1280; // Reset
            8'h01: command = 16'h1204; // QVGA, RGB
            8'h02: command = 16'h40D0; // RGB565
            8'h03: command = 16'h1101; // Prescaler
            8'h04: command = 16'h0C00; // COM3: default
            8'h05: command = 16'h3E00; // COM14: no scaling
            default: command = 16'hFFFF;
        endcase
    end
endmodule