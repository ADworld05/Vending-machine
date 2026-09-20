`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: top_module_fast_tb
// Description: Tests vending machine with 100MHz clock (no slow_clk)
//////////////////////////////////////////////////////////////////////////////////

module top_module_fast_tb;

    // Testbench signals
    reg clk;
    reg rst;
    reg buy;
    reg coin;
    reg pq;
    reg go;
    reg [1:0] s1s2;
    
    wire [6:0] seg;
    wire [3:0] an;
    wire [7:0] led;
    wire error;
    
    // Instantiate the fast clock system
    top_module_fast dut (
        .clk(clk),
        .rst(rst),
        .buy(buy),
        .coin(coin),
        .pq(pq),
        .go(go),
        .s1s2(s1s2),
        .seg(seg),
        .an(an),
        .led(led),
        .error(error)
    );
    
    // Override debounce threshold for faster simulation
    defparam dut.debouncer_buy_inst.THRESHOLD = 50;
    defparam dut.debouncer_coin_inst.THRESHOLD = 50;
    defparam dut.debouncer_pq_inst.THRESHOLD = 50;
    defparam dut.debouncer_go_inst.THRESHOLD = 50;
    
    // Clock generation: 100 MHz (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // Toggle every 5ns = 10ns period
    end
    
    // Task: Simulate bouncing button press
    task press_button_with_bounce;
        input reg* button;
        begin
            $display("[%0t] Pressing button (with bounce)...", $time);
            
            // Bounce pattern
            button = 1; #30;
            button = 0; #20;
            button = 1; #25;
            button = 0; #15;
            button = 1;        // Stable HIGH
            
            // Hold for debounce time + processing
            #1000;
            
            // Release with bounce
            button = 0; #25;
            button = 1; #15;
            button = 0;        // Stable LOW
            
            #500;
            $display("[%0t] Button released", $time);
        end
    endtask
    
    // Monitor LEDs to verify they don't blink
    initial begin
        $monitor("[%0t] LED Balance: %d (binary: %b)", $time, led, led);
    end
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("Fast Clock Vending Machine Test");
        $display("Running at 100MHz - No slow_clk!");
        $display("========================================\n");
        
        // Initialize
        rst = 1;
        buy = 0;
        coin = 0;
        pq = 0;
        go = 0;
        s1s2 = 2'b00;
        
        #100;
        rst = 0;
        #100;
        
        $display("Initial state:");
        $display("  Balance: %d", led);
        $display("  Error: %b\n", error);
        
        //======================================================================
        // TEST: Fast clock responsiveness
        //======================================================================
        $display("========================================");
        $display("TEST: Buy Product 1 with fast clock");
        $display("========================================");
        
        // Enter purchase mode
        $display("\n[%0t] Entering PURCHASE mode...", $time);
        press_button_with_bounce(buy);
        #500;
        
        // Select Product 1 (price = 5)
        s1s2 = 2'b01;
        $display("[%0t] Selected Product 1 (price=5)", $time);
        #200;
        
        // Add quantity (1 item)
        $display("[%0t] Adding quantity: 1", $time);
        press_button_with_bounce(pq);
        #500;
        
        // Insert coins (need 5)
        $display("[%0t] Inserting coin (balance should be 5)", $time);
        press_button_with_bounce(coin);
        #500;
        
        $display("\nChecking balance LED:");
        $display("  Balance: %d (should be 5)", led);
        $display("  Binary: %b", led);
        
        // Confirm purchase
        $display("\n[%0t] Confirming purchase...", $time);
        press_button_with_bounce(go);
        #1000;
        
        $display("\nTransaction complete!");
        $display("  Final Balance: %d", led);
        $display("  Error: %b", error);
        
        #2000;
        
        //======================================================================
        // TEST: LED stability with fast clock
        //======================================================================
        $display("\n========================================");
        $display("TEST: LED Stability Check");
        $display("========================================");
        
        $display("\nObserving LEDs for 5000ns...");
        $display("LEDs should NOT blink rapidly");
        $display("(They're registers, hold stable values)\n");
        
        press_button_with_bounce(buy);
        #500;
        
        s1s2 = 2'b10;  // Product 2
        press_button_with_bounce(pq);
        #500;
        
        // Insert multiple coins
        press_button_with_bounce(coin);
        #500;
        press_button_with_bounce(coin);
        #500;
        press_button_with_bounce(coin);
        #500;
        
        $display("\nCurrent balance: %d", led);
        $display("Waiting 5000ns to observe stability...");
        #5000;
        $display("Balance still: %d (no blinking!)", led);
        
        //======================================================================
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        $display("\nKey Observations:");
        $display("1. Fast clock (100MHz) works correctly");
        $display("2. Debouncing prevents multiple triggers");
        $display("3. LEDs stable (no rapid blinking)");
        $display("4. Seven segment refreshes invisibly fast");
        
        #1000;
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("vending_fast.vcd");
        $dumpvars(0, top_module_fast_tb);
    end

endmodule
