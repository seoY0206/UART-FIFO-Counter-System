`timescale 1ns / 1ps

module uart_fifo (
    input        clk,
    input        rst,
    input        rx,

    output [7:0] rx_data,
    output       rx_done,
    output       tx
);

    wire [7:0] w_fifo_rx_data;
    wire [7:0] w_fifo_tx_data;
    wire [7:0] w_uart_tx_data;
    wire w_fifo_tx_empty, w_tx_busy, w_b_tick, w_uart_tx_empty;
    wire w_fifo_rx_full, w_rx_done;

    assign rx_data = w_fifo_rx_data;
    assign rx_done = w_rx_done;

    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .b_tick(w_b_tick),
        .rx_data(w_fifo_rx_data),
        .rx_done(w_rx_done)
    );

    fifo U_FIFO_RX (
        .clk(clk),
        .rst(rst),
        .wr(w_rx_done),
        .rd(~w_fifo_rx_full),
        .wdata(w_fifo_rx_data),
        .rdata(w_fifo_tx_data),
        .full(),
        .empty(w_fifo_tx_empty)
    );


    fifo U_FIFO_TX (
        .clk(clk),
        .rst(rst),
        .wr(~w_fifo_tx_empty),
        .rd(~w_tx_busy),
        .wdata(w_fifo_tx_data),
        .rdata(w_uart_tx_data),
        .full(w_fifo_rx_full),
        .empty(w_uart_tx_empty)
    );


    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .start_trigger(~w_uart_tx_empty & ~w_tx_busy),
        .tx_data(w_uart_tx_data),
        .b_tick(w_b_tick),
        .tx(tx),
        .tx_busy(w_tx_busy)
    );

    baud_tick_gen U_BAUD_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
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

    // state
    reg [1:0] state, next;

    // tick count
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;

    //bit count
    reg [2:0] bit_cnt_reg, bit_cnt_next;

    // output
    reg rx_done_reg, rx_done_next;

    // rx internal buffer
    reg [7:0]
        rx_buf_reg,
        rx_buf_next;  // 값을 저장해야하니까 피드백구조

    // output
    assign rx_data = rx_buf_reg;
    assign rx_done = rx_done_reg;

    // state resister
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            rx_done_reg    <= 0;
            rx_buf_reg     <= 0;
        end else begin
            state          <= next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            rx_done_reg    <= rx_done_next;
            rx_buf_reg     <= rx_buf_next;
        end
    end

    //next CL
    always @(*) begin
        next = state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        rx_done_next = rx_done_reg;
        rx_buf_next = rx_buf_reg;
        // rx_done_next = 1'b0;

        case (state)
            IDLE: begin
                rx_done_next = 1'b0;
                if (b_tick) begin
                    if (rx == 1'b0) begin
                        b_tick_cnt_next = 0; // b_tick이 하나 세어졌을까봐 초기화(잔여데이터 제거)
                        next = START;
                    end
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 23) begin
                        bit_cnt_next = 0;
                        b_tick_cnt_next = 0;
                        next = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 0) begin
                        rx_buf_next[7] = rx;        //밖으로 빼면 계속 읽음. 한번만 읽기
                    end  //위해 틱 카운트 0일때 읽어라
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            next = STOP;
                        end else begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            rx_buf_next = rx_buf_reg >> 1;  // 우측으로 밀고 저장
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    rx_done_next = 1'b1;
                    next = IDLE;
                end
            end
        endcase
    end
endmodule


module uart_tx (
    input        clk,
    input        rst,
    input        start_trigger,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx,
    output       tx_busy
);

    // fsm state
    localparam [2:0] IDLE = 0, WAIT = 1, START = 2, DATA = 3, STOP = 4;

    // state
    reg [2:0] state, next;
    // bit control reg
    reg [2:0] bit_count, bit_next;
    // tx internal buffer
    reg [7:0] data_reg, data_next;
    // b_tick counter
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;

    //output
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    // state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            tx_reg         <= 1'b1;  // output high
            bit_count      <= 0;
            b_tick_cnt_reg <= 0;
            data_reg       <= 0;
            tx_busy_reg    <= 0;
        end else begin
            state          <= next;
            tx_reg         <= tx_next;
            bit_count      <= bit_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            data_reg       <= data_next;
            tx_busy_reg    <= tx_busy_next;
        end
    end

    // next CL
    always @(*) begin
        // remove latch
        next = state;
        tx_next = tx_reg;
        bit_next = bit_count;
        b_tick_cnt_next = b_tick_cnt_reg;
        data_next = data_reg;
        tx_busy_next = tx_busy_reg;
        case (state)
            IDLE: begin
                // output tx
                tx_next = 1'b1;
                tx_busy_next = 1'b0;
                if (start_trigger == 1'b1) begin
                    next = WAIT;
                    tx_busy_next = 1'b1;
                    data_next = tx_data;
                end
            end
            WAIT: begin
                if (b_tick == 1'b1) begin
                    next = START;
                    b_tick_cnt_next = 0;
                end
            end
            START: begin
                tx_next = 0;
                if (b_tick == 1'b1) begin
                    if (b_tick_cnt_reg == 15) begin
                        bit_next = 0;
                        b_tick_cnt_next = 0;
                        next = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_reg[0];
                if (b_tick == 1'b1) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_count == 3'b111) begin
                            next = STOP;
                        end else begin
                            data_next = data_reg >> 1;
                            bit_next  = bit_count + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick == 1'b1) begin
                    if (b_tick_cnt_reg == 15) begin
                        next = IDLE;
                        tx_busy_next = 1'b0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule


module baud_tick_gen (
    input  clk,
    input  rst,
    output b_tick
);

    //baudrate
    parameter BAUDRATE = 9600 * 16; // 16배 올려줬으니 b_tick counter 추가해야됨!
    localparam BAUD_COUNT = 100_000_000 / BAUDRATE;
    reg [$clog2(BAUD_COUNT)-1 : 0] counter_reg, counter_next;
    reg tick_reg, tick_next;  //feedback 구조로 만들거임.

    //output
    assign b_tick = tick_reg;

    //SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;
        end else begin
            counter_reg <= counter_next;
            tick_reg <= tick_next;  // 피드백 구조라!
        end
    end

    //next CL
    always @(*) begin
        tick_next = tick_reg;
        counter_next = counter_reg;  // 초기화 = 현상태 유지해라
        if (counter_reg == BAUD_COUNT - 1) begin
            counter_next = 0;
            tick_next = 1'b1;
        end else begin
            counter_next = counter_reg + 1;  // 상승클락일 때 +1
            tick_next = 1'b0;
        end
    end

endmodule