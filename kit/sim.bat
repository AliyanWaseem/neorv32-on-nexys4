@echo off
rem ===========================================================================
rem  NEORV32 Windows Kit - simulate a C program WITHOUT an FPGA board
rem
rem  Use:  double-click this file and type a project name, or
rem        drag a project folder onto this file.
rem  The program runs on a simulated copy of the FPGA processor (GHDL).
rem  UART output prints in this window; LED changes print as [LEDS] lines.
rem ===========================================================================
setlocal EnableExtensions
title NEORV32 simulation

set "KIT=%~dp0"
set "KIT=%KIT:~0,-1%"
if not "%KIT%"=="%KIT: =%" goto :kit_spaces

set "PATH=%KIT%\w64devkit\bin;%KIT%\riscv-gcc\bin;%KIT%\ghdl\bin;%SystemRoot%\system32;%SystemRoot%"
set "NEO=%KIT%\neorv32"
set "EXAMPLES=%NEO%\sw\example"
if not defined MARCH set "MARCH=rv32imc_zicsr_zifencei"

rem ---- Which project? ----
if not "%~1"=="" (
  set "PROJ=%~f1"
  goto :have_proj
)
echo Projects in neorv32\sw\example:
echo.
dir /b /ad "%EXAMPLES%"
echo.
set "NAME="
set /p "NAME=Type a project folder name and press Enter: "
if not defined NAME goto :no_proj
set "PROJ=%EXAMPLES%\%NAME%"

:have_proj
if not exist "%PROJ%\" goto :no_proj
if not exist "%PROJ%\makefile" if not exist "%PROJ%\Makefile" goto :no_makefile
if not "%PROJ%"=="%PROJ: =%" goto :proj_spaces

rem ---- How long to simulate? (simulated time, not real time) ----
if defined STOP goto :have_stop
set "STOP=1000ms"
if defined CI goto :have_stop
echo.
echo How much SIMULATED time to run? Examples: 300ms, 1000ms, 3000ms
echo More time = longer wait. Press Ctrl+C any time to stop early.
set "ANS="
set /p "ANS=Simulated time [1000ms]: "
if defined ANS set "STOP=%ANS%"
:have_stop

set "NHOME="
set "REST=%PROJ:*\neorv32\sw\example\=%"
if "%REST%"=="%PROJ%" set "NHOME=%KIT:\=/%/neorv32"

rem ---- 1. Compile for simulation and install the program into the IMEM image ----
echo.
echo [1/3] Compiling %PROJ% for simulation ...
pushd "%PROJ%"
if defined NHOME (
  make NEORV32_HOME=%NHOME% MARCH=%MARCH% USER_FLAGS+=-DUART0_SIM_MODE clean_all install
) else (
  make MARCH=%MARCH% USER_FLAGS+=-DUART0_SIM_MODE clean_all install
)
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" goto :failed

rem ---- 2. Analyse the VHDL (only changed files are re-analysed) ----
echo.
echo [2/3] Preparing the simulated processor ...
pushd "%NEO%\sim"
if not exist build_nexys4 mkdir build_nexys4
for %%F in ("%NEO%\rtl\core\*.vhd") do (
  ghdl -i --std=08 --workdir=build_nexys4 --work=neorv32 "%%F"
)
ghdl -i --std=08 --workdir=build_nexys4 --work=neorv32 sim_uart_rx.vhd neorv32_nexys4_tb.vhd
ghdl -m --std=08 --workdir=build_nexys4 --work=neorv32 neorv32_nexys4_tb
if errorlevel 1 (
  popd
  goto :failed
)

rem ---- 3. Run ----
echo.
echo [3/3] Simulating %STOP% of processor time. Output follows; Ctrl+C stops early.
echo -----------------------------------------------------------------------------
ghdl -r --std=08 --workdir=build_nexys4 --work=neorv32 neorv32_nexys4_tb --max-stack-alloc=0 --ieee-asserts=disable --assert-level=error --stop-time=%STOP%
set "RC=%ERRORLEVEL%"
popd
echo -----------------------------------------------------------------------------
if not "%RC%"=="0" goto :failed
echo Simulation finished.
if not defined CI pause
exit /b 0

:kit_spaces
echo ERROR: The kit folder path contains spaces:
echo   %KIT%
echo Move the kit to a path without spaces, for example C:\neorv32-kit
goto :fail_end

:proj_spaces
echo ERROR: The project path contains spaces:
echo   %PROJ%
goto :fail_end

:no_proj
echo ERROR: Project folder not found: %PROJ%
goto :fail_end

:no_makefile
echo ERROR: No makefile in %PROJ%
goto :fail_end

:failed
echo.
echo SIMULATION FAILED - read the messages above.
goto :fail_end

:fail_end
if not defined CI pause
exit /b 1
