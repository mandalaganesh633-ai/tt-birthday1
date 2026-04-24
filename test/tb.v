`default_nettype none
`timescale 1ns / 1ps

/*
 * tb.v — Tiny Tapeout Testbench Wrapper
 * Happy Birthday Detector
 *
 * This file wires up the tt_um_happy_birthday module so that
 * the cocotb test.py can drive and observe all signals.
 *
 * Dump format: FST (view with GTKWave or Surfer)
 */

module tb ();

  // ── Waveform dump ───────────────────────────────────────
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // ── Standard Tiny Tapeout signals ───────────────────────
  reg        clk;
  reg        rst_n;
  reg        ena;
  reg  [7:0] ui_in;
  reg  [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // ── Convenience aliases (for readable test.py access) ───
  // uo_out[6:0] = units 7-seg | uo_out[7] = hit_count_valid
  // uio_out[6:0] = tens 7-seg | uio_oe shows output direction

  // ── DUT instantiation ───────────────────────────────────
  tt_um_happy_birthday user_project (

`ifdef GL_TEST
      .VPWR   (VPWR),
      .VGND   (VGND),
`endif

      .ui_in  (ui_in),    // [0]=tx_ena_n, [7:1]=unused
      .uo_out (uo_out),   // [6:0]=units seg, [7]=valid
      .uio_in (uio_in),   // unused
      .uio_out(uio_out),  // [6:0]=tens seg
      .uio_oe (uio_oe),   // direction control
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
