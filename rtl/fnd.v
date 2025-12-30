`timescale 1ns / 1ps

module fnd (
    input       clk,
    input       rst,

    input       btn_clear,
    input       btn_mode,
    input       btn_run,

    input [7:0] rx_data,
    input       rx_done,

    output [3:0] fnd_com,
    output [7:0] fnd_data

);
    wire        w_tick_hz, w_tick_1khz;
    wire [3:0]  w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    wire [13:0] w_counter;
    wire [ 1:0] w_sel_digit;
    wire [ 3:0] w_digit_value;
    wire [26:0] w_set_hz_count;

    wire        bd_run, bd_clear, bd_mode;
    wire        w_btn_run, w_btn_clear, w_btn_mode;
    wire        w_cmd_run, w_cmd_clear, w_cmd_mode;

    reg         run_state, clear_state, mode_state;

    //assign      clear_state = w_btn_clear | w_cmd_clear;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            run_state   <= 1'b0;
            clear_state <= 1'b0;
            mode_state  <= 1'b0;
        end else begin
            if (w_cmd_run   | w_btn_run)   run_state   <= ~run_state;
            if (w_cmd_clear | w_btn_run | clear_state)   clear_state   <= ~clear_state;
            if (w_cmd_mode  | w_btn_mode)  mode_state  <= ~mode_state;
        end
    end

    command_control U_CMD_CU (
        .clk        (clk),
        .rst        (rst),
        .input_cmd  (rx_data),
        .rx_done    (rx_done),

        .cmd_run    (w_cmd_run),
        .cmd_clear  (w_cmd_clear),
        .cmd_mode   (w_cmd_mode),

        .set_hz_count     (w_set_hz_count)
    );

    button_control U_BTN_CU (
        .clk        (clk),
        .rst        (rst),
        .i_run      (bd_run),    // 1: run
        .i_clear    (bd_clear),  // 1: 0으로 초기화
        .i_mode     (bd_mode),   // 0: UP, 1: DOWN

        .run        (w_btn_run),
        .clear      (w_btn_clear),
        .mode       (w_btn_mode)
    );

    btn_debounce U_BD_RUN (
        .clk        (clk),
        .rst        (rst),
        .i_btn      (btn_run),

        .o_btn      (bd_run)
    );
    btn_debounce U_BD_CLEAR (
        .clk        (clk),
        .rst        (rst),
        .i_btn      (btn_clear),

        .o_btn      (bd_clear)
    );
    btn_debounce U_BD_MODE (
        .clk        (clk),
        .rst        (rst),
        .i_btn      (btn_mode),

        .o_btn      (bd_mode)
    );

    data_path_c10000 U_DP_C10000 (
        .rst        (rst),
        .tick_hz    (w_tick_hz),
        .mode       (mode_state),
        .clear      (clear_state),

        .counter    (w_counter)
    );

    digit_spliter U_DIGIT_SPLITER (
        .counter    (w_counter),
        .digit_1    (w_digit_1),
        .digit_10   (w_digit_10),
        .digit_100  (w_digit_100),
        .digit_1000 (w_digit_1000)
    );

    mux_4x1 U_MUX_4X1 (
        .sel_digit  (w_sel_digit),
        .digit_1    (w_digit_1),
        .digit_10   (w_digit_10),
        .digit_100  (w_digit_100),
        .digit_1000 (w_digit_1000),

        .digit_value(w_digit_value)
    );

    bcd_decoder U_BCD_DECODER (
        .bcd        (w_digit_value),

        .fnd_data   (fnd_data)
    );

    counter_4 U_COUNTER_4 (
        .tick_1khz  (w_tick_1khz),
        .rst        (rst),

        .sel_digit  (w_sel_digit)
    );

    decoder_2x4 U_DECODER_2x4 (
        .sel_digit  (w_sel_digit),

        .fnd_com    (fnd_com)
    );

    tick_gen_hz U_TICK_GEN_HZ (
        .clk        (clk),
        .rst        (rst),
        .run        (run_state),
        .set_hz_count (w_set_hz_count),

        .tick_hz    (w_tick_hz)
    );  

    tick_gen_1khz U_TICK_GEN_1KHZ (
        .clk        (clk),
        .rst        (rst),

        .tick_1khz  (w_tick_1khz)
    );
endmodule

`timescale 1ns / 1ps

