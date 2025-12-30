`timescale 1ns / 1ps


module tb_uart_fifo ();

    parameter UART_TX_DELAY = (100_000_000 / 9600) * 12 * 10;
    reg clk, rst, rx;
    wire       tx;
    reg  [7:0] send_data;


uart_fifo dut(
    .clk(clk),
    .rst(rst),
    .rx_done(),
    .rx_data(),
    .rx(rx),
    .tx(tx)
);

    always #5 clk = ~clk;

    initial begin
        #0;
        clk = 0;
        rst = 1;
        rx  = 1;
        #10;
        rst = 0;
        #10;
        
        // uart frame
        send_data = 8'h30;
        send_uart(send_data);
        #10;

        // uart frame
        send_data = 8'h31;
        send_uart(send_data);
        #10;

        // uart frame
        send_data = 8'h32;
        send_uart(send_data);
        #10;


        /*
        btn_r = 1;
        #10_000;  // 10usec
        btn_r = 0;
        */
        // 100_000_000 / 9600 * 10nsec
        #(UART_TX_DELAY);

        #1000;
        $stop;
    end

    // task tx -> rx send_uart
    task send_uart(input [7:0] send_data);
        integer i;
        begin
            // start bit
            rx = 0;
            #(104166);  // uart 9600bps bit time
            // data bit
            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(104166);  // uart 9600bps bit time 
            end
            // stopbit
            rx = 1;
            #(104166);  // uart 9600bps bit time
        end
    endtask

endmodule