`timescale 1ns / 1ps

// Testbench for Vending_machine_top
// DUT hierarchy:
//   Vending_machine_top
//     ├── Vending_datapath  (dp)
//     └── Vending_controller (ctrl)

module Vending_machine_tb();

    // Interface signals
    reg        clk, rst;
    reg        buy, coin, pq, go;
    reg [1:0]  s1s2;

    wire [3:0]  D0_AN, D1_AN;
    wire [7:0]  balance_display, return_display;
    wire [1:0]  selected_product_led;
    wire [3:0]  selected_quantity_led;
    wire        done, error, purchase_mode_active, idle_mode_status;

    // Internal probes for waveform visibility
    wire [7:0]  w_balance    = uut.dp.balance;
    wire [7:0]  w_return     = uut.dp.return_display;
    wire [7:0]  w_total_cost = uut.dp.total_cost;
    wire [3:0]  w_stock_p1   = uut.dp.stock_p1;
    wire [3:0]  w_stock_p2   = uut.dp.stock_p2;
    wire [1:0]  w_state      = uut.ctrl.state;

    // DUT
    Vending_machine_top uut (
        .clk                  (clk),
        .rst                  (rst),
        .buy                  (buy),
        .coin                 (coin),
        .pq                   (pq),
        .go                   (go),
        .s1s2                 (s1s2),
        .D0_AN                (D0_AN),
        .balance_display      (balance_display),
        .D1_AN                (D1_AN),
        .return_display       (return_display),
        .selected_product_led (selected_product_led),
        .selected_quantity_led(selected_quantity_led),
        .done                 (done),
        .error                (error),
        .purchase_mode_active (purchase_mode_active),
        .idle_mode_status     (idle_mode_status)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Single-cycle button pulse — no debouncer in top.v
    task pulse_button;
        inout reg btn;
        begin
            @(negedge clk); btn = 1;
            @(negedge clk); btn = 0;
        end
    endtask

    initial begin
        rst  = 1;
        buy  = 0; coin = 0; pq = 0; go = 0;
        s1s2 = 2'b00;
        #50; rst = 0;
        #30;

        $display("=== VENDING MACHINE TESTBENCH ===");

        // S1: Product 1 x1, exact payment (balance=5, cost=5)
        // Expect: done=1, return=0, stock_p1=9
        $display("\n[S1] P1 x1 | 1 coin | Go");
        pulse_button(buy);
        s1s2 = 2'b01;
        #20;
        pulse_button(pq);
        pulse_button(coin);
        #20;
        pulse_button(go);
        #50;
        $display("  done=%b error=%b return=%0d stock_p1=%0d",
                  done, error, w_return, w_stock_p1);
        $display("  expect: done=1 error=0 return=0 stock_p1=9");

        // S2: Product 2 x1, no payment
        // Expect: error=1 (insufficient balance)
        #30;
        $display("\n[S2] P2 x1 | no coin | Go");
        pulse_button(buy);
        s1s2 = 2'b10;
        #20;
        pulse_button(pq);
        pulse_button(go);
        #50;
        $display("  done=%b error=%b balance=%0d cost=%0d",
                  done, error, w_balance, w_total_cost);
        $display("  expect: done=0 error=1");

        // S3: Product 1 x2, overpay (balance=15, cost=10)
        // Expect: done=1, return=5, stock_p1=7
        #30;
        $display("\n[S3] P1 x2 | 3 coins | Go");
        pulse_button(buy);
        s1s2 = 2'b01;
        #20;
        pulse_button(pq);
        pulse_button(pq);
        pulse_button(coin);
        pulse_button(coin);
        pulse_button(coin);
        #20;
        pulse_button(go);
        #50;
        $display("  done=%b error=%b return=%0d stock_p1=%0d",
                  done, error, w_return, w_stock_p1);
        $display("  expect: done=1 error=0 return=5 stock_p1=7");

        // S4: Product 2 x1, exact payment (balance=10, cost=10)
        // Expect: done=1, return=0, stock_p2=9
        #30;
        $display("\n[S4] P2 x1 | 2 coins | Go");
        pulse_button(buy);
        s1s2 = 2'b10;
        #20;
        pulse_button(pq);
        pulse_button(coin);
        pulse_button(coin);
        #20;
        pulse_button(go);
        #50;
        $display("  done=%b error=%b return=%0d stock_p2=%0d",
                  done, error, w_return, w_stock_p2);
        $display("  expect: done=1 error=0 return=0 stock_p2=9");

        // S5: No product selected (s1s2=00), stock_ok fails
        // Expect: error=1
        #30;
        $display("\n[S5] No product | 1 coin | Go");
        pulse_button(buy);
        s1s2 = 2'b00;
        #20;
        pulse_button(pq);
        pulse_button(coin);
        pulse_button(go);
        #50;
        $display("  done=%b error=%b state=%0d",
                  done, error, w_state);
        $display("  expect: done=0 error=1");

        $display("\n=== SIMULATION COMPLETE ===\n");
        #50;
        $finish;
    end

    // State monitor — prints when FSM is active
    always @(posedge clk) begin
        if (purchase_mode_active || done || error)
            $display("T=%0t state=%0d bal=%0d qty=%0d cost=%0d done=%b err=%b",
                $time, w_state, w_balance,
                uut.dp.quantity, w_total_cost, done, error);
    end

    initial begin
        $dumpfile("vending_machine_tb.vcd");
        $dumpvars(0, Vending_machine_tb);
    end

endmodule
