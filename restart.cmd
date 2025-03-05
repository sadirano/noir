@echo off
taskkill /f /im explorer.exe
echo Press a key to restore Explorer
pause > nul
start explorer.exe
