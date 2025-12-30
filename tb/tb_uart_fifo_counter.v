`timescale 1ns / 1ps


module tb_uart_fifo_counter ();

    parameter UART_TX_DELAY = (100_000_000 / 9600) * 12 * 10;
    reg clk, rst, rx;
    wire       tx;
    reg  [7:0] send_data;


uart_fifo_counter dut (
    .clk(clk),
    .rst(rst),

    .btn_run(),
    .btn_clear(),
    .btn_mode(),

    .rx(rx),
    .tx(tx),

    .fnd_com(),
    .fnd_data()
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

        send_data = "r";
        send_uart(send_data);

        send_data = "u";
        send_uart(send_data);

        send_data = "n";
        send_uart(send_data);


        send_data = "c";
        send_uart(send_data);

        send_data = "l";
        send_uart(send_data);

        send_data = "e";
        send_uart(send_data);

        send_data = "a";
        send_uart(send_data);

        send_data = "r";
        send_uart(send_data);


        send_data = "m";
        send_uart(send_data);

        send_data = "o";
        send_uart(send_data);

        send_data = "d";
        send_uart(send_data);

        send_data = "e";
        send_uart(send_data);

   
        send_data = "r";
        send_uart(send_data);

        send_data = "u";
        send_uart(send_data);

        send_data = "n";
        send_uart(send_data);

    #1000000;

        send_data = "s";
        send_uart(send_data);
        send_data = "e";
        send_uart(send_data);
        send_data = "t";
        send_uart(send_data);
        send_data = "h";
        send_uart(send_data);
        send_data = "z";
        send_uart(send_data);
        send_data = "1";
        send_uart(send_data);
        send_data = "0";
        send_uart(send_data);
        send_data = "0";
        send_uart(send_data);
        send_data = "0";
        send_uart(send_data);
        send_data = "0";
        send_uart(send_data);
        send_data = ":";
        send_uart(send_data);

        // // 100_000_000 / 9600 * 10nsec
        // #(UART_TX_DELAY);


        #1000;
        $finish;
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