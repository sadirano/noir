# PowerShell counterparts of the doskey.mac macros. Wired into the user
# profile by noir.ps1's core-macros step.
function q { exit }
function cc { (Get-Location).Path | Set-Clipboard }
