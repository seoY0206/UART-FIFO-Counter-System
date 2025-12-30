`timescale 1ns / 1ps

interface uart_fifo_interface;
    logic clk;
    logic rst;
    logic rx;  // input to DUT
    logic tx;  // output from DUT
endinterface


class transaction;
    rand logic [7:0] rx_data;  // generator가 랜덤으로 넣는 데이터
    logic      [7:0] tx_data;  // monitor가 복원한 데이터

    task display(string name_s);
        $display("%t, [%s] tx_data = %d, rx_data = %d", $time, name_s, tx_data,
                 rx_data);
    endtask
endclass


class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event gen_next_event;
    int total_count = 0;
    int unique_count = 0;
    bit [255:0] seen_values;

    string status;  
    string ascii_data;  

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            total_count++;
            tr = new;
            assert (tr.randomize())
            else $display("[GEN] randomize() error!!!");

            if (!seen_values[tr.rx_data]) begin
                status = "new";
                seen_values[tr.rx_data] = 1;
                unique_count++;
            end else begin
                status = "seen";
            end

            if (tr.rx_data >= 32 && tr.rx_data <= 126) begin
                ascii_data = string'(tr.rx_data);
            end else begin
                ascii_data = "N/A";
            end

            $display(
                "[GEN] (%s) dec: %d, hex: %h, bin: %8b, ASCII: %s, Coverage: %.2f%%",
                status, tr.rx_data, tr.rx_data, tr.rx_data, ascii_data,
                (unique_count * 100.0) / 256.0);

            gen2drv_mbox.put(tr);
            gen2scb_mbox.put(tr);

            @gen_next_event;
        end
    endtask
endclass


class driver;
    transaction tr;
    virtual uart_fifo_interface uart_fifo_intf;
    mailbox #(transaction) gen2drv_mbox;
    event mon_next_event;
    int i_drv = 0;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_fifo_interface uart_fifo_intf,
                 event mon_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.uart_fifo_intf = uart_fifo_intf;
        this.mon_next_event = mon_next_event;
    endfunction

    task reset();
        uart_fifo_intf.clk = 0;
        uart_fifo_intf.rst = 1;
        uart_fifo_intf.rx  = 0;

        repeat (2) @(posedge uart_fifo_intf.clk);
        uart_fifo_intf.rst = 0;
        repeat (2) @(posedge uart_fifo_intf.clk);

        $display("[DRV] reset done!");
    endtask

    task run();
        forever begin
            #1;
            gen2drv_mbox.get(tr);
            tr.display("DRV");

            // Start bit
            uart_fifo_intf.rx = 0;
            ->mon_next_event;
            #(104166);

            // 8 Data bits
            for (i_drv = 0; i_drv < 8; i_drv++) begin
                uart_fifo_intf.rx = tr.rx_data[i_drv];
                $display("RX : %d, bit_count : %d", uart_fifo_intf.rx, i_drv);
                #(104166);
            end

            // Stop bit
            uart_fifo_intf.rx = 1;
            #(104166);

            @(posedge uart_fifo_intf.clk);
        end
    endtask
endclass


class monitor;
    transaction tr;
    mailbox #(transaction) mon2scr_mbox;
    virtual uart_fifo_interface uart_fifo_intf;
    event mon_next_event;
    bit [7:0] sampled_data;

    function new(mailbox#(transaction) mon2scr_mbox,
                 virtual uart_fifo_interface uart_fifo_intf,
                 event mon_next_event);
        this.mon2scr_mbox   = mon2scr_mbox;
        this.uart_fifo_intf = uart_fifo_intf;
        this.mon_next_event = mon_next_event;
    endfunction

    task run();
        forever begin
            @(mon_next_event);
            sampled_data = 0;

            // start bit 검출 후 중간에서 샘플링 시작
            wait (uart_fifo_intf.tx == 0);
            #(104166 / 2);

            // 8비트 데이터 수집
            for (int i_mon = 0; i_mon < 8; i_mon++) begin
                #(104166);
                sampled_data[i_mon] = uart_fifo_intf.tx;
            end

            #(104166);  // stop bit

            tr = new();
            tr.tx_data = sampled_data;
            tr.display("MON");
            mon2scr_mbox.put(tr);
        end
    endtask
endclass


class scoreboard;
    transaction gen_tr, mon_tr;
    mailbox #(transaction) mon2scr_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event gen_next_event;

    int pass = 0, fail = 0;

    function new(mailbox#(transaction) mon2scr_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_event);
        this.mon2scr_mbox   = mon2scr_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction

    task run();
        forever begin
            mon2scr_mbox.get(mon_tr);
            gen2scb_mbox.get(gen_tr);

            mon_tr.display("SCB");

            if (gen_tr.rx_data == mon_tr.tx_data) begin
                pass++;
                $display("[SCB] PASS: expected %d == actual %d",
                         gen_tr.rx_data, mon_tr.tx_data);
            end else begin
                fail++;
                $display("[SCB] FAIL: expected %d != actual %d",
                         gen_tr.rx_data, mon_tr.tx_data);
            end
            ->gen_next_event;
        end
    endtask
endclass


class environment;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scr_mbox;
    mailbox #(transaction) gen2scb_mbox;

    event gen_next_event;
    event mon_next_event;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    int count = 0;

    function new(virtual uart_fifo_interface uart_fifo_intf);
        gen2drv_mbox = new();
        mon2scr_mbox = new();
        gen2scb_mbox = new();

        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next_event);
        drv = new(gen2drv_mbox, uart_fifo_intf, mon_next_event);
        mon = new(mon2scr_mbox, uart_fifo_intf, mon_next_event);
        scb = new(mon2scr_mbox, gen2scb_mbox, gen_next_event);
    endfunction

    task report();
        $display("======== test report ==========");
        $display("==     Total test : %3d      ==", gen.total_count);
        $display("==     pass  test : %3d      ==", scb.pass);
        $display("==     fail  test : %3d      ==", scb.fail);
        $display("== Coverage(Unique RX values): %.2f%% ==",
                 100.0 * gen.unique_count / 256.0);

        // 최종적으로 어떤 값들이 나왔는지 출력
        $write("== Values seen: ");
        for (int i = 0; i < 256; i++) begin
            if (gen.seen_values[i]) begin
                $write("%4d ", i);
                count++;
                if ((count % 10) == 0) begin
                    $display("");
                end
            end
        end
        $display("");
        $display("===============================");
    endtask

    task reset();
        drv.reset();
    endtask

    task run();
        fork
            gen.run(1175);
            drv.run();
            mon.run();
            scb.run();
        join_none

        wait(scb.pass + scb.fail == 1175); // 1175: coverage 99.9% 나오는 값
        #(104166 * 2);  // 실제 시뮬은 99.2나왔음
        $display("finished");
        report();
        $stop;
    endtask
endclass


module uart_fifo_tb ();
    environment env;
    uart_fifo_interface uart_fifo_intf_tb ();

    uart_fifo_top_v dut0 (
        .clk(uart_fifo_intf_tb.clk),
        .rst(uart_fifo_intf_tb.rst),
        .rx (uart_fifo_intf_tb.rx),
        .tx (uart_fifo_intf_tb.tx)
    );

    initial uart_fifo_intf_tb.clk = 0;
    always #5 uart_fifo_intf_tb.clk = ~uart_fifo_intf_tb.clk;

    initial begin
        env = new(uart_fifo_intf_tb);
        env.reset();
        env.run();
    end
endmodule