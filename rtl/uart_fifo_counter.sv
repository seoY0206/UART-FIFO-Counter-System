`timescale 1ns / 1ps

module uart_fifo_counter (
    input       clk,
    input       rst,

    input       btn_run,
    input       btn_clear,
    input       btn_mode,

    input       rx,
    output      tx,

    output [3:0] fnd_com,
    output [7:0] fnd_data
);
    wire        w_rx_done;
    wire [7:0]  w_rx_data;

    assign rx_done = w_rx_done;

    fnd U_FND (
        .clk        (clk),
        .rst        (rst),

        .btn_run    (btn_run),
        .btn_clear  (btn_clear),
        .btn_mode   (btn_mode),

        .rx_data    (w_rx_data),
        .rx_done    (w_rx_done),

        .fnd_com    (fnd_com),
        .fnd_data   (fnd_data)
    );

    uart_fifo U_UART_FIFO (
        .clk        (clk),
        .rst        (rst),

        .tx         (tx),
        .rx         (rx),

        .rx_data    (w_rx_data),
        .rx_done    (w_rx_done)
    );
    
endmodule
