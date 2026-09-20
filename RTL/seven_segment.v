`timescale 1ns / 1ps
module seven_segment (
    input clk,
    input rst,
    input [7:0] number,     // 0-150
    output reg [6:0] seg,
    output reg [3:0] an
);

    // DIGITS //
    reg [3:0] d0, d1, d2, d3;
    reg [3:0] current_digit;

    // REFRESH COUNTER //
    reg [19:0] refresh_cnt;

    wire [1:0] digit_sel;
    assign digit_sel = refresh_cnt[19:18];

    always @(posedge clk or posedge rst) begin
        if (rst)
            refresh_cnt <= 0;
        else
            refresh_cnt <= refresh_cnt + 1;
    end

    // DIGIT EXTRACTION (NO DIVISION) //
    always @(*) begin
        // default
        d3 = 4'd15; // blank

        if (number >= 100) begin
            d2 = 1;

            if (number >= 150) begin
                d1 = 5;
                d0 = number - 150;
            end
            else if (number >= 140) begin d1 = 4; d0 = number - 140; end
            else if (number >= 130) begin d1 = 3; d0 = number - 130; end
            else if (number >= 120) begin d1 = 2; d0 = number - 120; end
            else if (number >= 110) begin d1 = 1; d0 = number - 110; end
            else begin d1 = 0; d0 = number - 100; end

        end else begin
            d2 = 4'd15; // hide leading zero

            if (number >= 90) begin d1 = 9; d0 = number - 90; end
            else if (number >= 80) begin d1 = 8; d0 = number - 80; end
            else if (number >= 70) begin d1 = 7; d0 = number - 70; end
            else if (number >= 60) begin d1 = 6; d0 = number - 60; end
            else if (number >= 50) begin d1 = 5; d0 = number - 50; end
            else if (number >= 40) begin d1 = 4; d0 = number - 40; end
            else if (number >= 30) begin d1 = 3; d0 = number - 30; end
            else if (number >= 20) begin d1 = 2; d0 = number - 20; end
            else if (number >= 10) begin d1 = 1; d0 = number - 10; end
            else begin d1 = 4'd15; d0 = number; end
        end
    end

    //DIGIT SELECT (MUX) //
    always @(*) begin
        case (digit_sel)
            2'b00: begin an = 4'b1110; current_digit = d0; end
            2'b01: begin an = 4'b1101; current_digit = d1; end
            2'b10: begin an = 4'b1011; current_digit = d2; end
            2'b11: begin an = 4'b0111; current_digit = d3; end
        endcase
    end

    // 7-SEG DECODER //
    always @(*) begin
        case (current_digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111; // blank
        endcase
    end

endmodule