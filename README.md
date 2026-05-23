# NEORV32 RISC-V on Nexys 4 — From Simulation to FPGA

> A complete, beginner-friendly guide to simulating and deploying the **NEORV32 RISC-V soft-core processor** on the **Digilent Nexys 4 no DDR (Artix-7)** FPGA board — including running real C programs on hardware.

[![NEORV32](https://img.shields.io/badge/NEORV32-v1.12.x-blue)](https://github.com/stnolting/neorv32)
[![FPGA](https://img.shields.io/badge/FPGA-Artix--7%20XC7A100T-orange)](https://digilent.com/reference/programmable-logic/nexys-4/start)
[![Simulator](https://img.shields.io/badge/Simulator-GHDL%20%2B%20Icarus-green)](https://github.com/ghdl/ghdl)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

## What This Repository Is

This repo documents a full end-to-end implementation of the [NEORV32 RISC-V processor](https://github.com/stnolting/neorv32) — from **laptop simulation** to **running C code on a real Artix-7 FPGA**. Every command, every error encountered, and every fix is documented so that any computer engineering student can reproduce it without getting stuck.

**This is not just a clone of NEORV32.** It is a practical guide that fills the gap between the official documentation and actually getting it working — including all the toolchain issues, testbench configuration problems, and FPGA constraints that beginners run into.

---

## What You Will Achieve

By following this guide you will:

- Simulate the complete NEORV32 SoC on your laptop using GHDL and Icarus Verilog
- Convert the VHDL source to Verilog using GHDL synthesis (useful if you know Verilog)
- Compile real C programs using the RISC-V GCC toolchain
- See `Hello World!` printed from a C program running on a **simulated RISC-V CPU**
- Synthesize and implement the full SoC on a Nexys 4 FPGA using Vivado
- Upload and execute C programs on **real FPGA hardware** via UART bootloader

---

## Hardware and Software Requirements

### Hardware
- Digilent Nexys 4 board (Legacy or DDR variant — both use Artix-7 XC7A100T)
- USB-A to USB-Micro cable

### Software
| Tool | Version | Purpose |
|------|---------|---------|
| Ubuntu Linux | 22.04 or 24.04 | Host OS (WSL2 on Windows also works) |
| GHDL | 4.x | VHDL simulation and Verilog conversion |
| Icarus Verilog | any | Verilog simulation |
| GTKWave | any | Waveform viewer |
| xPack riscv-none-elf-gcc | 14.x | RISC-V C compiler |
| Vivado WebPACK | 2023.x or later | FPGA synthesis and implementation (free) |
| minicom | any | Serial terminal for UART communication |

---

## Repository Structure

```
neorv32-nexys4/
├── README.md                        ← you are here
├── constraints/
│   └── neorv32_nexys4.xdc           ← Vivado constraints for Nexys 4
├── guides/
│   ├── 01_simulation_guide       ← complete simulation walkthrough
│   └── 02_fpga_deployment_guide    ← complete FPGA implementation walkthrough
├── docs/
│   └── NEORV32_Simulation_Guide.docx  ← full reference document
└── scripts/
    └── upload.py                    ← Python script to upload .bin via UART
```

> **Note:** This repo contains guides and constraints only. The NEORV32 processor source is kept as a Git submodule pointing to the official repo. You clone both with `--recursive`.

---

## Quick Start

### Step 1 — Clone everything

```bash
git clone --recursive https://github.com/YOUR_USERNAME/neorv32-nexys4-guide.git
cd neorv32-nexys4-guide

# Also clone the official repos
mkdir -p ~/projects
cd ~/projects
git clone --recursive https://github.com/stnolting/neorv32.git
git clone --recursive https://github.com/stnolting/neorv32-verilog.git
```

### Step 2 — Install tools

```bash
sudo apt update
sudo apt install -y ghdl ghdl-mcode iverilog gtkwave make git python3 minicom

# Install xPack RISC-V GCC (Ubuntu's built-in version is missing headers)
cd ~
wget https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v14.2.0-3/xpack-riscv-none-elf-gcc-14.2.0-3-linux-x64.tar.gz
mkdir -p ~/riscv-xpack
tar -xzf xpack-riscv-none-elf-gcc-14.2.0-3-linux-x64.tar.gz -C ~/riscv-xpack --strip-components=1
echo 'export PATH=~/riscv-xpack/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Verify
riscv-none-elf-gcc --version   # should show xPack 14.x
ghdl --version                 # should show 4.x
```

### Step 3 — Run Icarus Verilog simulation (Path B)

```bash
cd ~/projects/neorv32-verilog

# Fix testbench timeout first (default 15ms is too short)
sed -i 's/#15_000_000/#2_000_000_000/' sim/testbench.v

# Convert VHDL to Verilog and simulate
make clean && make SIMULATOR=iverilog sim
```

Expected output:
```
neorv32-verilog verification testbench

NEORV32
Simulation successful!
```

### Step 4 — Run Hello World in GHDL simulation (Path A)

```bash
# Edit testbench to reduce simulation overhead
cd ~/projects/neorv32
# In sim/neorv32_tb.vhd, set these four generics to false:
# DUAL_CORE_EN, ICACHE_EN, DCACHE_EN, TRACE_LOG_EN

# Compile hello_world with UART simulation mode
cd sw/example/hello_world
make MARCH=rv32imac_zicsr_zifencei USER_FLAGS+=-DUART0_SIM_MODE clean_all install

# Delete old GHDL build and run
rm -rf ~/projects/neorv32/sim/build
cd ~/projects/neorv32/sim
sh ghdl.sh --stop-time=100ms

# In a second terminal, watch for output
watch -n1 'cat ~/projects/neorv32/sim/tb.uart0_rx.log'
```

Expected output in `tb.uart0_rx.log`:
```
Hello world! :)
```

---

## FPGA Implementation (Nexys 4)

### Vivado Project Setup

1. Open Vivado → Create Project → RTL Project
2. Select part: `xc7a100tcsg324-1`
3. Add all files from `neorv32/rtl/core/` — set library to `neorv32`
4. Add `neorv32/rtl/test_setups/neorv32_test_setup_bootloader.vhd` — library `neorv32`
5. Add `constraints/neorv32_nexys4.xdc`
6. Set `neorv32_test_setup_bootloader` as Top
7. Run Synthesis → Implementation → Generate Bitstream

Or use the Vivado TCL console to add all files at once:

```tcl
set core_dir "/home/YOUR_USER/projects/neorv32/rtl/core"
set vhd_files [glob -directory $core_dir *.vhd]
add_files -fileset sources_1 $vhd_files
foreach f $vhd_files {
    set_property library neorv32 [get_files $f]
}
add_files -fileset sources_1 "/home/YOUR_USER/projects/neorv32/rtl/test_setups/neorv32_test_setup_bootloader.vhd"
set_property library neorv32 [get_files "neorv32_test_setup_bootloader.vhd"]
set_property top neorv32_test_setup_bootloader [current_fileset]
```

### Expected Resource Usage

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | ~6,000 | 63,400 | ~10% |
| Flip-Flops | ~4,000 | 126,800 | ~3% |
| BRAM (36Kb) | ~10 | 135 | ~7% |
| DSP Slices | ~6 | 240 | ~3% |

### Upload and Run C Programs

```bash
# Connect to UART (find your port first)
ls /dev/ttyUSB*
minicom -D /dev/ttyUSB1 -b 19200

# Compile your program
cd ~/projects/neorv32/sw/example/hello_world
make MARCH=rv32imac_zicsr_zifencei clean_all all

# Upload via Python script
python scripts/upload.py /dev/ttyUSB1 build/neorv32_exe.bin
```

At the `CMD:>` prompt you can also upload manually:
- Press `u` → send the `.bin` file
- Press `e` → execute it

---

## Constraints File

```tcl
## Clock - 100MHz
set_property PACKAGE_PIN E3  [get_ports clk_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk_i]
create_clock -add -name sys_clk_pin -period 10.00 [get_ports clk_i]

## CPU RESET button (dedicated reset button, active low - perfect for NEORV32)
set_property PACKAGE_PIN C12 [get_ports rstn_i]
set_property IOSTANDARD LVCMOS33 [get_ports rstn_i]

## UART TX
set_property PACKAGE_PIN D4  [get_ports uart0_txd_o]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_txd_o]

## UART RX
set_property PACKAGE_PIN C4  [get_ports uart0_rxd_i]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_rxd_i]

## LEDs 0-7
set_property PACKAGE_PIN H17 [get_ports {gpio_o[0]}]; set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[0]}]
set_property PACKAGE_PIN K15 [get_ports {gpio_o[1]}]; set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[1]}]
set_property PACKAGE_PIN J13 [get_ports {gpio_o[2]}]; set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[2]}]
set_property PACKAGE_PIN N14 [get_ports {gpio_o[3]}]; set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[3]}]
set_property PACKAGE_PIN R18 [get_ports {gpio_o[4]}]; set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[4]}]
set_property PACKAGE_PIN V17 [get_ports {gpio_o[5]}]; set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[5]}]
set_property PACKAGE_PIN U17 [get_ports {gpio_o[6]}]; set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[6]}]
set_property PACKAGE_PIN U16 [get_ports {gpio_o[7]}]; set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[7]}]
```

---

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `make: No rule to make target 'sim'` | Wrong directory | `cd ~/projects/neorv32-verilog` first |
| `make: 'sim' is up to date` | Old output file exists | `make clean` first |
| `ISA string must begin with rv32` | Duplicate `-march=` prefix | Use `MARCH=rv32imac_zicsr_zifencei` not `MARCH=-march=rv32...` |
| `fatal error: inttypes.h not found` | Ubuntu GCC missing newlib | Install xPack toolchain (see Step 2) |
| `unrecognized opcode 'fence.i'` | Missing zifencei extension | Add `_zifencei` to MARCH flag |
| `tb.uart0_rx.log` empty after simulation | `neorv32_imem_image.vhd` missing | Run `make install` in hello_world folder |
| GHDL simulation extremely slow | Dual-core + caches enabled | Set `DUAL_CORE_EN`, `ICACHE_EN`, `DCACHE_EN`, `TRACE_LOG_EN` to `false` in `neorv32_tb.vhd` |
| Vivado synthesis fails with library error | Files not under `neorv32` library | Set library to `neorv32` for all `.vhd` files |
| `ERROR_DEVICE` on bootloader startup | SPI flash is empty | Normal — just use `u` to upload your program |

---

## Understanding the Stack

```
Your C program (hello_world.c)
        ↓  compiled by riscv-none-elf-gcc
RISC-V machine code (.elf → .bin)
        ↓  converted by image_gen.py
VHDL memory image (neorv32_imem_image.vhd)
        ↓  loaded into simulated IMEM by GHDL
NEORV32 CPU fetches and executes instructions
        ↓  UART0 peripheral serializes output
Characters appear in your terminal
```

Everything in simulation maps 1:1 to what happens on the real FPGA — the same C code, same binary, same CPU architecture, same UART output. Simulation proves the design before committing to hardware.

---

## Next Steps — Custom Accelerator

This project is the foundation for adding a custom hardware accelerator to NEORV32. The two integration paths are:

**XBUS Peripheral (recommended for beginners):** Add your accelerator as a memory-mapped peripheral. C code writes data to a fixed address, your hardware processes it, C code reads the result back. Same interface as writing a device driver.

**Custom Functions Unit (CFU):** Add custom RISC-V instructions directly into the CPU pipeline. Accessed via inline assembly in C. Lowest latency but more complex to implement.

Both approaches can be simulated first using the exact same GHDL flow documented in this repo before going to FPGA.

---

## Credits and References

- [NEORV32 by Stephan Nolting](https://github.com/stnolting/neorv32) — the processor this guide is built around
- [NEORV32 Datasheet](https://stnolting.github.io/neorv32/) — official documentation
- [Digilent Nexys 4 Reference Manual](https://digilent.com/reference/programmable-logic/nexys-4/reference-manual) — board pinout and specs
- [xPack RISC-V GCC](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack) — the toolchain that actually works on Ubuntu 24.04

---

## License

MIT License — use this freely, attribution appreciated.

---

*Built by a computer engineering student learning RISC-V processor implementation from simulation to real FPGA hardware.*