module command_control(
    input       clk, rst,
    input [7:0] input_cmd,
    input       rx_done,

    output      cmd_run,
    output      cmd_clear,
    output      cmd_mode,

    output [26:0] set_hz_count
);

    // FSM 상태 정의: 각 명령어의 첫 글자만 추적하고, 나머지는 순차 확인
    localparam IDLE       = 4'b0000;
    localparam R          = 4'b0001; // "r"
    localparam RU         = 4'b0010; // "ru"
    localparam C          = 4'b0011; // "c"
    localparam CL         = 4'b0100; // "cl"
    localparam CLE        = 4'b0101; // "cle"
    localparam CLEA       = 4'b0110; // "clea"
    localparam M          = 4'b0111; // "m"
    localparam MO         = 4'b1000; // "mo"
    localparam MOD        = 4'b1001; // "mod"
    localparam S          = 4'b1010; // "s"
    localparam SE         = 4'b1011; // "se"
    localparam SET        = 4'b1100; // "set"
    localparam SETH       = 4'b1101; // "seth"
    localparam SETHZ      = 4'b1110; // "sethz"
    localparam NUM_INPUT  = 4'b1111; // 숫자 입력 상태

// 내부 레지스터 선언
    reg [3:0]   state_reg, state_next;
    reg [26:0]  num_buffer_reg, num_buffer_next;
    reg [26:0]  set_hz_count_reg, set_hz_count_next;
    
    // 출력 신호용 reg 선언
    reg cmd_run_next, cmd_clear_next, cmd_mode_next;
    reg cmd_run_reg, cmd_clear_reg, cmd_mode_reg;

    // 최종 출력은 항상 reg에서 나가도록 assign
    assign cmd_run      = cmd_run_reg;
    assign cmd_clear    = cmd_clear_reg;
    assign cmd_mode     = cmd_mode_reg;
    assign set_hz_count = set_hz_count_reg;
    
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg           <= IDLE;
            num_buffer_reg      <= 0;
        //  set_hz_count_reg    <= 10000000 - 1; // 100MHz 클럭 기준 10Hz
            set_hz_count_reg    <= 100000 - 1;
            cmd_run_reg         <= 1'b0;
            cmd_clear_reg       <= 1'b0;
            cmd_mode_reg        <= 1'b0;
        end else begin
            state_reg           <= state_next;
            num_buffer_reg      <= num_buffer_next;
            set_hz_count_reg    <= set_hz_count_next;
            cmd_run_reg         <= cmd_run_next;
            cmd_clear_reg       <= cmd_clear_next;
            cmd_mode_reg        <= cmd_mode_next;
        end
    end

    always @(*) begin
        // 기본적으로 현재 상태와 값을 유지하도록 설정 (Latch 방지)
        state_next          = state_reg;
        num_buffer_next     = num_buffer_reg;
        set_hz_count_next   = set_hz_count_reg;
        cmd_run_next        = 1'b0; // 출력 펄스는 기본적으로 0
        cmd_clear_next      = 1'b0;
        cmd_mode_next       = 1'b0;

        if (rx_done) begin
            case (state_reg)
                IDLE: begin
                    if      (input_cmd == "r") state_next = R;
                    else if (input_cmd == "c") state_next = C;
                    else if (input_cmd == "m") state_next = M;
                    else if (input_cmd == "s") state_next = S;
                    else                       state_next = IDLE;
                end
                
                // "run" 명령어 처리
                R:    state_next = (input_cmd == "u") ? RU   : IDLE;
                RU:   if (input_cmd == "n") begin
                          cmd_run_next = 1'b1;
                          state_next = IDLE;
                      end else state_next = IDLE;
                
                // "clear" 명령어 처리
                C:    state_next = (input_cmd == "l") ? CL   : IDLE;
                CL:   state_next = (input_cmd == "e") ? CLE  : IDLE;
                CLE:  state_next = (input_cmd == "a") ? CLEA : IDLE;
                CLEA: begin
                    if (input_cmd == "r") cmd_clear_next = 1'b1;
                    state_next = IDLE;
                end
                
                // "mode" 명령어 처리
                M:   state_next = (input_cmd == "o") ? MO  : IDLE;
                MO:  state_next = (input_cmd == "d") ? MOD : IDLE;
                MOD: begin
                    if (input_cmd == "e") cmd_mode_next = 1'b1;
                    state_next = IDLE;
                end

                // "sethz" 명령어 처리
                S:     state_next = (input_cmd == "e") ? SE    : IDLE;
                SE:    state_next = (input_cmd == "t") ? SET   : IDLE;
                SET:   state_next = (input_cmd == "h") ? SETH  : IDLE;
                SETH: begin
                    state_next = (input_cmd == "z") ? SETHZ : IDLE;
                    num_buffer_next = 0;
                end  
                SETHZ: begin
                    if (input_cmd >= "0" && input_cmd <= "9") begin
                        // 새 숫자가 들어오면 기존 값에 10을 곱하고 더함
                        num_buffer_next = num_buffer_reg * 10 + (input_cmd - "0");
                    end else if (input_cmd == ":") begin // 입력 종료
                        case (num_buffer_reg)
                            1:    set_hz_count_next = 100000000 - 1;   
                            10:   set_hz_count_next = 10000000 - 1;   
                            100:  set_hz_count_next = 1000000 - 1;   
                            1000: set_hz_count_next = 100000 - 1;
                            10000:set_hz_count_next = 10000 - 1;     
                            default: set_hz_count_next = 100_000_000 - 1;
                        endcase
                        state_next = IDLE;
                    end else begin
                        state_next = IDLE;
                    end
                end

                default: state_next = IDLE;
            endcase
        end
    end
