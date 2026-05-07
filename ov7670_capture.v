module ov7670_capture(
    input pclk, vsync, href,
    input [7:0] d,
    output reg [16:0] addr,
    output reg [11:0] dout,
    output reg we
    );

    reg [15:0] temp;
    reg cycle = 0;

    always @(posedge pclk) begin
        if (vsync) begin
            addr <= 0;
            cycle <= 0;
        end else if (href) begin
            temp <= {temp[7:0], d};
            if (cycle) begin
                // Convert RGB565 to RGB444
                dout <= {temp[15:12], temp[10:7], temp[4:1]};
                we <= 1;
                addr <= addr + 1;
            end else we <= 0;
            cycle <= ~cycle;
        end else we <= 0;
    end
endmodule