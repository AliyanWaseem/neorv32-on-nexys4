@echo off
rem ===========================================================================
rem  NEORV32 Windows Kit - build a C program into neorv32_exe.bin
rem
rem  Use:  double-click this file and type a project name, or
rem        drag a project folder onto this file.
rem  Projects live in:  neorv32\sw\example\<project>
rem  No WSL, Python or internet needed: all tools are inside this kit.
rem ===========================================================================
setlocal EnableExtensions
title NEORV32 build

rem ---- Where is the kit? (the folder that contains this file) ----
set "KIT=%~dp0"
set "KIT=%KIT:~0,-1%"

rem ---- make cannot handle spaces in paths ----
if not "%KIT%"=="%KIT: =%" goto :kit_spaces

rem ---- Use only the kit's tools, so other installed tools cannot interfere ----
set "PATH=%KIT%\w64devkit\bin;%KIT%\riscv-gcc\bin;%SystemRoot%\system32;%SystemRoot%"
set "EXAMPLES=%KIT%\neorv32\sw\example"
if not defined MARCH set "MARCH=rv32imac_zicsr_zifencei"

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

rem ---- Projects outside neorv32\sw\example need NEORV32_HOME ----
set "NHOME="
set "REST=%PROJ:*\neorv32\sw\example\=%"
if "%REST%"=="%PROJ%" set "NHOME=%KIT:\=/%/neorv32"
if defined NHOME echo Note: project is outside neorv32\sw\example, using NEORV32_HOME=%NHOME%

rem ---- Build ----
echo.
echo Building: %PROJ%
echo MARCH:    %MARCH%
echo.
pushd "%PROJ%"
if defined NHOME (
  make NEORV32_HOME=%NHOME% MARCH=%MARCH% clean_all exe
) else (
  make MARCH=%MARCH% clean_all exe
)
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" goto :failed
if not exist "%PROJ%\neorv32_exe.bin" goto :failed

echo.
echo ===========================================================
echo  SUCCESS
echo  %PROJ%\neorv32_exe.bin
echo  Upload it with NEORV32-Uploader.exe
echo ===========================================================
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
echo Rename the folder so the path has no spaces.
goto :fail_end

:no_proj
echo ERROR: Project folder not found: %PROJ%
goto :fail_end

:no_makefile
echo ERROR: No makefile in %PROJ%
echo Copy an existing example folder (for example hello_world) and edit main.c.
goto :fail_end

:failed
echo.
echo BUILD FAILED - read the messages above.
goto :fail_end

:fail_end
if not defined CI pause
exit /b 1
