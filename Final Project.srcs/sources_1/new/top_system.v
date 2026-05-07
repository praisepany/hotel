module top_system(
    input clk_100mhz,
    input btnC,             // ปุ่ม Reset การตั้งค่ากล้อง
    // Camera Pins
    input [7:0] d,          // P17, N17, M19, M18, L17, K17, C16, B16
    input pclk,             // A16
    input vsync_cam,        // B15
    input href,             // A17
    output pwdn,            // R18
    output rst,             // P18
    output xclk,            // C15
    output scl,             // A14
    inout sda,              // A15
    // VGA Pins
    output hsync,           // J18
    output vsync_vga,       // L18
    output [3:0] vga_r,     // G19, H19, J19, N19
    output [3:0] vga_g,     // J17, H17, G17, D17
    output [3:0] vga_b,     // N18, L18, K18, J18 (เช็คพินใน xdc อีกรอบ)
    // Controls & Status
    input [1:0] sw,         // ใช้เลือก Filter
    output [0:0] led        // โชว์สถานะ Config เสร็จ
    );

    // --- 1. Basic Controller ---
    assign pwdn = 0;        // กล้องทำงานปกติ (ไม่เข้า Power down)
    assign rst = 1;         // ไม่ Reset กล้อง (ยกเว้นจะใช้สัญญาณจากวงจร reset)

    // --- 2. Connect internal wires ---
    wire clk_25, clk_24;
    wire [16:0] write_addr, read_addr;
    wire [11:0] pixel_to_ram, pixel_from_ram, processed_pixel;
    wire we, video_on, config_finished;
    wire [9:0] vga_x, vga_y;

    // --- 3. Clock Generation (IP Core) ---
    // สร้าง IP: Clocking Wizard ให้ชื่อ clk_viz
    clk_viz instance_name (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_25),  // 25 MHz สำหรับ VGA
        .clk_out2(clk_24)   // 24 MHz สำหรับ XCLK กล้อง
    );
    assign xclk = clk_24;

    // --- 4. Camera Initialization (SCCB) ---
    ov7670_init config_unit (
        .clk(clk_25),
        .reset(btnC),
        .scl(scl),
        .sda(sda),
        .config_finished(config_finished)
    );
    assign led[0] = config_finished;

    // --- 5. Camera Capture (รับภาพจากกล้อง) ---
    ov7670_capture cap (
        .pclk(pclk),
        .vsync(vsync_cam),
        .href(href),
        .d(d),
        .addr(write_addr),
        .dout(pixel_to_ram),
        .we(we)
    );

    // --- 6. Frame Buffer (BRAM IP Core) ---
    // สร้าง IP: Block Memory Generator (Simple Dual Port)
    blk_mem_gen_0 frame_buffer (
        .clka(pclk),           // เขียนด้วย Clock กล้อง
        .wea(we),
        .addra(write_addr),
        .dina(pixel_to_ram),
        .clkb(clk_25),         // อ่านด้วย Clock VGA
        .addrb(read_addr),
        .doutb(pixel_from_ram)
    );

    // --- 7. VGA Control & Pixel Doubling ---
    vga_controller vga (
        .clk_25mhz(clk_25),
        .hsync(hsync),
        .vsync(vsync_vga),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .video_on(video_on)
    );
    
    // Pixel Doubling: ขยาย 320x240 เป็น 640x480
    // (x/2) + (y/2)*320
    assign read_addr = (vga_x >> 1) + (vga_y >> 1) * 320;

    // --- 8. Image Processing (Filters) ---
    image_processor proc (
        .raw_pixel(pixel_from_ram),
        .filter_mode(sw),      // รับจาก Switch
        .processed_pixel(processed_pixel)
    );

    // ส่งสัญญาณออกขา VGA จริง
    assign {vga_r, vga_g, vga_b} = (video_on) ? processed_pixel : 12'h000;

endmodule