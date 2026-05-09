module address_gen(
    input [9:0] x, y,
    output [16:0] addr
    );
    // Bit shift right (>> 1) effectively divides by 2
    // assign addr = (y >> 1) * 320 + (x >> 1);

    // If we are in the top-left 640x480 area, calculate address
    // We divide by 2 (>>1) to turn 640x480 screen space into 320x240 memory space
    assign addr = (x < 640 && y < 480) ? ((y >> 1) * 320 + (x >> 1)) : 17'd0;
endmodule