// `default_nettype none
// `timescale 1ns / 1ps

// /* This testbench just instantiates the module and makes some convenient wires
//    that can be driven / tested by the cocotb test.py.
// */
// module tb ();

//   // Dump the signals to a FST file. You can view it with gtkwave or surfer.
//   initial begin
//     $dumpfile("tb.fst");
//     $dumpvars(0, tb);
//     #1;
//   end

//   // Wire up the inputs and outputs:
//   reg clk;
//   reg rst_n;
//   reg ena;
//   reg [7:0] ui_in;
//   reg [7:0] uio_in;
//   wire [7:0] uo_out;
//   wire [7:0] uio_out;
//   wire [7:0] uio_oe;
// `ifdef GL_TEST
//   wire VPWR = 1'b1;
//   wire VGND = 1'b0;
// `endif

//   // Replace tt_um_example with your module name:
//   tt_um_example user_project (

//       // Include power ports for the Gate Level test:
// `ifdef GL_TEST
//       .VPWR(VPWR),
//       .VGND(VGND),
// `endif

//       .ui_in  (ui_in),    // Dedicated inputs
//       .uo_out (uo_out),   // Dedicated outputs
//       .uio_in (uio_in),   // IOs: Input path
//       .uio_out(uio_out),  // IOs: Output path
//       .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
//       .ena    (ena),      // enable - goes high when design is selected
//       .clk    (clk),      // clock
//       .rst_n  (rst_n)     // not reset
//   );

// endmodule
`default_nettype none
`timescale 1ns/1ps

module tb ();

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;

  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  always #5 clk = ~clk;

  tt_um_ganesh_birthday_detector dut (
      .ui_in(ui_in),
      .uo_out(uo_out),
      .uio_in(uio_in),
      .uio_out(uio_out),
      .uio_oe(uio_oe),
      .ena(ena),
      .clk(clk),
      .rst_n(rst_n)
  );

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);

    clk = 0;
    rst_n = 0;
    ena = 1;
    ui_in = 0;
    uio_in = 0;

    #20 rst_n = 1;

    // Send pattern: 001100111 (LSB first)
    send_bit(1);
    send_bit(1);
    send_bit(1);
    send_bit(0);
    send_bit(0);
    send_bit(1);
    send_bit(1);
    send_bit(0);
    send_bit(0);

    // Random noise
    repeat(20) send_bit($random);

    // Back-to-back patterns
    repeat(2) begin
        send_pattern();
    end

    #200 $finish;
  end

  task send_bit(input bit b);
    begin
      ui_in[0] = b;
      #10;
    end
  endtask

  task send_pattern;
    begin
      send_bit(1);
      send_bit(1);
      send_bit(1);
      send_bit(0);
      send_bit(0);
      send_bit(1);
      send_bit(1);
      send_bit(0);
      send_bit(0);
    end
  endtask

endmodule
