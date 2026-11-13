# NEORV32 RISC-V on Nexys 4 — From C Code to FPGA

> A beginner-friendly, hands-on guide to running the **NEORV32 RISC-V soft-core** on the **Digilent Nexys 4 (Artix-7)** FPGA, including building and uploading your own C programs on Windows with **no WSL, no Python and nothing to install**.

[![NEORV32](https://img.shields.io/badge/NEORV32-v1.13.7-blue)](https://github.com/stnolting/neorv32)
[![FPGA](https://img.shields.io/badge/FPGA-Artix--7%20XC7A100T-orange)](https://digilent.com/reference/programmable-logic/nexys-4/start)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-lightgrey)](#quick-start-windows)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

## What this repository is

A practical guide that fills the gap between the official [NEORV32 documentation](https://stnolting.github.io/neorv32/) and actually getting a RISC-V processor running on a Nexys 4. It contains:

- the **Vivado constraints** for the Nexys 4,
- a **Windows kit** (compiler + build tools + NEORV32, ready to unzip),
- a **double-click uploader app** for Windows and Linux,
- guides for the FPGA flow and for optional simulation.

---

## Downloads

Get everything from the **[latest release](https://github.com/AliyanWaseem/neorv32-on-nexys4/releases)**:

| File | For | What it is |
|------|-----|------------|
| `NEORV32-Kit-win64-v1.13.7.zip` | Windows | RISC-V compiler, build tools, NEORV32 v1.13.7, `build.bat`, constraints |
| `NEORV32-Uploader.exe` | Windows | Upload `neorv32_exe.bin` to the board and watch its output |
| `NEORV32-Uploader-linux.tar.gz` | Linux | The same uploader for Linux |

If you copied a file from someone else, check it is complete before using it:
`certutil -hashfile <file> SHA256` (Windows) or `sha256sum <file>` (Linux), and compare with the hash in the release notes.

---

## Requirements

**Hardware:** Digilent **Nexys 4** board (original, no DDR) and a USB-A to micro-USB cable. A Nexys 4 DDR also works with different LED pins, see [Board variants](#board-variants).

**Software:** Vivado (WebPACK, free) with the Digilent cable drivers. On Windows that is all; the kit and the uploader bring everything else.

---

## Quick start (Windows)

### 1. Install the kit

Extract `NEORV32-Kit-win64-v1.13.7.zip` to `C:\` so that `C:\neorv32-kit\build.bat` exists. **The path must not contain spaces.** Put `NEORV32-Uploader.exe` in the same folder.

### 2. Build the bitstream in Vivado

Create an RTL project for part `xc7a100tcsg324-1` (skip adding sources), then paste this into the **Tcl Console**:

```tcl
set NEO C:/neorv32-kit/neorv32
add_files [glob $NEO/rtl/core/*.vhd]
add_files $NEO/rtl/test_setups/neorv32_test_setup_bootloader.vhd
set_property library neorv32 [get_files -filter {FILE_TYPE == VHDL}]
set_property top neorv32_test_setup_bootloader [current_fileset]
add_files -fileset constrs_1 C:/neorv32-kit/neorv32_nexys4.xdc
update_compile_order -fileset sources_1
```

Then run **Synthesis → Implementation → Generate Bitstream**. Use forward slashes in TCL paths, even on Windows.

### 3. Program the FPGA

Hardware Manager → Open Target → Auto Connect → Program Device → select the `.bit` file. **LED 0 blinking** means the bootloader is running. The design is lost at power-off, so program it again after each power cycle.

### 4. Compile a C program

Double-click `C:\neorv32-kit\build.bat`, type `demo_blink_led`, press Enter. On success you get:

```
C:\neorv32-kit\neorv32\sw\example\demo_blink_led\neorv32_exe.bin
```

To write your own program, copy an example folder inside `neorv32\sw\example`, rename it (no spaces), and edit `main.c`.

### 5. Upload and run

Open `NEORV32-Uploader.exe`, pick the board's COM port and your `neorv32_exe.bin`, **press CPU RESET on the board**, then click **Upload & Run**. Program output appears in the window and in a log file. The app remembers your settings for next time.

> If Windows shows *"Windows protected your PC"*, click **More info → Run anyway** (the app is not code-signed).

---

## Linux or WSL

```bash
# xPack RISC-V GCC (Ubuntu's own riscv GCC is missing newlib headers)
cd ~
wget https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v14.2.0-3/xpack-riscv-none-elf-gcc-14.2.0-3-linux-x64.tar.gz
mkdir -p ~/riscv-xpack
tar -xzf xpack-riscv-none-elf-gcc-14.2.0-3-linux-x64.tar.gz -C ~/riscv-xpack --strip-components=1
echo 'export PATH=~/riscv-xpack/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
sudo apt install -y build-essential make git

# NEORV32, same version as the kit
mkdir -p ~/projects && cd ~/projects
git clone --depth 1 --branch v1.13.7 https://github.com/stnolting/neorv32.git

# Build
cd ~/projects/neorv32/sw/example/demo_blink_led
make MARCH=rv32imc_zicsr_zifencei clean_all exe
```

- **Projects must live inside `neorv32/sw/example/`.** The makefiles find NEORV32 with a relative path; elsewhere you get `common.mk: No such file or directory` (or pass `NEORV32_HOME=~/projects/neorv32`).
- **Upload on Linux:** use `NEORV32-Uploader-linux.tar.gz`, or the command-line script: `python3 scripts/upload.py /dev/ttyUSB1 neorv32_exe.bin`. Run `sudo usermod -aG dialout $USER` once, then log out and back in.
- **Upload on WSL:** build in WSL, but upload with the **Windows** app, because WSL cannot see COM ports. In its Browse dialog, WSL files are under `\\wsl.localhost\Ubuntu\home\<user>\`.
- **Slow internet?** Check every downloaded archive with `gzip -t file.tar.gz` before extracting, and share files between laptops with `python3 -m http.server 8000`.

### Why `rv32imc`?

`MARCH` tells the compiler which RISC-V extensions it may use, so it must match the hardware. The `neorv32_test_setup_bootloader` top enables **I, M, C, Zicsr and Zicntr** (no A). Using an extension the hardware lacks raises an illegal-instruction exception.

---

## Board variants

| Signal | Nexys 4 (original) | Nexys 4 DDR |
|--------|--------------------|-------------|
| Clock 100 MHz | E3 | E3 |
| CPU RESET (active low) | C12 | C12 |
| UART TX / RX | D4 / C4 | D4 / C4 |
| LEDs LD0–LD7 | T8, V9, R8, T6, T5, T4, U7, U6 | H17, K15, J13, N14, R18, V17, U17, U16 |

[`constraints/neorv32_nexys4.xdc`](constraints/neorv32_nexys4.xdc) uses the original Nexys 4 pins. With the wrong LED pins the bootloader still works over UART, but the LEDs stay dark.

---

## How it fits together

```
main.c
  ↓  riscv-none-elf-gcc (cross-compiler)
main.elf                       RISC-V machine code
  ↓  image_gen (small C tool, built automatically by the makefile)
neorv32_exe.bin                executable for the bootloader
  ↓  UART, 19200 baud (uploader app or terminal)
Bootloader copies it into instruction memory
  ↓
NEORV32 CPU executes your program
```

The bootloader is part of the bitstream, so you build the FPGA design **once** and then change programs as often as you like without touching Vivado.

---

## Common errors and fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `build.bat`: path contains spaces | Kit or project folder has a space | Use `C:\neorv32-kit` and project names without spaces |
| `common.mk: No such file or directory` | Project outside `neorv32/sw/example` | Move it there, or pass `NEORV32_HOME` |
| `riscv-none-elf-gcc: command not found` | Toolchain not on `PATH` | Re-run the `export PATH` step, open a new terminal |
| `gzip: unexpected end of file` / `not in gzip format` | Incomplete or broken download/copy | Check with `gzip -t` / `sha256sum` and copy again |
| Makefile errors after copying NEORV32 from Windows | Windows (CRLF) line endings | `file sw/common/common.mk`; convert with `sed -i 's/\r$//'` |
| Uploader: *Upload failed or timed out* | Missed the bootloader's ~8 s window | Press CPU RESET, then Upload & Run straight away |
| Uploader: *Access is denied* | COM port open in another program | Close the terminal / other uploader |
| Linux: *Permission denied* on `/dev/ttyUSB*` | Not in `dialout` group | `sudo usermod -aG dialout $USER`, log out and in |
| Bootloader works but LEDs dark | Wrong board variant pins | See [Board variants](#board-variants) |
| `ERROR_DEVICE` at bootloader start | SPI flash is empty | Normal, ignore it |
| Vivado library error | Files not in library `neorv32` | Run the `set_property library` line again |
| `ISA string must begin with rv32` | `MARCH=-march=...` | Use `MARCH=rv32imc_zicsr_zifencei` |

---

## Optional: simulation

Simulation is not needed for the FPGA flow, but it lets you test hardware changes without a board. See [`guides/01_simulation_guide.pdf`](guides/01_simulation_guide.pdf).

**GHDL (Path A):**

```bash
# In ~/projects/neorv32/sim/neorv32_tb.vhd set these generics to false for a much faster simulation:
# DUAL_CORE_EN, ICACHE_EN, DCACHE_EN, TRACE_SIMLOG_EN

cd ~/projects/neorv32/sw/example/hello_world
make MARCH=rv32imc_zicsr_zifencei USER_FLAGS+=-DUART0_SIM_MODE clean_all install

rm -rf ~/projects/neorv32/sim/build
cd ~/projects/neorv32/sim
sh ghdl.sh --stop-time=100ms
cat tb.uart0_rx.log        # Hello world! :)
```

`-DUART0_SIM_MODE` sends UART output to the simulator log. **Never use it for FPGA builds**, or you will see no output on the board.

**Icarus Verilog (Path B):** uses [neorv32-verilog](https://github.com/stnolting/neorv32-verilog); see the simulation guide.

---

## Repository structure

```
neorv32-on-nexys4/
├── README.md
├── LICENSE
├── constraints/
│   └── neorv32_nexys4.xdc         Vivado constraints (original Nexys 4)
├── guides/
│   ├── 01_simulation_guide.pdf    GHDL / Icarus simulation walkthrough
│   └── 02_fpga_deployment_guide.pdf
├── kit/
│   ├── build.bat                  Windows build script (goes into the kit)
│   └── README.txt                 Kit instructions
├── scripts/
│   └── upload.py                  Command-line uploader
├── tools/
│   └── fpga_uploader_gui.py       Source of the uploader app
└── .github/workflows/
    ├── build-uploader.yml         Builds the Windows .exe and Linux app
    └── build-kit.yml              Builds and tests the Windows kit
```

### Rebuilding the apps and the kit

Both are built by GitHub Actions, so you never need a Windows Python setup:

- **Uploader:** runs automatically when `tools/fpga_uploader_gui.py` changes.
- **Kit:** Actions → *Build Windows kit* → *Run workflow*. It downloads the pinned tools, compiles `demo_blink_led` on Windows as a test, and only then produces the zip.

Download the results from the run's **Artifacts** and attach them to a release.

---

## Next steps: custom hardware

NEORV32 offers three ways to attach your own logic, from loosely to tightly coupled:

- **XBUS** — external bus interface: attach a memory-mapped module outside the processor.
- **CFS** (Custom Functions Subsystem) — a memory-mapped block inside the SoC for tightly coupled co-processors.
- **CFU** (Custom Functions Unit) — new RISC-V instructions inside the CPU, used via inline assembly.

---

## Credits and references

- [NEORV32 by Stephan Nolting](https://github.com/stnolting/neorv32) and its [datasheet](https://stnolting.github.io/neorv32/)
- [Digilent Nexys 4 reference manual](https://digilent.com/reference/programmable-logic/nexys-4/reference-manual)
- [xPack RISC-V GCC](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack) and [w64devkit](https://github.com/skeeto/w64devkit), bundled in the Windows kit

## License

[MIT](LICENSE) for the guides, scripts and tools in this repository. NEORV32 itself is distributed under its own license (BSD-3-Clause).
