@echo off
setlocal EnableDelayedExpansion
set "PASS=0"
set "FAIL=0"
set "CORE=%~dp0..\core"

echo ============================================================
echo  core commands Test Suite
echo ============================================================
echo.

:: -- Every command exists and silences command echo ------------

for %%F in (adm cc env h hosts q restart u) do (
    if exist "%CORE%\%%F.cmd" (
        call :pass "%%F.cmd exists"
        set "FIRST="
        set /p FIRST=<"%CORE%\%%F.cmd"
        if /i "!FIRST!"=="@echo off" (call :pass "%%F.cmd starts with @echo off") else (call :fail "%%F.cmd starts with @echo off - got: !FIRST!")
    ) else (
        call :fail "%%F.cmd exists"
    )
)

:: -- Per-command structural checks -----------------------------

call :expect env.cmd "RunAs" "env elevates"
call :expect env.cmd "sysdm.cpl" "env opens the environment variables editor"

call :expect h.cmd "shutdown /h" "h hibernates the machine"

call :expect hosts.cmd "drivers\etc\hosts" "hosts targets the hosts file"
call :expect hosts.cmd "RunAs" "hosts elevates"
call :expect hosts.cmd "if not defined EDITOR" "hosts falls back when EDITOR is unset"

call :expect restart.cmd "taskkill" "restart kills Explorer"
call :expect restart.cmd "start explorer.exe" "restart restores Explorer"
call :expect restart.cmd "pause" "restart waits for a keypress"

call :expect u.cmd "user@noir" "u edits through the nix noir alias"

:: -- q/cc stay in sync (cmd shims and PowerShell) --------------

:: q must end the shell, so plain `exit` - `exit /b` would only return from
:: the script and leave the prompt open.
call :expect q.cmd "exit" "q.cmd exits"
findstr /b /l /c:"exit /b" "%CORE%\q.cmd" >nul 2>&1
if %errorlevel% neq 0 (call :pass "q.cmd uses exit, not exit /b") else (call :fail "q.cmd uses exit, not exit /b")
call :expect cc.cmd "clip" "cc.cmd copies to the clipboard"

:: The doskey.mac these replaced cost a doskey.exe spawn per cmd start.
if not exist "%CORE%\doskey.mac" (call :pass "no doskey.mac to load at startup") else (call :fail "no doskey.mac to load at startup")

if exist "%CORE%\core.ps1" (call :pass "core.ps1 exists") else (call :fail "core.ps1 exists")
findstr /l /c:"function cc" "%CORE%\core.ps1" >nul 2>&1
if %errorlevel% equ 0 (call :pass "core.ps1 defines cc") else (call :fail "core.ps1 defines cc")
findstr /l /c:"function q" "%CORE%\core.ps1" >nul 2>&1
if %errorlevel% equ 0 (call :pass "core.ps1 defines q") else (call :fail "core.ps1 defines q")

:: -- Results --------------------------------------------------

echo.
echo ============================================================
if %FAIL% equ 0 (
    echo  All %PASS% tests passed.
) else (
    echo  %PASS% passed, %FAIL% failed.
)
echo ============================================================
if %FAIL% gtr 0 exit /b 1
exit /b 0

:: -- Helpers --------------------------------------------------
:expect
:: %1 = file under core\, %2 = literal string it must contain, %3 = test name
findstr /l /c:"%~2" "%CORE%\%~1" >nul 2>&1
if %errorlevel% equ 0 (call :pass "%~3") else (call :fail "%~3")
exit /b 0

:pass
echo [PASS] %~1
set /a PASS+=1
exit /b 0

:fail
echo [FAIL] %~1
set /a FAIL+=1
exit /b 1