endmodule







// 나눗셈 들어간 WHS 가 매우 낮은 회로

//     always @(*) begin
//         // 기본적으로 현재 상태와 값을 유지하도록 설정 (Latch 방지)
//         state_next          = state_reg;
//         num_buffer_next     = num_buffer_reg;
//         set_hz_count_next   = set_hz_count_reg;
//         cmd_run_next        = 1'b0; // 출력 펄스는 기본적으로 0
//         cmd_clear_next      = 1'b0;
//         cmd_mode_next       = 1'b0;

//         if (rx_done) begin
//             case (state_reg)
//                 IDLE: begin
//                     if      (input_cmd == "r") state_next = R;
//                     else if (input_cmd == "c") state_next = C;
//                     else if (input_cmd == "m") state_next = M;
//                     else if (input_cmd == "s") state_next = S;
//                     else                       state_next = IDLE;
//                 end
                
//                 // "run" 명령어 처리
//                 R:    state_next = (input_cmd == "u") ? RU   : IDLE;
//                 RU:   if (input_cmd == "n") begin
//                           cmd_run_next = 1'b1;
//                           state_next = IDLE;
//                       end else state_next = IDLE;
                
//                 // "clear" 명령어 처리
//                 C:    state_next <= (input_cmd == "l") ? CL   : IDLE;
//                 CL:   state_next <= (input_cmd == "e") ? CLE  : IDLE;
//                 CLE:  state_next <= (input_cmd == "a") ? CLEA : IDLE;
//                 CLEA: begin
//                     if (input_cmd == "r") cmd_clear_next <= 1'b1;
//                     state_next <= IDLE;
//                 end
                
//                 // "mode" 명령어 처리
//                 M:   state_next <= (input_cmd == "o") ? MO  : IDLE;
//                 MO:  state_next <= (input_cmd == "d") ? MOD : IDLE;
//                 MOD: begin
//                     if (input_cmd == "e") cmd_mode_next <= 1'b1;
//                     state_next <= IDLE;
//                 end

//                 // "sethz" 명령어 처리
//                 S:     state_next = (input_cmd == "e") ? SE    : IDLE;
//                 SE:    state_next = (input_cmd == "t") ? SET   : IDLE;
//                 SET:   state_next = (input_cmd == "h") ? SETH  : IDLE;
//                 SETH: begin
//                     state_next = (input_cmd == "z") ? SETHZ : IDLE;
//                     num_buffer_next = 0;
//                 end  
//                 SETHZ: begin
//                     if (input_cmd >= "0" && input_cmd <= "9") begin
//                         // 새 숫자가 들어오면 기존 값에 10을 곱하고 더함
//                         num_buffer_next = num_buffer_reg * 10 + (input_cmd - "0");
//                     end else if (input_cmd == ":") begin // 입력 종료

//                         set_hz_count_reg <= (100_000_000 / num_buffer_reg) - 1;

//                         state_next = IDLE;
//                     end else begin
//                         state_next = IDLE;
//                     end
//                 end

//                 default: state_next = IDLE;
//             endcase
//         end
//     end
// endmodule

                                
module button_control (
    input       clk, rst,
    input       i_run,
    input       i_clear,
    input       i_mode,

    output      run,
    output      clear,
    output      mode
);

    reg         r_run, r_clear, r_mode;

    assign      run   = ~r_run & i_run;
    assign      clear = ~r_clear & i_clear;
    assign      mode  = ~r_mode & i_mode;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_run   <= 1'b0;
            r_clear <= 1'b0;
            r_mode  <= 1'b0;
        end else begin
            r_run   <= i_run;
            r_clear <= i_clear;
            r_mode  <= i_mode;
        end
    end
endmodule


