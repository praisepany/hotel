module ov7670_setup(
    input clk,
    output scl,        // Changed to wire
    inout sda,
    output reg ready = 0
    );

    reg [7:0] reg_idx = 0;
    wire [15:0] command;
    
    // ROM instantiation
    ov7670_registers rom (.index(reg_idx), .command(command));

    // Slow clock for SCCB (Approx 100KHz)
    reg [15:0] divider = 0;
    reg sccb_clk = 0;
    always @(posedge clk) begin
        if (divider == 500) begin 
            divider <= 0;
            sccb_clk <= ~sccb_clk;
        end else divider <= divider + 1;
    end

    // FSM States
    localparam IDLE=0, START=1, SEND_BYTE=2, ACK=3, STOP=4, TIMER=5;
    reg [3:0] state = IDLE;
    reg [7:0] current_byte;
    reg [3:0] bit_count = 0;
    reg [1:0] byte_count = 0;
    reg sda_out = 1;

    // --- FIX 1: Generate SCL ---
    // SCL should only toggle when we are actually sending data
    assign scl = (state == SEND_BYTE || state == ACK) ? ~sccb_clk : 1;
    assign sda = (sda_out) ? 1'bz : 1'b0; 

    always @(posedge sccb_clk) begin
        case(state)
            IDLE: begin
                ready <= 0;
                if (command != 16'hFFFF) begin
                    state <= START;
                    sda_out <= 1;
                end else begin
                    ready <= 1; // All registers sent
                end
            end
            
            START: begin
                sda_out <= 0; // Start condition
                bit_count <= 7;
                state <= SEND_BYTE;
                case(byte_count)
                    0: current_byte <= 8'h42;         // Device ID
                    1: current_byte <= command[15:8]; // Register Address
                    2: current_byte <= command[7:0];  // Register Data
                endcase
            end

            SEND_BYTE: begin
                sda_out <= current_byte[bit_count];
                if (bit_count == 0) state <= ACK;
                else bit_count <= bit_count - 1;
            end

            ACK: begin
                sda_out <= 1'bz; // "Don't care" bit in SCCB
                if (byte_count == 2) state <= STOP;
                else begin
                    state <= START;
                    byte_count <= byte_count + 1;
                end
            end

            STOP: begin
                sda_out <= 0; 
                state <= TIMER;
            end

            TIMER: begin
                sda_out <= 1; // Stop condition (SCL is high, SDA goes low to high)
                byte_count <= 0;
                reg_idx <= reg_idx + 1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
endmodule