`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: debouncer
// Description: Counter-based debouncer for mechanical button inputs
// 
// How it works:
// 1. Synchronizer: 3 cascaded FFs prevent metastability
// 2. Change detector: XOR compares sync input vs current output
// 3. Counter: Counts stable time (resets on change, increments when stable)
// 4. Threshold: When counter >= THRESHOLD, update output
//
// For 100 MHz clock:
// - 10ms debounce requires counting to 1,000,000 (default)
// - 5ms debounce requires counting to 500,000
// - 20ms debounce requires counting to 2,000,000
//////////////////////////////////////////////////////////////////////////////////

module debouncer #(
    parameter COUNTER_WIDTH = 20,                    // 20 bits for counting to 1M
    parameter THRESHOLD = 1000000                    // 10ms @ 100MHz
)(
    input  wire clk,                                 // System clock (100 MHz)
    input  wire rst,                                 // Async reset
    input  wire button_in,                           // Raw noisy button input
    output reg  button_out                           // Clean debounced output
);

    //==========================================================================
    // STAGE 1: SYNCHRONIZER (Metastability Protection)
    //==========================================================================
    // Three cascaded flip-flops to prevent metastability when sampling
    // asynchronous button input
    
    reg sync_ff1;  // First synchronizer stage
    reg sync_ff2;  // Second synchronizer stage  
    reg sync_ff3;  // Third synchronizer stage (synchronized output)
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
            sync_ff3 <= 1'b0;
        end
        else begin
            sync_ff1 <= button_in;      // Sample the async input
            sync_ff2 <= sync_ff1;       // Propagate through chain
            sync_ff3 <= sync_ff2;       // Final synchronized value
        end
    end
    
    //==========================================================================
    // STAGE 2: CHANGE DETECTION
    //==========================================================================
    // Detect when synchronized input differs from current debounced output
    
    wire input_changed;
    wire input_stable;
    
    assign input_changed = (sync_ff3 != button_out);  // XOR logic
    assign input_stable  = ~input_changed;            // Inverted
    
    //==========================================================================
    // STAGE 3: STABILITY COUNTER
    //==========================================================================
    // Count how many clock cycles the input has been stable
    // Reset to 0 when input changes
    // Increment when input is stable
    
    reg [COUNTER_WIDTH-1:0] counter;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= {COUNTER_WIDTH{1'b0}};
        end
        else begin
            if (input_changed) begin
                // Input changed - reset counter
                counter <= {COUNTER_WIDTH{1'b0}};
            end
            else if (input_stable && counter < THRESHOLD) begin
                // Input stable and haven't reached threshold - increment
                counter <= counter + 1'b1;
            end
            // else: counter holds at THRESHOLD (or above)
        end
    end
    
    //==========================================================================
    // STAGE 4: OUTPUT UPDATE
    //==========================================================================
    // Only update output when counter reaches threshold
    // This ensures input has been stable for the full debounce period
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            button_out <= 1'b0;
        end
        else begin
            if (counter >= THRESHOLD) begin
                // Input has been stable long enough - update output
                button_out <= sync_ff3;
            end
            // else: output holds previous value
        end
    end

endmodule
