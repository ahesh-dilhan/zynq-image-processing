# 🖼️ Zynq Image Processing — Line Buffer IP Core

> A parameterised Verilog/VHDL line buffer for real-time image processing, packaged as a reusable AXI4-Stream IP core for Xilinx Zynq SoCs.

![Language](https://img.shields.io/badge/HDL-Verilog%20%2F%20VHDL-blue)
![Platform](https://img.shields.io/badge/Platform-Xilinx%20Zynq-orange)
![Tool](https://img.shields.io/badge/Tool-Vivado-blueviolet)
![License](https://img.shields.io/github/license/ahesh-dilhan/zynq-image-processing)
![Last Commit](https://img.shields.io/github/last-commit/ahesh-dilhan/zynq-image-processing)

---

## 📌 Overview

This project implements a **line buffer** — a fundamental building block for 2D image processing kernels — in Verilog/VHDL, targeting the **Xilinx Zynq-7000 SoC** platform. A line buffer stores `N` rows of pixel data so that a sliding kernel window (e.g., 3×3 for Sobel, Gaussian blur) can access multiple image rows simultaneously on an FPGA without requiring external memory access per pixel.

The core is packaged as a **custom IP block** in Vivado IP Packager, making it drop-in ready for Zynq block designs.

---

## ✨ Features

- ✅ Parameterisable image width, number of buffer lines, and pixel bit-depth
- ✅ Sliding window output — exposes a full `N × M` pixel neighbourhood each clock cycle
- ✅ Fully synchronous design with active-high synchronous reset
- ✅ Packaged as a Vivado-compatible custom IP core (`component.xml`)
- ✅ Waveform configuration files included for quick simulation review
- ✅ Block design schematic exported as PDF

---

## 🛠 Tech Stack

| Category | Detail |
|---|---|
| **HDL** | Verilog (RTL), VHDL (94.0%) |
| **Target Platform** | Xilinx Zynq-7000 SoC |
| **EDA Tool** | Xilinx Vivado Design Suite |
| **Simulation** | Vivado Behavioural Simulation |
| **IP Packaging** | Vivado IP Packager (AXI4-Stream) |

---

## 📁 Project Structure

```
zynq-image-processing/
├── image_processing.srcs/       # RTL source files & testbenches
│   ├── sources_1/               # Design sources (Verilog / VHDL)
│   └── sim_1/                   # Simulation / testbench files
├── xgui/                        # Vivado IP GUI customisation TCL
├── component.xml                # IP-XACT descriptor (Vivado IP core)
├── image_processing.xpr         # Vivado project file
├── linebuffer_behav.wcfg        # Waveform config — line buffer sim
├── tb_behav.wcfg                # Waveform config — testbench sim
├── schematic.pdf                # Block design schematic export
└── .gitignore
```

---

## 🚀 Getting Started

### Prerequisites

- [Xilinx Vivado Design Suite](https://www.xilinx.com/support/download.html) **2020.1 or later** (free WebPACK edition is sufficient)
- A Xilinx Zynq-7000 development board (e.g., Zynq ZC702, Digilent Zybo Z7) — *optional for simulation*

### Open the Project

```bash
# 1. Clone the repository
git clone https://github.com/ahesh-dilhan/zynq-image-processing.git

# 2. Launch Vivado and open the project
#    File → Open Project → select image_processing.xpr
```

Or open directly from the Vivado Tcl console:

```tcl
open_project /path/to/zynq-image-processing/image_processing.xpr
```

### Run Simulation

1. In Vivado, go to **Flow Navigator → Simulation → Run Simulation → Run Behavioural Simulation**
2. Load the saved waveform layout:
   - For the line buffer: `linebuffer_behav.wcfg`
   - For the full testbench: `tb_behav.wcfg`

### Use as a Custom IP in Your Block Design

1. In Vivado: **Tools → Settings → IP → Repository** → Add this repo's root directory
2. The `Line Buffer` IP will appear in the IP Catalogue
3. Drag it into your block design and connect AXI4-Stream ports

---

## 📐 How It Works

A line buffer stores `N` complete rows of an image in on-chip BRAM. As new pixels stream in, the buffer shifts rows and presents a full pixel neighbourhood to the downstream processing kernel every clock cycle.

```
Input stream (pixel by pixel, row by row):
  → Row N stored in BRAM
  → Row N-1 shifted down
  → 3×3 window assembled from 3 simultaneous row outputs
  → Window passed to kernel (e.g., edge detector, blur)
```

This eliminates the need for external DDR access mid-frame, enabling **low-latency, fully pipelined** image processing at pixel clock speeds.

---

## 🔌 Port Description

| Port | Direction | Description |
|---|---|---|
| `clk` | Input | System clock |
| `rst` | Input | Active-high synchronous reset |
| `pixel_in` | Input | Incoming pixel data |
| `data_valid` | Input | Pixel data valid strobe |
| `window_out` | Output | N×M pixel neighbourhood window |
| `window_valid` | Output | Output window valid flag |

> 📄 See `schematic.pdf` for the full block design connectivity diagram.

---

## 🧪 Simulation Results

Waveform configuration files are included for immediate simulation review:

- **`linebuffer_behav.wcfg`** — isolates line buffer BRAM read/write behaviour
- **`tb_behav.wcfg`** — full top-level testbench showing window assembly timing

Load either `.wcfg` file in the Vivado waveform viewer after running behavioural simulation.

---

## 🗺 Roadmap

- [x] Parameterisable line buffer RTL
- [x] Testbench & behavioural simulation
- [x] Vivado IP packaging
- [ ] AXI4-Stream wrapper for plug-and-play Zynq PS integration
- [ ] 3×3 Sobel edge detection kernel example design
- [ ] Constraints file for common Zynq boards (Zybo Z7, ZC702)
- [ ] Python test image generator for simulation stimulus

---

## 🤝 Contributing

Contributions and improvements are welcome!

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes with clear messages
4. Open a Pull Request against `main`

For bug reports, open an issue with a description of the unexpected simulation or synthesis behaviour.

---

## 👤 Author

**Ahesh Dilhan**
- GitHub: [@ahesh-dilhan](https://github.com/ahesh-dilhan)

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for details.

---

> 💡 **Tip:** If you found this useful for your FPGA image processing work, consider leaving a ⭐ — it helps others find the project!
