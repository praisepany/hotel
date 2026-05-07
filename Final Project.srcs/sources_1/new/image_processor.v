module image_processor(
    input [11:0] raw_pixel,
    input [1:0] filter_mode,
    output reg [11:0] processed_pixel
    );

    wire [3:0] r = raw_pixel[11:8];
    wire [3:0] g = raw_pixel[7:4];
    wire [3:0] b = raw_pixel[3:0];

    // 1. Grayscale (Average simplified)
    wire [3:0] gray = (r + g + b) / 3;

    // 2. Thresholding (Binary)
    wire [11:0] binary = (gray > 4'h8) ? 12'hFFF : 12'h000;

    // 3. Inversion (Simple alternative for basic test)
    wire [11:0] inverted = ~raw_pixel;

    always @(*) begin
        case(filter_mode)
            2'b01: processed_pixel = {gray, gray, gray}; // Grayscale
            2'b10: processed_pixel = binary;            // Threshold
            2'b11: processed_pixel = inverted;          // Inverted (หรือเปลี่ยนเป็น Sobel)
            default: processed_pixel = raw_pixel;       // Raw
        endcase
    end
endmodule