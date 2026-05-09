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
           if (cycle == 0) begin
            // First byte (High Byte: RRRRRGGG)
            temp[15:8] <= d;
            we <= 0;
            cycle <= 1;
            end else begin
                // Second byte (Low Byte: GGGBBBBB)
                // Combine the 'temp' we just stored with the current 'd'
                dout <= {temp[15:12], d[7:4], d[3:0]}; 
                we <= 1;
                addr <= addr + 1;
                cycle <= 0;
            end
        end else begin
            cycle <= 0;
            we <= 0;
        end;
    end
endmodule