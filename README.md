# Streaming 3x3 Mean Filter for Zynq-7000

[![verify](https://github.com/ahesh-dilhan/zynq-image-processing/actions/workflows/verify.yml/badge.svg)](https://github.com/ahesh-dilhan/zynq-image-processing/actions/workflows/verify.yml)

This repository contains a source-first RTL implementation of a streaming
3x3 grayscale mean filter. The default configuration accepts a 512 x 512,
8-bit frame and targets the Zynq-7000 device used on the ZedBoard
(`xc7z020clg484-1`).

The engineering focus is the programmable-logic data path: line storage,
window construction, AXI4-Stream flow control, and bit-accurate verification.
It does **not** claim a completed ARM processing-system application or measured
on-board performance.

## Project status

| Capability | Status | Evidence |
|---|---|---|
| Parameterised 3x3 mean-filter RTL | Implemented | [`rtl/axis_mean_filter_3x3.sv`](rtl/axis_mean_filter_3x3.sv) |
| AXI4-Stream ready/valid backpressure | Implemented | State advances only on an input handshake; the testbench injects sink stalls |
| SOF/EOL framing checks | Implemented | `tuser`, `tlast`, sticky `protocol_error`, and malformed-SOF test |
| Bit-accurate software reference | Implemented | [`sim/reference_model.py`](sim/reference_model.py) |
| Automated self-checking simulation | Implemented locally | [`sim/tb_axis_mean_filter_3x3.sv`](sim/tb_axis_mean_filter_3x3.sv); workflow runs after push |
| Vivado PL project-creation script | Provided, not synthesis-validated | [`scripts/create_vivado_project.tcl`](scripts/create_vivado_project.tcl) |
| Zynq PS block design and AXI DMA | Planned | Integration boundary is documented; no block design is claimed |
| ARM software/driver and board validation | Planned | No application, bitstream, frequency, or board measurements are published |

The root `image_processing.xpr`, `component.xml`, generated FIFO files, and
original Verilog are preserved as a **legacy 2020 prototype snapshot**. They
are useful project history, but they are not the authoritative implementation.
See [Legacy snapshot](docs/legacy_snapshot.md) for the specific reasons.

## Architecture

```text
 AXI4-Stream input                                      AXI4-Stream output
 tdata/tvalid/tready    +--------------------------+    tdata/tvalid/tready
 tuser(SOF)/tlast(EOL) ->| coordinate + frame check |---> tuser(SOF)/tlast(EOL)
                        +------------+-------------+
                                     |
                        +------------v-------------+
                        | two line memories + taps  |
                        |       3 x 3 window        |
                        +------------+-------------+
                                     |
                        +------------v-------------+
                        | sum 9 pixels / divide by 9|
                        +------------+-------------+
                                     |
                        +------------v-------------+
                        | one-entry elastic output  |
                        +--------------------------+
```

Every coordinate, memory write, and horizontal tap advances only when
`s_axis_tvalid && s_axis_tready` is true. If the downstream interface stalls,
the registered output and all image state remain stable. When unstalled, the
core can accept one input pixel per clock and produce one valid-window output
per clock.

The border policy is deliberately explicit: no padding is invented. A
`WIDTH x HEIGHT` input produces `(WIDTH-2) x (HEIGHT-2)` outputs. Division uses
unsigned integer truncation, matching the Python reference (`sum // 9`).

More detail is in [Architecture and interface contract](docs/architecture.md).

## Reproduce the verification

The tests require Python 3, GNU Make, Icarus Verilog, and `vvp`.

```bash
make test
```

`make test` runs:

1. Python unit tests for dimensions, known frames/windows, value ranges, and output
   size.
2. A SystemVerilog testbench that generates a deterministic frame, calculates
   an independent nested-loop result, checks every pixel and sideband, inserts
   source bubbles, applies multi-cycle output stalls, checks that AXI output
   signals remain stable under backpressure, injects a malformed SOF, and
   checks reset assertion.

Generate small viewable PGM input/reference files without third-party Python
packages:

```bash
make reference
```

The generated artifacts go under `build/` and are intentionally ignored by
Git.

## Rebuild in Vivado

Vivado is only required for Xilinx synthesis or project work, not for the
open-source simulation path.

```bash
vivado -mode batch -source scripts/create_vivado_project.tcl
```

This script is intended to create `build/vivado/zynq_mean_filter.xpr` from the
authoritative RTL and testbench, targeting the ZedBoard's Zynq-7020 part. It is
not run by the open-source CI and no synthesis result is claimed. It does not
silently add a processing system, DMA, board constraints, or software
application.

## Interface contract

| Signal | Meaning |
|---|---|
| `s_axis_tdata` | One unsigned grayscale sample |
| `s_axis_tvalid/tready` | Input transfer occurs only when both are high |
| `s_axis_tuser` | Must be high on the first pixel of each input frame |
| `s_axis_tlast` | Must be high on the last pixel of each input line |
| `m_axis_tdata` | Truncated mean of one complete 3x3 window |
| `m_axis_tuser` | High on the first pixel of the cropped output frame |
| `m_axis_tlast` | High on the last pixel of each cropped output line |
| `protocol_error` | Sticky flag for unexpected input SOF/EOL; cleared by reset |

`aresetn` asynchronously clears control and output-valid state. In a physical
design, reset deassertion must be synchronised to `aclk`. The line memories are
not bulk-reset; after reset, two accepted rows refill them before the first
output can be valid.

## Repository layout

```text
rtl/                         authoritative synthesizable SystemVerilog
sim/                         self-checking testbench and Python model
tests/                       reference-model unit tests
scripts/                     source-first Vivado project-generation script
docs/                        design decisions, limitations, legacy notes
.github/workflows/verify.yml automated test workflow
image_processing.srcs/       preserved legacy Vivado snapshot
image_processing.xpr         preserved legacy project (not authoritative)
```

## Current limitations

- One unsigned component per beat; RGB packing is not implemented.
- The only kernel is a fixed 3x3 box mean with cropped borders.
- Width, height, and pixel width are elaboration-time parameters, not runtime
  registers. Pixel width must be a whole number of AXI byte lanes.
- Framing errors are reported but do not resynchronise the coordinate counters.
- Line-memory mapping, utilization, timing closure, and maximum clock rate must
  be established with a named Vivado version and a committed synthesis report.
- AXI DMA, Zynq PS software, cache maintenance, and physical-board validation
  remain integration work.

These boundaries are intentional: the repository separates PL logic checked by
the included deterministic simulation from work that has not yet been
demonstrated.

## Planned PS-to-PL integration

The next system milestone is:

```text
DDR -> Zynq PS -> AXI DMA (MM2S) -> this PL core -> AXI DMA (S2MM) -> DDR
```

That work will require an address map, DMA buffer ownership/cache policy,
interrupt handling, frame-stride decisions, a block-design Tcl script, and an
ARM-side test that compares returned pixels with the same reference model.
Those artifacts should be added before describing the project as an integrated
PS-PL image-processing system.

## License

The newly authored clean-path files are MIT licensed; preserved Xilinx-generated
and legacy collateral remains subject to any notices embedded in those files.
See [LICENSE](LICENSE).
