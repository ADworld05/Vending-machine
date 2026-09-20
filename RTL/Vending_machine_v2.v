`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Vending_machine_v2
// Description: Improved vending machine with proper FSM structure
// Based on: vending.v (fixed and enhanced)
//
// Features:
// - Two products with individual quantity tracking
// - Proper state machine (IDLE, PURCHASE, DONE, ERROR)
// - Product selection via s1s2 switches
// - Coin insertion and quantity selection
// - Stock management per product
//////////////////////////////////////////////////////////////////////////////////

module Vending_machine_v2 (
    input clk,
    input rst,
    input coin,           // Add coin (debounced)
    input pq,             // Increment quantity (debounced)
    input buy,            // Enter purchase mode (debounced)
    input go,             // Confirm transaction (debounced)
    input [1:0] s1s2,     // Product selection: 01=P1, 10=P2
    
    output reg done,
    output reg error,
    output reg [7:0] balance_display,
    output reg [7:0] return_display,
    output reg [1:0] selected_product_led,
    output reg [3:0] selected_quantity_led,
    output reg purchase_mode_active,
    output reg idle_mode_status    
);

    //==========================================================================
    // STATE ENCODING
    //==========================================================================
    parameter IDLE     = 2'b00;
    parameter PURCHASE = 2'b01;
    parameter DONE     = 2'b10;
    parameter ERROR    = 2'b11;

    //==========================================================================
    // PRODUCT PRICES (FIXED)
    //==========================================================================
    parameter PRICE_P1 = 8'd5;   // Product 1 costs 5 units
    parameter PRICE_P2 = 8'd10;  // Product 2 costs 10 units

    //==========================================================================
    // STATE REGISTERS
    //==========================================================================
    reg [1:0] current_state, next_state;

    //==========================================================================
    // INTERNAL REGISTERS
    //==========================================================================
    reg [7:0] quantity_p1;       // Quantity selected for product 1
    reg [7:0] quantity_p2;       // Quantity selected for product 2
    reg [7:0] stock_p1;          // Available stock for product 1
    reg [7:0] stock_p2;          // Available stock for product 2
    
    //==========================================================================
    // COMBINATIONAL LOGIC: Calculate total cost
    //==========================================================================
    wire [7:0] total_cost;
    wire sufficient_balance;
    wire sufficient_stock;
    
    assign total_cost = (PRICE_P1 * quantity_p1) + (PRICE_P2 * quantity_p2);
    assign sufficient_balance = (balance_display >= total_cost);
    assign sufficient_stock = (stock_p1 >= quantity_p1) && (stock_p2 >= quantity_p2);

    //==========================================================================
    // STATE REGISTER (SEQUENTIAL)
    //==========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    //==========================================================================
    // NEXT STATE LOGIC (COMBINATIONAL)
    //==========================================================================
    always @(*) begin
        next_state = current_state;  // Default: stay in current state
        
        case (current_state)
            IDLE: begin
                if (buy)
                    next_state = PURCHASE;
            end

            PURCHASE: begin
                if (go) begin
                    if (sufficient_balance && sufficient_stock)
                        next_state = DONE;
                    else
                        next_state = ERROR;
                end
            end

            DONE: begin
                next_state = IDLE;  // Auto-transition back to IDLE
            end

            ERROR: begin
                next_state = IDLE;  // Auto-transition back to IDLE
            end
            
            default: next_state = IDLE;
        endcase
    end

    //==========================================================================
    // OUTPUT AND DATAPATH LOGIC (SEQUENTIAL)
    //==========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all values
            balance_display <= 8'd0;
            return_display <= 8'd0;
            quantity_p1 <= 8'd0;
            quantity_p2 <= 8'd0;
            stock_p1 <= 8'd10;         // Initial stock
            stock_p2 <= 8'd10;         // Initial stock
            
            idle_mode_status <= 1'b1;
            purchase_mode_active <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            selected_product_led <= 2'b00;
            selected_quantity_led <= 4'd0;
        end
        else begin
            // Default outputs
            idle_mode_status <= 1'b0;
            purchase_mode_active <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;

            case (current_state)
                //--------------------------------------------------------------
                IDLE: begin
                    idle_mode_status <= 1'b1;
                    
                    // Reset transaction values
                    balance_display <= 8'd0;
                    return_display <= 8'd0;
                    quantity_p1 <= 8'd0;
                    quantity_p2 <= 8'd0;
                    selected_product_led <= 2'b00;
                    selected_quantity_led <= 4'd0;
                end

                //--------------------------------------------------------------
                PURCHASE: begin
                    purchase_mode_active <= 1'b1;
                    
                    // Add coins
                    if (coin) begin
                        balance_display <= balance_display + 8'd5;
                    end
                    
                    // Product selection and quantity increment
                    if (s1s2 == 2'b01) begin
                        // Product 1 selected
                        selected_product_led <= 2'b01;
                        
                        if (pq) begin
                            quantity_p1 <= quantity_p1 + 8'd1;
                        end
                        
                        selected_quantity_led <= quantity_p1[3:0];
                    end
                    else if (s1s2 == 2'b10) begin
                        // Product 2 selected
                        selected_product_led <= 2'b10;
                        
                        if (pq) begin
                            quantity_p2 <= quantity_p2 + 8'd1;
                        end
                        
                        selected_quantity_led <= quantity_p2[3:0];
                    end
                end

                //--------------------------------------------------------------
                DONE: begin
                    done <= 1'b1;
                    
                    // Update stock
                    stock_p1 <= stock_p1 - quantity_p1;
                    stock_p2 <= stock_p2 - quantity_p2;
                    
                    // Calculate and return change
                    return_display <= balance_display - total_cost;
                end

                //--------------------------------------------------------------
                ERROR: begin
                    error <= 1'b1;
                    
                    // Return all money (no stock deduction)
                    return_display <= balance_display;
                end
            endcase
        end
    end

endmodule
