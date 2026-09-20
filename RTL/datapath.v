`timescale 1ns / 1ps
module Vending_datapath(
    input clk, rst,
    input coin, pq,
    input [1:0] s1s2,

    input clr,
    input ld_balance,
    input inc_qty,
    input calc,
    input update_stock,

    output reg [7:0] balance_display,
    output reg [7:0] return_display,
    output reg [3:0] quantity,

    output enough_balance,
    output stock_ok
);

parameter P1_PRICE = 5;
parameter P2_PRICE = 10;

reg [7:0] balance, total_cost, price;
reg [3:0] stock_p1, stock_p2;

always @(posedge clk) begin
    if(rst) begin
        balance <= 0;
        quantity <= 0;
        stock_p1 <= 10;
        stock_p2 <= 10;
        return_display <= 0;
    end
    else begin
        if(clr) begin
            balance <= 0;
            quantity <= 0;
        end
        if(ld_balance && coin) balance <= balance + 5;

        if(inc_qty && pq) quantity <= quantity + 1;

        case(s1s2)
            2'b01: price <= P1_PRICE;
            2'b10: price <= P2_PRICE;
            default: price <= 0;
        endcase

        if(calc) total_cost <= price * quantity;

        if(update_stock) begin
            return_display <= balance - total_cost;

            if(s1s2 == 2'b01) stock_p1 <= stock_p1 - quantity;
            else if(s1s2 == 2'b10) stock_p2 <= stock_p2 - quantity;
        end
    end
end


always @(*)
    balance_display = balance;


assign enough_balance = (balance >= total_cost);

assign stock_ok =
    (s1s2 == 2'b01 && stock_p1 >= quantity) ||
    (s1s2 == 2'b10 && stock_p2 >= quantity);

endmodule