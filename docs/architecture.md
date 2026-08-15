# Architecture and interface contract

## Scope

`axis_mean_filter_3x3` is a programmable-logic streaming component. It builds a
complete 3x3 neighbourhood from raster-order pixels and outputs the unsigned
integer mean. `IMAGE_WIDTH`, `IMAGE_HEIGHT`, and `PIXEL_WIDTH` are fixed at
elaboration time; the defaults are 512, 512, and 8. Pixel width must be a
positive multiple of eight so `tdata` consists of complete AXI byte lanes.

The module is designed to be placed between AXI4-Stream-compatible producers
and consumers. It is not an AXI memory-mapped peripheral, an AXI DMA engine, or
a complete Zynq system.

## Transaction and framing rules

An input pixel is accepted only on:

```text
s_axis_tvalid && s_axis_tready
```

The source must present pixels in row-major order. `s_axis_tuser` marks the
first pixel of the frame, and `s_axis_tlast` marks the final pixel in each row,
following the common AXI4-Stream Video convention. Internal fixed-dimension
counters define the expected positions. An unexpected sideband sets the sticky
`protocol_error` output; reset is required to clear it.

The component does not attempt to recover from a missing or early sideband.
That choice avoids a partially specified resynchronisation policy. A system
that must recover in-band should add an explicit frame-discard/resync state.

## Datapath

For each accepted coordinate `(x,y)`:

1. `previous_row[x]` provides `(x,y-1)` and is replaced with the input.
2. `second_previous_row[x]` provides `(x,y-2)` and is replaced with the old
   `previous_row[x]`.
3. Two delays per row retain columns `x-1` and `x-2`.
4. Once `x >= 2` and `y >= 2`, the nine taps are summed and divided by nine.
5. The result and its sidebands enter a one-entry elastic output register.

The first valid result is formed when input coordinate `(2,2)` is accepted. It
represents the window whose centre is `(1,1)`. The last two coordinates in the
window are known only after their samples arrive, so the design naturally
discards the outer one-pixel input border instead of synthesising padding.

For an input of `W x H`, the output is `(W-2) x (H-2)`.

## Backpressure invariant

The output register is available when it is empty or being consumed in the
current cycle:

```text
s_axis_tready = aresetn && (!m_axis_tvalid || m_axis_tready)
```

If `m_axis_tvalid` is high while `m_axis_tready` is low, input ready is low.
No coordinate, line-memory write, or horizontal delay advances, and output
data/SOF/EOL remain unchanged. If the sink is ready, an old output may be
consumed in the same cycle that a new result replaces it, maintaining one
sample per clock across the valid interior of a row.

This small elastic stage creates a combinational ready path from output to
input. If timing analysis shows that path is critical in a larger design, an
AXI register slice can be inserted at the integration boundary without changing
the filter's numerical behavior.

## Reset behavior

`aresetn` asynchronously clears coordinate state, delays, output-valid, output
sidebands, output data, and `protocol_error`. Line memories are intentionally
not reset because bulk reset can prevent inference of efficient FPGA memory.
Their stale contents cannot become valid output: the cropped-window rule forces
two newly accepted rows to overwrite every address used before output starts.

The source must restart at frame coordinate `(0,0)` after reset. In hardware,
deassertion of this asynchronously asserted reset must be synchronised to
`aclk`; that synchroniser belongs at the reset/integration boundary.

## Arithmetic

The accumulator has `PIXEL_WIDTH + 4` bits. Nine maximum-width unsigned pixels
fit in that range because `ceil(log2(9)) = 4`. Division by the constant nine
uses integer truncation. Synthesis tools can strength-reduce constant division,
but its resource and timing cost must be taken from an actual report rather
than assumed.

## Memory implementation

The source describes two line arrays with read-before-write behavior. Exact
mapping to LUT RAM, block RAM, or registers is tool-, version-, parameter-, and
constraint-dependent. No particular primitive or utilization is claimed until
a synthesis report for the relevant configuration is committed.

## Zynq integration boundary

Only the box labelled `implemented` exists in this repository's clean path:

```text
                      programmable logic
                    +----------------------+
PS/DDR -- AXI DMA -->| axis_mean_filter_3x3 |--> AXI DMA -- PS/DDR
 planned             |     implemented      |    planned
                    +----------------------+
```

Completing this system requires at least:

- a block design and reproducible block-design Tcl;
- MM2S and S2MM DMA configuration;
- agreement on frame dimensions, packing, and buffer strides;
- ARM-side buffer allocation and cache maintenance;
- interrupt or polling logic with timeout/error paths;
- comparison against the software model on real board output;
- committed utilization/timing reports and board/test conditions.

Until those exist, the accurate description is “streaming PL mean filter
checked by the included deterministic RTL simulation and intended for Zynq
PS/DMA integration.”
