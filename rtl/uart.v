`timescale 1ns / 1ps

module uart (
    input clk,
    input rst,
    input tx_start,
    input [7:0] tx_data,

    output tx,

    input rx,
    output [7:0] rx_data,
    output rx_done
);

    wire w_b_tick;


    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .rx_data(rx_data),
        .b_tick(w_b_tick),

        .rx_done(rx_done)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .b_tick(w_b_tick),
        .tx(tx)
    );

    baudrate_tick_gen U_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .o_b_tick(w_b_tick)
    );
endmodule

module uart_rx (
    input clk,
    input rst,
    input rx,
    input b_tick,

    output [7:0] rx_data,
    output rx_done
);
    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [1:0] c_state, n_state;
    reg [3:0] b_tick_reg, b_tick_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [7:0] rx_data_reg, rx_data_next;
    reg rx_done_reg, rx_done_next;

    assign rx_data = rx_data_reg;
    assign rx_done = rx_done_reg;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            b_tick_reg <= 0;
            bit_cnt_reg <= 0;
            rx_data_reg <= 0;
            rx_done_reg <= 0;
        end else begin
            c_state <= n_state;
            b_tick_reg <= b_tick_next;
            bit_cnt_reg <= bit_cnt_next;
            rx_data_reg <= rx_data_next;
            rx_done_reg <= rx_done_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        b_tick_next = b_tick_reg;
        bit_cnt_next = bit_cnt_reg;
        rx_data_next = rx_data_reg;
        rx_done_next = rx_done_reg;

        case (c_state)

            IDLE: begin
                rx_done_next = 1'b0;
                
                if (~rx) begin
                    b_tick_next = 0;
                    n_state = START;
                end
            end

            START: begin
                if (b_tick) begin
                    if (b_tick_reg == 7) begin
                        b_tick_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_next = b_tick_reg + 1;  // reg + 1 중요
                    end
                end
            end

            DATA: begin
                if (b_tick) begin
                    if (b_tick_reg == 15) begin
                        b_tick_next  = 0;

                        rx_data_next = {rx, rx_data_reg[7:1]};

                        if (bit_cnt_next == 7) begin
                            bit_cnt_next = 0;
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;  // reg + 1 중요
                        end
                    end else begin
                        b_tick_next = b_tick_reg + 1;  // reg + 1 중요
                    end
                end
            end

            STOP: begin
                if (b_tick) begin
                    if (b_tick_reg == 15) begin
                        rx_done_next = 1'b1;

                        n_state = IDLE;
                    end else begin
                        b_tick_next = b_tick_reg + 1;
                    end
                end
            end
        endcase
    end




endmodule


module uart_tx (
    input clk,
    input rst,
    input tx_start,
    input b_tick,
    input [7:0] tx_data,

    output tx
);

    localparam [1:0] IDLE = 0, TX_START = 1, TX_DATA = 2, TX_STOP = 3;

    reg [1:0] state_reg, state_next;
    reg tx_reg, tx_next;
    reg [7:0] data_buf_reg, data_buf_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;

    assign tx      = tx_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg     <= IDLE;
            tx_reg         <= 0;
            data_buf_reg   <= 0;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
        end else begin
            state_reg      <= state_next;
            tx_reg         <= tx_next;
            data_buf_reg   <= data_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
        end
    end


    always @(*) begin
        state_next      = state_reg;
        tx_next         = tx_reg;
        data_buf_next   = data_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;

        case (state_reg)
            IDLE: begin
                tx_next = 1;
                if (tx_start) begin
                    b_tick_cnt_next = 0;
                    data_buf_next = tx_data;
                    state_next = TX_START;
                end
            end
            TX_START: begin
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_next == 15) begin
                        state_next = TX_DATA;
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            TX_DATA: begin
                tx_next = data_buf_reg[0];  // 핵심
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next = 0;
                            state_next = TX_STOP;
                        end else begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next    = bit_cnt_reg + 1;
                            data_buf_next   = data_buf_reg >> 1;  // 핵심
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            TX_STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        state_next = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end

                end
            end
            default: state_next = state_reg;
        endcase
    end
endmodule


module baudrate_tick_gen (
    input  clk,
    input  rst,
    output o_b_tick
);


    parameter BAUD = 9600;
    parameter BAUD_TICK_COUNT = (100_000_000 / (9600 * 16)) - 1;
    reg [$clog2(BAUD_TICK_COUNT)-1:0] counter_reg;
    reg b_tick_reg;

    assign o_b_tick = b_tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick_reg  <= 0;
        end else begin
            if (counter_reg == BAUD_TICK_COUNT) begin
                counter_reg <= 0;
                b_tick_reg  <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                b_tick_reg  <= 1'b0;
            end
        end
    end

endmodule
