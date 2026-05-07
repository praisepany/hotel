`timescale 1ns / 1ps

module sccb (
    input wire clk_25mhz,      // 25 MHz system clock
    input wire reset,          // Active-high reset
    output wire sioc,          // CHANGED: Now a wire instead of a reg
    inout wire siod,           // SCCB Data pin (Must be bidirectional)
    output reg config_done     // Goes high when setup is complete
);

    // -----------------------------------------------------------------
    // 1. Clock Divider (25 MHz -> ~100 kHz for I2C)
    // -----------------------------------------------------------------
    reg [7:0] clk_div;
    reg i2c_tick;

    always @(posedge clk_25mhz) begin
        if (reset) begin
            clk_div <= 0;
            i2c_tick <= 0;
        end else begin
            if (clk_div == 8'd249) begin
                clk_div <= 0;
                i2c_tick <= ~i2c_tick;
            end else begin
                clk_div <= clk_div + 1;
            end
        end
    end

    // -----------------------------------------------------------------
    // 2. ROM Configuration Array (The "Magic" Registers)
    // -----------------------------------------------------------------
    parameter ROM_SIZE = 38;
    reg [15:0] rom [0:ROM_SIZE-1];

    initial begin
        // 1. Reset and Core Setup
        rom[0]  = 16'h12_80; rom[1]  = 16'h12_04; rom[2]  = 16'h40_D0;
        rom[3]  = 16'h8C_00; rom[4]  = 16'h11_00;
        // 2. Enable Scaling for QVGA (320x240)
        rom[5]  = 16'h0C_04; rom[6]  = 16'h3E_19; rom[7]  = 16'h70_3A;
        rom[8]  = 16'h71_35; rom[9]  = 16'h72_11; rom[10] = 16'h73_F0;
        rom[11] = 16'hA2_02;
        // 3. Hardware Windowing
        rom[12] = 16'h17_16; rom[13] = 16'h18_04; rom[14] = 16'h32_A4;
        rom[15] = 16'h19_02; rom[16] = 16'h1A_7A; rom[17] = 16'h03_0A;
        // 4. Test Pattern & Orientation
        rom[18] = 16'h71_35; rom[19] = 16'h1E_37;
        // 5. Color Matrix
        rom[20] = 16'h4F_80; rom[21] = 16'h50_80; rom[22] = 16'h51_00;
        rom[23] = 16'h52_22; rom[24] = 16'h53_5E; rom[25] = 16'h54_80;
        rom[26] = 16'h56_40;
        // 6. AWB & Exposure
        rom[27] = 16'h13_E5; rom[28] = 16'h00_00; rom[29] = 16'h01_00;
        rom[30] = 16'h02_00; rom[31] = 16'h10_00; rom[32] = 16'h41_08;
        rom[33] = 16'hB0_84;
        // 7. Gamma Curve
        rom[34] = 16'h7A_20; rom[35] = 16'h7B_10; rom[36] = 16'h7C_1E;
        rom[37] = 16'h7D_35;
    end

    // -----------------------------------------------------------------
    // 3. I2C State Machine
    // -----------------------------------------------------------------
    parameter
        IDLE      = 0, START     = 1, SEND_ID   = 2, ACK1      = 3,
        SEND_REG  = 4, ACK2      = 5, SEND_DATA = 6, ACK3      = 7,
        STOP      = 8, DELAY     = 9;

    reg [3:0] state;
    reg [7:0] reg_index;
    reg [15:0] current_cmd;
    reg [7:0] tx_data;
    reg [3:0] bit_count;
    reg [15:0] delay_count;

    reg siod_out;
    reg siod_oe;

    // Open-Drain wiring for Data
    assign siod = (siod_oe && siod_out == 1'b0) ? 1'b0 : 1'bz;

    // CHANGED: Combinational Clock Generation (Fixes the MDRV-1 error)
    // Clock is held high during IDLE, START, and STOP.
    // During data transmission, it goes low when i2c_tick is high so data can safely change.
    assign sioc = (state == SEND_ID || state == SEND_REG || state == SEND_DATA ||
                   state == ACK1 || state == ACK2 || state == ACK3) ? ~i2c_tick : 1'b1;

    always @(posedge i2c_tick or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            reg_index <= 0;
            config_done <= 0;
            siod_out <= 1'b1;
            siod_oe <= 1'b1;
        end else begin
            case(state)
                IDLE: begin
                    siod_out <= 1'b1;
                    siod_oe <= 1'b1;
                    if (reg_index < ROM_SIZE) begin
                        current_cmd <= rom[reg_index];
                        state <= START;
                    end else begin
                        config_done <= 1'b1;
                    end
                end

                START: begin
                    siod_out <= 1'b0;
                    tx_data <= 8'h42;
                    bit_count <= 0;
                    state <= SEND_ID;
                end

                SEND_ID: begin
                    siod_out <= tx_data[7];
                    tx_data <= {tx_data[6:0], 1'b0};
                    if (bit_count == 7) state <= ACK1;
                    else bit_count <= bit_count + 1;
                end

                ACK1: begin
                    siod_oe <= 1'b0;
                    state <= SEND_REG;
                    tx_data <= current_cmd[15:8];
                    bit_count <= 0;
                end

                SEND_REG: begin
                    siod_oe <= 1'b1;
                    siod_out <= tx_data[7];
                    tx_data <= {tx_data[6:0], 1'b0};
                    if (bit_count == 7) state <= ACK2;
                    else bit_count <= bit_count + 1;
                end

                ACK2: begin
                    siod_oe <= 1'b0;
                    state <= SEND_DATA;
                    tx_data <= current_cmd[7:0];
                    bit_count <= 0;
                end

                SEND_DATA: begin
                    siod_oe <= 1'b1;
                    siod_out <= tx_data[7];
                    tx_data <= {tx_data[6:0], 1'b0};
                    if (bit_count == 7) state <= ACK3;
                    else bit_count <= bit_count + 1;
                end

                ACK3: begin
                    siod_oe <= 1'b0;
                    state <= STOP;
                end

                STOP: begin
                    siod_oe <= 1'b1;
                    siod_out <= 1'b0;

                    if (current_cmd[15:8] == 8'h12 && current_cmd[7:0] == 8'h80) begin
                        delay_count <= 0;
                        state <= DELAY;
                    end else begin
                        reg_index <= reg_index + 1;
                        state <= IDLE;
                    end
                end

                DELAY: begin
                    if (delay_count == 16'hFFFF) begin
                        reg_index <= reg_index + 1;
                        state <= IDLE;
                    end else begin
                        delay_count <= delay_count + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
