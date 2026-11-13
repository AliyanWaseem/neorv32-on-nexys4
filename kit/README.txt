NEORV32 Windows Kit
===================

Everything needed to compile C programs for NEORV32 on Windows.
No WSL, no Python, no internet, nothing to install.

1. Unzip this folder to a path WITHOUT spaces, for example:
       C:\neorv32-kit

2. Your programs live in:
       C:\neorv32-kit\neorv32\sw\example\<project>
   To start a new one, copy an example folder (e.g. demo_blink_led)
   and edit main.c.

3. Build: double-click build.bat and type the project folder name,
   or drag the project folder onto build.bat.
   The result is neorv32_exe.bin inside the project folder.

4. Upload: open NEORV32-Uploader.exe, press CPU RESET on the board,
   pick neorv32_exe.bin and click "Upload & Run".

5. No board? Simulate instead: double-click sim.bat and type the project
   name. Your program runs on a simulated copy of the FPGA processor.
   UART output (printf etc.) prints in the window; LED changes print as
   [LEDS] lines. The simulated clock is 1 MHz to keep it fast, but the
   timestamps are real milliseconds. Short programs work best.

Contents:
   riscv-gcc\    RISC-V compiler (xPack riscv-none-elf-gcc)
   w64devkit\    make, shell tools and the PC compiler used by the build
   neorv32\      NEORV32 sources (pinned version)
   build.bat     the build script
   sim.bat       the simulation script (no board needed)
   ghdl\         GHDL VHDL simulator
   neorv32_nexys4.xdc   Vivado constraints for the original Nexys 4
