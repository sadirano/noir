@echo off
if "%~1"=="" (
    title User Scripts
    e user@noir .
    goto :EOF
)
title User Script %~1
if "%~x1"=="" (
    e user@noir "%~1.cmd"
) else (
    e user@noir "%~1"
)
