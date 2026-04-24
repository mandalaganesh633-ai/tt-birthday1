// // `default_nettype none
// // `timescale 1ns / 1ps

// // /*
// //  * tb.v — Tiny Tapeout Testbench Wrapper
// //  * Happy Birthday Detector
// //  *
// //  * Wires up tt_um_happy_birthday so cocotb test.py can
// //  * drive and observe all signals.
// //  */

// // module tb ();

// //   // ── Waveform dump ─────────────────────────────────────
// //   initial begin
// //     $dumpfile("tb.fst");
// //     $dumpvars(0, tb);
// //     #1;
// //   end

// //   // ── Standard TT signals ───────────────────────────────
// //   reg        clk;
// //   reg        rst_n;
// //   reg        ena;
// //   reg  [7:0] ui_in;
// //   reg  [7:0] uio_in;
// //   wire [7:0] uo_out;
// //   wire [7:0] uio_out;
// //   wire [7:0] uio_oe;

// // `ifdef GL_TEST
// //   wire VPWR = 1'b1;
// //   wire VGND = 1'b0;
// // `endif

// //   // ── DUT ───────────────────────────────────────────────
// //   tt_um_happy_birthday user_project (

// // `ifdef GL_TEST
// //       .VPWR   (VPWR),
// //       .VGND   (VGND),
// // `endif

// //       .ui_in  (ui_in),    // [0]=tx_ena_n
// //       .uo_out (uo_out),   // [6:0]=units 7-seg, [7]=valid
// //       .uio_in (uio_in),   // unused
// //       .uio_out(uio_out),  // [6:0]=tens 7-seg
// //       .uio_oe (uio_oe),   // direction control
// //       .ena    (ena),
// //       .clk    (clk),
// //       .rst_n  (rst_n)
// //   );

// // endmodule

// `default_nettype none
// `timescale 1ns / 1ps
// /*
//  * tb.v — Tiny Tapeout Testbench Wrapper
//  * Happy Birthday Detector
//  *
//  * Fixed for GL simulation:
//  *  - Timeout extended to cover all 7 tests (3 × 10 000-cycle windows
//  *    plus reset/mid-reset overhead ≈ 350 000 cycles × 100 ns = 35 ms)
//  *  - Outputs initialised to 0 before reset so cocotb sees defined values
//  *    as soon as possible
//  *  - $dumpvars depth set to 0 (full hierarchy) for complete FST capture
//  */
// module tb ();

//   // ── Waveform dump ─────────────────────────────────────
//   initial begin
//     $dumpfile("tb.fst");
//     $dumpvars(0, tb);   // depth=0 → dump full hierarchy
//     #1;
//   end

//   // ── Timeout: enough for all 7 tests ───────────────────
//   // Worst case: 3 wait_valid calls × 12 000 cycles × 100 ns
//   //           + test_06 500-cycle run + reset + margin
//   // = ~40 000 000 ns = 40 ms  →  use 50 ms to be safe
//   initial begin
//     #50_000_000;
//     $display("TIMEOUT: simulation exceeded 50 ms");
//     $finish;
//   end

//   // ── Standard TT signals ───────────────────────────────
//   reg        clk;
//   reg        rst_n;
//   reg        ena;
//   reg  [7:0] ui_in;
//   reg  [7:0] uio_in;
//   wire [7:0] uo_out;
//   wire [7:0] uio_out;
//   wire [7:0] uio_oe;

//   // ── Initialise all driven signals to known values ─────
//   // This prevents X-propagation into cocotb before do_reset() runs.
//   initial begin
//     clk     = 0;
//     rst_n   = 0;
//     ena     = 1;
//     ui_in   = 8'b0000_0001;   // tx_ena_n HIGH (TX off) during init
//     uio_in  = 8'b0000_0000;
//   end

//   // ── 10 kHz clock (period = 100 µs = 100 000 ns) ──────
//   always #50_000 clk = ~clk;

// `ifdef GL_TEST
//   wire VPWR = 1'b1;
//   wire VGND = 1'b0;
// `endif

//   // ── DUT ───────────────────────────────────────────────
//   tt_um_happy_birthday user_project (
// `ifdef GL_TEST
//       .VPWR   (VPWR),
//       .VGND   (VGND),
// `endif
//       .ui_in  (ui_in),    // [0]=tx_ena_n
//       .uo_out (uo_out),   // [6:0]=units 7-seg, [7]=valid
//       .uio_in (uio_in),   // unused
//       .uio_out(uio_out),  // [6:0]=tens 7-seg
//       .uio_oe (uio_oe),   // direction control
//       .ena    (ena),
//       .clk    (clk),
//       .rst_n  (rst_n)
//   );

// endmodule



`default_nettype none
`timescale 1ns / 1ps
/*
 * tb.v — Tiny Tapeout Testbench Wrapper
 * Happy Birthday Detector
 *
 * Fix history:
 *  v3 — GL test uses PDK primitives that force internal timescale to 1ps.
 *       The cocotb Clock(100, "us") = 100_000 ns per cycle, so
 *       10 000 cycles = 1 000 000 000 ns = 1 s of sim time.
 *       3 wait_valid calls × 12 000 cycles × 100 000 ns = 3.6 s sim time.
 *       Timeout must be >> 3.6 s. Use 30 s to cover all 7 tests.
 *       Expressed as #30_000_000_000 under `timescale 1ns/1ps.
 *
 *  v2 — Removed always-block clock (cocotb owns clock).
 *       Added safe initial values for all inputs.
 *
 *  v1 — Extended timeout, added $dumpvars depth 0.
 */
module tb ();

  // ── Waveform dump ─────────────────────────────────────
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // ── Timeout ───────────────────────────────────────────
  // Under `timescale 1ns/1ps, #N = N nanoseconds.
  // 7 tests worst case:
  //   test_01: 10 cycles reset + 2 = 12 cycles
  //   test_02: 50 + 20 = 70 cycles
  //   test_03: 12 000 cycles
  //   test_04: 3 × 12 000 = 36 000 cycles
  //   test_05: 5 cycles
  //   test_06: 500 + 5 + 12 000 = 12 505 cycles
  //   test_07: 2 × 12 000 = 24 000 cycles
  //   Total: ~85 000 cycles × 100 000 ns/cycle = 8 500 000 000 ns = 8.5 s
  // Use 30 s for safety margin.
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

  // NOTE: No always-block clock. cocotb drives clk via
  //       Clock(dut.clk, 100, unit="us") in every test.

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // ── DUT ───────────────────────────────────────────────
  tt_um_happy_birthday user_project (
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
