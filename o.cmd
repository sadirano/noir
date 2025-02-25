:: Sample usage:
:: Change the directory to the desired destination, or send it in place of the "dest"
::  o %0 %~dpn0 %dest% %1

:: This script allows for a single entry point to navigate to a folder in a single command.

:: Open the Command Line directly at the desired folder from the Start Menu.
:: Open the Folder directly from anywhere by passing -s as argument
:: Open the Folder in Nvim from anywhere by passing -n as argument
:: When inside a command line, navigate to the folder using the same command.
:: Open the file in Nvim from anywhere by passing it as argument

@echo off
cls

pushd %3 || (echo Folder not found & pause & exit /b)

set "arg=%~4"
if /i "%arg:~0,2%"=="-s" (
    start . & goto :end
)
if /i "%arg:~0,2%"=="-n" (
    nvim . 
    popd
    goto :end
)
if not "%arg:~0,1%"=="." (
    nvim "%arg%"
    popd
    goto :end
)

:: Because the start menu will give the complete path to the file.
:: While the cmd line just passes the file name.
if /i "%~1"=="%~2.cmd" (start "" cmd /k)

:end

