module vga_controller(
    input clk_25mhz,
    output hsync,
    output vsync,
    output [9:0] vga_x,
    output [9:0] vga_y,
    output video_on
    );

    reg [9:0] h_cnt = 0;
    reg [9:0] v_cnt = 0;

    // VGA 640x480 @ 60Hz timings
    always @(posedge clk_25mhz) begin
        if (h_cnt == 799) begin
            h_cnt <= 0;
            if (v_cnt == 524) v_cnt <= 0;
            else v_cnt <= v_cnt + 1;
        end else h_cnt <= h_cnt + 1;
    end

    assign hsync = (h_cnt >= 656 && h_cnt < 752) ? 0 : 1;
    assign vsync = (v_cnt >= 490 && v_cnt < 492) ? 0 : 1;
    assign video_on = (h_cnt < 640 && v_cnt < 480);
    assign vga_x = h_cnt;
    assign vga_y = v_cnt;
endmodule