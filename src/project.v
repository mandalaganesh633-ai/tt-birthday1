// /*
//  * Copyright (c) 2024 Your Name
//  * SPDX-License-Identifier: Apache-2.0
//  */

// `default_nettype none

// module tt_um_example (
//     input  wire [7:0] ui_in,    // Dedicated inputs
//     output wire [7:0] uo_out,   // Dedicated outputs
//     input  wire [7:0] uio_in,   // IOs: Input path
//     output wire [7:0] uio_out,  // IOs: Output path
//     output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
//     input  wire       ena,      // always 1 when the design is powered, so you can ignore it
//     input  wire       clk,      // clock
//     input  wire       rst_n     // reset_n - low to reset
// );

//   // All output pins must be assigned. If not used, assign to 0.
//   assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
//   assign uio_out = 0;
//   assign uio_oe  = 0;

//   // List all unused inputs to prevent warnings
//   wire _unused = &{ena, clk, rst_n, 1'b0};

// endmodule

/*
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_ganesh_birthday_detector (
    input  wire [7:0] ui_in,     // ui_in[0] = serial input
    output wire [7:0] uo_out,    // outputs
    input  wire [7:0] uio_in,    // unused
    output wire [7:0] uio_out,   // unused
    output wire [7:0] uio_oe,    // unused
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Internal signals
    reg [8:0] shift_reg;
    reg [7:0] counter;
    reg match;

    wire serial_in = ui_in[0];

    parameter [8:0] BIRTHDAY = 9'b001100111;

    // Main logic
    always @(posedge clk) begin
        if (!rst_n) begin
            shift_reg <= 0;
            counter   <= 0;
            match     <= 0;
        end else begin
            // Shift register
            shift_reg <= {serial_in, shift_reg[8:1]};

            // Pattern detect
            if (shift_reg == BIRTHDAY) begin
                match   <= 1;
                counter <= counter + 1;
            end else begin
                match <= 0;
            end
        end
    end

    // Outputs
    assign uo_out[0] = match;          // match flag
    assign uo_out[7:1] = counter[6:0]; // count (7 bits)

    // Unused IOs
    assign uio_out = 0;
    assign uio_oe  = 0;

    wire _unused = &{ena, uio_in};

endmodule
