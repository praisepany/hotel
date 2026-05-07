module ov7670_init(
    input clk,
    input reset,
    output scl,
    inout sda,
    output reg config_finished
    );

    reg [15:0] rom_data;
    reg [7:0] rom_addr = 0;
    wire ready, done;
    reg start = 0;

    // เรียกใช้ Controller ที่เขียนไว้ด้านบน
    sccb_controller sccb (
        .clk(clk), .id_data(rom_data), .start(start),
        .done(done), .scl(scl), .sda(sda), .ready(ready)
    );

    // รายการ Register (ตัวอย่างสำคัญ)
    always @(*) begin
        case(rom_addr)
            0: rom_data = 16'h1280; // COM7: Reset กล้อง
            1: rom_data = 16'h1204; // COM7: ตั้งค่าเป็น RGB
            2: rom_data = 16'h40D0; // COM15: RGB565, 0-255 range
            3: rom_data = 16'h0C00; // COM3: Normal Output
            4: rom_data = 16'h3E00; // COM14: Scaling ON
            // ... เพิ่มรายการตั้งค่า 320x240 ที่นี่ ...
            default: rom_data = 16'hFFFF;
        endcase
    end

    // State Machine สำหรับส่งทีละคำสั่ง
    always @(posedge clk) begin
        if (reset) begin
            rom_addr <= 0;
            config_finished <= 0;
        end else if (!config_finished) begin
            if (ready && !start) begin
                start <= 1;
            end else if (done) begin
                start <= 0;
                if (rom_data == 16'hFFFF) config_finished <= 1;
                else rom_addr <= rom_addr + 1;
            end
        end
    end
endmodule