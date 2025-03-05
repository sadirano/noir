:: Clean setup configuration

@echo off

::Install Scoop
PowerShell -Command "irm https://get.scoop.sh | iex"

:: Essentials

::  - Aria2: Multi-connection downloads
call scoop install aria2
scoop config aria2-warning-enabled false

::  - Git
call scoop install git

::  - Neovim
call scoop install neovim
call scoop bucket add extras
call scoop install extras/vcredist2022

::  - Noir
git clone https://github.com/sadirano/noir

::  - Clink
:: Install and configure Clink
call scoop install clink
clink inject
clink autorun install
clink set clink.autostart C:\Windows\System32\doskey.exe /macrofile=%~dp0noir/doskey.mac
clink set clink.logo none

:: Optionals

:: Install languages we might need (maybe make it optional)

:: - Python
call scoop install python
C:\Users\Sadirano\scoop\apps\python\current\install-pep-514.reg

call noir/checkhealth

:: If run a second time, update all modules.
call scoop update *
