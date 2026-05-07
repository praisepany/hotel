module address_gen(
    input [9:0] x, y,
    output [16:0] addr
    );
    // Bit shift right (>> 1) effectively divides by 2
    assign addr = (y >> 1) * 320 + (x >> 1);
endmodule