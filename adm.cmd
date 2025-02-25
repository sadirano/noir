@echo off
:: Check if running with admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: Relaunch this script with PowerShell elevation
    powershell -Command "Start-Process '%1' -Verb runAs"
    exit
)
