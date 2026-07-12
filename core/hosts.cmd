@echo off
if not defined EDITOR set "EDITOR=notepad"
powershell -NoProfile -Command "Start-Process $env:EDITOR \"$env:SystemRoot\System32\drivers\etc\hosts\" -Verb RunAs"