module btn_debounce (
    input       clk, rst, i_btn,
    output      o_btn
);

    wire        debounce;
    reg [3:0]   q_reg, q_next;  // Shift Register

    // Clk divider 1Mhz
    reg [$clog2(100)-1:0] counter;  // 100Mhz -> 1Mhz (/100)
    reg                   r_db_clk;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter  <= 0;
            r_db_clk <= 0;
        end else begin
            if(counter == (100-1))      // 0~99 (=100-1)
            begin
                counter  <= 0;
                r_db_clk <= 1'b1;
            end else begin
                counter  <= counter + 1;
                r_db_clk <= 1'b0;
            end
        end
    end

    // Shift Register
    always @(posedge r_db_clk, posedge rst) begin
        if (rst) begin
            q_reg <= 0;
        end else begin
            q_reg <= q_next;
        end
    end

    // Shift Register
    always @(*) begin
        q_next = {i_btn, q_reg[3:1]};
    end

    // debounce = 4bit AND(&)
    assign debounce = &q_reg;

    // Edge Detection
    reg edge_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            edge_reg <= 0;
        end else begin
            edge_reg <= debounce;
        end
    end

    // Invert a 1 tick after debounce signal
    // o_btn = Rising Edged debounce signal
    assign o_btn = ~edge_reg & debounce;
endmodule

module data_path_c10000 (
    input tick_hz,
    input rst,
    input mode,
    input clear,

    output [13:0] counter
);
    reg [13:0] r_counter;
    assign counter = r_counter;

    always @(posedge tick_hz, posedge rst, posedge clear) begin
        if (rst | clear) begin
            r_counter <= 0;
        end else begin
            if (~mode) begin
                if (r_counter == 10_000 - 1) begin
                    r_counter <= 0;
                end else begin
                    r_counter <= r_counter + 1;
                end
            end else begin
                if (r_counter == 0) begin
                    r_counter <= 9999;
                end else begin
                    r_counter <= r_counter - 1;
                end
            end
        end
    end
endmodule


module digit_spliter (
    input [13:0] counter,

    output [3:0] digit_1,
    digit_10,
    digit_100,
    digit_1000
);
    assign digit_1    = counter % 10;
    assign digit_10   = (counter / 10) % 10;
    assign digit_100  = (counter / 100) % 10;
    assign digit_1000 = counter / 1000;
endmodule

module mux_4x1 (
    input [1:0] sel_digit,
    input [3:0] digit_1,
    digit_10,
    digit_100,
    digit_1000,

    output [3:0] digit_value
);
    reg [3:0] mux_4x1_reg;
    assign digit_value = mux_4x1_reg;

    always @(*) begin
        case (sel_digit)
            2'b00:   mux_4x1_reg = digit_1;
            2'b01:   mux_4x1_reg = digit_10;
            2'b10:   mux_4x1_reg = digit_100;
            2'b11:   mux_4x1_reg = digit_1000;
            default: mux_4x1_reg = digit_1;
        endcase
    end
endmodule

module bcd_decoder (
    input [3:0] bcd,

    output reg [7:0] fnd_data
);

    always @(bcd) begin
        case (bcd)
            0: fnd_data = 8'hc0;
            1: fnd_data = 8'hf9;
            2: fnd_data = 8'ha4;
            3: fnd_data = 8'hb0;
            4: fnd_data = 8'h99;
            5: fnd_data = 8'h92;
            6: fnd_data = 8'h82;
            7: fnd_data = 8'hf8;
            8: fnd_data = 8'h80;
            9: fnd_data = 8'h90;
            default: fnd_data = 8'hff;
        endcase
    end
endmodule

module counter_4 (
    input       rst,
    input       tick_1khz,
    output [1:0] sel_digit
);
    reg [1:0]   r_counter;
    assign      sel_digit = r_counter;

    always @(posedge tick_1khz, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
        end else begin
            r_counter <= r_counter + 1;
        end
    end
endmodule

module decoder_2x4 (
    input [1:0] sel_digit,

    output [3:0] fnd_com
);  
    reg [3:0] decoder_reg;
    assign fnd_com = decoder_reg;

    always @(sel_digit) begin
        case (sel_digit)
            2'b00:   decoder_reg = 4'b1110;
            2'b01:   decoder_reg = 4'b1101;
            2'b10:   decoder_reg = 4'b1011;
            2'b11:   decoder_reg = 4'b0111;
            default: decoder_reg = 4'b1110;
        endcase
    end
endmodule


module tick_gen_hz (
    input       clk,
    input       rst,
    input       run,
    input [26:0] set_hz_count,

    output reg  tick_hz
);

    reg [26:0]  r_counter;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
            tick_hz <= 0;
        end else begin
            if (run) begin
                if (r_counter >= set_hz_count) begin
                    r_counter <= 0;
                    tick_hz <= 1'b1;
                end else begin
                    r_counter <= r_counter + 1;
                    tick_hz <= 1'b0;
                end 
            end else r_counter <= 0;
        end
    end
endmodule

module tick_gen_1khz (
    input clk,
    input rst,

    output reg tick_1khz
);

    reg [26:0] r_counter;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
            tick_1khz <= 0;
        end else begin
            if (r_counter == 100_000 - 1) begin
                r_counter <= 0;
                tick_1khz <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;
                tick_1khz <= 1'b0;
            end
        end
    end

endmodule
