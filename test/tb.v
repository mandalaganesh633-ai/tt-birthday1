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
`timescale 1ns/1ps

module tb;

    reg clk = 0;
    reg rst_n = 0;
    reg ena = 1;

    reg  [7:0] ui_in;
    reg  [7:0] uio_in;

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // DUT
    tt_um_happy_birthday dut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),          // ⭐ VERY IMPORTANT
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // Clock
    always #5 clk = ~clk;

    initial begin
        // Initialize
        ui_in  = 8'hFF;
        uio_in = 8'h00;

        // Reset
        rst_n = 0;
        repeat (5) @(posedge clk);

        rst_n = 1;

        // Enable TX (active LOW)
        ui_in[0] = 0;

        // Run simulation
        repeat (500) @(posedge clk);

        $finish;
    end

endmodule
