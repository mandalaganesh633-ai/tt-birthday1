# Happy Birthday Detector

## How it works
This project detects a 9-bit birthday pattern (March 7) from a serial input stream.

It uses:
- A transmitter (tx_generator) to generate serial data
- A finite state machine (FSM) to detect the pattern
- A counter to count matches

When the pattern is detected, the output signal goes HIGH and the counter increments.

## How to test
1. Apply clock and reset signals.
2. Provide a serial input stream.
3. Insert the target pattern into the stream.
4. Observe the output:
   - Output goes HIGH when pattern is detected
   - Counter increments for each detection

You can verify using simulation tools like GTKWave.
## How it works

This project implements a **Happy Birthday Detector** — a digital system that transmits a
continuously looping serial bit stream and detects a hardcoded 9-bit birthday pattern within it.

### Birthday Pattern

The birthday date is **March 7 (03/07/2005)**:

| Field  | Value | Binary     |
|--------|-------|------------|
| Month  | 3     | `0011`     |
| Date   | 7     | `00111`    |
| **Pattern** | — | **`001100111`** |

### System Architecture

The design consists of five sub-modules all integrated into `project.v`:

1. **TX Generator** — A 10-bit counter (0–1023) that produces data words. It increments
   only after the serializer has finished sending the previous word, preventing overlap.

2. **TX Serializer** — Takes each 10-bit word and transmits it one bit per clock cycle,
   LSB first, producing a continuous serial stream at the 10 kHz system clock rate.

3. **RX Detector** — A 9-bit shift register that captures incoming serial bits and compares
   the last 9 bits to the birthday pattern every clock cycle. Asserts a match pulse for
   one cycle whenever the pattern is found. Overlapping matches are handled correctly by design.

4. **Hit Counter** — Accumulates match pulses. Every 10,000 clock cycles (1 second at 10 kHz),
   it latches the running count, resets it to zero, and pulses `hit_count_valid` to notify
   the display driver that fresh data is available.

5. **7-Segment Driver** — Converts the latched 8-bit binary count into two active-low
   7-segment display codes (tens digit and units digit), supporting display of values 0–99.

### Timing

| Parameter         | Value                        |
|-------------------|------------------------------|
| Clock frequency   | 10 kHz                       |
| Bits per frame    | 10                           |
| Frame rate        | 1 kHz (one word per ms)      |
| Counter cycle     | 1024 ms ≈ 1.024 s            |
| Display update    | Every 1 s (10,000 clocks)    |
| Pattern length    | 9 bits                       |

### Pin Mapping

| Pin           | Direction | Description                                      |
|---------------|-----------|--------------------------------------------------|
| `ui_in[0]`    | Input     | `TX_ENA_N` — active-low transmit enable          |
| `uo_out[6:0]` | Output    | Units digit 7-segment code (active low, gfedcba) |
| `uo_out[7]`   | Output    | `HIT_COUNT_VALID` — pulses HIGH each second      |
| `uio_out[6:0]`| Output    | Tens digit 7-segment code (active low, gfedcba)  |

## How to test

### Basic Verification Steps

1. **Apply reset**: Hold `rst_n` LOW for at least 10 clock cycles, then release it HIGH.
   All internal counters and state machines will initialise to zero.

2. **Enable transmission**: Drive `ui_in[0]` (TX_ENA_N) LOW. This activates the transmitter.
   The serial bit stream will begin immediately on the next clock cycle.

3. **Wait for the first display update**: After exactly 10,000 clock cycles (1 second at
   10 kHz), `uo_out[7]` (HIT_COUNT_VALID) will pulse HIGH for one cycle. At this moment,
   `uo_out[6:0]` holds the units digit and `uio_out[6:0]` holds the tens digit of the
   birthday hit count for that second.

4. **Read the 7-segment display**:
   - Decode `uo_out[6:0]` for the **units** digit
   - Decode `uio_out[6:0]` for the **tens** digit
   - Both use active-low encoding: `1000000` = 0, `1111001` = 1, `0100100` = 2, etc.

5. **Verify non-zero count**: Because the 10-bit counter sweeps values 0–1023 and the
   birthday pattern `001100111` (decimal 103) falls within that range, the detector will
   find at least one match per counter cycle (~1.024 s). The display should show a non-zero
   value after the first second of operation.

6. **Test disable**: Drive `ui_in[0]` HIGH to stop transmission. The detector will stop
   receiving bits. The display will eventually show 0 hits/sec after the next update interval.

7. **Test reset recovery**: Assert `rst_n` LOW mid-operation, then release. The system
   should cleanly restart and resume producing display updates after another 1-second interval.

### Expected Display Values

At 10 kHz with a 1 kHz frame rate, the 1024-word counter completes roughly once per second.
The birthday pattern `001100111` appears as bits within the serial stream of each counter cycle.
Typical hit counts observed per second are in the range of **1–5 hits/sec** depending on
how the 9-bit pattern aligns across frame boundaries.

### 7-Segment Encoding Reference (active low)

| Digit | `gfedcba` code |
|-------|----------------|
| 0     | `1000000`      |
| 1     | `1111001`      |
| 2     | `0100100`      |
| 3     | `0110000`      |
| 4     | `0011001`      |
| 5     | `0010010`      |
| 6     | `0000010`      |
| 7     | `1111000`      |
| 8     | `0000000`      |
| 9     | `0010000`      | 
