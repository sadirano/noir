@echo off
:: Noir web installer for cmd. One-liner:
::   curl -fsSL https://sadirano.com.br/noir.cmd -o %TEMP%\noir.cmd && %TEMP%\noir.cmd && del %TEMP%\noir.cmd
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/sadirano/noir/main/install/install.ps1 | iex"
