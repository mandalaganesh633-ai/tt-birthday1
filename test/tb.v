// `default_nettype none
// `timescale 1ns / 1ps

// /*
//  * tb.v — Tiny Tapeout Testbench Wrapper
//  * Happy Birthday Detector
//  *
//  * Wires up tt_um_happy_birthday so cocotb test.py can
//  * drive and observe all signals.
//  */

// module tb ();

//   // ── Waveform dump ─────────────────────────────────────
//   initial begin
//     $dumpfile("tb.fst");
//     $dumpvars(0, tb);
//     #1;
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
 * Fixed for GL simulation:
 *  - Timeout extended to cover all 7 tests (3 × 10 000-cycle windows
 *    plus reset/mid-reset overhead ≈ 350 000 cycles × 100 ns = 35 ms)
 *  - Outputs initialised to 0 before reset so cocotb sees defined values
 *    as soon as possible
 *  - $dumpvars depth set to 0 (full hierarchy) for complete FST capture
 */
module tb ();

  // ── Waveform dump ─────────────────────────────────────
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);   // depth=0 → dump full hierarchy
    #1;
  end

  // ── Timeout: enough for all 7 tests ───────────────────
  // Worst case: 3 wait_valid calls × 12 000 cycles × 100 ns
  //           + test_06 500-cycle run + reset + margin
  // = ~40 000 000 ns = 40 ms  →  use 50 ms to be safe
  initial begin
    #50_000_000;
    $display("TIMEOUT: simulation exceeded 50 ms");
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

  // ── Initialise all driven signals to known values ─────
  // This prevents X-propagation into cocotb before do_reset() runs.
  initial begin
    clk     = 0;
    rst_n   = 0;
    ena     = 1;
    ui_in   = 8'b0000_0001;   // tx_ena_n HIGH (TX off) during init
    uio_in  = 8'b0000_0000;
  end

  // ── 10 kHz clock (period = 100 µs = 100 000 ns) ──────
  always #50_000 clk = ~clk;

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
      .ui_in  (ui_in),    // [0]=tx_ena_n
      .uo_out (uo_out),   // [6:0]=units 7-seg, [7]=valid
      .uio_in (uio_in),   // unused
      .uio_out(uio_out),  // [6:0]=tens 7-seg
      .uio_oe (uio_oe),   // direction control
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
