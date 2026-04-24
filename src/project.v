// // /*
// //  * Copyright (c) 2024 Your Name
// //  * SPDX-License-Identifier: Apache-2.0
// //  */

// // `default_nettype none

// // module tt_um_example (
// //     input  wire [7:0] ui_in,    // Dedicated inputs
// //     output wire [7:0] uo_out,   // Dedicated outputs
// //     input  wire [7:0] uio_in,   // IOs: Input path
// //     output wire [7:0] uio_out,  // IOs: Output path
// //     output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
// //     input  wire       ena,      // always 1 when the design is powered, so you can ignore it
// //     input  wire       clk,      // clock
// //     input  wire       rst_n     // reset_n - low to reset
// // );

// //   // All output pins must be assigned. If not used, assign to 0.
// //   assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
// //   assign uio_out = 0;
// //   assign uio_oe  = 0;

// //   // List all unused inputs to prevent warnings
// //   wire _unused = &{ena, clk, rst_n, 1'b0};

// // endmodule

// /*
//  * SPDX-License-Identifier: Apache-2.0
//  */

// `default_nettype none

// module tt_um_ganesh_birthday_detector (
//     input  wire [7:0] ui_in,     // ui_in[0] = serial input
//     output wire [7:0] uo_out,    // outputs
//     input  wire [7:0] uio_in,    // unused
//     output wire [7:0] uio_out,   // unused
//     output wire [7:0] uio_oe,    // unused
//     input  wire       ena,
//     input  wire       clk,
//     input  wire       rst_n
// );

//     // Internal signals
//     reg [8:0] shift_reg;
//     reg [7:0] counter;
//     reg match;

//     wire serial_in = ui_in[0];

//     parameter [8:0] BIRTHDAY = 9'b001100111;

//     // Main logic
//     always @(posedge clk) begin
//         if (!rst_n) begin
//             shift_reg <= 0;
//             counter   <= 0;
//             match     <= 0;
//         end else begin
//             // Shift register
//             shift_reg <= {serial_in, shift_reg[8:1]};

//             // Pattern detect
//             if (shift_reg == BIRTHDAY) begin
//                 match   <= 1;
//                 counter <= counter + 1;
//             end else begin
//                 match <= 0;
//             end
//         end
//     end

//     // Outputs
//     assign uo_out[0] = match;          // match flag
//     assign uo_out[7:1] = counter[6:0]; // count (7 bits)

//     // Unused IOs
//     assign uio_out = 0;
//     assign uio_oe  = 0;

//     wire _unused = &{ena, uio_in};

// endmodule
/*
 * Copyright (c) 2024 Student
 * SPDX-License-Identifier: Apache-2.0
 *
 * Happy Birthday Detector — Tiny Tapeout Wrapper
 *
 * Birthday : March 7 (03/07/2005)
 * Pattern  : Month=3 (0011) + Date=7 (00111) = 9'b001100111
 *
 * ── Pin Mapping ──────────────────────────────────────────
 *
 * INPUTS  (ui_in):
 *   ui_in[0]  = i_tx_ena_n   (active-low transmit enable)
 *   ui_in[7:1] = unused
 *
 * INPUTS  (uio_in):
 *   uio_in    = unused
 *
 * OUTPUTS (uo_out):
 *   uo_out[6:0] = units digit 7-segment code  (active low)
 *   uo_out[7]   = o_hit_count_valid
 *
 * OUTPUTS (uio_out):
 *   uio_out[6:0] = tens digit 7-segment code  (active low)
 *   uio_out[7]   = 0 (unused)
 *
 * CONTROL:
 *   clk   = 10 kHz system clock
 *   rst_n = active-low reset (Tiny Tapeout standard)
 *
 * ─────────────────────────────────────────────────────────
 */

`default_nettype none

module tt_um_happy_birthday (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // 10 kHz system clock
    input  wire       rst_n     // active-low reset
);

    // ── Parameter: your birthday pattern ─────────────────
    localparam [8:0] BIRTHDAY = 9'b001100111;  // March(0011) + 7(00111)
    localparam       CLK_FREQ = 10000;         // 10 kHz → 1 sec = 10000 cycles

    // ── Internal reset (active high for our modules) ──────
    wire i_rst = ~rst_n;

    // ── Pin mapping ───────────────────────────────────────
    wire i_tx_ena_n = ui_in[0];   // transmit enable (active low)

    // ── Internal wires ────────────────────────────────────
    wire [9:0] w_tx_data;
    wire       w_tx_done;
    wire       w_serial;
    wire       w_match;
    wire [7:0] w_count;
    wire       w_valid;
    wire [6:0] w_seg_tens;
    wire [6:0] w_seg_units;

    // ── TX Generator: 10-bit counter 0–1023 ──────────────
    tx_generator gen (
        .i_clk    (clk),
        .i_rst    (i_rst),
        .i_tx_done(w_tx_done),
        .o_data   (w_tx_data)
    );

    // ── TX Serializer: parallel→serial, LSB first ─────────
    tx_serializer ser (
        .i_clk     (clk),
        .i_rst     (i_rst),
        .i_tx_ena_n(i_tx_ena_n),
        .i_data    (w_tx_data),
        .o_serial  (w_serial),
        .o_tx_done (w_tx_done)
    );

    // ── RX Detector: 9-bit shift-register comparator ──────
    rx_detector #(
        .BIRTHDAY(BIRTHDAY)
    ) det (
        .i_clk   (clk),
        .i_rst   (i_rst),
        .i_serial(w_serial),
        .o_match (w_match)
    );

    // ── Hit Counter: counts matches, latches every 1 sec ──
    hit_counter #(
        .CLK_FREQ(CLK_FREQ)
    ) cnt (
        .i_clk          (clk),
        .i_rst          (i_rst),
        .i_match        (w_match),
        .o_count_latched(w_count),
        .o_valid        (w_valid)
    );

    // ── 7-Segment Driver: count → display codes ───────────
    seg7_driver seg (
        .i_count    (w_count),
        .o_seg_tens (w_seg_tens),
        .o_seg_units(w_seg_units)
    );

    // ── Output assignments ────────────────────────────────
    assign uo_out[6:0] = w_seg_units;   // units digit on dedicated out
    assign uo_out[7]   = w_valid;       // valid pulse on MSB

    assign uio_out[6:0] = w_seg_tens;   // tens digit on bidir out
    assign uio_out[7]   = 1'b0;

    assign uio_oe = 8'b0111_1111;       // uio[6:0] = output, uio[7] = input

    // ── Suppress unused input warnings ────────────────────
    wire _unused = &{ena, ui_in[7:1], uio_in, 1'b0};

endmodule
