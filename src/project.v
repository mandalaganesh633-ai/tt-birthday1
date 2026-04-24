/*
 * Copyright (c) 2024 Ganesh
 * SPDX-License-Identifier: Apache-2.0
 *
 * Happy Birthday Detector — Tiny Tapeout Single File
 *
 * Birthday : March 7 (03/07/2005)
 * Pattern  : Month=3 (0011) + Date=7 (00111) = 9'b001100111
 *
 * ── Pin Mapping ──────────────────────────────────────────
 *  ui_in[0]     = tx_ena_n (active-low transmit enable)
 *  ui_in[7:1]   = unused
 *
 *  uo_out[6:0]  = units digit 7-segment (active low, gfedcba)
 *  uo_out[7]    = hit_count_valid (pulses HIGH each second)
 *
 *  uio_out[6:0] = tens digit 7-segment (active low, gfedcba)
 *  uio_out[7]   = 0 (unused)
 *  uio_oe       = 8'b0111_1111 (uio[6:0]=output, uio[7]=input)
 *
 *  clk          = 10 kHz system clock
 *  rst_n        = active-low reset (Tiny Tapeout standard)
 * ─────────────────────────────────────────────────────────
 */

`default_nettype none

// ═══════════════════════════════════════════════════════════
// MODULE 1 — TX Generator
// 10-bit counter (0–1023), increments on tx_done pulse
// ═══════════════════════════════════════════════════════════
module tx_generator (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_tx_done,
    output reg  [9:0]  o_data
);
    always @(posedge i_clk) begin
        if (i_rst)
            o_data <= 10'd0;
        else if (i_tx_done)
            o_data <= o_data + 1'b1;   // wraps 1023 → 0 automatically
    end
endmodule


// ═══════════════════════════════════════════════════════════
// MODULE 2 — TX Serializer
// Sends 10-bit word serially, 1 bit/clock, LSB first
// Pulses o_tx_done for 1 cycle after all 10 bits sent
// ═══════════════════════════════════════════════════════════
module tx_serializer (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_tx_ena_n,   // active-low enable
    input  wire [9:0]  i_data,
    output reg         o_serial,
    output reg         o_tx_done
);
    reg [3:0] bit_count;
    reg [9:0] shift_reg;
    reg       active;

    always @(posedge i_clk) begin
        if (i_rst) begin
            bit_count <= 4'd0;
            shift_reg <= 10'd0;
            o_serial  <= 1'b0;
            o_tx_done <= 1'b0;
            active    <= 1'b0;
        end else begin
            o_tx_done <= 1'b0;

            if (!i_tx_ena_n) begin
                if (!active) begin
                    shift_reg <= i_data;
                    active    <= 1'b1;
                    bit_count <= 4'd0;
                end else begin
                    o_serial  <= shift_reg[0];
                    shift_reg <= {1'b0, shift_reg[9:1]};

                    if (bit_count == 4'd9) begin
                        o_tx_done <= 1'b1;
                        active    <= 1'b0;
                        bit_count <= 4'd0;
                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end
            end
        end
    end
endmodule


// ═══════════════════════════════════════════════════════════
// MODULE 3 — RX Detector
// 9-bit shift-register comparator
// Birthday: March(0011) + 7(00111) = 9'b001100111
// Pulses o_match for 1 cycle on every pattern match
// ═══════════════════════════════════════════════════════════
module rx_detector #(
    parameter [8:0] BIRTHDAY = 9'b001100111
)(
    input  wire  i_clk,
    input  wire  i_rst,
    input  wire  i_serial,
    output reg   o_match
);
    reg [8:0] shift_reg;

    always @(posedge i_clk) begin
        if (i_rst) begin
            shift_reg <= 9'd0;
            o_match   <= 1'b0;
        end else begin
            shift_reg <= {i_serial, shift_reg[8:1]};
            o_match   <= (shift_reg == BIRTHDAY) ? 1'b1 : 1'b0;
        end
    end
endmodule


// ═══════════════════════════════════════════════════════════
// MODULE 4 — Hit Counter
// Counts matches per second, latches value for display
// At every CLK_FREQ cycles: latch count, reset, pulse valid
// ═══════════════════════════════════════════════════════════
module hit_counter #(
    parameter CLK_FREQ = 10000   // 10 kHz → 10000 cycles = 1 sec
)(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_match,
    output reg  [7:0]  o_count_latched,
    output reg         o_valid
);
    reg [7:0]  count;
    reg [13:0] sec_counter;

    always @(posedge i_clk) begin
        if (i_rst) begin
            count           <= 8'd0;
            sec_counter     <= 14'd0;
            o_count_latched <= 8'd0;
            o_valid         <= 1'b0;
        end else begin
            o_valid <= 1'b0;

            if (i_match)
                count <= count + 1'b1;

            if (sec_counter == CLK_FREQ - 1) begin
                sec_counter     <= 14'd0;
                o_count_latched <= count;
                count           <= 8'd0;
                o_valid         <= 1'b1;
            end else begin
                sec_counter <= sec_counter + 1'b1;
            end
        end
    end
endmodule


// ═══════════════════════════════════════════════════════════
// MODULE 5 — 7-Segment Driver
// Converts 8-bit binary count → two 7-seg codes
// Active LOW encoding (common anode), segments = gfedcba
// ═══════════════════════════════════════════════════════════
module seg7_driver (
    input  wire [7:0]  i_count,
    output reg  [6:0]  o_seg_tens,
    output reg  [6:0]  o_seg_units
);
    wire [3:0] tens  = i_count / 10;
    wire [3:0] units = i_count % 10;

    function [6:0] encode;
        input [3:0] digit;
        case (digit)
            4'd0: encode = 7'b1000000;
            4'd1: encode = 7'b1111001;
            4'd2: encode = 7'b0100100;
            4'd3: encode = 7'b0110000;
            4'd4: encode = 7'b0011001;
            4'd5: encode = 7'b0010010;
            4'd6: encode = 7'b0000010;
            4'd7: encode = 7'b1111000;
            4'd8: encode = 7'b0000000;
            4'd9: encode = 7'b0010000;
            default: encode = 7'b1111111;
        endcase
    endfunction

    always @(*) begin
        o_seg_tens  = encode(tens);
        o_seg_units = encode(units);
    end
endmodule


// ═══════════════════════════════════════════════════════════
// MODULE 6 — TOP LEVEL (Tiny Tapeout Wrapper)
// ═══════════════════════════════════════════════════════════
module tt_um_happy_birthday (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1=output)
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // 10 kHz system clock
    input  wire       rst_n     // active-low reset
);

    // ── Parameters ────────────────────────────────────────
    localparam [8:0] BIRTHDAY = 9'b001100111; // March(0011)+7(00111)
    localparam       CLK_FREQ = 10000;        // 10 kHz clock

    // ── Internal reset (active-high for our modules) ──────
    wire i_rst      = ~rst_n;
    wire i_tx_ena_n = ui_in[0];

    // ── Internal wires ────────────────────────────────────
    wire [9:0] w_tx_data;
    wire       w_tx_done;
    wire       w_serial;
    wire       w_match;
    wire [7:0] w_count;
    wire       w_valid;
    wire [6:0] w_seg_tens;
    wire [6:0] w_seg_units;

    // ── Module instantiations ─────────────────────────────
    tx_generator gen (
        .i_clk    (clk),
        .i_rst    (i_rst),
        .i_tx_done(w_tx_done),
        .o_data   (w_tx_data)
    );

    tx_serializer ser (
        .i_clk     (clk),
        .i_rst     (i_rst),
        .i_tx_ena_n(i_tx_ena_n),
        .i_data    (w_tx_data),
        .o_serial  (w_serial),
        .o_tx_done (w_tx_done)
    );

    rx_detector #(
        .BIRTHDAY(BIRTHDAY)
    ) det (
        .i_clk   (clk),
        .i_rst   (i_rst),
        .i_serial(w_serial),
        .o_match (w_match)
    );

    hit_counter #(
        .CLK_FREQ(CLK_FREQ)
    ) cnt (
        .i_clk          (clk),
        .i_rst          (i_rst),
        .i_match        (w_match),
        .o_count_latched(w_count),
        .o_valid        (w_valid)
    );

    seg7_driver seg (
        .i_count    (w_count),
        .o_seg_tens (w_seg_tens),
        .o_seg_units(w_seg_units)
    );

    // ── Output assignments ────────────────────────────────
    assign uo_out[6:0]  = w_seg_units;   // units digit
    assign uo_out[7]    = w_valid;       // valid pulse

    assign uio_out[6:0] = w_seg_tens;   // tens digit
    assign uio_out[7]   = 1'b0;

    assign uio_oe       = 8'b0111_1111; // uio[6:0]=output, uio[7]=input

    // ── Suppress unused input warnings ────────────────────
    wire _unused = &{ena, ui_in[7:1], uio_in, 1'b0};

endmodule
