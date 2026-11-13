#!/usr/bin/env bash
# =============================================================================
#  Simulate a NEORV32 C program WITHOUT an FPGA board (Linux / WSL)
#
#  Usage:  scripts/sim.sh <project-folder> [stop-time]
#     e.g. scripts/sim.sh ~/projects/neorv32/sw/example/hello_world 1000ms
#
#  Needs: riscv-none-elf-gcc and ghdl on PATH.
#  NEORV32 location: $NEORV32_HOME (default ~/projects/neorv32)
#  The program runs on a simulated copy of the FPGA processor
#  (sim/neorv32_nexys4_tb.vhd). UART output prints here; LED changes print
#  as [LEDS] lines.
# =============================================================================
set -e

PROJ="${1:?usage: $0 <project-folder> [stop-time]}"
STOP="${2:-1000ms}"
MARCH="${MARCH:-rv32imc_zicsr_zifencei}"
NEO="${NEORV32_HOME:-$HOME/projects/neorv32}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TB="$SCRIPT_DIR/../sim/neorv32_nexys4_tb.vhd"

PROJ="$(cd "$PROJ" && pwd)"
NEO="$(cd "$NEO" && pwd)"
[ -f "$TB" ] || { echo "ERROR: testbench not found: $TB"; exit 1; }
command -v ghdl >/dev/null || { echo "ERROR: ghdl not found (sudo apt install ghdl)"; exit 1; }
command -v riscv-none-elf-gcc >/dev/null || { echo "ERROR: riscv-none-elf-gcc not on PATH"; exit 1; }

echo "[1/3] Compiling $PROJ for simulation ..."
make -C "$PROJ" NEORV32_HOME="$NEO" MARCH="$MARCH" USER_FLAGS+=-DUART0_SIM_MODE clean_all install

echo "[2/3] Preparing the simulated processor ..."
cd "$NEO/sim"
mkdir -p build_nexys4
ghdl -i --std=08 --workdir=build_nexys4 --work=neorv32 "$NEO"/rtl/core/*.vhd sim_uart_rx.vhd "$TB"
ghdl -m --std=08 --workdir=build_nexys4 --work=neorv32 neorv32_nexys4_tb

echo "[3/3] Simulating $STOP of processor time. Ctrl+C stops early."
echo "-----------------------------------------------------------------------------"
ghdl -r --std=08 --workdir=build_nexys4 --work=neorv32 neorv32_nexys4_tb \
  --max-stack-alloc=0 --ieee-asserts=disable --assert-level=error --stop-time="$STOP"
echo "-----------------------------------------------------------------------------"
