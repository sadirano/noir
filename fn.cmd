@echo off
title Searching files with %*
es %* | fzf --bind "enter:execute(nvim {})" 
