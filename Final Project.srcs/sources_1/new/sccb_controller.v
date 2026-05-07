module sccb_controller(
    input clk,            // แนะนำให้ใช้ clk 25MHz หรือต่ำกว่า
    input [15:0] id_data, // [15:8] Register Address, [7:0] Data
    input start,
    output reg done,
    output reg scl,
    inout sda,
    output reg ready
    );

    // กำหนดจังหวะ SCCB (ประมาณ 100kHz)
    reg [7:0] clk_divider = 0;
    reg sccb_clk = 0;
    always @(posedge clk) begin
        if (clk_divider == 125) begin // 25MHz / 250 = 100kHz
            clk_divider <= 0;
            sccb_clk <= ~sccb_clk;
        end else clk_divider <= clk_divider + 1;
    end

    reg [4:0] state = 0;
    reg [23:0] tx_data; // Device ID (0x42) + Reg Addr + Data
    reg [4:0] bit_cnt = 0;
    reg sda_out = 1;
    
    assign sda = (sda_out) ? 1'bz : 0; // SCCB ใช้ Open Drain (จำลองด้วย High-Z)

    always @(posedge sccb_clk) begin
        case(state)
            0: begin // Ready State
                ready <= 1;
                done <= 0;
                scl <= 1;
                sda_out <= 1;
                if (start) begin
                    tx_data <= {8'h42, id_data}; // ID กล้องคือ 0x42
                    state <= 1;
                    ready <= 0;
                end
            end
            1: begin // Start Condition
                sda_out <= 0;
                scl <= 1;
                state <= 2;
                bit_cnt <= 0;
            end
            2: begin // Send Data Bits (3 bytes: ID, Addr, Data)
                scl <= 0;
                if (bit_cnt == 8 || bit_cnt == 17 || bit_cnt == 26) begin
                    sda_out <= 1; // Don't care bit (เหมือน ACK ใน I2C)
                end else begin
                    sda_out <= tx_data[26 - bit_cnt]; // ส่งบิตสูงสุดก่อน
                end
                
                if (bit_cnt == 27) state <= 3;
                else bit_cnt <= bit_cnt + 1;
            end
            // จังหวะจัดการ SCL ให้เป็น Pulse สำหรับแต่ละบิต
            3: begin 
                scl <= 1;
                state <= 4;
            end
            4: begin // Stop Condition
                scl <= 1;
                sda_out <= 1;
                done <= 1;
                state <= 0;
            end
        endcase
    end
endmodule