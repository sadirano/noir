@echo off
setlocal EnableDelayedExpansion
set "PASS=0"
set "FAIL=0"
set "ROOT=%~dp0..\"
set "ADM=%ROOT%core\adm.cmd"

echo ============================================================
echo  adm.cmd Test Suite
echo ============================================================
echo.

:: -- Structural tests (verify file content) -------------------

if exist "%ADM%" (
    call :pass "adm.cmd exists"
) else (
    call :fail "adm.cmd exists"
    goto :results
)

findstr /c:"net session" "%ADM%" >nul 2>&1
if %errorlevel% equ 0 (call :pass "admin check uses net session") else (call :fail "admin check uses net session")

findstr /c:"exit /b" "%ADM%" >nul 2>&1
if %errorlevel% equ 0 (call :pass "already-admin path uses exit /b") else (call :fail "already-admin path uses exit /b")

findstr /c:"pause" "%ADM%" >nul 2>&1
if %errorlevel% neq 0 (call :pass "no pause on exit") else (call :fail "no pause on exit")

findstr /c:"ADM_COMMAND" "%ADM%" >nul 2>&1
if %errorlevel% equ 0 (call :pass "command travels via environment variable") else (call :fail "command travels via environment variable")

findstr /c:"Start-Process" "%ADM%" >nul 2>&1
if %errorlevel% equ 0 (call :pass "elevates via PowerShell Start-Process") else (call :fail "elevates via PowerShell Start-Process")

:: -- Behavioral test: already-admin path ----------------------
:: When running as admin, adm.cmd must return to caller via exit /b
:: without launching anything. We verify by calling it and checking
:: that execution resumes here (i.e. exit /b was used, not exit).

net session >nul 2>&1
if %errorlevel% equ 0 (
    set "RETURNED=0"
    call "%ADM%"
    set "RETURNED=1"
    if "!RETURNED!"=="1" (
        call :pass "returns to caller when already admin [behavioral]"
    ) else (
        call :fail "returns to caller when already admin [behavioral]"
    )
) else (
    echo [SKIP] behavioral test: session is not elevated, skipping already-admin check
)

:: -- Dry-run tests: argument construction ---------------------
:: Mirror the real adm.cmd with the elevation short-circuit disabled
:: and the PowerShell launch replaced by an echo of the command and
:: argument list it would hand to Start-Process. This exercises the
:: actual requoting loop without triggering UAC.

set "DRY=%TEMP%\adm_test_dry.cmd"
powershell -NoProfile -Command "$bang=[char]33; $repl='echo DRY_COMMAND=' + $bang + 'command' + $bang + '& echo DRY_ARGS=' + $bang + 'args' + $bang; $c=Get-Content -LiteralPath $env:ADM; $c=$c -replace '^if .errorlevel. equ 0 exit /b 0$','rem dry-run: elevation short-circuit disabled'; $c=$c -replace '^powershell .*$',$repl; $c=$c -replace '^exit$','exit /b 0'; Set-Content -LiteralPath $env:DRY -Value $c"

:: Test: no-arg invocation should target bare cmd with no arguments
set "DCMD=" & set "DARGS="
for /f "tokens=1* delims==" %%A in ('call "%DRY%"') do (
    if "%%A"=="DRY_COMMAND" set "DCMD=%%B"
    if "%%A"=="DRY_ARGS" set "DARGS=%%B"
)
if "!DCMD!"=="cmd" (call :pass "no-arg invocation targets cmd [dry-run]") else (call :fail "no-arg invocation targets cmd [dry-run] - got: !DCMD!")
if "!DARGS!"=="" (call :pass "no-arg invocation passes no arguments [dry-run]") else (call :fail "no-arg invocation passes no arguments [dry-run] - got: !DARGS!")

:: Test: single command arg
set "DCMD=" & set "DARGS="
for /f "tokens=1* delims==" %%A in ('call "%DRY%" notepad') do (
    if "%%A"=="DRY_COMMAND" set "DCMD=%%B"
    if "%%A"=="DRY_ARGS" set "DARGS=%%B"
)
if "!DCMD!"=="notepad" (call :pass "single-arg invocation targets the command [dry-run]") else (call :fail "single-arg invocation targets the command [dry-run] - got: !DCMD!")

:: Test: argument containing spaces survives requoting
set "DCMD=" & set "DARGS="
for /f "tokens=1* delims==" %%A in ('call "%DRY%" notepad "C:\path with spaces\file.txt"') do (
    if "%%A"=="DRY_COMMAND" set "DCMD=%%B"
    if "%%A"=="DRY_ARGS" set "DARGS=%%B"
)
set "EXPECT= "C:\path with spaces\file.txt""
if "!DARGS!"=="!EXPECT!" (call :pass "spaced argument survives requoting [dry-run]") else (call :fail "spaced argument survives requoting [dry-run] - got: !DARGS!")

:: Test: self-re-elevation pattern used by env.cmd and hosts.cmd
set "MOCK_CALLER=%TEMP%\adm_test_caller.cmd"
(
    echo @echo off
    echo call "%DRY%" "%%~f0"
) > "%MOCK_CALLER%"
set "DCMD=" & set "DARGS="
for /f "tokens=1* delims==" %%A in ('call "%MOCK_CALLER%"') do (
    if "%%A"=="DRY_COMMAND" set "DCMD=%%B"
    if "%%A"=="DRY_ARGS" set "DARGS=%%B"
)
if /i "!DCMD!"=="%MOCK_CALLER%" (call :pass "call adm pattern re-elevates caller script [dry-run]") else (call :fail "call adm pattern re-elevates caller script [dry-run] - got: !DCMD!")

del "%DRY%" >nul 2>&1
del "%MOCK_CALLER%" >nul 2>&1

:: -- Results --------------------------------------------------
:results
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
:pass
echo [PASS] %~1
set /a PASS+=1
exit /b 0

:fail
echo [FAIL] %~1
set /a FAIL+=1
exit /b 1
