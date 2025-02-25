@echo off
setlocal EnableDelayedExpansion

echo ===================================================
echo Noir Core Utilities Health Check
echo ===================================================
echo.

:: Check for Neovim (nvim)
where nvim >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Neovim is not installed.
    echo         This is required for editing scripts.
    echo         To install: scoop install neovim
    echo.
) else (
    echo [OK] Neovim is installed.
)

:: Check for Everything CLI (es)
where es >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Everything CLI is not installed.
    echo           The "fn" command will not work.
    echo           To install: scoop install everything
    echo.
) else (
    echo [OK] Everything CLI is installed.
)

:: Check for fzf
where fzf >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] fzf is not installed.
    echo           The "fn" command will not work.
    echo           To install: scoop install fzf
    echo.
) else (
    echo [OK] fzf is installed.
)

:: Check for Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Python is not installed.
    echo           The "m" command will not work.
    echo           To install: scoop install python
    echo.
) else (
    echo [OK] Python is installed.
)

:: Check for Scoop (informational only)
where scoop >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Scoop is not installed.
    echo         Installing missing tools via Scoop will not be available.
    echo         To install Scoop, run this in PowerShell as Administrator:
    echo.
    echo         Invoke-WebRequest -UseBasicParsing https://get.scoop.sh ^| iex
    echo.
) else (
    echo [OK] Scoop is installed.
)

echo ===================================================
echo Health check complete.
endlocal
