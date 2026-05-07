module vga_sync(
    input clk,
    output reg h_sync, v_sync,
    output video_on,
    output [9:0] x, y
    );

    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    localparam HD = 640, HF = 16, HR = 96, HB = 48;
    localparam VD = 480, VF = 10, VR = 2, VB = 33;

    always @(posedge clk) begin
        if (h_count == HD + HF + HR + HB - 1) begin
            h_count <= 0;
            if (v_count == VD + VF + VR + VB - 1) v_count <= 0;
            else v_count <= v_count + 1;
        end else h_count <= h_count + 1;
    end

    assign video_on = (h_count < HD) && (v_count < VD);
    assign x = h_count;
    assign y = v_count;
    
    always @(*) h_sync = ~(h_count >= (HD+HF) && h_count < (HD+HF+HR));
    always @(*) v_sync = ~(v_count >= (VD+VF) && v_count < (VD+VF+VR));
endmodule