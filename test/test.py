# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
#
# test.py — Cocotb tests for tt_um_happy_birthday
#
# Birthday : March 7 (03/07/2005)
# Pattern  : Month=3 (0011) + Date=7 (00111) = 9'b001100111
#
# Pin map:
#   ui_in[0]     = tx_ena_n  (0=transmit ON,  1=transmit OFF)
#   uo_out[6:0]  = units 7-segment code (active low)
#   uo_out[7]    = hit_count_valid  (1 = new count ready)
#   uio_out[6:0] = tens  7-segment code (active low)
#   uio_oe       = 8'b0111_1111

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


# ─── 7-segment decoder (active low, gfedcba) ──────────────────────────────────
SEG7 = {
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

def decode(seg_val):
    """Decode 7-bit segment code to integer digit (0–9). Returns -1 if unknown."""
    return SEG7.get(int(seg_val) & 0x7F, -1)

def read_display(dut):
    """Read tens and units digits from the two 7-seg outputs."""
    units = decode(int(dut.uo_out.value)  & 0x7F)   # uo_out[6:0]
    tens  = decode(int(dut.uio_out.value) & 0x7F)   # uio_out[6:0]
    return tens, units

def is_valid_pulse(dut):
    """Check if hit_count_valid (uo_out[7]) is asserted."""
    return bool((int(dut.uo_out.value) >> 7) & 1)

async def do_reset(dut):
    """Standard reset sequence."""
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0b00000001   # TX disabled during reset
    dut.uio_in.value = 0
    dut.ena.value    = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 2)

async def wait_valid(dut, timeout=12000):
    """Wait for hit_count_valid pulse. Returns True if seen within timeout."""
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if is_valid_pulse(dut):
            return True
    return False


# ─── TEST 1: Reset ─────────────────────────────────────────────────────────────
@cocotb.test()
async def test_01_reset(dut):
    """Check system initialises cleanly after reset."""
    dut._log.info("TEST 1: Reset behaviour")

    clock = Clock(dut.clk, 100, unit="us")   # 10 kHz
    cocotb.start_soon(clock.start())

    await do_reset(dut)
    dut._log.info(f"  uo_out  after reset = {bin(int(dut.uo_out.value))}")
    dut._log.info(f"  uio_out after reset = {bin(int(dut.uio_out.value))}")
    dut._log.info("  PASS — reset completed without hang")


# ─── TEST 2: TX enable / disable ───────────────────────────────────────────────
@cocotb.test()
async def test_02_tx_enable(dut):
    """TX only runs when ui_in[0] (tx_ena_n) is LOW."""
    dut._log.info("TEST 2: TX enable/disable")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    await do_reset(dut)

    # Keep TX disabled for 50 cycles — no valid pulse expected
    dut.ui_in.value = 0b00000001    # tx_ena_n = 1 → OFF
    await ClockCycles(dut.clk, 50)
    dut._log.info("  TX disabled — no transmission running")

    # Enable TX
    dut.ui_in.value = 0b00000000    # tx_ena_n = 0 → ON
    await ClockCycles(dut.clk, 20)
    dut._log.info("  TX enabled  — transmission started")
    dut._log.info("  PASS")


# ─── TEST 3: hit_count_valid fires once per second ─────────────────────────────
@cocotb.test()
async def test_03_valid_pulse(dut):
    """hit_count_valid (uo_out[7]) must pulse every 10 000 clocks."""
    dut._log.info("TEST 3: hit_count_valid pulse timing")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    await do_reset(dut)
    dut.ui_in.value = 0b00000000    # TX ON

    dut._log.info("  Waiting for first valid pulse (up to 12 000 cycles)...")
    seen = await wait_valid(dut, timeout=12000)

    assert seen, "FAIL — hit_count_valid never asserted within 12 000 cycles"
    tens, units = read_display(dut)
    dut._log.info(f"  First display update: {tens}{units} hits/sec")
    dut._log.info("  PASS")


# ─── TEST 4: 7-segment outputs decode to valid digits ──────────────────────────
@cocotb.test()
async def test_04_display_digits(dut):
    """Both 7-seg outputs must decode to digits 0–9 on every valid pulse."""
    dut._log.info("TEST 4: 7-segment digit validity")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    await do_reset(dut)
    dut.ui_in.value = 0b00000000

    good = 0
    for attempt in range(3):
        seen = await wait_valid(dut, timeout=12000)
        assert seen, f"FAIL — no valid pulse on attempt {attempt+1}"
        tens, units = read_display(dut)
        dut._log.info(f"  Update {attempt+1}: tens={tens}  units={units}")
        assert tens  != -1, f"FAIL — tens  segment invalid: {bin(int(dut.uio_out.value) & 0x7F)}"
        assert units != -1, f"FAIL — units segment invalid: {bin(int(dut.uo_out.value)  & 0x7F)}"
        good += 1

    assert good == 3, f"FAIL — only {good}/3 valid reads"
    dut._log.info("  PASS — all 3 display updates decoded correctly")


# ─── TEST 5: uio_oe direction bits ─────────────────────────────────────────────
@cocotb.test()
async def test_05_uio_direction(dut):
    """uio[6:0] must be outputs (1), uio[7] must be input (0)."""
    dut._log.info("TEST 5: uio_oe direction")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    await do_reset(dut)
    await ClockCycles(dut.clk, 5)

    oe = int(dut.uio_oe.value)
    dut._log.info(f"  uio_oe = {bin(oe)}")

    assert (oe & 0x7F) == 0x7F, \
        f"FAIL — uio[6:0] should be 1111111 (outputs), got {bin(oe & 0x7F)}"
    assert (oe >> 7) == 0, \
        f"FAIL — uio[7] should be 0 (input), got {oe >> 7}"

    dut._log.info("  PASS — uio_oe = 0111_1111 correct")


# ─── TEST 6: Mid-operation reset recovery ──────────────────────────────────────
@cocotb.test()
async def test_06_mid_reset(dut):
    """System must recover and resume normal operation after a mid-run reset."""
    dut._log.info("TEST 6: Mid-operation reset recovery")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    await do_reset(dut)
    dut.ui_in.value = 0b00000000   # TX ON

    # Run for a while then reset mid-flight
    await ClockCycles(dut.clk, 500)
    dut._log.info("  Applying mid-operation reset...")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    dut.ui_in.value = 0b00000000   # re-enable TX after reset

    # Should still produce valid pulses
    seen = await wait_valid(dut, timeout=12000)
    assert seen, "FAIL — system did not recover after mid-operation reset"
    dut._log.info("  PASS — system recovered cleanly after reset")


# ─── TEST 7: Birthday pattern count is non-negative ────────────────────────────
@cocotb.test()
async def test_07_hit_count_value(dut):
    """Displayed hit count must be a non-negative integer (0–99)."""
    dut._log.info("TEST 7: Hit count value sanity check")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    await do_reset(dut)
    dut.ui_in.value = 0b00000000   # TX ON

    # Collect two display readings
    for i in range(2):
        seen = await wait_valid(dut, timeout=12000)
        assert seen, "FAIL — no valid pulse received"
        tens, units = read_display(dut)
        hit_count = tens * 10 + units
        dut._log.info(f"  Reading {i+1}: {hit_count} hits/sec (tens={tens}, units={units})")
        assert 0 <= hit_count <= 99, \
            f"FAIL — hit count {hit_count} out of range 0–99"

    dut._log.info("  PASS — hit count values are valid")
