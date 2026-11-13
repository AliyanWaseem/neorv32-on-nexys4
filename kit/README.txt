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

Contents:
   riscv-gcc\    RISC-V compiler (xPack riscv-none-elf-gcc)
   w64devkit\    make, shell tools and the PC compiler used by the build
   neorv32\      NEORV32 sources (pinned version)
   build.bat     the build script
   neorv32_nexys4.xdc   Vivado constraints for the original Nexys 4
