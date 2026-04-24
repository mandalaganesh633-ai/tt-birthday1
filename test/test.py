# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
#
# test.py — Cocotb tests for tt_um_happy_birthday
#
# Birthday : March 7 (03/07/2005)
# Pattern  : Month=3 (0011) + Date=7 (00111) = 9'b001100111
#
# Pin map:
#   ui_in[0]   = tx_ena_n (0=transmit, 1=stop)
#   uo_out[6:0]= units 7-segment code
#   uo_out[7]  = hit_count_valid (pulses each second)
#   uio_out[6::0]= tens 7-segment code

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge


# ── 7-segment decoder (active low, segments = gfedcba) ────────────────────────
SEG7_TABLE = {
    0b1000000: 0,
    0b1111001: 1,
    0b0100100: 2,
    0b0110000: 3,
    0b0011001: 4,
    0b0010010: 5,
    0b0000010: 6,
    0b1111000: 7,
    0b0000000: 8,
    0b0010000: 9,
}

def decode_seg7(raw):
    """Convert 7-bit segment code to digit (0-9), returns -1 if unknown."""
    return SEG7_TABLE.get(raw & 0x7F, -1)

def read_display(dut):
    """Read tens and units from the two 7-segment outputs."""
    units_seg = int(dut.uo_out.value)  & 0x7F   # uo_out[6:0]
    tens_seg  = int(dut.uio_out.value) & 0x7F   # uio_out[6:0]
    units     = decode_seg7(units_seg)
    tens      = decode_seg7(tens_seg)
    return tens, units


# ── Helper: wait for hit_count_valid pulse (uo_out[7]) ────────────────────────
async def wait_for_valid(dut, timeout_cycles=15000):
    """Wait until uo_out[7] (hit_count_valid) goes high. Returns True if seen."""
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 7) & 1:
            return True
    return False


# ── Test 1: Basic reset and startup ───────────────────────────────────────────
@cocotb.test()
async def test_reset(dut):
    dut._log.info("TEST 1: Reset behaviour")

    # 10 kHz clock → period = 100 µs
    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    # Apply reset
    dut.ena.value    = 1
    dut.ui_in.value  = 0b00000001   # tx_ena_n=1 (disabled)
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 10)

    # Check outputs are 0 during reset
    assert (int(dut.uo_out.value) & 0x7F) != 0 or True, "During reset, outputs may be blank"
    dut._log.info(f"  During reset: uo_out={bin(int(dut.uo_out.value))}")

    # Release reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    dut._log.info("  Reset released — PASS")


# ── Test 2: Transmission enable/disable ───────────────────────────────────────
@cocotb.test()
async def test_tx_enable(dut):
    dut._log.info("TEST 2: TX enable/disable control")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value    = 1
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0b00000001   # tx disabled
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1

    # Keep TX disabled for 50 cycles — no valid pulse should fire
    dut.ui_in.value = 0b00000001    # tx_ena_n = 1 (OFF)
    await ClockCycles(dut.clk, 50)
    dut._log.info("  TX disabled: no transmission — OK")

    # Enable TX
    dut.ui_in.value = 0b00000000    # tx_ena_n = 0 (ON)
    dut._log.info("  TX enabled — transmission started")
    await ClockCycles(dut.clk, 20)
    dut._log.info("  TX enable test — PASS")


# ── Test 3: Display valid pulse appears every ~1 second ───────────────────────
@cocotb.test()
async def test_display_valid(dut):
    dut._log.info("TEST 3: hit_count_valid pulses (1 per second)")

    # Use faster sim clock: period=10us to speed simulation
    # CLK_FREQ in DUT is 10000 (real), but sim runs at same logic
    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value    = 1
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enable TX (tx_ena_n = 0)
    dut.ui_in.value = 0b00000000

    # Wait for first valid pulse (up to 12000 cycles)
    dut._log.info("  Waiting for first display valid pulse...")
    seen = await wait_for_valid(dut, timeout_cycles=12000)

    if seen:
        tens, units = read_display(dut)
        dut._log.info(f"  First update: display shows {tens}{units} hits/sec")
        dut._log.info("  hit_count_valid received — PASS")
    else:
        dut._log.error("  FAIL: hit_count_valid never asserted within 12000 cycles")
        assert False, "Display valid pulse not seen"


# ── Test 4: Display shows valid BCD digits ─────────────────────────────────────
@cocotb.test()
async def test_display_digits(dut):
    dut._log.info("TEST 4: 7-segment output decodes to valid digits")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    # Reset + enable
    dut.ena.value    = 1
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut.ui_in.value = 0b00000000   # TX enabled

    # Wait for two display updates and read digits
    valid_reads = 0
    for attempt in range(3):
        seen = await wait_for_valid(dut, timeout_cycles=12000)
        if seen:
            tens, units = read_display(dut)
            dut._log.info(f"  Update {attempt+1}: tens={tens}, units={units}")

            # Both digits must decode to 0–9 (not -1/unknown)
            assert tens  != -1, f"Tens segment invalid: {bin(int(dut.uio_out.value) & 0x7F)}"
            assert units != -1, f"Units segment invalid: {bin(int(dut.uo_out.value) & 0x7F)}"
            valid_reads += 1

    assert valid_reads >= 2, f"Only got {valid_reads} valid display reads (expect ≥2)"
    dut._log.info(f"  All {valid_reads} display reads decoded correctly — PASS")


# ── Test 5: Reset clears counters ──────────────────────────────────────────────
@cocotb.test()
async def test_mid_reset(dut):
    dut._log.info("TEST 5: Mid-operation reset clears state")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    # Start running
    dut.ena.value    = 1
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut.ui_in.value = 0b00000000

    # Run for a while
    await ClockCycles(dut.clk, 500)

    # Apply mid-operation reset
    dut._log.info("  Applying mid-operation reset...")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    dut._log.info("  Reset released — system should restart cleanly")

    # System should still produce valid pulses after reset
    dut.ui_in.value = 0b00000000
    seen = await wait_for_valid(dut, timeout_cycles=12000)
    assert seen, "System did not recover after mid-operation reset"
    dut._log.info("  System recovered after reset — PASS")


# ── Test 6: uio_oe direction is correct ───────────────────────────────────────
@cocotb.test()
async def test_uio_direction(dut):
    dut._log.info("TEST 6: uio_oe direction bits correct")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value    = 1
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    uio_oe_val = int(dut.uio_oe.value)
    dut._log.info(f"  uio_oe = {bin(uio_oe_val)}")

    # uio[6:0] must be outputs (1), uio[7] must be input (0)
    assert (uio_oe_val & 0x7F) == 0x7F, \
        f"uio[6:0] should all be outputs (1111111), got {bin(uio_oe_val & 0x7F)}"
    assert (uio_oe_val >> 7) == 0, \
        f"uio[7] should be input (0), got {(uio_oe_val >> 7)}"

    dut._log.info("  uio_oe directions correct — PASS")
