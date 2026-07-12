@echo off
powershell -NoProfile -Command "Start-Process rundll32 'sysdm.cpl,EditEnvironmentVariables' -Verb RunAs"
