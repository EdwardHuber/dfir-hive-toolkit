@echo off
:: WinRE Helper – Lab Edition (offline only)
:: Copies SAM & SYSTEM into \hives\<Label>\ on this USB.

set WINPART=D:
set USBPART=E:
set LABEL=

echo === WinRE Hive Copy Helper ===
echo This assumes Windows is NOT running (you are in Recovery Command Prompt).
echo.

set /p WINPART=Windows partition letter (default D:):
if "%WINPART%"=="" set WINPART=D:
set /p USBPART=USB drive letter (default E:):
if "%USBPART%"=="" set USBPART=E:
set /p LABEL=Target Label (e.g., WIN10LAB):
if "%LABEL%"=="" set LABEL=LABCASE

set DEST=%USBPART%\hives\%LABEL%
if not exist "%DEST%" mkdir "%DEST%"

echo Copying hives into %DEST% ...
copy "%WINPART%\Windows\System32\config\SAM" "%DEST%\SAM"
copy "%WINPART%\Windows\System32\config\SYSTEM" "%DEST%\SYSTEM"

echo.
echo Done. Hives now at: %DEST%
pause
