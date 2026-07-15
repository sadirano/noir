@echo off
setlocal DisableDelayedExpansion

set "command=%~1"
if not defined command set "command=cmd"

:: Requote each remaining argument so paths with spaces survive the relaunch.
:: Plain %-expansion works here because goto re-parses the line every
:: iteration, and unlike delayed expansion it leaves ! in arguments intact.
set "args="
:buildArgs
shift
if "%~1"=="" goto doneArgs
set "args=%args% "%~1""
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

:: Stop the calling batch script - the `call adm "%~f0"` self-elevation
:: pattern relies on that - without closing an interactive shell: the empty
:: parens raise a fatal parse error that aborts the entire batch call stack,
:: where a plain `exit` would also kill the cmd window whenever adm is typed
:: at the prompt.
call :halt 2>nul
exit /b

:halt
()
