<#
.SYNOPSIS
Automated Windows Setup and Customization Script.

.DESCRIPTION
This script configures a Windows 11 machine for development and aesthetics.
It shows an interactive checklist where you pick the steps to run
(Up/Down or J/K to move, Space to toggle, A to toggle all, Enter to run, Q to quit).
Steps already detected on this machine are marked 'ok' and start unchecked;
re-running a package step updates it instead of reinstalling.

.PARAMETER Yolo
Bypass the checklist and all prompts, answering Yes to everything.

.PARAMETER Doctor
Report which steps are already set up on this machine and exit without changing anything.

.EXAMPLE
.\noir.ps1

.EXAMPLE
.\noir.ps1 -Doctor
#>
# Requires to be run as the user
param (
    [Alias("y")]
    [switch]$Yolo,
    [switch]$Doctor
)

$CategoryColors = @{ "Visual" = "Magenta"; "Application" = "Yellow"; "Configuration" = "Cyan" }

function Get-ScoopCmd {
    # If scoop was just installed, PATH for the current session isn't updated yet,
    # so fall back to the shim path explicitly.
    if (Test-Path "$env:USERPROFILE\scoop\shims\scoop.ps1") {
        return "$env:USERPROFILE\scoop\shims\scoop.ps1"
    }
    return "scoop"
}

function Get-GitCmd {
    if (Test-Path "$env:USERPROFILE\scoop\shims\git.exe") {
        return "$env:USERPROFILE\scoop\shims\git.exe"
    }
    return "git"
}

function Get-NixCmd {
    if (Test-Path "$env:USERPROFILE\scoop\shims\nix.exe") {
        return "$env:USERPROFILE\scoop\shims\nix.exe"
    }
    return "nix"
}

function Test-CommandExists {
    # PATH may not include freshly-created scoop shims in this session, so
    # look at the shims folder directly as well.
    param([string]$Name)
    if (Get-Command $Name -ErrorAction SilentlyContinue) { return $true }
    return [bool]((Test-Path "$env:USERPROFILE\scoop\shims\$Name.exe") -or
                  (Test-Path "$env:USERPROFILE\scoop\shims\$Name.cmd") -or
                  (Test-Path "$env:USERPROFILE\scoop\shims\$Name.ps1"))
}

function Install-ScoopApp {
    # Installs each app, or updates it when a previous install is detected.
    param([string[]]$Apps)
    $scoopCmd = Get-ScoopCmd
    foreach ($app in $Apps) {
        $name = ($app -split '/')[-1]
        if (Test-Path "$env:USERPROFILE\scoop\apps\$name") {
            Write-Host "$name is already installed - checking for updates..." -ForegroundColor Cyan
            & $scoopCmd update $name
        } else {
            Write-Host "Installing $app..." -ForegroundColor Cyan
            & $scoopCmd install $app
        }
    }
}

function Get-StepStatus {
    # $true = detected as already set up, $false = not detected,
    # $null = step has no check or the check itself failed.
    param($Step)
    if (-not $Step.Check) { return $null }
    try { return [bool](& $Step.Check) } catch { return $null }
}

