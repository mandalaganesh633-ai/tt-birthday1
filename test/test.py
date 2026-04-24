# # SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# # SPDX-License-Identifier: Apache-2.0

# import cocotb
# from cocotb.clock import Clock
# from cocotb.triggers import ClockCycles


# @cocotb.test()
# async def test_project(dut):
#     dut._log.info("Start")

#     # Set the clock period to 10 us (100 KHz)
#     clock = Clock(dut.clk, 10, unit="us")
#     cocotb.start_soon(clock.start())

#     # Reset
#     dut._log.info("Reset")
#     dut.ena.value = 1
#     dut.ui_in.value = 0
#     dut.uio_in.value = 0
#     dut.rst_n.value = 0
#     await ClockCycles(dut.clk, 10)
#     dut.rst_n.value = 1

#     dut._log.info("Test project behavior")

#     # Set the input values you want to test
#     dut.ui_in.value = 20
#     dut.uio_in.value = 30

#     # Wait for one clock cycle to see the output values
#     await ClockCycles(dut.clk, 1)

#     # The following assersion is just an example of how to check the output values.
#     # Change it to match the actual expected output of your module:
#     assert dut.uo_out.value == 50

#     # Keep testing the module by changing the input values, waiting for
#     # one or more clock cycles, and asserting the expected output values.
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def send_bit(dut, bit):
    dut.ui_in.value = bit
    await ClockCycles(dut.clk, 1)


async def send_pattern(dut):
    pattern = [1,1,1,0,0,1,1,0,0]
    for b in pattern:
        await send_bit(dut, b)


@cocotb.test()
async def test_project(dut):

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    # TEST 1: single pattern
    await send_pattern(dut)
    await ClockCycles(dut.clk, 2)

    assert dut.uo_out.value != 0, "Pattern not detected!"

    # TEST 2: noise
    for _ in range(20):
        await send_bit(dut, 0)

    # TEST 3: multiple patterns
    await send_pattern(dut)
    await send_pattern(dut)

    await ClockCycles(dut.clk, 5)

    count = dut.uo_out.value.integer >> 1

    assert count >= 2, "Counter not incrementing correctly"

    dut._log.info(f"Detected count: {count}")
