`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: top_module_fast
// Description: Complete vending machine running on 100MHz clock (NO slow_clk)
//
// Key Changes:
// - No slow_clk module - everything runs on 100MHz
// - Debounced buttons prevent multiple triggers
// - LEDs won't blink (they're registers, stable values)
// - Seven segment multiplexes fast (invisible to human eye)
//////////////////////////////////////////////////////////////////////////////////

module top_module_fast (
    input clk,              // 100 MHz system clock
    input rst,              // Reset button
    
    // Raw button inputs (noisy from mechanical buttons)
    input buy,              
    input coin,
    input pq,
    input go,
    input [1:0] s1s2,       // Product selection switches

    // Outputs to FPGA board
    output [6:0] seg,       // Seven-segment display segments
    output [3:0] an,        // Seven-segment display anodes (4 digits)
    output [7:0] led,       // LED outputs (balance display)
    output error            // Error indicator LED
);

    //==========================================================================
    // INTERNAL WIRES
    //==========================================================================
    
    // Debounced button signals
    wire buy_clean;
    wire coin_clean;
    wire pq_clean;
    wire go_clean;
    
    // Vending machine outputs
    wire done;
    wire idle_mode_status;
    wire purchase_mode_active;
    wire [7:0] return_display;
    wire [7:0] balance_display;
    wire [1:0] selected_product_led;
    wire [3:0] selected_quantity_led;

    //==========================================================================
    // BUTTON DEBOUNCERS (100MHz clock, 10ms debounce)
    //==========================================================================
    // These prevent button bounce from causing multiple triggers
    
    debouncer #(
        .COUNTER_WIDTH(20),
        .THRESHOLD(1000000)      // 10ms @ 100MHz = 1,000,000 cycles
    ) debouncer_buy_inst (
        .clk(clk),
        .rst(rst),
        .button_in(buy),
        .button_out(buy_clean)
    );
    
    debouncer #(
        .COUNTER_WIDTH(20),
        .THRESHOLD(1000000)
    ) debouncer_coin_inst (
        .clk(clk),
        .rst(rst),
        .button_in(coin),
        .button_out(coin_clean)
    );
    
    debouncer #(
        .COUNTER_WIDTH(20),
        .THRESHOLD(1000000)
    ) debouncer_pq_inst (
        .clk(clk),
        .rst(rst),
        .button_in(pq),
        .button_out(pq_clean)
    );
    
    debouncer #(
        .COUNTER_WIDTH(20),
        .THRESHOLD(1000000)
    ) debouncer_go_inst (
        .clk(clk),
        .rst(rst),
        .button_in(go),
        .button_out(go_clean)
    );

    //==========================================================================
    // VENDING MACHINE (runs on FAST 100MHz clock now!)
    //==========================================================================
    // Key change: No slow_clk - uses 100MHz directly
    // This makes the system more responsive
    // Debouncing prevents multiple button presses
    
    Vending_machine_v2 vending_machine_inst (
        .clk(clk),                   // ← FAST CLOCK (was slow_clk before)
        .rst(rst),
        .buy(buy_clean),             // Debounced buttons
        .coin(coin_clean),
        .pq(pq_clean),
        .go(go_clean),
        .s1s2(s1s2),                 // Switches don't need debouncing
        
        .done(done),
        .error(error),
        .balance_display(balance_display),
        .return_display(return_display),
        .selected_product_led(selected_product_led),
        .selected_quantity_led(selected_quantity_led),
        .purchase_mode_active(purchase_mode_active),
        .idle_mode_status(idle_mode_status)
    );

    //==========================================================================
    // SEVEN SEGMENT DISPLAY (shows return/change amount, 0-150)
    //==========================================================================
    // Uses fast clock for multiplexing (invisible refresh)
    // Already supports 0-150 range!
    
    seven_segment seven_seg_inst (
        .clk(clk),                   // 100MHz for fast refresh
        .rst(rst),
        .number(return_display),     // Shows change returned
        .seg(seg),
        .an(an)
    );

    //==========================================================================
    // LED OUTPUT (shows current balance, 0-255)
    //==========================================================================
    // These LEDs won't blink fast because:
    // 1. balance_display is a REGISTER (holds stable value)
    // 2. Changes only when FSM updates it
    // 3. Not affected by fast clock - just displays current value
    
    assign led = balance_display;

endmodule
