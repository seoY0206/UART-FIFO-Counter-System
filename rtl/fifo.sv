`timescale 1ns / 1ps

module fifo (
    input  logic       clk,
    input  logic       rst,
    input  logic       wr,
    input  logic       rd,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,
    output logic       full,
    output logic       empty
);

    logic [2:0] waddr, raddr;
    logic wr_en;

    assign wr_en = wr & ~full;

    register_file U_REG_FILE (
        .*,
        .wr(wr_en)
    );
    fifo_control_unit U_FIFO_CU (.*);
endmodule


module register_file #(
    parameter DEPTH = 8,
    AWIDTH = 3
) (
    input  logic               clk,
    input  logic               wr,
    input  logic [AWIDTH -1:0] waddr,
    input  logic [AWIDTH -1:0] raddr,
    input  logic [  DEPTH-1:0] wdata,
    output logic [  DEPTH-1:0] rdata
);
    logic [7:0] ram[0:DEPTH - 1];

    assign rdata = ram[raddr];

    always_ff @(posedge clk) begin
        if (wr) begin
            ram[waddr] <= wdata;
        end
    end
endmodule


module fifo_control_unit #(
    parameter AWIDTH = 3
) (
    input  logic              clk,
    input  logic              rst,
    input  logic              wr,
    input  logic              rd,
    output logic [AWIDTH-1:0] waddr,
    output logic [AWIDTH-1:0] raddr,
    output logic              full,
    output logic              empty
);

    logic [AWIDTH-1:0] waddr_reg, waddr_next;
    logic [AWIDTH-1:0] raddr_reg, raddr_next;
    logic full_reg, full_next;
    logic empty_reg, empty_next;

    assign waddr = waddr_reg;
    assign raddr = raddr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            waddr_reg <= 0;
            raddr_reg <= 0;
            full_reg  <= 0;
            empty_reg <= 1'b1;
        end else begin
            waddr_reg <= waddr_next;
            raddr_reg <= raddr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always_comb begin
        waddr_next = waddr_reg;
        raddr_next = raddr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            wr, rd
        })
            //pop 
            2'b01: begin
                if (!empty_reg) begin
                    raddr_next = raddr_reg + 1;
                    full_next  = 1'b0;
                    if (waddr_reg == raddr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end

            //push 
            2'b10: begin
                if (!full_reg) begin
                    waddr_next = waddr_reg + 1;
                    empty_next = 1'b0;
                    if (raddr_reg == waddr_next) begin
                        full_next = 1'b1;
                    end
                end
            end

            //pop&push
            2'b11: begin
                if (full_reg) begin
                    raddr_next = raddr_reg + 1;
                    full_next  = 1'b0;
                end else if (empty_reg) begin
                    waddr_next = waddr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    raddr_next = raddr_reg + 1;
                    waddr_next = waddr_reg + 1;
                end
            end
        endcase
    end
endmodule