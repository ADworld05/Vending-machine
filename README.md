# Vending Machine Controller — Verilog HDL on Artix-7 FPGA

A hardware Finite State Machine (FSM) based vending machine controller implemented in Verilog HDL and deployed on a Xilinx Artix-7 FPGA. The design supports two products, coin-based balance accumulation, quantity selection, stock management, change return, and a counter-based mechanical button debouncer running on a single 100 MHz clock domain.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Module Descriptions](#module-descriptions)
- [FSM — States and Transitions](#fsm--states-and-transitions)
- [Debouncer](#debouncer)
- [I/O Port Reference](#io-port-reference)
- [Pin Constraints — Artix-7](#pin-constraints--artix-7)
- [Simulation and Implementation — Vivado](#simulation-and-implementation--vivado)
- [Author](#author)

---

## Overview

The vending machine accepts two products at configurable prices, accumulates a coin-based balance, tracks per-product stock, and calculates change on successful transactions. All mechanical button inputs are debounced in hardware using a counter-based filter tuned to the 100 MHz system clock, eliminating the need for a divided slow clock and ensuring glitch-free FSM transitions.

---

## Features

- Four-state Moore FSM: `IDLE → PURCHASE → DONE / ERROR`
- Two independently priced and stocked products selectable via switches
- Coin insertion accumulates balance in units of 5
- Per-product quantity selection with LED feedback
- Automatic change calculation and display on seven-segment output
- Counter-based hardware debouncer (10 ms filter) on all four button inputs
- Single 100 MHz clock domain — no clock divider required
- Multiplexed four-digit seven-segment display supporting values 0–150
- Binary-encoded balance readout on 8-bit LED bar

---

## Repository Structure

```
Vending-machine/
│
├── README.md
│
├── RTL/
│   ├── debouncer.v            Counter-based button debouncer (24 FFs per instance)
│   ├── Vending_machine_v2.v   Core FSM — state, datapath, stock management
│   ├── seven_segment.v        Multiplexed 4-digit 7-segment display driver (0–150)
│   ├── top_module_fast.v      Top-level integration, 100 MHz, no slow clock
│   └── top_module_fast_tb.v   Simulation testbench
│
└── Constraints/
    └── vending.xdc            Xilinx pin and timing constraints for Artix-7
```

---

## Module Descriptions

| Module                 | File                     | Clock    | Description                                                                                                                                                                       |
|:-----------------------|:-------------------------|:--------:|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `debouncer`            | `debouncer.v`            | 100 MHz  | Counter-based mechanical bounce filter. 3-FF synchroniser chain followed by a 20-bit stability counter and one output FF — 24 FFs per instance. Instantiated ×4 for buy, coin, pq, go. |
| `Vending_machine_v2`   | `Vending_machine_v2.v`   | 100 MHz  | Core FSM with sequential datapath. Three always blocks: state register, combinational next-state logic, and sequential output and datapath. Manages balance, quantity, stock, and change. |
| `seven_segment`        | `seven_segment.v`        | 100 MHz  | Multiplexed 4-digit display driver. 20-bit refresh counter drives a 4-to-1 digit MUX. Digit extraction via cascaded comparators — no division. Supports 0–150 with leading-zero blanking. |
| `top_module_fast`      | `top_module_fast.v`      | 100 MHz  | Top-level integration. Routes raw button inputs through debouncers into the FSM. Sends balance to the LED bar and return amount to the seven-segment display. No slow clock instantiated.  |

---

## FSM — States and Transitions

The controller uses a four-state Moore FSM encoded in 2 bits. Outputs are registered and updated on the clock edge, keeping the datapath free of combinational glitches.

| State      | Encoding | Entry Condition                                        | Actions on Entry                                       |
|:-----------|:--------:|:-------------------------------------------------------|:-------------------------------------------------------|
| `IDLE`     | `2'b00`  | Reset asserted, or auto-transition from DONE / ERROR   | Clears balance, quantity, product LEDs to zero         |
| `PURCHASE` | `2'b01`  | `buy = 1` while in IDLE                                | Accumulates coins, increments quantity, selects product |
| `DONE`     | `2'b10`  | `go = 1` AND balance ≥ total cost AND stock ≥ quantity | Deducts stock, computes change, drives seven-segment   |
| `ERROR`    | `2'b11`  | `go = 1` AND (balance < cost OR stock < quantity)      | Asserts error output, returns full balance on display  |

**Transition summary:**

- From `IDLE` — pressing `buy` moves to `PURCHASE`. All transaction registers are held at zero until then.
- From `PURCHASE` — coins and quantity accumulate on each debounced pulse. Pressing `go` evaluates the transaction and branches to either `DONE` or `ERROR`.
- From `DONE` — stock is decremented by the purchased quantity and change is written to the display. The FSM auto-returns to `IDLE` on the next clock cycle.
- From `ERROR` — the error LED is asserted and the full balance is shown on the display as the return amount. The FSM auto-returns to `IDLE` on the next clock cycle.

---

## Debouncer

Each of the four button inputs (`buy`, `coin`, `pq`, `go`) is connected to a dedicated debouncer instance before the signal reaches the FSM. The design runs at 100 MHz, so without debouncing a single physical press would register thousands of false edges during the mechanical bounce window of 5–20 ms.

**How it works:**

- The raw button signal first passes through a chain of three flip-flops (synchroniser). This prevents metastability — the undefined state a flip-flop can enter when an asynchronous signal arrives near a clock edge. Three stages bring the probability of metastability failure down to approximately 10⁻¹⁵.
- A change detector (XOR gate) compares the synchronised input against the current debounced output. If they differ, the counter is reset to zero. If they match, the counter increments by one each clock cycle.
- The counter is 20 bits wide, allowing it to count to 1,048,576. At 100 MHz each count represents 10 ns, so reaching 1,000,000 corresponds to exactly 10 ms of stable input.
- Only when the counter reaches the threshold of 1,000,000 does the output flip-flop update to the new value. Any bounce that causes the input to change before the threshold is reached will reset the counter and restart the 10 ms window from zero.
- The result is one clean, registered edge per physical button press, regardless of how long or how severely the contacts bounce.

**Flip-flop count per instance:**

| Stage               | Flip-Flops |
|:--------------------|:----------:|
| Synchroniser chain  | 3          |
| Stability counter   | 20         |
| Output register     | 1          |
| **Total per button**| **24**     |

With four buttons, the debouncer block uses 96 flip-flops in total.

---

## I/O Port Reference

### Inputs

| Port     | Width  | Type    | Description                                              |
|:---------|:------:|:--------|:---------------------------------------------------------|
| `clk`    | 1-bit  | Clock   | 100 MHz system clock                                     |
| `rst`    | 1-bit  | Async   | Active-high asynchronous reset                           |
| `buy`    | 1-bit  | Button  | Enter purchase mode (debounced internally)               |
| `coin`   | 1-bit  | Button  | Insert one coin — adds 5 to balance (debounced)          |
| `pq`     | 1-bit  | Button  | Increment quantity by 1 (debounced)                      |
| `go`     | 1-bit  | Button  | Confirm and execute transaction (debounced)              |
| `s1s2`   | 2-bit  | Switch  | Product select — `01` = Product 1, `10` = Product 2     |

### Outputs

| Port       | Width  | Description                                               |
|:-----------|:------:|:----------------------------------------------------------|
| `seg[6:0]` | 7-bit  | Seven-segment cathode signals (active-low)                |
| `an[3:0]`  | 4-bit  | Seven-segment anode enables (active-low, multiplexed)     |
| `led[7:0]` | 8-bit  | Binary balance display on LED bar                         |
| `error`    | 1-bit  | High when transaction fails (insufficient balance/stock)  |

---

## Pin Constraints — Artix-7

### Clock

| Signal  | FPGA Pin | Standard  | Frequency |
|:--------|:--------:|:----------|:---------:|
| `clk`   | F14      | LVCMOS33  | 100 MHz   |

### Button Inputs

| Signal  | FPGA Pin | Standard  |
|:--------|:--------:|:----------|
| `rst`   | J2       | LVCMOS33  |
| `buy`   | U1       | LVCMOS33  |
| `coin`  | H2       | LVCMOS33  |
| `go`    | J1       | LVCMOS33  |
| `pq`    | J5       | LVCMOS33  |

### Switch Inputs

| Signal     | FPGA Pin | Standard  |
|:-----------|:--------:|:----------|
| `s1s2[0]`  | V2       | LVCMOS33  |
| `s1s2[1]`  | U2       | LVCMOS33  |

### LED Outputs — Balance Display

| Signal    | FPGA Pin | Standard  |
|:----------|:--------:|:----------|
| `led[0]`  | G1       | LVCMOS33  |
| `led[1]`  | G2       | LVCMOS33  |
| `led[2]`  | F1       | LVCMOS33  |
| `led[3]`  | F2       | LVCMOS33  |
| `led[4]`  | E1       | LVCMOS33  |
| `led[5]`  | E2       | LVCMOS33  |
| `led[6]`  | E3       | LVCMOS33  |
| `led[7]`  | E5       | LVCMOS33  |

### Seven-Segment Display

| Signal    | FPGA Pin | Standard  |
|:----------|:--------:|:----------|
| `seg[0]`  | D7       | LVCMOS33  |
| `seg[1]`  | C5       | LVCMOS33  |
| `seg[2]`  | A5       | LVCMOS33  |
| `seg[3]`  | B7       | LVCMOS33  |
| `seg[4]`  | A7       | LVCMOS33  |
| `seg[5]`  | D6       | LVCMOS33  |
| `seg[6]`  | B5       | LVCMOS33  |
| `an[0]`   | D5       | LVCMOS33  |
| `an[1]`   | C4       | LVCMOS33  |
| `an[2]`   | C7       | LVCMOS33  |
| `an[3]`   | A8       | LVCMOS33  |

### Error LED

| Signal   | FPGA Pin | Standard  |
|:---------|:--------:|:----------|
| `error`  | A4       | LVCMOS33  |

---

## Simulation and Implementation — Vivado

**Step 1 — Create Project**

Open Xilinx Vivado and create a new RTL project targeting the Artix-7 device on your board.

**Step 2 — Add Design Sources**

Add the following files from `RTL/` as design sources:

```
RTL/debouncer.v
RTL/Vending_machine_v2.v
RTL/seven_segment.v
RTL/top_module_fast.v
```

Add `RTL/top_module_fast_tb.v` as a simulation-only source.

**Step 3 — Add Constraints**

Add `Constraints/vending.xdc` as the constraint source.

**Step 4 — Set Top Module**

Set `top_module_fast` as the top module for synthesis and implementation.

**Step 5 — Simulate**

In the Flow Navigator, select **Run Simulation → Run Behavioral Simulation**. Vivado will compile and open the waveform viewer automatically. Add the following signals to verify correct behaviour:

| Signal Group  | Signals to Add                                             |
|:--------------|:-----------------------------------------------------------|
| Clock & Reset | `clk`, `rst`                                               |
| Raw Buttons   | `buy`, `coin`, `pq`, `go`                                  |
| Debounced     | `buy_clean`, `coin_clean`, `pq_clean`, `go_clean`          |
| FSM           | `current_state`, `next_state`                              |
| Datapath      | `balance_display`, `return_display`, `quantity_p1`         |
| Outputs       | `led`, `error`, `seg`, `an`                                |

**Step 6 — Implement and Program**

```
Synthesize Design  →  Implement Design  →  Generate Bitstream  →  Program Device
```

---

## Author

**Abir Dutta**  
B.Tech Electronics and Communication Engineering  
NIT Durgapur
