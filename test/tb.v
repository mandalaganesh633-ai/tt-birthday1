`default_nettype none
`timescale 1ns / 1ps
/*
 * tb.v — Tiny Tapeout Testbench Wrapper
 * Happy Birthday Detector
 *
 * Fix history:
 *  v4 — Corrected DUT module name from tt_um_example → tt_um_happy_birthday.
 *       The template default was never updated, causing elaboration failure.
 *  v3 — Timeout extended to 30 s (30_000_000_000 ns) to cover all 7 tests.
 *  v2 — Removed always-block clock (cocotb owns clock via Clock(100,"us")).
 *       Added safe initial values for all inputs.
 */
module tb ();

  // ── Waveform dump ─────────────────────────────────────
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // ── Timeout ───────────────────────────────────────────
  // Worst case: 7 tests × up to 12 000 cycles × 100 000 ns = 8.4 s sim time.
  // Use 30 s for comfortable margin.
  initial begin
    #30_000_000_000;
    $display("TIMEOUT: simulation exceeded 30 s");
    $finish;
  end

  // ── Standard TT signals ───────────────────────────────
  reg        clk;
  reg        rst_n;
  reg        ena;
  reg  [7:0] ui_in;
  reg  [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // ── Safe initial values — prevent X before cocotb starts ──
  initial begin
    clk    = 0;
    rst_n  = 0;
    ena    = 1;
    ui_in  = 8'b0000_0001;   // tx_ena_n HIGH (TX off)
    uio_in = 8'b0000_0000;
  end

  // NOTE: No always-block clock here.
  // cocotb drives clk via Clock(dut.clk, 100, unit="us") in every test.

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // ── DUT ───────────────────────────────────────────────
  tt_um_happy_birthday user_project (   // <-- correct module name
`ifdef GL_TEST
      .VPWR   (VPWR),
      .VGND   (VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
