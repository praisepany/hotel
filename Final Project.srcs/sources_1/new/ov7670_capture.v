module ov7670_capture(
    input pclk,
    input vsync,
    input href,
    input [7:0] d,
    output reg [16:0] addr,    // 320x240 = 76800 addresses
    output reg [11:0] dout,   // แปลงเป็น 12-bit (444) สำหรับ Basys 3
    output reg we
    );

    reg [15:0] temp_pixel;
    reg pixel_half;

    always @(posedge pclk) begin
        if (vsync) begin
            addr <= 0;
            pixel_half <= 0;
        end else if (href) begin
            if (pixel_half == 0) begin
                temp_pixel[15:8] <= d;
                pixel_half <= 1;
                we <= 0;
            end else begin
                // แปลง RGB565 เป็น RGB444 เพื่อลง BRAM และแสดงผลบน Basys 3
                dout <= {temp_pixel[15:12], temp_pixel[10:7], d[4:1]};
                addr <= addr + 1;
                we <= 1;
                pixel_half <= 0;
            end
        end else begin
            we <= 0;
        end
    end
endmodule