function Show-StepMenu {
    # Arrow-key checkbox picker. Returns @{ Action = "Run"; Names = [string[]] } or
    # @{ Action = "Quit" }; returns $null when the console can't host an interactive
    # menu (tiny window, redirected input) so the caller falls back to per-step prompts.
    param([array]$Steps, [string[]]$CheckedNames)

    $items = @()
    foreach ($step in $Steps) {
        if ($step.IsGatekeeper) {
            $items += @{ Header = $true; Label = "--- Advanced Developer Tools (heavy, case-by-case) ---" }
        } else {
            $items += @{ Header = $false; Name = $step.Name; Label = $step.Prompt; Category = $step.Category; Detail = $step.Detail; Status = $step.Status; Checked = ($CheckedNames -contains $step.Name) }
        }
    }
    $selectable = @(0..($items.Count - 1) | Where-Object { -not $items[$_].Header })
    $pos = 0

    try {
        # Prefer the PowerShell host's measurement: in pseudo-console hosts the
        # raw Console API under-reports the window (or has no handle at all)
        # while $Host.UI.RawUI reports the real size.
        $measure = {
            $s = $Host.UI.RawUI.WindowSize
            if ($s -and $s.Height -gt 4 -and $s.Width -gt 4) { return $s }
            return New-Object System.Management.Automation.Host.Size([Console]::WindowWidth, [Console]::WindowHeight)
        }
        $printHeader = {
            Write-Host "Up/Down (or K/J): move | Space: toggle | A: toggle all | Enter: run selected | Q/Esc: quit" -ForegroundColor Cyan
            Write-Host -NoNewline "Categories: "
            Write-Host -NoNewline "Visual" -ForegroundColor Magenta
            Write-Host -NoNewline " / "
            Write-Host -NoNewline "Application/Programs" -ForegroundColor Yellow
            Write-Host -NoNewline " / "
            Write-Host "Configuration" -ForegroundColor Cyan
        }

        $size = & $measure
        if ($size.Height -lt 15) { return $null }
        if ($size.Width -lt 60) { return $null }
        try { [Console]::CursorVisible = $false } catch {}

        & $printHeader
        $top = 0
        $drawn = $false
        while ($true) {
            # The list claims every row the host reports, minus fixed chrome:
            # 2 header + 2 detail + 1 status + 1 cursor row; scrolling adds the
            # two "... more ..." indicator lines. Re-measured each pass so
            # resizing the window mid-menu grows the list to fill it.
            $newSize = & $measure
            if ($drawn -and ($newSize.Height -ne $size.Height -or $newSize.Width -ne $size.Width)) {
                Clear-Host
                & $printHeader
                $drawn = $false
            }
            $size = $newSize
            $scrolling = $items.Count -gt ($size.Height - 6)
            $viewRows = if ($scrolling) { [Math]::Max(3, $size.Height - 8) } else { $items.Count }
            $redrawLines = $viewRows + 3 + $(if ($scrolling) { 2 } else { 0 })
            if ($drawn) { [Console]::SetCursorPosition(0, [Console]::CursorTop - $redrawLines) }
            $cursorIdx = $selectable[$pos]
            if ($cursorIdx -lt $top) { $top = $cursorIdx }
            if ($cursorIdx -ge $top + $viewRows) { $top = $cursorIdx - $viewRows + 1 }
            $width = $size.Width - 1
            $labelWidth = $width - 29
            if ($scrolling) {
                $aboveText = if ($top -gt 0) { "    ... $top more above ..." } else { "" }
                Write-Host ($aboveText.PadRight($width).Substring(0, $width)) -ForegroundColor DarkGray
            }
            for ($i = $top; $i -lt $top + $viewRows; $i++) {
                $item = $items[$i]
                if ($item.Header) {
                    Write-Host ("      $($item.Label)".PadRight($width).Substring(0, $width)) -ForegroundColor DarkGray
                    continue
                }
                $isCursor = ($i -eq $selectable[$pos])
                $pointer = if ($isCursor) { ">" } else { " " }
                $mark = if ($item.Checked) { "[x]" } else { "[ ]" }
                $stateColor = if ($isCursor) { "Green" } elseif ($item.Checked) { "White" } else { "DarkGray" }
                $nameColor = $CategoryColors[$item.Category]
                if (-not $item.Checked -and -not $isCursor) { $nameColor = "Dark$nameColor" }
                Write-Host -NoNewline " $pointer $mark " -ForegroundColor $stateColor
                Write-Host -NoNewline $item.Name.PadRight(19).Substring(0, 19) -ForegroundColor $nameColor
                # Detection marker: ok = already set up, -- = not detected, blank = no check.
                $statusText = if ($item.Status -eq $true) { " ok" } elseif ($item.Status -eq $false) { " --" } else { "   " }
                $statusColor = if ($item.Status -eq $true) { "DarkGreen" } else { "DarkGray" }
                Write-Host -NoNewline $statusText -ForegroundColor $statusColor
                Write-Host ((" " + $item.Label).PadRight($labelWidth).Substring(0, $labelWidth)) -ForegroundColor $stateColor
            }
            if ($scrolling) {
                $belowCount = $items.Count - ($top + $viewRows)
                $belowText = if ($belowCount -gt 0) { "    ... $belowCount more below ..." } else { "" }
                Write-Host ($belowText.PadRight($width).Substring(0, $width)) -ForegroundColor DarkGray
            }
            # Detail panel: two lines describing the focused item, so the user can
            # deliberate before toggling. Word-wraps to the real console width;
            # only a genuinely narrow window ever truncates (with an ellipsis).
            $focusDetail = [string]$items[$selectable[$pos]].Detail
            $wrapWidth = $width - 4
            $detailLines = @("", "")
            $lineIdx = 0
            foreach ($word in ($focusDetail -split ' ')) {
                $candidate = if ($detailLines[$lineIdx]) { "$($detailLines[$lineIdx]) $word" } else { $word }
                if ($candidate.Length -le $wrapWidth) {
                    $detailLines[$lineIdx] = $candidate
                } else {
                    $lineIdx++
                    if ($lineIdx -ge 2) {
                        $keep = [Math]::Max(0, [Math]::Min($detailLines[1].Length, $wrapWidth - 3))
                        $detailLines[1] = $detailLines[1].Substring(0, $keep) + "..."
                        break
                    }
                    $detailLines[$lineIdx] = $word
                }
            }
            foreach ($line in $detailLines) {
                Write-Host ("    $line".PadRight($width).Substring(0, $width)) -ForegroundColor Gray
            }
            $checkedCount = @($items | Where-Object { -not $_.Header -and $_.Checked }).Count
            $scrollHint = if ($items.Count -gt $viewRows) { " | showing $($top + 1)-$($top + $viewRows) of $($items.Count)" } else { "" }
            Write-Host ("  $checkedCount selected | ok = already set up$scrollHint".PadRight($width).Substring(0, $width)) -ForegroundColor DarkGray
            $drawn = $true

            $key = [Console]::ReadKey($true).Key
            if ($key -eq 'UpArrow' -or $key -eq 'K') {
                $pos = ($pos - 1 + $selectable.Count) % $selectable.Count
            } elseif ($key -eq 'DownArrow' -or $key -eq 'J') {
                $pos = ($pos + 1) % $selectable.Count
            } elseif ($key -eq 'Spacebar') {
                $items[$selectable[$pos]].Checked = -not $items[$selectable[$pos]].Checked
            } elseif ($key -eq 'A') {
                $allChecked = @($items | Where-Object { -not $_.Header -and -not $_.Checked }).Count -eq 0
                foreach ($item in $items) {
                    if (-not $item.Header) { $item.Checked = -not $allChecked }
                }
            } elseif ($key -eq 'Enter') {
                return @{ Action = "Run"; Names = @($items | Where-Object { -not $_.Header -and $_.Checked } | ForEach-Object { $_.Name }) }
            } elseif ($key -eq 'Q' -or $key -eq 'Escape') {
                return @{ Action = "Quit" }
            }
        }
    } catch {
        # Surface the reason instead of silently degrading, so menu bugs
        # don't hide behind the per-step prompt fallback.
        Write-Host "Interactive menu unavailable ($($_.Exception.Message)); falling back to step-by-step prompts." -ForegroundColor DarkGray
        return $null
    } finally {
        try { [Console]::CursorVisible = $true } catch {}
    }
}

function Confirm-Action {
    param([string]$Prompt, [string]$Detail = "")

    if ($Yolo) {
        Write-Host "$Prompt [Auto-Confirmed: Yes]" -ForegroundColor DarkGreen
        return "Yes"
    }

    if ($Detail) { Write-Host "  $Detail" -ForegroundColor DarkGray }
    Write-Host -NoNewline "$Prompt "

    try {
        while ($true) {
            $keyInfo = [System.Console]::ReadKey($true)
            if ($keyInfo.Key -eq 'Enter' -or $keyInfo.Key -eq 'Y') {
                Write-Host "Yes" -ForegroundColor Green
                return "Yes"
            } elseif ($keyInfo.Key -eq 'Escape' -or $keyInfo.Key -eq 'N') {
                Write-Host "Skipped" -ForegroundColor Yellow
                return "No"
            } elseif ($keyInfo.Key -eq 'Q') {
                Write-Host "Quit" -ForegroundColor Red
                return "Quit"
            }
        }
    } catch {
        # No usable console for ReadKey (redirected input). Default to No:
        # a broken console must never auto-accept system changes.
        $response = Read-Host
        if ($response -match "^[Yy]") { return "Yes" }
        if ($response -match "^[Qq]") { return "Quit" }
        return "No"
    }
}

