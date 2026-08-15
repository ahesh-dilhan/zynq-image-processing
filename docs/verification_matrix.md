# Verification matrix

This matrix separates behavior exercised by the current portable tests from
properties that still require synthesis, formal analysis, or system hardware.

Status meanings: **checked** = exercised by a passing current test;
**partial** = some cases are exercised but the stated requirement is broader;
**gap** = no executable evidence is published yet.

| Requirement or invariant | Current evidence | Status | Remaining gap / acceptance criterion |
|---|---|---:|---|
| A valid 3x3 window produces the unsigned sum divided by 9 with truncation. | Python known-window/frame tests in [`tests/test_reference_model.py`](../tests/test_reference_model.py); every RTL result is scored in [`sim/tb_axis_mean_filter_3x3.sv`](../sim/tb_axis_mean_filter_3x3.sv). | **checked** | Add extreme-value and randomized image suites if broader arithmetic coverage is required. |
| A `W x H` frame produces exactly `(W-2) x (H-2)` results; no padding or row wrap is introduced. | The 8x6 RTL test checks 24 results and their order; Python checks 3x3, 4x4, and 8x6 shapes. | **checked** | Exercise additional widths/heights, including the default 512x512 configuration. |
| Image state advances only on `s_axis_tvalid && s_axis_tready`. | RTL source bubbles and multi-cycle sink stalls are injected by the self-checking testbench. | **checked** | Add assertions/coverage or formal proof over arbitrary stall sequences. |
| While `m_axis_tvalid && !m_axis_tready`, output data, SOF, and EOL remain stable and no input is accepted. | Explicit held-output comparison and ready check in the RTL testbench. | **checked** | Formal AXI stability properties are not present. |
| Output SOF marks the first cropped pixel and EOL marks every cropped line end. | Every transferred output sideband is checked by the RTL scoreboard. | **checked** | Continuous multi-frame operation is not exercised. |
| Unexpected input framing sets `protocol_error`, which remains set until reset. | A missing SOF is injected and the flag is observed; reset clearing is checked. | **partial** | Test early/missing EOL, extra SOF, persistence across several transfers, and the documented no-resynchronization behavior. |
| Reset immediately clears output-valid/control diagnostics, and two fresh rows refill unreset memories before output resumes. | Asynchronous assertion clearing is tested after a malformed beat. | **partial** | Restart a complete frame after reset, including reset during an active/stalled frame. Synchronised reset deassertion is an integration obligation. |
| Elaboration parameters reject invalid dimensions/stream widths. | RTL contains elaboration-time checks; Python rejects invalid model dimensions/sample ranges. | **partial** | Run negative RTL elaborations and test legal non-default `PIXEL_WIDTH`, width, and height values. |
| The clean RTL maps to the intended FPGA memories, meets timing, and sustains the claimed pixel rate. | No synthesis or implementation report is committed. | **gap** | Record tool/version/part, inferred memories, LUT/FF/BRAM/DSP use, achieved clock, and post-route timing. |
| The packaged IP metadata and AXI4-Stream interface match the clean RTL. | The clean source-first path is tested; legacy `component.xml` is explicitly non-authoritative. | **gap** | Repackage the clean core, inspect the generated bus mappings, and run AXI protocol checks. |
| Zynq PS, AXI DMA, cache maintenance, interrupts, and board output are correct. | Documented as planned; no system artifact is claimed. | **gap** | Add block-design Tcl, address map, ARM software, timeout/error paths, and a board result checked against the same oracle. |
| Functional/code/branch/toggle coverage and formal properties meet a stated target. | No coverage database or formal run is published. | **gap** | Define targets, add assertions/covers, and archive reproducible reports. |

Portable regression command: `make test`. A green run covers the Python model
and the deterministic RTL scenario above; it does not establish synthesis,
timing, IP packaging, PS/DMA integration, or board performance.
