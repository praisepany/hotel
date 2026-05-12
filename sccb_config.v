/*
module sccb_config(
    input clk,            // Master Clock (เช่น 25MHz)
    output sioc,          // SIO_C (Clock)
    inout siod            // SIO_D (Data)
);
    // ---------------------------------------------------------
    // 1. Clock Divider: สร้าง Base Clock (~400 kHz)
    // สำหรับ 4-phase state machine เพื่อสร้าง SCCB Clock ที่ ~100 kHz
    // ---------------------------------------------------------
    reg [7:0] clk_div = 0;
    reg i2c_clk = 0;
    always @(posedge clk) begin
        if (clk_div == 31) begin // 25MHz / (32 * 2) = ~390 kHz
            clk_div <= 0;
            i2c_clk <= ~i2c_clk;
        end else begin
            clk_div <= clk_div + 1;
        end
    end

    // ---------------------------------------------------------
    // 2. Register ROM: ตารางเก็บค่าตั้งค่ากล้อง
    // ---------------------------------------------------------
    reg [7:0] reg_idx = 0;
    reg [15:0] reg_data;        // [15:8] = Sub-address, [7:0] = Write Data
    wire [7:0] TOTAL_REGS = 8; // [FIXED] กลับไปใช้ 8 คำสั่งพื้นฐานที่เสถียรที่สุด

    always @(*) begin
        case(reg_idx)
            0: reg_data = 16'h1280; // COM7: RESET
            1: reg_data = 16'h1101; // CLKRC: Enable clock prescaler
            2: reg_data = 16'h6B4A; // DBLV: Stabilize PLL clock
            3: reg_data = 16'h1204; // COM7: RGB Mode
            4: reg_data = 16'h8C00; // RGB444: Disable
            5: reg_data = 16'h40D0; // COM15: RGB565 Full range
            6: reg_data = 16'h3A04; // TSLB
            7: reg_data = 16'hB084; // Magic Register
            default: reg_data = 16'hFFFF;
        endcase
    end

    // ---------------------------------------------------------
    // 3. SCCB State Machine (4-Phase ป้องกัน Race Condition)
    // ---------------------------------------------------------
    reg [3:0] state = 0;
    reg [5:0] bit_cnt = 0;
    reg [23:0] shift_reg = 0;   // เก็บ {ID Address, Sub-address, Write Data}
    reg sioc_reg = 1;
    reg siod_reg = 1;
    reg siod_out_en = 1;        // 1 = FPGA ขับสัญญาณ, 0 = High-Z (ช่วง Don't-Care bit)
    reg [9:0] delay_cnt = 0;    // 10-bit สำหรับนับ 400

    wire [7:0] ID_ADDR = 8'h42; // ID Address ของกล้อง (บิตที่ 0 เป็น 0 = Write)

    assign sioc = sioc_reg;
    // ป้องกันการชนกันของสัญญาณ (Bus Contention) ด้วย Open-Drain
    assign siod = (siod_out_en && siod_reg == 1'b0) ? 1'b0 : 1'bz;

    always @(posedge i2c_clk) begin
        case (state)
            0: begin // IDLE: เตรียมข้อมูล
                if (reg_idx < TOTAL_REGS) begin
                    // รอ 1ms หลังจากสั่ง Reset กล้อง (คำสั่งที่ 0)
                    // i2c_clk ~400kHz (2.5us), ดังนั้น 1ms = 400 cycles
                    if (reg_idx == 1 && delay_cnt < 400) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        shift_reg <= {ID_ADDR, reg_data[15:8], reg_data[7:0]};
                        siod_out_en <= 1;
                        sioc_reg <= 1;
                        siod_reg <= 1;
                        state <= 1;
                    end
                end
            end

            1: begin // START Condition (SIO_D ลง 0 ขณะที่ SIO_C เป็น 1)
                siod_reg <= 0;
                bit_cnt <= 23;
                state <= 2;
            end

            // --- 4-Phase Send Bit ---
            2: begin // Phase 0: ดึง Clock ลง LOW
                sioc_reg <= 0;
                state <= 3;
            end

            3: begin // Phase 1: เปลี่ยนข้อมูล (ขณะ Clock เป็น LOW ปลอดภัย)
                siod_reg <= shift_reg[bit_cnt];
                state <= 4;
            end

            4: begin // Phase 2: ดึง Clock ขึ้น HIGH
                sioc_reg <= 1;
                state <= 5;
            end

            5: begin // Phase 3: ค้าง Clock เป็น HIGH ให้ Slave อ่าน
                if (bit_cnt == 16 || bit_cnt == 8 || bit_cnt == 0) begin
                    state <= 6; // ส่งครบ 8 บิต ไป Don't Care
                end else begin
                    bit_cnt <= bit_cnt - 1;
                    state <= 2; // ส่งบิตต่อไป
                end
            end

            // --- 4-Phase Don't Care Bit ---
            6: begin // Phase 0: ดึง Clock ลง LOW
                sioc_reg <= 0;
                state <= 7;
            end

            7: begin // Phase 1: ปล่อยสายเป็น High-Z ให้ Slave ตอบ ACK
                siod_out_en <= 0;
                state <= 8;
            end

            8: begin // Phase 2: ดึง Clock ขึ้น HIGH
                sioc_reg <= 1;
                state <= 9;
            end

            9: begin // Phase 3: ค้าง Clock เป็น HIGH
                if (bit_cnt == 0) begin
                    state <= 10; // จบ Phase 3 แล้ว เตรียม STOP
                end else begin
                    bit_cnt <= bit_cnt - 1;
                    state <= 13; // กลับไปส่งข้อมูลต่อ
                end
            end

            13: begin // ดึง Clock ลง LOW ก่อน
                sioc_reg <= 0;
                state <= 14;
            end

            14: begin // Master กลับมาขับสาย SIO_D
                siod_out_en <= 1;
                state <= 3; // ไปเปลี่ยนข้อมูลเป็นบิตถัดไป (ข้าม state 2)
            end

            // --- STOP Condition ---
            10: begin // เตรียม STOP: ดึง Clock ลง LOW
                sioc_reg <= 0;
                state <= 11;
            end

            11: begin // Master ขับ Data ให้เป็น 0 ขณะ Clock เป็น LOW
                siod_out_en <= 1;
                siod_reg <= 0;
                state <= 12;
            end

            12: begin // ดึง Clock ขึ้น HIGH
                sioc_reg <= 1;
                state <= 15;
            end

            15: begin // ดึง Data ขึ้น HIGH ขณะ Clock เป็น HIGH -> STOP
                siod_reg <= 1;
                reg_idx <= reg_idx + 1; // เลื่อนไปรีจิสเตอร์ถัดไป
                state <= 0;
            end

            default: state <= 0;
        endcase
    end
endmodule
*/

