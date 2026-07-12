@echo off
setlocal EnableDelayedExpansion

set "command=%~1"
if not defined command set "command=cmd"

:: Requote each remaining argument so paths with spaces survive the relaunch.
set "args="
:buildArgs
shift
if "%~1"=="" goto doneArgs
set "args=!args! "%~1""
goto buildArgs
:doneArgs

:: Already elevated: return so a calling script can continue its work.
net session >nul 2>&1
if %errorlevel% equ 0 exit /b 0

:: Not elevated: relaunch the command with elevated rights, then stop the
:: caller. Command and arguments travel via environment variables so no
:: shell-level quote escaping is needed.
set "ADM_COMMAND=%command%"
set "ADM_ARGS=%args%"
powershell -NoProfile -Command "if ($env:ADM_ARGS) { Start-Process -FilePath $env:ADM_COMMAND -ArgumentList $env:ADM_ARGS -Verb RunAs } else { Start-Process -FilePath $env:ADM_COMMAND -Verb RunAs }"
exit
