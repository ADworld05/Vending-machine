`timescale 1ns / 1ps
module Vending_controller(
    input clk, rst,
    input buy, go,
    input enough_balance, stock_ok,

    output reg clr,
    output reg ld_balance,
    output reg inc_qty,
    output reg calc,
    output reg update_stock,

    output reg done,
    output reg error,
    output reg purchase_mode_active,
    output reg idle_mode_status
);

parameter IDLE = 2'b00;
parameter PURCHASE = 2'b01;
parameter DONE = 2'b10;
parameter ERROR = 2'b11;

reg [1:0] state, next_state;

always @(posedge clk) begin
    if(rst)
        state <= IDLE;
    else
        state <= next_state;
end


always @(*) begin
    case(state)
    IDLE:
        next_state = (buy) ? PURCHASE : IDLE;
    PURCHASE:
        if(go) begin
            if(enough_balance && stock_ok) next_state = DONE;
            else next_state = ERROR;
        end
        else
            next_state = PURCHASE;
    DONE:  next_state = IDLE;
    ERROR: next_state = IDLE;
    default: next_state = IDLE;
    endcase
end

always @(posedge clk) begin
    if(rst) begin
        done <= 0;
        error <= 0;
    end
    else begin
        done <= 0;
        error <= 0;
        
        if(state == PURCHASE && go && enough_balance && stock_ok) done <= 1;
        if(state == PURCHASE && go && !(enough_balance && stock_ok)) error <= 1;
    end
end

always @(*) begin
    clr = 0;
    ld_balance = 0;
    inc_qty = 0;
    calc = 0;
    update_stock = 0;

    purchase_mode_active = 0;
    idle_mode_status = 0;

    case(state)
    IDLE: begin
        idle_mode_status = 1;
        clr = 1;
    end
    PURCHASE: begin
        purchase_mode_active = 1;
        ld_balance = 1;
        inc_qty = 1;
        calc = 1;
    end
    DONE: update_stock = 1;
    ERROR:  ;
    endcase
end

endmodule