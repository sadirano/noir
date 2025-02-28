@echo off
title Searching files with %*
set folder=%2
if defined folder set folder=-path %folder%
es %folder% %1 | fzf --bind "enter:execute(nvim {})" 
