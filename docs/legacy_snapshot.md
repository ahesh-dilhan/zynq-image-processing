# Legacy Vivado snapshot

The repository preserves the original 2020 Vivado project and generated IP
files to show the project's history. They have not been deleted or rewritten,
but they are not the source used by the current reproducible verification path.

## Preserved files

- `image_processing.xpr`
- `image_processing.srcs/`
- `component.xml` and `xgui/`
- saved waveform configurations
- `schematic.pdf`

The large VHDL percentage shown by GitHub comes primarily from generated Xilinx
FIFO support files; it is not a claim that the filter datapath was authored in
VHDL.

## Why the clean path was added

Reviewing the old prototype identified several interface and reproducibility
problems:

- `o_data_ready` reflected an output FIFO threshold, but the legacy
  `imageControl` still advanced on `i_data_valid` without requiring the input
  ready/valid handshake.
- The generated FIFO's `s_axis_tready` was left unconnected, so its ability to
  accept the convolution result was ignored.
- Filter pipeline-valid registers had no explicit reset behavior.
- Frame width, buffer count, counter sizes, and thresholds were fixed to the
  512-pixel experiment even though the old README described the design as
  broadly parameterised.
- The file-driven testbench assumed an external bitmap at a hard-coded path,
  forced the sink permanently ready, and did not check numerical results.
- The stored IP package describes the historical module, not the new
  `axis_mean_filter_3x3` interface.

These are normal issues for an early prototype, but leaving them implicit makes
the repository hard to review. The new `rtl/`, `sim/`, `tests/`, and `scripts/`
directories provide a small authoritative path with an explicit contract.

## Opening the old project

The snapshot may still be opened for historical inspection, but generated IP
and Vivado-version differences can affect it. Do not treat a successful open of
`image_processing.xpr` as verification of the new core. Use `make test` for the
portable self-check, or rebuild the clean Vivado project with:

```bash
vivado -mode batch -source scripts/create_vivado_project.tcl
```

If the new core is packaged for an IP catalog later, its generated metadata
should live in a clearly versioned build/release flow rather than overwriting
the historical package without review.
