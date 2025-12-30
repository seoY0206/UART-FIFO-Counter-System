`timescale 1ns / 1ps

module LED_Controller
(
    input clk, rst,
    input sw_2, sw_3,
    input [3:0] i_led_data, 

    output reg [8:0] o_led_data

);

tick_gen_10hz U_TICK_10HZ (
    .clk        (clk),
    .rst        (rst),
    .run        (),

    .tick_10hz  ()              /////////////////////////////////////////////요기 하던주우우우우웅
);



    always @(posedge clk, posedge rst) 
    begin
        if(rst)  o_led_data <= 9'b0;
        else
        begin
            if(sw_2 == 1'b1 && sw_3 == 1'b1)
            begin
                case(i_led_data)
                    0 :  o_led_data <= 9'b000000000;
                    1 :  o_led_data <= 9'b000000001;
                    2 :  o_led_data <= 9'b000000010;
                    3 :  o_led_data <= 9'b000000100;
                    4 :  o_led_data <= 9'b000001000;
                    5 :  o_led_data <= 9'b000010000;
                    6 :  o_led_data <= 9'b000100000;
                    7 :  o_led_data <= 9'b001000000;
                    8 :  o_led_data <= 9'b010000000;
                    9 :  o_led_data <= 9'b100000000;
                    default : o_led_data <= 9'b000000000;
                endcase
            end
            else o_led_data <= 9'b0;
        end
    end
endmodule


module tick_gen_10hz (
    input       clk,
    input       rst,
    input       run,

    output reg  tick_10hz
);

    reg [23:0]  r_counter;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
            tick_10hz <= 0;
        end else begin
            if (run) begin
                if (r_counter == 10_000_000 - 1) begin
                    r_counter <= 0;
                    tick_10hz <= 1'b1;
                end else begin
                    r_counter <= r_counter + 1;
                    tick_10hz <= 1'b0;
                end 
            end else r_counter <= 0;
        end
    end
endmodule