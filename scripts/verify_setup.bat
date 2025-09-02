@echo off
setlocal ENABLEDELAYEDEXPANSION
set ROOT=%~d0
set PY=%ROOT%\Python\python.exe
set IMPKT=%ROOT%\impacket\examples\secretsdump.py
set HIVES=%ROOT%\hives

echo === Verify Portable Setup ===
echo USB root: %ROOT%
echo.

if exist "%PY%" (
  echo [OK] Python: %PY%
) else (
  echo [X] Missing: %PY%
)

if exist "%IMPKT%" (
  echo [OK] Impacket: %IMPKT%
) else (
  echo [X] Missing: %IMPKT%
)

set LABEL=
set /p LABEL=Enter Label to check for hives (e.g., WIN10LAB, leave blank to skip): 
if "%LABEL%"=="" goto done

if exist "%HIVES%\%LABEL%\SAM" (
  echo [OK] Found: \hives\%LABEL%\SAM
) else (
  echo [X] Missing: \hives\%LABEL%\SAM
)
if exist "%HIVES%\%LABEL%\SYSTEM" (
  echo [OK] Found: \hives\%LABEL%\SYSTEM
) else (
  echo [X] Missing: \hives\%LABEL%\SYSTEM
)

:done
echo.
echo Done.
pause
