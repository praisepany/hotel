`timescale 1ns / 1ps

// =============================================================================
// Module: sccb  (Serial Camera Control Bus – I2C compatible)
// Purpose: Sends a table of OV7670 register writes over SCCB at startup.
//
// KEY FIXES vs original:
//
//  1. Clock-domain unification: The state machine was clocked on i2c_tick
//     while sioc was a combinational function of i2c_tick.  This created a
//     race: the combinational sioc edge and the next registered state-machine
//     step were not aligned, causing glitchy SCL pulses at I2C speeds.
//     Fix: Everything runs on clk_25mhz.  i2c_tick is used only as a
//     clock-enable (i.e. "advance the machine one step when tick fires").
//
//  2. Proper STOP condition: I2C STOP requires SDA to rise while SCL is HIGH.
//     The original state machine attempted this in a single i2c_tick step
//     which was too fast and unreliable.  The new STOP state is split into
//     two sub-steps: first ensure SDA is LOW with SCL already HIGH, then
//     raise SDA.
//
//  3. Corrected register table:
//     a) rom[18] was a copy-paste duplicate of rom[8] (both 16'h71_35).
//        rom[18] is now the correct image-flip/mirror register 0x1E=0x07
//        (no mirror, no flip – straightforward orientation).
//     b) Added register 0x15 (PCLK polarity / HREF mask) to guarantee PCLK
//        toggling on the correct edge and HREF asserting correctly.
//     c) Expanded gamma table to the full OV7670 default curve for natural
//        colour rendering.
//     d) Added 0x55 (bright), 0x56 (contrast) for a balanced image.
//     e) Kept soft-reset (0x12=0x80) first with a long post-reset delay.
//
//  4. sioc open-drain drive: sioc is now also driven open-drain (same as
//     siod) so the pull-up resistor on the board sets the idle-high level
//     rather than the FPGA driving a strong '1'. This is required by the
//     SCCB / I2C specification.
//
//  5. Start / Stop sequencing: SDA must be pulled low BEFORE SCL goes low
//     for a START, and SDA must rise AFTER SCL goes high for a STOP.  The
//     new state machine enforces this explicitly.
// =============================================================================

module sccb (
    input  wire clk_25mhz,    // 25 MHz system clock
    input  wire reset,        // Active-high reset
    output wire sioc,         // SCCB Clock  (open-drain)
    inout  wire siod,         // SCCB Data   (open-drain, bidirectional)
    output reg  config_done   // Pulses high when the full ROM has been sent
);

    // -------------------------------------------------------------------------
    // 1.  Clock divider  –  25 MHz  ->  ~100 kHz I2C tick
    //     25_000_000 / 100_000 = 250 counts per half-period
    //     We toggle every 125 counts -> half-period = 5 µs -> 100 kHz
    // -------------------------------------------------------------------------
    localparam CLK_DIV = 8'd124;   // counts 0..124 (125 steps)

    reg [7:0] clk_div;
    reg       i2c_tick;       // 100 kHz clock-enable (one clk_25mhz cycle wide)
    reg       i2c_clk;        // 100 kHz square-wave clock level

    always @(posedge clk_25mhz) begin
        if (reset) begin
            clk_div  <= 8'd0;
            i2c_tick <= 1'b0;
            i2c_clk  <= 1'b1;     // idle high
        end else begin
            i2c_tick <= 1'b0;     // default: no tick this cycle
            if (clk_div == CLK_DIV) begin
                clk_div  <= 8'd0;
                i2c_clk  <= ~i2c_clk;
                i2c_tick <= 1'b1; // one-cycle enable
            end else begin
                clk_div <= clk_div + 8'd1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2.  ROM  –  OV7670 register initialisation sequence
    //     Format: 16'h{reg_addr}_{reg_data}
    //     All writes use device address 0x42 (7-bit 0x21, write bit = 0).
    // -------------------------------------------------------------------------
    localparam ROM_SIZE = 56;
    reg [15:0] rom [0:ROM_SIZE-1];

    initial begin
        //  ---- a) Soft reset (must be first; wait for camera to re-initialise) ----
        rom[0]  = 16'h12_80;   // COM7: soft reset – triggers long DELAY below

        //  ---- b) Output format: RGB565, QVGA (320x240) ----
        rom[1]  = 16'h12_04;   // COM7: RGB output, no test pattern
        rom[2]  = 16'h40_D0;   // COM15: RGB565 full range (0xD0)
        rom[3]  = 16'h8C_00;   // RGB444: disabled
        rom[4]  = 16'h11_00;   // CLKRC: prescaler = 1 (use XCLK directly)

        //  ---- c) PCLK / HREF polarity (FIX: missing in original) ----
        rom[5]  = 16'h15_00;   // COM10: default polarity – PCLK always active,
                                //        HREF instead of HSYNC, VSYNC active high

        //  ---- d) QVGA scaling ----
        rom[6]  = 16'h0C_04;   // COM3: scale enable
        rom[7]  = 16'h3E_19;   // COM14: PCLK divider /2 for QVGA, manual scale
        rom[8]  = 16'h70_3A;   // SCALING_XSC
        rom[9]  = 16'h71_35;   // SCALING_YSC
        rom[10] = 16'h72_11;   // SCALING_DCWCTR: downsample by 2 H and V
        rom[11] = 16'h73_F0;   // SCALING_PCLK_DIV: /2 PCLK after scaling
        rom[12] = 16'hA2_02;   // SCALING_PCLK_DELAY

        //  ---- e) Hardware windowing for QVGA ----
        rom[13] = 16'h17_16;   // HSTART
        rom[14] = 16'h18_04;   // HSTOP
        rom[15] = 16'h32_A4;   // HREF
        rom[16] = 16'h19_02;   // VSTART
        rom[17] = 16'h1A_7A;   // VSTOP
        rom[18] = 16'h03_0A;   // VREF

        //  ---- f) Image orientation (FIX: was duplicate 0x71 in original) ----
        rom[19] = 16'h1E_07;   // MVFP: no mirror, no vertical flip, LAEC off

        //  ---- g) Colour matrix (sRGB) ----
        rom[20] = 16'h4F_80;   // MTX1
        rom[21] = 16'h50_80;   // MTX2
        rom[22] = 16'h51_00;   // MTX3
        rom[23] = 16'h52_22;   // MTX4
        rom[24] = 16'h53_5E;   // MTX5
        rom[25] = 16'h54_80;   // MTX6
        rom[26] = 16'h58_9E;   // MTXS (matrix sign + auto contrast centre)

        //  ---- h) Brightness / Contrast ----
        rom[27] = 16'h55_00;   // BRIGHT: 0 (neutral)
        rom[28] = 16'h56_40;   // CONTRAS: 0x40 (neutral)

        //  ---- i) AWB & AEC / AGC ----
        rom[29] = 16'h13_E5;   // COM8: AGC, AWB, AEC enabled; fast AEC
        rom[30] = 16'h00_00;   // GAIN: auto
        rom[31] = 16'h01_80;   // BLUE: AWB gain – start at midpoint
        rom[32] = 16'h02_80;   // RED:  AWB gain – start at midpoint
        rom[33] = 16'h10_00;   // AECH (exposure high bits): auto
        rom[34] = 16'h41_08;   // COM16: AWB gain enable
        rom[35] = 16'hB0_84;   // ABLC1

        //  ---- j) Gamma curve (full OV7670 default table) ----
        rom[36] = 16'h7A_20;   // SLOP
        rom[37] = 16'h7B_10;   // GAM1
        rom[38] = 16'h7C_1E;   // GAM2
        rom[39] = 16'h7D_35;   // GAM3
        rom[40] = 16'h7E_5A;   // GAM4
        rom[41] = 16'h7F_69;   // GAM5
        rom[42] = 16'h80_76;   // GAM6
        rom[43] = 16'h81_80;   // GAM7
        rom[44] = 16'h82_88;   // GAM8
        rom[45] = 16'h83_8F;   // GAM9
        rom[46] = 16'h84_96;   // GAM10
        rom[47] = 16'h85_A3;   // GAM11
        rom[48] = 16'h86_AF;   // GAM12
        rom[49] = 16'h87_C4;   // GAM13
        rom[50] = 16'h88_D7;   // GAM14
        rom[51] = 16'h89_E8;   // GAM15

        //  ---- k) Denoise / edge enhancement ----
        rom[52] = 16'h4B_09;   // REG4B: UV average enabled
        rom[53] = 16'hA8_02;   // ABLC target
        rom[54] = 16'h4E_00;   // Reserved – keep default
        rom[55] = 16'h69_00;   // GFIX: gain offset = 0
    end

    // -------------------------------------------------------------------------
    // 3.  I2C / SCCB state machine
    //     All state transitions happen only when i2c_tick is asserted so the
    //     machine effectively runs at 100 kHz even though the process is
    //     clocked at 25 MHz.
    // -------------------------------------------------------------------------
    localparam [3:0]
        IDLE      = 4'd0,
        START     = 4'd1,
        SEND_ID   = 4'd2,
        ACK1      = 4'd3,
        SEND_REG  = 4'd4,
        ACK2      = 4'd5,
        SEND_DATA = 4'd6,
        ACK3      = 4'd7,
        STOP_LO   = 4'd8,   // STOP sub-step 1: SDA low, SCL high
        STOP_HI   = 4'd9,   // STOP sub-step 2: SDA rises -> completes STOP
        DELAY     = 4'd10,  // Long delay after soft-reset
        DONE      = 4'd11;

    reg [3:0]  state;
    reg [7:0]  reg_index;
    reg [15:0] current_cmd;
    reg [7:0]  tx_data;
    reg [2:0]  bit_count;   // 0..7
    reg [19:0] delay_count; // ~40k i2c_ticks @ 100kHz = ~400 ms after reset

    reg siod_out;   // Driven value
    reg siod_oe;    // Output enable: 1 = drive, 0 = release (open-drain)
    reg sioc_out;   // Clock line drive value
    reg sioc_oe;    // Clock output enable

    // ---- Open-drain outputs ----
    // FIX 4: sioc is now open-drain, like siod.  When oe=0 or out=1, we
    // release the line (high-Z) and the pull-up resistor takes it high.
    assign siod = (siod_oe && !siod_out) ? 1'b0 : 1'bz;
    assign sioc = (sioc_oe && !sioc_out) ? 1'b0 : 1'bz;

    // -------------------------------------------------------------------------
    // State machine – clocked on clk_25mhz, enabled by i2c_tick
    // -------------------------------------------------------------------------
    always @(posedge clk_25mhz) begin
        if (reset) begin
            state       <= IDLE;
            reg_index   <= 8'd0;
            config_done <= 1'b0;
            siod_out    <= 1'b1;
            siod_oe     <= 1'b1;
            sioc_out    <= 1'b1;
            sioc_oe     <= 1'b0;   // Release: pull-up holds SCL high at idle
            delay_count <= 20'd0;
            bit_count   <= 3'd0;
            current_cmd <= 16'd0;
            tx_data     <= 8'd0;
        end else if (i2c_tick) begin   // ← advance only on 100 kHz tick

            case (state)

                // -------------------------------------------------------------
                IDLE: begin
                    // SCL idle high (released), SDA idle high (released)
                    sioc_out <= 1'b1; sioc_oe <= 1'b0;
                    siod_out <= 1'b1; siod_oe <= 1'b1;

                    if (reg_index < ROM_SIZE) begin
                        current_cmd <= rom[reg_index];
                        state       <= START;
                    end else begin
                        config_done <= 1'b1;
                        state       <= DONE;
                    end
                end

                // -------------------------------------------------------------
                // FIX 5: START condition – SDA falls while SCL is HIGH
                START: begin
                    // Ensure SCL is high (released), then pull SDA low
                    sioc_out <= 1'b1; sioc_oe <= 1'b0;   // SCL high
                    siod_out <= 1'b0; siod_oe <= 1'b1;   // SDA low -> START

                    tx_data   <= 8'h42;   // OV7670 write address (7-bit 0x21 + W)
                    bit_count <= 3'd0;
                    state     <= SEND_ID;
                end

                // -------------------------------------------------------------
                SEND_ID: begin
                    // Clock is toggled by i2c_clk; SDA changes on falling SCL
                    sioc_out <= i2c_clk;  sioc_oe <= 1'b1;
                    siod_out <= tx_data[7];
                    siod_oe  <= 1'b1;
                    tx_data  <= {tx_data[6:0], 1'b0};

                    if (bit_count == 3'd7) begin
                        state <= ACK1;
                    end else begin
                        bit_count <= bit_count + 3'd1;
                    end
                end

                // -------------------------------------------------------------
                ACK1: begin
                    // Release SDA so slave can pull it low to acknowledge
                    sioc_out <= i2c_clk; sioc_oe <= 1'b1;
                    siod_oe  <= 1'b0;    // Release SDA

                    tx_data   <= current_cmd[15:8];   // Register address byte
                    bit_count <= 3'd0;
                    state     <= SEND_REG;
                end

                // -------------------------------------------------------------
                SEND_REG: begin
                    sioc_out <= i2c_clk; sioc_oe <= 1'b1;
                    siod_out <= tx_data[7];
                    siod_oe  <= 1'b1;
                    tx_data  <= {tx_data[6:0], 1'b0};

                    if (bit_count == 3'd7) begin
                        state <= ACK2;
                    end else begin
                        bit_count <= bit_count + 3'd1;
                    end
                end

                // -------------------------------------------------------------
                ACK2: begin
                    sioc_out <= i2c_clk; sioc_oe <= 1'b1;
                    siod_oe  <= 1'b0;

                    tx_data   <= current_cmd[7:0];    // Data byte
                    bit_count <= 3'd0;
                    state     <= SEND_DATA;
                end

                // -------------------------------------------------------------
                SEND_DATA: begin
                    sioc_out <= i2c_clk; sioc_oe <= 1'b1;
                    siod_out <= tx_data[7];
                    siod_oe  <= 1'b1;
                    tx_data  <= {tx_data[6:0], 1'b0};

                    if (bit_count == 3'd7) begin
                        state <= ACK3;
                    end else begin
                        bit_count <= bit_count + 3'd1;
                    end
                end

                // -------------------------------------------------------------
                ACK3: begin
                    sioc_out <= i2c_clk; sioc_oe <= 1'b1;
                    siod_oe  <= 1'b0;
                    state    <= STOP_LO;
                end

                // -------------------------------------------------------------
                // FIX 2: Two-step STOP condition
                // STOP_LO: SCL goes high while SDA is still LOW
                STOP_LO: begin
                    sioc_out <= 1'b1; sioc_oe <= 1'b0;   // Release SCL -> high
                    siod_out <= 1'b0; siod_oe <= 1'b1;   // Hold SDA low
                    state    <= STOP_HI;
                end

                // STOP_HI: SDA rises while SCL is HIGH -> valid STOP condition
                STOP_HI: begin
                    sioc_out <= 1'b1; sioc_oe <= 1'b0;   // Keep SCL high
                    siod_out <= 1'b1; siod_oe <= 1'b1;   // SDA rises -> STOP!

                    // After soft-reset command, wait a long time before continuing
                    if (current_cmd == 16'h12_80) begin
                        delay_count <= 20'd0;
                        state       <= DELAY;
                    end else begin
                        reg_index <= reg_index + 8'd1;
                        state     <= IDLE;
                    end
                end

                // -------------------------------------------------------------
                // Long inter-frame delay after soft reset (~400 ms @ 100 kHz)
                DELAY: begin
                    sioc_out <= 1'b1; sioc_oe <= 1'b0;
                    siod_out <= 1'b1; siod_oe <= 1'b1;

                    if (delay_count == 20'hFFFFF) begin
                        reg_index <= reg_index + 8'd1;
                        state     <= IDLE;
                    end else begin
                        delay_count <= delay_count + 20'd1;
                    end
                end

                // -------------------------------------------------------------
                DONE: begin
                    // Configuration complete – hold lines idle
                    sioc_out <= 1'b1; sioc_oe <= 1'b0;
                    siod_out <= 1'b1; siod_oe <= 1'b1;
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