module sccb_config(
    input  wire clk,     // 25MHz Master Clock
    output wire sioc,    // SCCB Clock
    inout  wire siod     // SCCB Data
);

    // Clock Divider
    // Generate ~390kHz internal SCCB timing clock
    reg [7:0] clk_div = 0;
    reg i2c_clk = 0;

    always @(posedge clk) begin
        if (clk_div == 8'd31) begin
            clk_div <= 0;
            i2c_clk <= ~i2c_clk;
        end
        else begin
            clk_div <= clk_div + 1'b1;
        end
    end

    // Camera Register ROM
    reg [7:0] reg_idx = 0;
    reg [15:0] reg_data;

    wire [7:0] TOTAL_REGS = 8;
    wire [7:0] ID_ADDR    = 8'h42;

    always @(*) begin
        case(reg_idx)

            0: reg_data = 16'h1280; // COM7 : RESET
            1: reg_data = 16'h1101; // CLKRC
            2: reg_data = 16'h6B4A; // PLL
            3: reg_data = 16'h1204; // RGB mode
            4: reg_data = 16'h8C00; // Disable RGB444
            5: reg_data = 16'h40D0; // RGB565
            6: reg_data = 16'h3A04; // TSLB
            7: reg_data = 16'hB084; // Magic register

            default: reg_data = 16'hFFFF;

        endcase
    end

    // SCCB Internal Signals
    reg [3:0] state = 0;
    reg [1:0] phase = 0;

    reg [5:0]  bit_cnt = 0;
    reg [23:0] shift_reg = 0;

    reg sioc_reg = 1;
    reg siod_reg = 1;
    reg siod_out_en = 1;

    reg [9:0] delay_cnt = 0;

    assign sioc = sioc_reg;

    // Open-drain behavior
    assign siod = (siod_out_en && (siod_reg == 1'b0))
                ? 1'b0
                : 1'bz;

    // State Definitions
    localparam ST_IDLE  = 4'd0;
    localparam ST_START = 4'd1;
    localparam ST_BIT   = 4'd2;
    localparam ST_ACK   = 4'd3;
    localparam ST_NEXT  = 4'd4;
    localparam ST_STOP  = 4'd5;

    // SCCB Main FSM
    always @(posedge i2c_clk) begin

        case(state)

        // IDLE
        ST_IDLE: begin

            if (reg_idx < TOTAL_REGS) begin

                // Delay after reset command
                if (reg_idx == 1 && delay_cnt < 10'd400) begin
                    delay_cnt <= delay_cnt + 1'b1;
                end
                else begin

                    shift_reg <= {
                        ID_ADDR,
                        reg_data[15:8],
                        reg_data[7:0]
                    };

                    sioc_reg <= 1'b1;
                    siod_reg <= 1'b1;
                    siod_out_en <= 1'b1;

                    phase <= 0;
                    state <= ST_START;

                end
            end
        end

        // START CONDITION
        ST_START: begin

            // SDA falls while SCL stays HIGH
            siod_reg <= 1'b0;

            bit_cnt <= 6'd23;

            phase <= 0;
            state <= ST_BIT;

        end

        // SEND DATA BIT (4-Phase)
        ST_BIT: begin

            case(phase)

            // Phase 0 : Pull clock LOW
            2'd0: begin
                sioc_reg <= 1'b0;
                phase <= 2'd1;
            end

            // Phase 1 : Put data on SDA
            2'd1: begin

                siod_out_en <= 1'b1;
                siod_reg <= shift_reg[bit_cnt];

                phase <= 2'd2;
            end

            // Phase 2 : Clock HIGH
            2'd2: begin
                sioc_reg <= 1'b1;
                phase <= 2'd3;
            end

            // Phase 3 : Hold
            2'd3: begin

                if (bit_cnt == 16 ||
                    bit_cnt == 8  ||
                    bit_cnt == 0) begin

                    phase <= 0;
                    state <= ST_ACK;

                end
                else begin

                    bit_cnt <= bit_cnt - 1'b1;
                    phase <= 0;

                end
            end

            endcase
        end

        // ACK / DON'T CARE BIT
        ST_ACK: begin

            case(phase)

            // Phase 0 : Clock LOW
            2'd0: begin
                sioc_reg <= 1'b0;
                phase <= 2'd1;
            end

            // Phase 1 : Release SDA
            2'd1: begin
                siod_out_en <= 1'b0;
                phase <= 2'd2;
            end

            // Phase 2 : Clock HIGH
            2'd2: begin
                sioc_reg <= 1'b1;
                phase <= 2'd3;
            end

            // Phase 3 : Hold
            2'd3: begin

                if (bit_cnt == 0) begin

                    phase <= 0;
                    state <= ST_STOP;

                end
                else begin

                    bit_cnt <= bit_cnt - 1'b1;

                    phase <= 0;
                    state <= ST_NEXT;

                end
            end

            endcase
        end

        // Resume transmission after ACK
        ST_NEXT: begin

            sioc_reg <= 1'b0;
            siod_out_en <= 1'b1;

            state <= ST_BIT;

        end

        // STOP CONDITION
        ST_STOP: begin

            case(phase)

            // Phase 0 : Pull LOW
            2'd0: begin

                sioc_reg <= 1'b0;

                siod_out_en <= 1'b1;
                siod_reg <= 1'b0;

                phase <= 2'd1;

            end

            // Phase 1 : Clock HIGH
            2'd1: begin

                sioc_reg <= 1'b1;

                phase <= 2'd2;

            end

            // Phase 2 : SDA HIGH => STOP
            2'd2: begin

                siod_reg <= 1'b1;

                phase <= 2'd3;

            end

            // Phase 3 : Finish register
            2'd3: begin

                reg_idx <= reg_idx + 1'b1;

                phase <= 0;
                state <= ST_IDLE;

            end

            endcase
        end

        // Default
        default: begin
            state <= ST_IDLE;
        end

        endcase
    end

endmodule
