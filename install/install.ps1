# Noir web installer. Meant to be piped, so it must stay self-contained
# (no $PSScriptRoot, no repo files) and Windows PowerShell 5.1-compatible:
#   irm https://sadirano.com.br/noir | iex
# Direct URL: https://raw.githubusercontent.com/sadirano/noir/main/install/install.ps1
# Installs to %LOCALAPPDATA%\noir by default; override with the NOIR_DIR
# environment variable.

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = "sadirano/noir"
$branch = "main"
$installDir = if ($env:NOIR_DIR) { $env:NOIR_DIR } else { Join-Path $env:LOCALAPPDATA "noir" }

Write-Host "Installing Noir from github.com/$repo to $installDir..." -ForegroundColor Cyan

$tmp = Join-Path $env:TEMP "noir-install"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp | Out-Null

$zip = Join-Path $tmp "noir.zip"
Invoke-WebRequest -Uri "https://github.com/$repo/archive/refs/heads/$branch.zip" -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $tmp

# Merge into the install dir: existing files (e.g. your user\ scripts) survive,
# repo files overwrite their older copies.
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item (Join-Path $tmp "noir-$branch\*") $installDir -Recurse -Force
Remove-Item $tmp -Recurse -Force

Write-Host "Noir installed to $installDir." -ForegroundColor Green
# Fresh machines default to the Restricted execution policy, which blocks
# script files even though the piped installer itself runs; bypass for the run.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installDir "noir.ps1")
