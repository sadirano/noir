@echo off
:: Runs every Noir test suite; exits nonzero if any suite fails.
setlocal
set "FAILED=0"

call "%~dp0test_adm.cmd" || set "FAILED=1"
echo.
call "%~dp0test_core.cmd" || set "FAILED=1"
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test_noir.ps1" || set "FAILED=1"
echo.

if "%FAILED%"=="1" (
    echo Some test suites failed.
    exit /b 1
)
echo All test suites passed.
exit /b 0