$steps = @(
    @{
        Name = "dark-mode"
        Category = "Visual"
        Prompt = "Enable Dark Mode?"
        Detail = "Switches apps and system UI to the dark theme (per-user registry). Skip if you prefer light mode."
        Check = {
            $p = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
            $p -and $p.AppsUseLightTheme -eq 0 -and $p.SystemUsesLightTheme -eq 0
        }
        Action = {
            Write-Host "Applying Dark Mode..." -ForegroundColor Cyan
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -Type DWord
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 -Type DWord
        }
    },
    @{
        Name = "hide-desktop-icons"
        Category = "Visual"
        Prompt = "Hide Desktop Icons?"
        Detail = "Hides every icon for a clean desktop; the files stay in your Desktop folder and reappear if you toggle back. Skip if you launch things from the desktop."
        Check = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction SilentlyContinue).HideIcons -eq 1 }
        Action = {
            Write-Host "Hiding Desktop Icons..." -ForegroundColor Cyan
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideIcons" -Value 1 -Type DWord
        }
    },
    @{
        Name = "remove-search-bar"
        Category = "Visual"
        Prompt = "Remove Search Bar from Taskbar?"
        Detail = "Hides the taskbar search box; searching still works by pressing Start and typing. Skip if you click the search box."
        Check = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -ErrorAction SilentlyContinue).SearchboxTaskbarMode -eq 0 }
        Action = {
            Write-Host "Removing Search Bar..." -ForegroundColor Cyan
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
        }
    },
    @{
        Name = "clear-taskbar"
        Category = "Visual"
        Prompt = "Remove all shortcuts from the taskbar?"
        Detail = "Unpins everything for a minimal taskbar - the Noir workflow launches apps from Win+R instead. Repin favorites anytime. Skip if you rely on pins."
        Action = {
            Write-Host "Removing Taskbar Pinned Items..." -ForegroundColor Cyan
            $taskbandPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
            if (Test-Path $taskbandPath) {
                Remove-Item -Path $taskbandPath -Recurse -Force
            }
        }
    },
    @{
        Name = "taskbar-autohide"
        Category = "Visual"
        Prompt = "Enable Auto-Hide for Taskbar?"
        Detail = "The taskbar slides away until the mouse touches the screen edge, freeing vertical space. Skip if you glance at the clock/tray a lot."
        Check = {
            $s = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" -Name Settings -ErrorAction SilentlyContinue).Settings
            $s -and $s.Length -gt 8 -and $s[8] -eq 3
        }
        Action = {
            Write-Host "Enabling Taskbar Auto-hide..." -ForegroundColor Cyan
            $stuckRects3Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
            if (Test-Path $stuckRects3Path) {
                $settings = Get-ItemProperty -Path $stuckRects3Path -Name "Settings"
                $bytes = $settings.Settings
                if ($bytes.Length -gt 8 -and $bytes[8] -ne 3) {
                    $bytes[8] = 3
                    Set-ItemProperty -Path $stuckRects3Path -Name "Settings" -Value $bytes
                }
            }
        }
    },
    @{
        Name = "black-wallpaper"
        Category = "Visual"
        Prompt = "Change Wallpaper to Solid Black?"
        Detail = "Solid black background - the noir look, easy on OLEDs, zero distraction. Skip to keep your current wallpaper."
        Check = {
            ((Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -ErrorAction SilentlyContinue).WallPaper -eq "") -and
            ((Get-ItemProperty -Path "HKCU:\Control Panel\Colors" -ErrorAction SilentlyContinue).Background -eq "0 0 0")
        }
        Action = {
            Write-Host "Setting Wallpaper to Solid Black..." -ForegroundColor Cyan
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallPaper" -Value ""
            Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value "0 0 0"

            $code = @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
            [Wallpaper]::SystemParametersInfo(0x0014, 0, "", 0x01 -bOR 0x02) | Out-Null
        }
    },
    @{
        Name = "nags-and-ads"
        Category = "Configuration"
        Prompt = "Disable 'finish setting up' nag screens and ad personalization?"
        Detail = "Registry opt-outs for the 'finish setting up your device' screen, tips, and personalized-ads ID. Purely less noise; rarely worth skipping."
        Check = {
            ((Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -ErrorAction SilentlyContinue).ScoobeSystemSettingEnabled -eq 0) -and
            ((Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -ErrorAction SilentlyContinue).Enabled -eq 0)
        }
        Action = {
            Write-Host "Disabling setup nag screens and ad personalization..." -ForegroundColor Cyan
            # Disable 'Let's finish setting up your device'
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            # Disable Windows Welcome Experience
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            # Disable Tailored Experiences (Diagnostic Data)
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            # Disable Advertising ID
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

            Write-Host "Disabled successfully!" -ForegroundColor Green
        }
    },
    @{
        Name = "noir-path"
        Category = "Configuration"
        Prompt = "Add Noir's 'core' commands and 'user' scripts folders to your PATH?"
        Detail = "Puts core\ (adm, env, hosts, u, ...) and your personal user\ folder on the user PATH so they run from Win+R or any shell. Most of Noir assumes this."
        Check = {
            $normalized = @(([Environment]::GetEnvironmentVariable("Path", "User") -split ";" | Where-Object { $_ }) | ForEach-Object { $_.TrimEnd("\") })
            ($normalized -contains (Join-Path $PSScriptRoot "core")) -and ($normalized -contains (Join-Path $PSScriptRoot "user"))
        }
        Action = {
            $noirDir = $PSScriptRoot
            $coreDir = Join-Path $noirDir "core"
            $userDir = Join-Path $noirDir "user"
            if (!(Test-Path $userDir)) {
                Write-Host "Creating user scripts folder at $userDir..." -ForegroundColor Cyan
                New-Item -ItemType Directory -Path $userDir | Out-Null
            }

            $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
            $parts = @($currentPath -split ";" | Where-Object { $_ })
            $normalized = @($parts | ForEach-Object { $_.TrimEnd("\") })
            $added = @()
            foreach ($dir in @($coreDir, $userDir)) {
                if ($normalized -notcontains $dir.TrimEnd("\")) {
                    $parts += $dir
                    $added += $dir
                }
            }
            if ($added) {
                [Environment]::SetEnvironmentVariable("Path", ($parts -join ";"), "User")
                Write-Host "Added to user PATH: $($added -join '; ')" -ForegroundColor Green
                Write-Host "Open a new terminal for the PATH change to take effect." -ForegroundColor Yellow
            } else {
                Write-Host "Noir folders are already on PATH." -ForegroundColor Green
            }
        }
    },
    @{
        Name = "core-macros"
        Category = "Configuration"
        Prompt = "Register Noir core macros (doskey cc/q for cmd, q/cc functions for PowerShell)?"
        Detail = "Appends doskey.mac to cmd's AutoRun and dot-sources core.ps1 from your PowerShell profiles (cc copies the current path, q exits the shell); entries left over from an old install path are repaired in place. Skip if you curate your own profiles."
        Check = {
            # Matching just the marker/filename isn't enough: a profile line left
            # over from an old install path still matches while the file it points
            # at is gone. Verify the registered paths point at *this* install.
            $macFile = Join-Path $PSScriptRoot "core\doskey.mac"
            $corePs1 = Join-Path $PSScriptRoot "core\core.ps1"
            $autoRun = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Command Processor" -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
            if (-not ($autoRun -match [regex]::Escape($macFile))) { return $false }
            $docs = [Environment]::GetFolderPath("MyDocuments")
            $profileDirs = @(Join-Path $docs "WindowsPowerShell")
            if (Get-Command pwsh -ErrorAction SilentlyContinue) { $profileDirs += Join-Path $docs "PowerShell" }
            foreach ($dir in $profileDirs) {
                $profilePath = Join-Path $dir "profile.ps1"
                if (-not ((Test-Path $profilePath) -and (Select-String -Path $profilePath -SimpleMatch $corePs1 -Quiet))) { return $false }
            }
            $true
        }
        Action = {
            $coreDir = Join-Path $PSScriptRoot "core"

            # cmd: doskey macros via AutoRun
            $key = "HKCU:\Software\Microsoft\Command Processor"
            $macFile = Join-Path $coreDir "doskey.mac"
            $macroCmd = "doskey /macrofile=`"$macFile`""
            $autoRun = (Get-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
            if ($autoRun -match [regex]::Escape($macFile)) {
                Write-Host "cmd AutoRun already loads this doskey.mac - skipping." -ForegroundColor Green
            } elseif ($autoRun -match 'doskey\.mac') {
                # A doskey.mac entry from an old install path: rewrite it in place.
                $updated = $autoRun -replace '\S*doskey(?:\.exe)?\s+/macrofile=(?:"[^"]*doskey\.mac"|\S*doskey\.mac)', $macroCmd
                if ($updated -eq $autoRun) {
                    # Unrecognized shape; append the correct command instead.
                    $updated = "$autoRun & $macroCmd"
                }
                Set-ItemProperty -Path $key -Name AutoRun -Value $updated
                Write-Host "Updated cmd AutoRun to load $macFile." -ForegroundColor Green
            } else {
                if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
                # Append rather than overwrite: other tools (e.g. clink) hook AutoRun too.
                $new = if ($autoRun) { "$autoRun & $macroCmd" } else { $macroCmd }
                Set-ItemProperty -Path $key -Name AutoRun -Value $new
                Write-Host "Registered doskey macros in cmd AutoRun." -ForegroundColor Green
            }

            # PowerShell: dot-source core.ps1 from the user profile(s)
            $marker = "# noir-core"
            $corePs1 = Join-Path $coreDir "core.ps1"
            $line = ". `"$corePs1`"  $marker"
            $docs = [Environment]::GetFolderPath("MyDocuments")
            $profileDirs = @(Join-Path $docs "WindowsPowerShell")
            if (Get-Command pwsh -ErrorAction SilentlyContinue) {
                $profileDirs += Join-Path $docs "PowerShell"
            }
            foreach ($dir in $profileDirs) {
                $profilePath = Join-Path $dir "profile.ps1"
                if (Test-Path $profilePath) {
                    if (Select-String -Path $profilePath -SimpleMatch $corePs1 -Quiet) {
                        Write-Host "PowerShell profile already loads core.ps1 - skipping ($profilePath)." -ForegroundColor Green
                        continue
                    }
                    if (Select-String -Path $profilePath -SimpleMatch $marker -Quiet) {
                        # A noir-core line pointing at an old install path: rewrite it in place.
                        $content = @(Get-Content $profilePath) | ForEach-Object {
                            if ($_ -like "*$marker*") { $line } else { $_ }
                        }
                        Set-Content -Path $profilePath -Value $content -Encoding utf8
                        Write-Host "Updated stale noir-core line in $profilePath." -ForegroundColor Green
                        continue
                    }
                }
                New-Item -ItemType Directory -Force -Path $dir | Out-Null
                Add-Content -Path $profilePath -Value $line
                Write-Host "Registered core.ps1 in $profilePath." -ForegroundColor Green
            }
            Write-Host "Open a new cmd or PowerShell window to pick up the macros." -ForegroundColor Yellow
        }
    },
    @{
        Name = "scoop-nix"
        Category = "Application"
        Prompt = "Install Scoop and your Nix project?"
        Detail = "Installs the Scoop package manager, adds the sadirano bucket, and installs nix (directory aliases: o/e/r/sg...). Pulls bat, fzf, ripgrep, fd, Neovim, and clink along as dependencies."
        Check = { Test-CommandExists nix }
        Action = {
            Write-Host "Checking for Scoop..." -ForegroundColor Cyan
            if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
                Write-Host "Setting execution policy to RemoteSigned for CurrentUser (required by the Scoop installer)..." -ForegroundColor Yellow
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Write-Host "Installing Scoop..." -ForegroundColor Cyan
                Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
            } else {
                Write-Host "Scoop is already installed." -ForegroundColor Green
            }

            $scoopCmd = Get-ScoopCmd

            # Scoop requires Git to add custom buckets.
            if (!(Get-Command git -ErrorAction SilentlyContinue) -and !(Test-Path "$env:USERPROFILE\scoop\apps\git")) {
                Write-Host "Git is required for custom buckets. Installing Git via Scoop..." -ForegroundColor Cyan
                & $scoopCmd install git
            }

            Write-Host "Adding 'sadirano' bucket..." -ForegroundColor Cyan
            & $scoopCmd bucket add sadirano https://github.com/sadirano/bucket

            Install-ScoopApp nix

            # Note: C compilers were moved to an optional step to save time if not needed
        }
    },
    @{
        Name = "noir-alias"
        Category = "Configuration"
        Prompt = "Register the 'noir' nix alias for this folder?"
        Detail = "Runs 'nix noir <this folder>' so alias-based commands resolve to this install - u relies on it to edit user\ scripts via 'e user@noir'. Requires nix (scoop-nix step)."
        Check = {
            if (-not (Test-CommandExists nix)) { return $false }
            $resolved = [string](& (Get-NixCmd) noir 2>$null | Select-Object -First 1)
            $resolved -and ($resolved.Trim().TrimEnd("\") -eq $PSScriptRoot.TrimEnd("\"))
        }
        Action = {
            $nixCmd = Get-NixCmd
            if ($nixCmd -eq "nix" -and !(Get-Command nix -ErrorAction SilentlyContinue)) {
                Write-Host "nix is not installed; run the scoop-nix step first, then rerun this one." -ForegroundColor Yellow
                return
            }
            & $nixCmd noir $PSScriptRoot
            Write-Host "nix alias 'noir' -> $PSScriptRoot" -ForegroundColor Green
        }
    },
    @{
        Name = "clink"
        Category = "Application"
        Prompt = "Install clink (cmd autosuggestions) and hook the core doskey macros into it?"
        Detail = "clink gives cmd fish-style autosuggestions and sane line editing; this wires it into every cmd session and autoloads the core macros through it. Skip if you never live in cmd."
        Check = { Test-CommandExists clink }
        Action = {
            Install-ScoopApp clink

            $clinkCmd = "$env:USERPROFILE\scoop\shims\clink.cmd"
            if (!(Test-Path $clinkCmd)) { $clinkCmd = "clink" }

            $macFile = Join-Path $PSScriptRoot "core\doskey.mac"
            & $clinkCmd autorun install | Out-Null
            & $clinkCmd set clink.autostart "$env:SystemRoot\System32\doskey.exe /macrofile=$macFile" | Out-Null
            & $clinkCmd set clink.logo none | Out-Null
            & $clinkCmd set autosuggest.inline true | Out-Null
            Write-Host "clink installed; autorun and core macros configured." -ForegroundColor Green
        }
    },
    @{
        Name = "neovim"
        Category = "Application"
        Prompt = "Install Neovim?"
        Detail = "Standalone Neovim via Scoop. Redundant if you take the scoop-nix step - nix already brings Neovim as a dependency."
        Check = { Test-CommandExists nvim }
        Action = {
            Install-ScoopApp neovim
        }
    },
    @{
        Name = "bat"
        Category = "Application"
        Prompt = "Install bat (cat with syntax highlighting)?"
        Detail = "Nicer file previews in the terminal. Redundant if you take the scoop-nix step - it arrives as a nix dependency."
        Check = { Test-CommandExists bat }
        Action = {
            Install-ScoopApp bat
        }
    },
    @{
        Name = "fzf"
        Category = "Application"
        Prompt = "Install fzf (fuzzy finder, used by nix's pickers)?"
        Detail = "The fuzzy picker behind nix's sg/ff and many shell workflows. Redundant if you take the scoop-nix step - it arrives as a nix dependency."
        Check = { Test-CommandExists fzf }
        Action = {
            Install-ScoopApp fzf
        }
    },
    @{
        Name = "rga"
        Category = "Application"
        Prompt = "Install ripgrep-all (rga - search inside PDFs, office docs, archives; powers nix's 'sg --all')?"
        Detail = "Optional nix companion: lets 'sg --all' grep inside PDFs, office documents, and archives. Skip if plain-text search covers your needs."
        Check = { Test-CommandExists rga }
        Action = {
            Install-ScoopApp rga
        }
    },
    @{
        Name = "terminal-fonts"
        Category = "Application"
        Prompt = "Install Windows Terminal and Nerd Fonts?"
        Detail = "Installs Windows Terminal (if missing) plus the Mononoki Nerd Font - the icons and glyphs the terminal config and Neovim UI expect."
        Check = { (Test-Path "$env:USERPROFILE\scoop\apps\Mononoki-NF-Mono") -and (Test-CommandExists wt) }
        Action = {
            $scoopCmd = Get-ScoopCmd

            Write-Host "Adding 'nerd-fonts' and 'extras' buckets..." -ForegroundColor Cyan
            & $scoopCmd bucket add nerd-fonts
            & $scoopCmd bucket add extras

            Install-ScoopApp nerd-fonts/Mononoki-NF-Mono

            if (Get-Command wt -ErrorAction SilentlyContinue) {
                Write-Host "Windows Terminal is already installed on this system. Skipping Scoop installation." -ForegroundColor Yellow
            } else {
                Write-Host "Installing Windows Terminal..." -ForegroundColor Cyan
                & $scoopCmd install extras/windows-terminal
            }
        }
    },
    @{
        Name = "nvim-config"
        Category = "Configuration"
        Prompt = "Clone Neovim configuration?"
        Detail = "Clones the Neovim config repo into place so nvim opens fully set up. Skip on machines where you will not edit in Neovim."
        Check = { Test-Path "$env:LOCALAPPDATA\nvim\.git" }
        Action = {
            $nvimDir = "$env:LOCALAPPDATA\nvim"
            $gitCmd = Get-GitCmd

            if (Test-Path $nvimDir) {
                Write-Host "Neovim config directory already exists. Pulling latest changes..." -ForegroundColor Yellow
                Push-Location $nvimDir
                & $gitCmd pull
                Pop-Location
            } else {
                Write-Host "Cloning sadirano/nvim..." -ForegroundColor Cyan
                & $gitCmd clone https://github.com/sadirano/nvim $nvimDir
            }
        }
    },
    @{
        Name = "dotfiles"
        Category = "Configuration"
        Prompt = "Clone Dotfiles?"
        Detail = "Clones the personal dotfiles repo. Skip on shared or throwaway machines that should not carry your configs."
        Check = { Test-Path "$env:USERPROFILE\dotfiles\.git" }
        Action = {
            $dotfilesDir = "$env:USERPROFILE\dotfiles"
            $gitCmd = Get-GitCmd

            if (Test-Path $dotfilesDir) {
                Write-Host "Dotfiles directory already exists. Pulling latest changes..." -ForegroundColor Yellow
                Push-Location $dotfilesDir
                & $gitCmd pull
                Pop-Location
            } else {
                Write-Host "Cloning sadirano/dotfiles..." -ForegroundColor Cyan
                & $gitCmd clone https://github.com/sadirano/dotfiles $dotfilesDir
            }
        }
    },
    @{
        Name = "terminal-config"
        Category = "Configuration"
        Prompt = "Configure Windows Terminal preferences?"
        Detail = "Writes the Windows Terminal settings (font, scheme, default profile). Overwrites any preferences you already tuned there."
        Check = {
            $del = Get-ItemProperty -Path "HKCU:\Console\%%Startup" -ErrorAction SilentlyContinue
            if (-not $del -or $del.DelegationTerminal -ne "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}") { return $false }
            $settingsFile = @(
                "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
            ) | Where-Object { Test-Path $_ } | Select-Object -First 1
            [bool]($settingsFile -and ((Get-Content $settingsFile -Raw) -match 'Tokyo Night'))
        }
        Action = {
            Write-Host "Setting Windows Terminal as the Default Terminal Application..." -ForegroundColor Cyan
            $delegationConsole = "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
            $delegationTerminal = "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"

            # A wrong or unregistered GUID doesn't error - Windows just silently
            # falls back to another terminal - so refuse to write the pair unless
            # both resolve to a registered COM class (packaged or unpackaged).
            $guidRegistered = {
                param($guid)
                (Test-Path "HKLM:\SOFTWARE\Classes\PackagedCom\ClassIndex\$guid") -or
                (Test-Path "HKLM:\SOFTWARE\Classes\CLSID\$guid") -or
                (Test-Path "HKCU:\Software\Classes\CLSID\$guid")
            }
            if ((& $guidRegistered $delegationConsole) -and (& $guidRegistered $delegationTerminal)) {
                $delegationPath = "HKCU:\Console\%%Startup"
                if (!(Test-Path $delegationPath)) { New-Item -Path $delegationPath -Force | Out-Null }
                Set-ItemProperty -Path $delegationPath -Name "DelegationConsole" -Value $delegationConsole -Type String
                Set-ItemProperty -Path $delegationPath -Name "DelegationTerminal" -Value $delegationTerminal -Type String
                Write-Host "Default terminal set to Windows Terminal." -ForegroundColor Green
            } else {
                Write-Host "WARNING: Windows Terminal's delegation classes are not registered on this machine (is it installed?). Leaving the default terminal unchanged." -ForegroundColor Yellow
            }

            $wtSettingsPaths = @(
                "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
            )
            $settingsFile = $wtSettingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

            if ($settingsFile) {
                if (Test-Path "$settingsFile.bak") {
                    Write-Host "Keeping existing settings.json.bak (your pre-Noir settings)." -ForegroundColor DarkGray
                } else {
                    Write-Host "Backing up settings.json to settings.json.bak..." -ForegroundColor Cyan
                    Copy-Item $settingsFile "$settingsFile.bak"
                }

                Write-Host "Updating Windows Terminal settings.json..." -ForegroundColor Cyan
                $jsonContent = Get-Content $settingsFile -Raw
                try {
                    $settings = $jsonContent | ConvertFrom-Json
                } catch {
                    # Windows PowerShell 5.1 can't parse the // comment lines Windows Terminal
                    # generates in a fresh settings.json; strip them and retry.
                    $stripped = ($jsonContent -split "`r?`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
                    $settings = $stripped | ConvertFrom-Json
                }

                $settings | Add-Member -MemberType NoteProperty -Name "defaultProfile" -Value "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}" -Force
                $settings | Add-Member -MemberType NoteProperty -Name "defaultTerminal" -Value $delegationTerminal -Force
                $settings | Add-Member -MemberType NoteProperty -Name "language" -Value "en-US" -Force
                $settings | Add-Member -MemberType NoteProperty -Name "launchMode" -Value "maximizedFocus" -Force

                if ($null -eq $settings.profiles) {
                    $settings | Add-Member -MemberType NoteProperty -Name "profiles" -Value ([PSCustomObject]@{defaults=[PSCustomObject]@{}}) -Force
                } elseif ($null -eq $settings.profiles.defaults) {
                    $settings.profiles | Add-Member -MemberType NoteProperty -Name "defaults" -Value ([PSCustomObject]@{}) -Force
                }

                $settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name "colorScheme" -Value "Tokyo Night" -Force
                $settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name "opacity" -Value 89 -Force

                $settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name "font" -Value ([PSCustomObject]@{face="Mononoki Nerd Font Mono"; size=16; weight="bold"}) -Force

                $hasTokyoNight = $false
                if ($null -ne $settings.schemes) {
                    foreach ($s in $settings.schemes) {
                        if ($s.name -eq "Tokyo Night") { $hasTokyoNight = $true }
                    }
                }

                if (-not $hasTokyoNight) {
                    $tokyoNightScheme = [PSCustomObject]@{
                        name = "Tokyo Night"
                        foreground = "#C0CAF5"
                        background = "#1A1B26"
                        selectionBackground = "#283457"
                        black = "#15161E"
                        blue = "#7AA2F7"
                        brightBlack = "#414868"
                        brightBlue = "#7AA2F7"
                        brightCyan = "#7DCFFF"
                        brightGreen = "#9ECE6A"
                        brightPurple = "#9D7CD8"
                        brightRed = "#F7768E"
                        brightWhite = "#C0CAF5"
                        brightYellow = "#E0AF68"
                        cursorColor = "#C0CAF5"
                        cyan = "#7DCFFF"
                        green = "#9ECE6A"
                        purple = "#BB9AF7"
                        red = "#F7768E"
                        white = "#A9B1D6"
                        yellow = "#E0AF68"
                    }
                    $newSchemes = @()
                    if ($null -ne $settings.schemes) { $newSchemes += $settings.schemes }
                    $newSchemes += $tokyoNightScheme
                    $settings | Add-Member -MemberType NoteProperty -Name "schemes" -Value $newSchemes -Force
                }

                $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding utf8
                Write-Host "Windows Terminal configuration updated successfully!" -ForegroundColor Green
            } else {
                Write-Host "Could not find Windows Terminal settings.json. You might need to open Terminal at least once." -ForegroundColor Yellow
            }
        }
    },
    @{
        Name = "dev-tools"
        Prompt = "Proceed to Advanced Developer Tools section? [WARNING: Heavy, niche, case-by-case tools]"
        Detail = "Gate for the heavy developer tools below; answering No skips the whole section."
        Action = {
            Write-Host "Entering Advanced Developer Tools section..." -ForegroundColor Magenta
        }
        IsGatekeeper = $true
    },
    @{
        Name = "nodejs"
        Category = "Application"
        Prompt = "Install Node.js? (Required for Mason LSPs like tsserver, prettier, pyright)"
        Detail = "Runtime for Neovim's Mason-managed language servers and formatters (tsserver, prettier, pyright) and general JS work. Skip if none of that runs here."
        Check = { Test-CommandExists node }
        Action = {
            Install-ScoopApp nodejs
        }
    },
    @{
        Name = "python"
        Category = "Application"
        Prompt = "Install Python? (Required for Mason tools like xmlformatter, black)"
        Detail = "Runtime for Mason tools like black and xmlformatter, plus everyday scripting. Skip if no Python tooling is needed on this machine."
        Check = {
            if (Test-Path "$env:USERPROFILE\scoop\shims\python.exe") { return $true }
            $p = Get-Command python -ErrorAction SilentlyContinue
            # The WindowsApps 'python' is a Store stub, not a real install.
            [bool]($p -and $p.Source -notmatch 'WindowsApps')
        }
        Action = {
            Install-ScoopApp python
        }
    },
    @{
        Name = "c-build-tools"
        Category = "Application"
        Prompt = "Install C Build Tools (gcc, make, tree-sitter)? [~500MB]"
        Detail = "Compilers for building tree-sitter grammars and native extensions - roughly 500MB. Skip unless Neovim tree-sitter or C builds matter here."
        Check = { (Test-CommandExists gcc) -and (Test-CommandExists make) }
        Action = {
            Install-ScoopApp gcc, make, tree-sitter
        }
    },
    @{
        Name = "ripgrep-fd"
        Category = "Application"
        Prompt = "Install ripgrep (rg) and fd? (Mandatory for fast Telescope searches)"
        Detail = "rg and fd power fast Telescope searches in Neovim and are cheap, broadly useful CLI staples (also nix dependencies)."
        Check = { (Test-CommandExists rg) -and (Test-CommandExists fd) }
        Action = {
            Install-ScoopApp ripgrep, fd
        }
    },
    @{
        Name = "pwsh-powertoys"
        Category = "Application"
        Prompt = "Install PowerShell 7 and PowerToys (for remapping Caps Lock)?"
        Detail = "Modern PowerShell plus PowerToys utilities (Keyboard Manager remaps Caps Lock, FancyZones, etc.). Skip if stock shell and keys are fine."
        Check = {
            (Test-CommandExists pwsh) -and
            ((Test-Path "$env:USERPROFILE\scoop\apps\powertoys") -or (Test-Path "$env:ProgramFiles\PowerToys"))
        }
        Action = {
            $scoopCmd = Get-ScoopCmd
            & $scoopCmd bucket add extras
            Install-ScoopApp pwsh, powertoys
        }
    },
    @{
        Name = "git-identity"
        Category = "Configuration"
        Prompt = "Configure Git Global Identity (Name & Email)?"
        Detail = "Sets git config --global user.name and user.email so commits are attributed correctly. Skips itself if an identity is already configured."
        Check = {
            $gitCmd = Get-GitCmd
            if ($gitCmd -eq "git" -and !(Get-Command git -ErrorAction SilentlyContinue)) { return $false }
            [bool]((& $gitCmd config --global user.name 2>$null) -and (& $gitCmd config --global user.email 2>$null))
        }
        Action = {
            $gitCmd = Get-GitCmd
            if ($gitCmd -eq "git" -and !(Get-Command git -ErrorAction SilentlyContinue)) {
                Write-Host "Git is not installed. Skipping git identity." -ForegroundColor Yellow
                return
            }

            $existingName = & $gitCmd config --global user.name 2>$null
            $existingEmail = & $gitCmd config --global user.email 2>$null
            if ($existingName -and $existingEmail) {
                Write-Host "Git identity already configured ($existingName <$existingEmail>). Skipping." -ForegroundColor Green
                return
            }

            if ($Yolo) {
                Write-Host "Yolo mode can't prompt for an identity; run the git-identity step interactively later." -ForegroundColor Yellow
                return
            }
            $name = Read-Host "Enter Git User Name (e.g., John Doe)"
            $email = Read-Host "Enter Git Email (e.g., john@example.com)"

            if ($name -and $email) {
                & $gitCmd config --global user.name $name
                & $gitCmd config --global user.email $email
                Write-Host "Git identity configured." -ForegroundColor Green
            } else {
                Write-Host "Skipped git config." -ForegroundColor Yellow
            }
        }
    },
    @{
        Name = "remove-onedrive"
        Category = "Application"
        Prompt = "Uninstall Microsoft OneDrive? [WARNING: Permanently removes OneDrive]"
        Detail = "Removes OneDrive and its autostart hooks. Local files stay, but sync stops - skip if anything on this machine lives in OneDrive."
        Check = { -not (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe") }
        Action = {
            if (-not $Yolo) {
                $confirm = Read-Host "Are you absolutely sure you want to uninstall OneDrive? Type 'yes' to confirm"
                if ($confirm -ne "yes") {
                    Write-Host "Aborted OneDrive uninstall." -ForegroundColor Yellow
                    return
                }
            }

            Write-Host "Killing OneDrive processes..." -ForegroundColor Cyan
            Stop-Process -Name "OneDrive" -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2

            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-Host "Uninstalling OneDrive via winget..." -ForegroundColor Cyan
                & winget uninstall Microsoft.OneDrive --accept-source-agreements --silent
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "OneDrive uninstalled successfully!" -ForegroundColor Green
                    return
                }
                Write-Host "winget uninstall did not succeed. Falling back to OneDriveSetup.exe..." -ForegroundColor Yellow
            }

            Write-Host "Executing OneDrive uninstaller..." -ForegroundColor Cyan
            $candidates = @(
                "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe",
                "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
            )
            # Per-user installs on current Win11 builds keep the installer under LOCALAPPDATA
            if (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive") {
                $candidates += Get-ChildItem "$env:LOCALAPPDATA\Microsoft\OneDrive" -Filter "OneDriveSetup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
            }
            $onedriveSetup = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($onedriveSetup) {
                & $onedriveSetup /uninstall
                Write-Host "OneDrive uninstalled successfully!" -ForegroundColor Green
            } else {
                Write-Host "OneDrive installer not found. It might already be uninstalled." -ForegroundColor Yellow
            }
        }
    },
    @{
        Name = "windhawk"
        Category = "Application"
        Prompt = "Install Windhawk? (Used for advanced Windows UI mods like 'Taskbar on top')"
        Detail = "Mod platform for Windows UI tweaks like moving the taskbar to the top. Niche - skip unless you want to customize the shell beyond stock options."
        Check = {
            [bool](@(
                "$env:LOCALAPPDATA\Programs\Windhawk\windhawk.exe",
                "$env:PROGRAMFILES\Windhawk\windhawk.exe",
                "${env:ProgramFiles(x86)}\Windhawk\windhawk.exe"
            ) | Where-Object { Test-Path $_ })
        }
        Action = {
            Write-Host "Installing Windhawk via Winget..." -ForegroundColor Cyan
            & winget install RamenSoftware.Windhawk --accept-package-agreements --accept-source-agreements --silent

            Write-Host "`n========================================================" -ForegroundColor Magenta
            Write-Host "Windhawk is installed! Three clicks left, which have to happen in its UI:" -ForegroundColor Magenta
            Write-Host "1. Click Explore (top of the home screen)." -ForegroundColor Yellow
            Write-Host "2. Search for 'Taskbar on top' - the mod by m417z." -ForegroundColor Yellow
            Write-Host "3. Open its details and click Install. It compiles, injects into Explorer, and your taskbar jumps to the top immediately!" -ForegroundColor Yellow

            Write-Host "========================================================`n" -ForegroundColor Magenta

            Write-Host "Launching Windhawk..." -ForegroundColor Cyan
            $windhawkPaths = @(
                "$env:LOCALAPPDATA\Programs\Windhawk\windhawk.exe",
                "$env:PROGRAMFILES\Windhawk\windhawk.exe",
                "${env:ProgramFiles(x86)}\Windhawk\windhawk.exe"
            )
            foreach ($path in $windhawkPaths) {
                if (Test-Path $path) {
                    Start-Process $path
                    break
                }
            }
        }
    }
)

Write-Host "Starting Windows 11 Customization...`n"

# Probe what is already set up so the checklist (and -Doctor) can show it.
foreach ($step in $steps) { $step.Status = Get-StepStatus $step }

if ($Doctor) {
    Write-Host "Noir doctor - detected state of each step:`n" -ForegroundColor Cyan
    foreach ($step in $steps) {
        if ($step.IsGatekeeper) { continue }
        if ($step.Status -eq $true) {
            Write-Host -NoNewline "   ok  " -ForegroundColor Green
        } elseif ($step.Status -eq $false) {
            Write-Host -NoNewline "   --  " -ForegroundColor Yellow
        } else {
            Write-Host -NoNewline "    ?  " -ForegroundColor DarkGray
        }
        Write-Host -NoNewline $step.Name.PadRight(20) -ForegroundColor $CategoryColors[$step.Category]
        Write-Host $step.Prompt -ForegroundColor Gray
    }
    $okCount = @($steps | Where-Object { $_.Status -eq $true }).Count
    $missingCount = @($steps | Where-Object { $_.Status -eq $false }).Count
    Write-Host "`n$okCount set up, $missingCount not detected (? = no check for that step). Nothing was changed." -ForegroundColor Cyan
    return
}

$anyChanges = $false
$quitRequested = $false
$menuSelection = $null

if (-not $Yolo) {
    # Pre-check only what isn't already set up.
    $preChecked = @($steps | Where-Object { -not $_.IsGatekeeper -and $_.Status -ne $true } | ForEach-Object { $_.Name })
    $menuSelection = Show-StepMenu -Steps $steps -CheckedNames $preChecked
    if ($null -ne $menuSelection -and $menuSelection.Action -eq "Quit") {
        Write-Host "Quitting script. Nothing was changed." -ForegroundColor Magenta
        $quitRequested = $true
    }
}

if (-not $quitRequested) {
    if ($null -ne $menuSelection) {
        # Menu mode: run exactly what was checked, no per-step confirmation.
        foreach ($step in $steps) {
            if ($menuSelection.Names -contains $step.Name) {
                $stepColor = $CategoryColors[$step.Category]
                if (-not $stepColor) { $stepColor = "Cyan" }
                Write-Host "`n[$($step.Name)] $($step.Prompt)" -ForegroundColor $stepColor
                & $step.Action
                $anyChanges = $true
            }
        }
    } else {
        # Yolo or menu-less fallback: prompt step by step (Yolo auto-confirms).
        Write-Host "Options: [Y=Yes / N=No / Esc=Skip / Q=Quit] (Default: Yes)`n" -ForegroundColor Cyan

        for ($i = 0; $i -lt $steps.Length; $i++) {
            $step = $steps[$i]

            $statusNote = if ($step.Status -eq $true) { " (already set up)" } else { "" }
            $choice = Confirm-Action -Prompt "$($i + 1). [$($step.Name)]$statusNote $($step.Prompt)" -Detail $step.Detail

            if ($choice -eq "Quit") {
                Write-Host "Quitting script." -ForegroundColor Magenta
                $quitRequested = $true
                break
            }

            if ($choice -eq "Yes") {
                & $step.Action
                $anyChanges = $true
            } elseif ($choice -eq "No" -and $step.IsGatekeeper) {
                Write-Host "Skipping the Advanced Developer Tools section..." -ForegroundColor Yellow
                break
            }
        }
    }
}

if (-not $quitRequested) {
    if ($anyChanges) {
        $choice = Confirm-Action -Prompt "Restart Windows Explorer now to apply all changes?"
        if ($choice -eq "Yes") {
            Write-Host "Restarting Windows Explorer..." -ForegroundColor Cyan
            taskkill /f /im explorer.exe
            Start-Sleep -Seconds 1
            Start-Process explorer.exe
        } else {
            Write-Host "Please restart your computer or sign out to see all changes." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No changes were made."
    }
    Write-Host "Done!" -ForegroundColor Green
}
